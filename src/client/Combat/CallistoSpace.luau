--!strict
--[[
	CallistoSpace — 칼리스토 2·3페이즈 전투 배경 우주(2026-11-01 사용자).
	  "2·3페이즈로 넘어가 배경이 우주가 되는 건 — 다른 플레이어도 전투 칸 위에 서면 우주가 보임, 우주는 블렌더로,
	   전투 구역 위에 올라가 있지 않으면 안 보임(스카이 스피어·스카이박스 금지)"
	  "2페이즈: 의수 팔을 휘두르면 배경이 우주로 바뀌며 빠르게 돌다 느려짐" · "3페이즈: 우주 회전 속도가 점점 빨라지고, 우리은하가 전투 필드 아래에"

	블렌더 우주(ReplicatedStorage.CallistoAssets.Space · Galaxy — models/build_callisto_space.py)를 이 사람 카메라 아래에 복제해 둔다
	(카메라 밑 물체는 그 사람 화면에만 그려진다 — 전투 칸 위에 선 사람만 부른다). 빛·하늘은 RegionAtmosphere 의 "우주" 분위기로 덮는다.
	2026-11-01 사용자: "2페 돌입하면 날이 어두워지게, 우주 사진도 배경에 깔아 주고" —
	  · 이 사람 화면만 밤으로(Lighting.ClockTime → 자정, 걷으면 되돌림)
	  · 우주 사진(CallistoAssets 속성 SpaceLayerImage) 판을 카메라 앞 BACKDROP 거리에 화면을 덮게 둔다(카메라를 보는 판 — 스카이박스·하늘 구 아님).
	    그보다 가까운 것(전투 판·블렌더 별·행성)은 앞에, 먼 지형·하늘은 뒤로 가려진다. 우주가 도는 만큼 옆으로 흐른다.
	  SetCenter(pos)          전투 필드 가운데(전투 화면이 스냅숏마다 알려 준다)
	  Show(fade?)             우주를 띄운다(이미 떠 있으면 아무 일 없음). fade = 초(서서히)
	  Spin(rate, ramp)        도는 빠르기(라디안/초)를 ramp 초에 걸쳐 그쪽으로
	  Galaxy(on, rise?)       우리은하(필드 아래) — rise = 초(아래에서 떠오르며 밝아짐)
	  Hide()                  다 걷는다(전투가 끝나면)
	들여온 것이 없으면(시험 환경) 아무 일도 하지 않는다.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local RegionAtmosphere = require(script.Parent.Parent.RegionAtmosphere)

local CallistoSpace = {}

type State = {
	Folder: Folder,
	Space: Model,
	Galaxy: Model?,
	GalaxyOn: boolean,
	Angle: number,
	GalaxyAngle: number,
	SpinNow: number,
	SpinTarget: number,
	Ramp: number,
	Conn: RBXScriptConnection,
	Clock: number,
}

local center = Vector3.zero
local state: State? = nil
local GALAXY_DROP = 26
local BACKDROP = 460 -- 우주 사진 판까지 거리(블렌더 별 반지름 140~360 보다 멀리)
local BACKDROP_TILE = 760
local BACKDROP_BIND = "CallistoBackdrop"

function CallistoSpace.SetCenter(pos: Vector3)
	center = pos
end

function CallistoSpace.IsShown(): boolean
	return state ~= nil
end

-- 부품마다 원래 투명도를 기억해 두고 0(보임) 비율로 맞춘다
local function fade(model: Model, from: number, to: number, time: number)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local base = p:GetAttribute("BaseAlpha")
			if type(base) ~= "number" then
				base = p.Transparency
				p:SetAttribute("BaseAlpha", base)
			end
			local function at(k: number): number
				return 1 - (1 - (base :: number)) * k
			end
			p.Transparency = at(from)
			if time > 0 then
				TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Sine), { Transparency = at(to) }):Play()
			else
				p.Transparency = at(to)
			end
		end
	end
end

