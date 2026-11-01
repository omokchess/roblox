--!strict
--[[
	SpaceLayer — 칼리스토 '우주를 담은 몸'(2026-11-01 사용자: "우주를 담은 느낌은 모델링보다 레이어 같은 걸 이용해서
	특정 공간에 우주 이미지 자체를 갖다 때려박은 느낌" · "머리는 동그라미 말고 로블록스 아바타 머리에 빛나는 하얀 윤곽").

	화면 위 겹(ScreenGui) 하나에, 몸 부품마다 그 부품이 화면에 그리는 실제 윤곽(고전 머리 모양 · R6 상자 — 3D 표본 점을 화면에 비춘
	볼록 껍질)을 매 프레임 가로 띠로 잘게 썰어 띠마다 우주 그림을 **화면에 고정**해 담고, 윤곽선엔 빛나는 하얀 테두리를 두른다.
	몸이 움직여도 별은 화면에 박힌 채, 아바타 윤곽만 그 위를 지나가는 '오려 낸 창'(포토샵 클리핑 레이어처럼).
	띠는 회전 없는 Frame 의 ClipsDescendants 로 자른다(CanvasGroup 은 이 환경에서 그림을 네모로 통째로 내보냈다).
	앞 겹(작은 타일, 반투명)은 몸을 조금 따라가 깊이감, 둘 다 아주 천천히 흐른다. 가까운 부품이 위에 그려지게 깊이로 겹 순서를 맞춘다.
	  SpaceLayer.Add(part, shape, fade?) → 걷는 함수. shape = "Head"(고전 머리 — 지름 1.25 둥근 원통) | "Box"(부품 상자 그대로)
	    fade = 나타나는 데 걸리는 초(3페이즈 옷이 사라지는 동안)
	그림 = ReplicatedStorage.CallistoAssets 속성 SpaceLayerImage(models/build_space_layer.py → tools/Callisto_SpaceLayer.luau).
	화면 위 겹이라 3D 에 가려지지 않으므로, 카메라 뒤 · 260 스터드 밖(남의 전투) · 무엇에 가려졌으면 통째로 감춘다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpaceLayer = {}

export type Shape = "Head" | "Box"

type Strip = { Frame: Frame, Far: ImageLabel, Near: ImageLabel }
type Edge = { Glow: Frame, Core: Frame }
type Layer = { Part: BasePart, Shape: Shape, Root: Frame, Strips: { Strip }, Edges: { Edge }, Born: number, Fade: number, Alpha: number }

local MAX_STRIPS = 44
local MAX_EDGES = 64
local FAR_TILE, NEAR_TILE = 560, 320
local NEAR_ALPHA = 0.4
-- 고전 머리(R6 Head, SpecialMesh Head ×1.25): 높이 → 반지름. 위아래 모서리가 둥근 원통
local HEAD_RINGS = { { -0.625, 0.36 }, { -0.56, 0.52 }, { -0.44, 0.61 }, { 0, 0.625 }, { 0.44, 0.61 }, { 0.56, 0.52 }, { 0.625, 0.36 } }
local HEAD_SEGMENTS = 18

local layers: { Layer } = {}
local conn: RBXScriptConnection? = nil
local screen: ScreenGui? = nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function image(): string
	local kit = ReplicatedStorage:FindFirstChild("CallistoAssets")
	local id = kit and kit:GetAttribute("SpaceLayerImage")
	return if type(id) == "string" then id else ""
end

-- 화면 위 겹(전투 화면·HUD 보다 아래)
local function overlay(): ScreenGui?
	if screen and screen.Parent then
		return screen
	end
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	local s = Instance.new("ScreenGui")
	s.Name = "CallistoSpaceLayer"
	s.IgnoreGuiInset = true -- 좌표 = WorldToViewportPoint 그대로
	s.ResetOnSpawn = false
	s.DisplayOrder = -5
	s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	s.Parent = playerGui
	screen = s
	return s
end

local function tile(parent: Instance, size: number, z: number): ImageLabel
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = image()
	label.ScaleType = Enum.ScaleType.Tile
	label.TileSize = UDim2.fromOffset(size, size)
	label.ImageTransparency = 1
	label.Size = UDim2.new(1, size, 1, size) -- 띠보다 한 칸 크게(밀어도 비지 않게)
	label.ZIndex = z
	label.Parent = parent
	return label
end

local function strip(root: Frame): Strip
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(8, 7, 22)
	f.BackgroundTransparency = 1
	f.ClipsDescendants = true
	f.Visible = false
	f.ZIndex = 1
	f.Parent = root
	return { Frame = f, Far = tile(f, FAR_TILE, 1), Near = tile(f, NEAR_TILE, 2) }
end

-- 윤곽선 한 토막: 넓고 흐린 빛(가운데가 진한 그라데이션) + 가는 하얀 심
local function edge(root: Frame): Edge
	local glow = Instance.new("Frame")
	glow.BorderSizePixel = 0
	glow.BackgroundColor3 = Color3.fromRGB(235, 242, 255)
	glow.BackgroundTransparency = 1
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Visible = false
	glow.ZIndex = 4
	glow.Parent = root
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) })
	grad.Parent = glow
	local core = Instance.new("Frame")
	core.BorderSizePixel = 0
	core.BackgroundColor3 = Color3.new(1, 1, 1)
	core.BackgroundTransparency = 1
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Visible = false
	core.ZIndex = 5
	core.Parent = root
	return { Glow = glow, Core = core }
