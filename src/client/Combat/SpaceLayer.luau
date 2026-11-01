--!strict
--[[
	SpaceLayer — 칼리스토 '우주를 담은 몸'(2026-11-01 사용자: "우주를 담은 느낌은 모델링보다 레이어 같은 걸 이용해서
	특정 공간에 우주 이미지 자체를 갖다 때려박은 느낌" — 샘플로 2페이즈 머리·오른팔).

	화면 위 겹(ScreenGui — 카메라를 보는 판 안에선 CanvasGroup 이 오려 내지 못해 그림이 통째로 나왔다) 하나에, 몸 부품마다
	매 프레임 그 부품이 화면에 그리는 자리·각도·길이·굵기대로 둥근 틀(CanvasGroup)을 맞추고, 그 안에 우주 그림(이음매 없는 타일)을 **화면에 고정**해 깐다 — 몸이 움직여도 별은 화면에 박힌 채, 몸 윤곽만 그 위를
	지나가는 '오려 낸 창'(포토샵 클리핑 레이어처럼). 앞 겹(작은 타일, 반투명)은 몸을 조금 따라가 깊이감, 둘 다 아주 천천히 흐른다.
	  SpaceLayer.Add(part, shape, width?) → 걷는 함수. shape = "Disc"(머리 — 지름 width 스터드) | "Limb"(팔·다리 — 끝이 둥근 막대,
	    굵기 = 화면에 비친 상자 폭 × width) | "Box"(몸통 — 모서리 둥근 판)
	그림 = ReplicatedStorage.CallistoAssets 속성 SpaceLayerImage(models/build_space_layer.py → tools/Callisto_SpaceLayer.luau). 없으면 짙은 남색 틀만.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpaceLayer = {}

export type Shape = "Disc" | "Limb" | "Box"

type Tile = { Label: ImageLabel, Size: number, Follow: number, Drift: Vector2 }
type Layer = { Part: BasePart, Shape: Shape, Width: number, Group: CanvasGroup, Tiles: { Tile } }

local layers: { Layer } = {}
local conn: RBXScriptConnection? = nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local screen: ScreenGui? = nil

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
local EDGE = Color3.fromRGB(176, 208, 255)

local function image(): string
	local kit = ReplicatedStorage:FindFirstChild("CallistoAssets")
	local id = kit and kit:GetAttribute("SpaceLayerImage")
	return if type(id) == "string" then id else ""
end

-- 화면 고정 타일 한 겹. follow = 몸을 따라가는 비율(0 = 화면에 박힘), drift = 초당 흐름(픽셀)
local function tile(parent: Instance, size: number, transparency: number, follow: number, drift: Vector2, z: number): Tile
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = image()
	label.ScaleType = Enum.ScaleType.Tile
	label.TileSize = UDim2.fromOffset(size, size)
	label.ImageTransparency = transparency
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.ZIndex = z
	label.Parent = parent
	return { Label = label, Size = size, Follow = follow, Drift = drift }
end

local function step()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camCf = cam.CFrame
	local tanHalf = math.tan(math.rad(cam.FieldOfView) / 2)
	local now = os.clock()
	for i = #layers, 1, -1 do
		local L = layers[i]
		local part, group = L.Part, L.Group
		if not part:IsDescendantOf(workspace) or not group.Parent then
			group:Destroy()
			table.remove(layers, i)
			continue
		end
		local c = part.Position
		local depth = (c - camCf.Position):Dot(camCf.LookVector)
		-- 화면 위 겹이라 3D 에 가려지지 않는다 — 카메라 뒤 · 멀리(남의 전투) · 무엇에 가려졌으면 감춘다
		local model = part:FindFirstAncestorOfClass("Model")
		params.FilterDescendantsInstances = { model or part, cam, Players.LocalPlayer and Players.LocalPlayer.Character or part }
		if depth < 0.5 or depth > 260 or workspace:Raycast(camCf.Position, c - camCf.Position, params) then
			group.Visible = false
			continue
		end
		group.Visible = true
		local pps = cam.ViewportSize.Y / (2 * depth * tanHalf) -- 그 깊이에서 스터드당 화면 픽셀
		local p0 = cam:WorldToViewportPoint(c)
		local g0 = Vector2.new(p0.X, p0.Y)
		local a, b, w = g0, g0, L.Width * pps
		if L.Shape ~= "Disc" then
			local up = part.CFrame.UpVector * (part.Size.Y / 2)
			local pa, pb = cam:WorldToViewportPoint(c + up), cam:WorldToViewportPoint(c - up)
			a, b = Vector2.new(pa.X, pa.Y), Vector2.new(pb.X, pb.Y)
			-- 굵기: 상자 모서리 여덟을 화면에 비춰, 몸 축에 수직인 폭
			local d = b - a
			local axis = if d.Magnitude > 1e-3 then d.Unit else Vector2.new(0, 1)
			local perp = Vector2.new(-axis.Y, axis.X)
			local lo, hi = math.huge, -math.huge
			local half = part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local q = cam:WorldToViewportPoint((part.CFrame * CFrame.new(half.X * sx, half.Y * sy, half.Z * sz)).Position)
						local k = (Vector2.new(q.X, q.Y) - a):Dot(perp)
						lo, hi = math.min(lo, k), math.max(hi, k)
					end
				end
			end
			w = (hi - lo) * L.Width
		end
		local d = b - a
		local len = d.Magnitude
		local h = if L.Shape == "Disc" then w elseif L.Shape == "Limb" then len + w * 0.6 else len
		h = math.max(h, w)
		local angle = if len > 1e-3 then math.deg(math.atan2(-d.X, d.Y)) else 0
		local mid = (a + b) / 2
		group.Position = UDim2.fromOffset(mid.X, mid.Y)
		group.Size = UDim2.fromOffset(w, h)
		group.Rotation = angle
		-- 타일: 틀 안에서 거꾸로 돌려 화면과 나란히, 왼쪽 위 모서리가 화면 기준 격자(+ 흐름 · 따라가기)에 오도록 민다
		local r = math.rad(angle)
		local cr, sr = math.cos(r), math.sin(r)
		for _, t in L.Tiles do
			local side = math.sqrt(w * w + h * h) + t.Size * 2
			local tl = mid - Vector2.new(side, side) / 2
			local shift = t.Drift * now + mid * t.Follow
			local ox = -((tl.X + shift.X) % t.Size)
			local oy = -((tl.Y + shift.Y) % t.Size)
			t.Label.Size = UDim2.fromOffset(side, side)
			t.Label.Rotation = -angle
			t.Label.Position = UDim2.new(0.5, ox * cr + oy * sr, 0.5, -ox * sr + oy * cr)
		end
	end
	if #layers == 0 and conn then
		conn:Disconnect()
		conn = nil
	end
end

function SpaceLayer.Add(part: BasePart, shape: Shape, width: number?): () -> ()
	local parent = overlay()
	local group = Instance.new("CanvasGroup")
	group.Name = part.Name
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.BackgroundColor3 = Color3.fromRGB(8, 7, 22)
	group.BorderSizePixel = 0
	group.Visible = false
	group.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(if shape == "Box" then 0.2 else 0.5, 0)
	corner.Parent = group
	local stroke = Instance.new("UIStroke")
	stroke.Color = EDGE
	stroke.Thickness = 1.6
	stroke.Transparency = 0.3
	stroke.Parent = group
	local layer: Layer = {
		Part = part,
		Shape = shape,
		Width = width or (if shape == "Disc" then 1.3 else 1),
		Group = group,
		Tiles = {
			tile(group, 560, 0, 0, Vector2.new(5, 3), 1),
			tile(group, 320, 0.6, 0.18, Vector2.new(-11, 6), 2),
		},
	}
	table.insert(layers, layer)
	if not conn then
		conn = RunService.RenderStepped:Connect(step)
	end
	return function()
		group:Destroy()
	end
end

return SpaceLayer
