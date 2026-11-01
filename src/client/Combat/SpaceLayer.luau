--!strict
--[[
	SpaceLayer — 칼리스토 '우주를 담은 몸'(2026-11-01 사용자: "우주를 담은 느낌은 모델링보다 레이어 같은 걸 이용해서
	특정 공간에 우주 이미지 자체를 갖다 때려박은 느낌" — 샘플로 2페이즈 머리·오른팔).

	화면 위 겹(ScreenGui) 하나에, 몸 부품마다 그 부품이 화면에 그리는 윤곽(둥근 막대 · 원 · 둥근 판)을 매 프레임 가로 띠로 잘게 썰어
	띠마다 우주 그림을 **화면에 고정**해 담는다 — 몸이 움직여도 별은 화면에 박힌 채, 몸 윤곽만 그 위를 지나가는 '오려 낸 창'
	(포토샵 클리핑 레이어처럼). 띠는 회전 없는 Frame 의 ClipsDescendants 로 자른다(회전·둥근 틀 잘라 내기는 이 환경에서 믿을 수 없었다 —
	CanvasGroup 은 그림을 네모로 통째로 내보냈다). 띠 양 끝엔 옅은 빛선. 앞 겹(작은 타일, 반투명)은 몸을 조금 따라가 깊이감.
	  SpaceLayer.Add(part, shape, width?) → 걷는 함수. shape = "Disc"(머리 — 지름 width 스터드) | "Limb"(팔·다리 — 끝이 둥근 막대,
	    굵기 = 화면에 비친 상자 폭 × width) | "Box"(몸통 — 모서리 둥근 판)
	그림 = ReplicatedStorage.CallistoAssets 속성 SpaceLayerImage(models/build_space_layer.py → tools/Callisto_SpaceLayer.luau).
	화면 위 겹이라 3D 에 가려지지 않으므로, 카메라 뒤 · 260 스터드 밖(남의 전투) · 무엇에 가려졌으면 통째로 감춘다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpaceLayer = {}

export type Shape = "Disc" | "Limb" | "Box"

type Strip = { Frame: Frame, Far: ImageLabel, Near: ImageLabel }
type Layer = { Part: BasePart, Shape: Shape, Width: number, Root: Frame, Strips: { Strip } }

local MAX_STRIPS = 40
local FAR_TILE, NEAR_TILE = 560, 320
local EDGE = Color3.fromRGB(176, 208, 255)

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
	s.Parent = playerGui
	screen = s
	return s
end

local function tile(parent: Instance, size: number, transparency: number, z: number): ImageLabel
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = image()
	label.ScaleType = Enum.ScaleType.Tile
	label.TileSize = UDim2.fromOffset(size, size)
	label.ImageTransparency = transparency
	label.Size = UDim2.new(1, size, 1, size) -- 띠보다 한 칸 크게(밀어도 비지 않게)
	label.ZIndex = z
	label.Parent = parent
	return label
end

local function edge(parent: Instance, right: boolean)
	local e = Instance.new("Frame")
	e.BorderSizePixel = 0
	e.BackgroundColor3 = EDGE
	e.BackgroundTransparency = 0.35
	e.AnchorPoint = Vector2.new(if right then 1 else 0, 0)
	e.Position = UDim2.fromScale(if right then 1 else 0, 0)
	e.Size = UDim2.new(0, 2, 1, 0)
	e.ZIndex = 3
	e.Parent = parent
end

local function strip(root: Frame): Strip
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(8, 7, 22)
	f.ClipsDescendants = true
	f.Visible = false
	f.Parent = root
	edge(f, false)
	edge(f, true)
	return { Frame = f, Far = tile(f, FAR_TILE, 0, 1), Near = tile(f, NEAR_TILE, 0.6, 2) }
end

-- 둥근 사각(가운데 c · 축 u · 반길이 A · 반폭 B · 모서리 R)의 윤곽 점들(화면 좌표)
local function outline(c: Vector2, u: Vector2, A: number, B: number, R: number): { Vector2 }
	local v = Vector2.new(-u.Y, u.X)
	local pts = {}
	for _, k in { { 1, 1, 0 }, { -1, 1, 90 }, { -1, -1, 180 }, { 1, -1, 270 } } do
		local inner = c + u * ((A - R) * k[1]) + v * ((B - R) * k[2])
		for s = 0, 6 do
			local th = math.rad(k[3] + s * 15)
			table.insert(pts, inner + (u * math.cos(th) + v * math.sin(th)) * R)
		end
	end
	return pts
end

local function step()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camCf = cam.CFrame
	local tanHalf = math.tan(math.rad(cam.FieldOfView) / 2)
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
		L.Root.Visible = true
		local pps = cam.ViewportSize.Y / (2 * depth * tanHalf) -- 그 깊이에서 스터드당 화면 픽셀
		local p0 = cam:WorldToViewportPoint(c)
		local center = Vector2.new(p0.X, p0.Y)
		local u, A, B, R = Vector2.new(0, 1), 0, 0, 0
		if L.Shape == "Disc" then
			A = L.Width * pps / 2
			B, R = A, A
		else
			local up = part.CFrame.UpVector * (part.Size.Y / 2)
			local pa, pb = cam:WorldToViewportPoint(c + up), cam:WorldToViewportPoint(c - up)
			local a, b = Vector2.new(pa.X, pa.Y), Vector2.new(pb.X, pb.Y)
			local d = b - a
			u = if d.Magnitude > 1e-3 then d.Unit else Vector2.new(0, 1)
			-- 굵기: 상자 모서리 여덟을 화면에 비춰, 몸 축에 수직인 폭
			local v = Vector2.new(-u.Y, u.X)
			local lo, hi = math.huge, -math.huge
			local half = part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local q = cam:WorldToViewportPoint((part.CFrame * CFrame.new(half.X * sx, half.Y * sy, half.Z * sz)).Position)
						local k = (Vector2.new(q.X, q.Y) - a):Dot(v)
						lo, hi = math.min(lo, k), math.max(hi, k)
					end
				end
			end
			center = (a + b) / 2
			B = (hi - lo) * L.Width / 2
			if L.Shape == "Limb" then
				R = B
				A = d.Magnitude / 2 + B * 0.3
			else
				A = d.Magnitude / 2
				R = math.min(A, B) * 0.35
			end
			A = math.max(A, R)
		end
		-- 가로 띠로 썬다: 띠 가운데 줄과 윤곽의 교차 구간 = 띠의 왼·오른 끝
		local pts = outline(center, u, A, B, R)
		local ymin, ymax = math.huge, -math.huge
		for _, p in pts do
			ymin, ymax = math.min(ymin, p.Y), math.max(ymax, p.Y)
		end
		local n = math.clamp(math.ceil((ymax - ymin) / 3), 1, MAX_STRIPS)
		local dy = (ymax - ymin) / n
		local farShift = Vector2.new(5, 3) * now
		local nearShift = Vector2.new(-11, 6) * now + center * 0.18
		for s = 1, MAX_STRIPS do
			local st = L.Strips[s]
			if s > n then
				st.Frame.Visible = false
				continue
			end
			local y0 = ymin + (s - 1) * dy
			local yc = y0 + dy / 2
			local xl, xr = math.huge, -math.huge
			for k = 1, #pts do
				local p, q = pts[k], pts[k % #pts + 1]
				if (p.Y - yc) * (q.Y - yc) <= 0 and p.Y ~= q.Y then
					local x = p.X + (yc - p.Y) * (q.X - p.X) / (q.Y - p.Y)
					xl, xr = math.min(xl, x), math.max(xr, x)
				end
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
		end
	end
	if #layers == 0 and conn then
		conn:Disconnect()
		conn = nil
	end
end

function SpaceLayer.Add(part: BasePart, shape: Shape, width: number?): () -> ()
	local root = Instance.new("Frame")
	root.Name = part.Name
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = overlay()
	local strips = {}
	for s = 1, MAX_STRIPS do
		strips[s] = strip(root)
	end
	table.insert(layers, {
		Part = part,
		Shape = shape,
		Width = width or (if shape == "Disc" then 1.3 else 1),
		Root = root,
		Strips = strips,
	})
	if not conn then
		conn = RunService.RenderStepped:Connect(step)
	end
	return function()
		root:Destroy()
	end
end

return SpaceLayer