end

-- 부품 윤곽의 3D 표본 점
local function samples(part: BasePart, shape: Shape): { Vector3 }
	local cf = part.CFrame
	local pts = {}
	if shape == "Head" then
		for _, ring in HEAD_RINGS do
			for k = 0, HEAD_SEGMENTS - 1 do
				local a = k / HEAD_SEGMENTS * math.pi * 2
				table.insert(pts, (cf * CFrame.new(ring[2] * math.cos(a), ring[1], ring[2] * math.sin(a))).Position)
			end
		end
	else
		local h = part.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					table.insert(pts, (cf * CFrame.new(h.X * sx, h.Y * sy, h.Z * sz)).Position)
				end
			end
		end
	end
	return pts
end

-- 볼록 껍질(단조 사슬) — 화면 점들의 바깥 윤곽(반시계)
local function hull(pts: { Vector2 }): { Vector2 }
	table.sort(pts, function(a, b)
		return a.X < b.X or (a.X == b.X and a.Y < b.Y)
	end)
	local function cross(o: Vector2, a: Vector2, b: Vector2): number
		return (a.X - o.X) * (b.Y - o.Y) - (a.Y - o.Y) * (b.X - o.X)
	end
	local lower, upper = {}, {}
	for _, p in pts do
		while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do
			table.remove(lower)
		end
		table.insert(lower, p)
	end
	for i = #pts, 1, -1 do
		local p = pts[i]
		while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do
			table.remove(upper)
		end
		table.insert(upper, p)
	end
	table.remove(lower)
	table.remove(upper)
	for _, p in upper do
		table.insert(lower, p)
	end
	return lower
end