function CallistoSpace.Show(fadeTime: number?)
	if state then
		return
	end
	local kit = ReplicatedStorage:FindFirstChild("CallistoAssets")
	local source = kit and kit:FindFirstChild("Space")
	local camera = workspace.CurrentCamera
	if not source or not source:IsA("Model") or not camera then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CallistoSpace"
	folder.Parent = camera
	local space = source:Clone()
	space:PivotTo(CFrame.new(center))
	space.Parent = folder
	fade(space, 0, 1, fadeTime or 0)
	local galaxySource = kit and kit:FindFirstChild("Galaxy")
	local galaxy: Model? = nil
	if galaxySource and galaxySource:IsA("Model") then
		local g = galaxySource:Clone()
		fade(g, 0, 0, 0)
		g:PivotTo(CFrame.new(center - Vector3.new(0, GALAXY_DROP, 0)))
		g.Parent = folder
		galaxy = g
	end
	RegionAtmosphere.SetOverride("우주")
	-- 우주 사진 판: 보이지 않는 닻을 매 프레임 카메라 앞 BACKDROP 에 두고, 그 닻의 판을 화면보다 조금 크게
	local anchor = Instance.new("Part")
	anchor.Name = "BackdropAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Parent = folder
	local board = Instance.new("BillboardGui")
	board.Name = "Backdrop"
	board.Adornee = anchor
	board.AlwaysOnTop = false
	board.LightInfluence = 0
	board.ClipsDescendants = true
	board.MaxDistance = math.huge
	board.Parent = folder
	local photo = Instance.new("ImageLabel")
	photo.BackgroundColor3 = Color3.fromRGB(4, 4, 14)
	photo.BorderSizePixel = 0
	local kitImage = kit and kit:GetAttribute("SpaceLayerImage")
	photo.Image = if type(kitImage) == "string" then kitImage else ""
	photo.ScaleType = Enum.ScaleType.Tile
	photo.TileSize = UDim2.fromOffset(BACKDROP_TILE, BACKDROP_TILE)
	photo.Size = UDim2.new(1, BACKDROP_TILE, 1, BACKDROP_TILE)
	photo.ImageTransparency = 1
	photo.BackgroundTransparency = 1
	photo.Parent = board
	local fadeIn = TweenInfo.new(math.max(fadeTime or 0, 0.05), Enum.EasingStyle.Sine)
	TweenService:Create(photo, fadeIn, { ImageTransparency = 0.05, BackgroundTransparency = 0 }):Play()
	-- 날이 저문다: 오후면 해 질 녘을 지나 자정(24)으로, 오전이면 거꾸로 0 시로
	local clock = Lighting.ClockTime
	TweenService:Create(Lighting, TweenInfo.new(math.max(fadeTime or 0, 1.5), Enum.EasingStyle.Sine), { ClockTime = if clock >= 12 then 24 else 0 }):Play()
	local s: State = {
		Folder = folder,
		Space = space,
		Galaxy = galaxy,
		GalaxyOn = false,
		Angle = 0,
		GalaxyAngle = 0,
		SpinNow = 0.08,
		SpinTarget = 0.08,
		Ramp = 1,
		Conn = nil :: any,
		Clock = clock,
	}
	RunService:BindToRenderStep(BACKDROP_BIND, Enum.RenderPriority.Camera.Value + 1, function()
		local cam = workspace.CurrentCamera
		if not cam or not anchor.Parent then
			return
		end
		anchor.CFrame = cam.CFrame * CFrame.new(0, 0, -BACKDROP)
		board.Size = UDim2.fromOffset(cam.ViewportSize.X * 1.15, cam.ViewportSize.Y * 1.15)
		local scroll = s.Angle * 320 + os.clock() * 4
		photo.Position = UDim2.fromOffset(-(scroll % BACKDROP_TILE), -((os.clock() * 2) % BACKDROP_TILE))
	end)
	s.Conn = RunService.Heartbeat:Connect(function(dt: number)
		if not folder.Parent then
			return
		end
		s.SpinNow += (s.SpinTarget - s.SpinNow) * math.min(1, dt / math.max(s.Ramp, 0.05))
		s.Angle += s.SpinNow * dt
		space:PivotTo(CFrame.new(center) * CFrame.Angles(0, s.Angle, 0))
		if galaxy and s.GalaxyOn then
			s.GalaxyAngle += (0.06 + s.SpinNow * 0.25) * dt
			local pivot = galaxy:GetPivot()
			galaxy:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(math.rad(6), -s.GalaxyAngle, 0))
		end
	end)
	state = s
end

function CallistoSpace.Spin(rate: number, ramp: number)
	if state then
		state.SpinTarget = rate
		state.Ramp = ramp
	end
end

function CallistoSpace.Galaxy(on: boolean, rise: number?)
	local s = state
	local galaxy = s and s.Galaxy
	if not s or not galaxy or s.GalaxyOn == on then
		return
	end
	s.GalaxyOn = on
	local time = rise or 0
	local below = center - Vector3.new(0, GALAXY_DROP + (if on and time > 0 then 30 else 0), 0)
	galaxy:PivotTo(CFrame.new(below))
	fade(galaxy, if on then 0 else 1, if on then 1 else 0, time)
	if on and time > 0 then
		-- 아래에서 떠오른다(값 하나를 트윈해 매 프레임 자리를 옮긴다)
		local lift = Instance.new("NumberValue")
		lift.Value = 30
		lift.Parent = s.Folder
		TweenService:Create(lift, TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Value = 0 }):Play()
		lift.Changed:Connect(function(v: number)
			local pivot = galaxy:GetPivot()
			galaxy:PivotTo(CFrame.new(center - Vector3.new(0, GALAXY_DROP + v, 0)) * pivot.Rotation)
		end)
	end
end

function CallistoSpace.Hide()
	local s = state
	if not s then
		return
	end
	state = nil
	s.Conn:Disconnect()
	RunService:UnbindFromRenderStep(BACKDROP_BIND)
	s.Folder:Destroy()
	RegionAtmosphere.SetOverride(nil)
	Lighting.ClockTime %= 24
	TweenService:Create(Lighting, TweenInfo.new(1.5, Enum.EasingStyle.Sine), { ClockTime = s.Clock }):Play()
end

return CallistoSpace