-- 다각형(poly)과 가로줄 y 의 교차 구간(없으면 xl > xr)
local function span(poly: { Vector2 }, y: number): (number, number)
	local xl, xr = math.huge, -math.huge
	for k = 1, #poly do
		local p, q = poly[k], poly[k % #poly + 1]
		if (p.Y - y) * (q.Y - y) <= 0 and p.Y ~= q.Y then
			local x = p.X + (y - p.Y) * (q.X - p.X) / (q.Y - p.Y)
			xl, xr = math.min(xl, x), math.max(xr, x)
		end
	end
	return xl, xr
end

local function step()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camCf = cam.CFrame
	local now = os.clock()
	local me = Players.LocalPlayer and Players.LocalPlayer.Character
	for i = #layers, 1, -1 do
		local L = layers[i]
		local part = L.Part
		if not part:IsDescendantOf(workspace) or not L.Root.Parent then
			L.Root:Destroy()
			table.remove(layers, i)
			continue
		end
		local c = part.Position
		local depth = (c - camCf.Position):Dot(camCf.LookVector)
		params.FilterDescendantsInstances = { part:FindFirstAncestorOfClass("Model") or part, cam, me or part }
		if depth < 0.5 or depth > 260 or workspace:Raycast(camCf.Position, c - camCf.Position, params) then
			L.Root.Visible = false
			continue
		end
		-- 화면 윤곽(볼록 껍질)
		local flat: { Vector2 } = {}
		local behind = false
		for _, p in samples(part, L.Shape) do
			local q = cam:WorldToViewportPoint(p)
			behind = behind or q.Z <= 0
			table.insert(flat, Vector2.new(q.X, q.Y))
		end
		if behind then
			L.Root.Visible = false
			continue
		end
		local p0 = cam:WorldToViewportPoint(c)
		local poly = hull(flat)
		L.Root.Visible = true
		L.Root.ZIndex = 100000 - math.floor(depth * 50) -- 가까운 부품이 위에
		-- 나타나는 중이면 투명도를 맞춘다(다 나타난 뒤엔 한 번만)
		local alpha = if L.Fade > 0 then math.clamp((now - L.Born) / L.Fade, 0, 1) else 1
		local fading = alpha ~= L.Alpha
		L.Alpha = alpha
		-- 가로 띠로 썬다: 띠 가운데 줄과 윤곽의 교차 구간 = 띠의 왼·오른 끝
		local ymin, ymax = math.huge, -math.huge
		for _, p in poly do
			ymin, ymax = math.min(ymin, p.Y), math.max(ymax, p.Y)
		end
		local n = math.clamp(math.ceil((ymax - ymin) / 3), 1, MAX_STRIPS)
		local dy = (ymax - ymin) / n
		local farShift = Vector2.new(5, 3) * now
		local nearShift = Vector2.new(-11, 6) * now + Vector2.new(p0.X, p0.Y) * 0.18
		for s = 1, MAX_STRIPS do
			local st = L.Strips[s]
			local xl, xr = math.huge, -math.huge
			local y0 = ymin + (s - 1) * dy
			if s <= n then
				xl, xr = span(poly, y0 + dy / 2)
			end
			if xr <= xl then
				st.Frame.Visible = false
				continue
			end
			local x0, top = math.floor(xl), math.floor(y0)
			st.Frame.Visible = true
			st.Frame.Position = UDim2.fromOffset(x0, top)
			st.Frame.Size = UDim2.fromOffset(math.ceil(xr) - x0, math.ceil(dy) + 1)
			st.Far.Position = UDim2.fromOffset(-((x0 + farShift.X) % FAR_TILE), -((top + farShift.Y) % FAR_TILE))
			st.Near.Position = UDim2.fromOffset(-((x0 + nearShift.X) % NEAR_TILE), -((top + nearShift.Y) % NEAR_TILE))
			if fading then
				st.Frame.BackgroundTransparency = 1 - alpha
				st.Far.ImageTransparency = 1 - alpha
				st.Near.ImageTransparency = 1 - alpha * NEAR_ALPHA
			end
		end
		-- 빛나는 하얀 윤곽선
		for k = 1, MAX_EDGES do
			local e = L.Edges[k]
			if k > #poly then
				e.Glow.Visible, e.Core.Visible = false, false
				continue
			end
			local p, q = poly[k], poly[k % #poly + 1]
			local d = q - p
			local mid = UDim2.fromOffset((p.X + q.X) / 2, (p.Y + q.Y) / 2)
			local rot = math.deg(math.atan2(d.Y, d.X))
			e.Glow.Visible, e.Core.Visible = true, true
			e.Glow.Position, e.Core.Position = mid, mid
			e.Glow.Size = UDim2.fromOffset(d.Magnitude + 6, 9)
			e.Core.Size = UDim2.fromOffset(d.Magnitude + 1.5, 2)
			e.Glow.Rotation, e.Core.Rotation = rot, rot
			if fading then
				e.Glow.BackgroundTransparency = 1 - alpha * 0.85
				e.Core.BackgroundTransparency = 1 - alpha * 0.95
			end
		end
	end
	if #layers == 0 and conn then
		conn:Disconnect()
		conn = nil
	end
end

function SpaceLayer.Add(part: BasePart, shape: Shape, fade: number?): () -> ()
	local root = Instance.new("Frame")
	root.Name = part.Name
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = overlay()
	local strips, edges = {}, {}
	for s = 1, MAX_STRIPS do
		strips[s] = strip(root)
	end
	for k = 1, MAX_EDGES do
		edges[k] = edge(root)
	end
	table.insert(layers, {
		Part = part,
		Shape = shape,
		Root = root,
		Strips = strips,
		Edges = edges,
		Born = os.clock(),
		Fade = fade or 0,
		Alpha = -1,
	})
	if not conn then
		conn = RunService.RenderStepped:Connect(step)
	end
	return function()
		root:Destroy()
	end
end

return SpaceLayer
