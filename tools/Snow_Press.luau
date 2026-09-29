--!nocheck
--[[
	Snow_Press.luau — 차펜 공방 증기 압착기를 움직이는 것으로 바꾼다. (2026-09-29 요청: "설원 공방쪽 압착기가 움직였으면")

	키트의 Steam_Press 는 재질마다 메시 하나라 누름판만 따로 움직일 수 없다. 그래서 같은 자리·같은 꼴을 블록으로
	다시 짓는다(models/build_props.py steam_press 치수 그대로, 잔 리벳은 덜어 게임에 맞는 밀도로).
	  Ram       누름 뭉치(윗 금형·램·놋쇠 옆판·피스톤 막대·아래 고리). 위(쉼) ↔ 2.85 아래(찍음)를 오간다
	  Flywheel  +X 쪽 플라이휠. 계속 돈다
	  HotPlate  달군 판. 찍는 순간 밝아졌다 식는다. SteamPuff 에서 김이 훅 나온다
	움직임은 클라이언트 스크립트(SnowPressRun, 도시 폴더)가 서버 시간에 맞춰 그린다 — 모두에게 같은 박자.
	자리: 모델 원점 = 바닥 가운데, 앞(-Z) = 운반대 쪽. 키트 모델의 피벗을 그대로 쓴다.
	다시 돌리면 앞서 지은 것을 지우고 새로 짓는다. 원래 키트 압착기는 ServerStorage.Snow_Cleared 로 옮긴다.
	Snow_City 로 도시를 다시 지으면 이 스크립트를 다시 돌린다.
]]
local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local HS = game:GetService("HttpService")
local RGB = Color3.fromRGB
local M = Enum.Material

local IRON = { RGB(58, 60, 66), M.Metal }
local IRONL = { RGB(94, 98, 107), M.DiamondPlate }
local BRASS = { RGB(184, 145, 63), M.Metal }
local COPPER = { RGB(176, 106, 63), M.Metal }
local GLOW = { RGB(225, 120, 50), M.Neon }
local WHITE = { RGB(226, 220, 200), M.SmoothPlastic }

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local PRESS_SCRIPT = [==[
-- 증기 압착기(차펜 공방). 서버 시간에 맞춰 누름 뭉치가 오르내리고 플라이휠이 돈다. Snow_Press.luau 가 넣는다
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local PERIOD, DROP = 2.6, 2.85
local presses = {}
local function add(m)
	local ram, wheel = m:FindFirstChild("Ram"), m:FindFirstChild("Flywheel")
	if not (ram and wheel) then
		return
	end
	local puff = m:FindFirstChild("SteamPuff", true)
	presses[m] = {
		ram = ram, ramBase = ram:GetPivot(), wheel = wheel, wheelBase = wheel:GetPivot(),
		plate = m:FindFirstChild("HotPlate"), puff = puff and puff:FindFirstChildOfClass("ParticleEmitter"), cycle = -1,
	}
end
for _, m in CS:GetTagged("SnowPress") do
	add(m)
end
CS:GetInstanceAddedSignal("SnowPress"):Connect(add)
CS:GetInstanceRemovedSignal("SnowPress"):Connect(function(m)
	presses[m] = nil
end)
local function smooth(x)
	return x * x * (3 - 2 * x)
end
local DULL, HOT = Color3.fromRGB(190, 80, 34), Color3.fromRGB(255, 170, 80)
RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	local phase = t % PERIOD
	local cycle = math.floor(t / PERIOD)
	-- 0~0.35 눌러 둠 · 0.35~1.6 천천히 오름 · 1.6~2.2 위에서 멈춤 · 2.2~2.32 내리찍음 · 2.32~ 눌러 둠
	local down
	if phase < 0.35 then
		down = 1
	elseif phase < 1.6 then
		down = 1 - smooth((phase - 0.35) / 1.25)
	elseif phase < 2.2 then
		down = 0
	elseif phase < 2.32 then
		local a = (phase - 2.2) / 0.12
		down = a * a
	else
		down = 1
	end
	-- 찍은 뒤 1초 동안 판이 밝았다 식는다
	local since = if phase >= 2.32 then phase - 2.32 else phase + PERIOD - 2.32
	local heat = math.clamp(1 - since / 1.0, 0, 1)
	for m, p in presses do
		if not m.Parent then
			continue
		end
		p.ram:PivotTo(p.ramBase * CFrame.new(0, -DROP * down, 0))
		p.wheel:PivotTo(p.wheelBase * CFrame.Angles(math.rad((t * 120) % 360), 0, 0))
		if p.plate then
			p.plate.Color = DULL:Lerp(HOT, heat)
		end
		if phase >= 2.32 and p.cycle ~= cycle then
			p.cycle = cycle
			if p.puff then
				p.puff:Emit(10)
			end
		end
	end
end)
]==]

local ok, err = pcall(function()
	local city = assert(workspace:FindFirstChild("Schneereich"), "Workspace.Schneereich 가 없다")
	local room = assert(city:FindFirstChild("안쪽방") and city["안쪽방"]:FindFirstChild("차펜공방"), "차펜공방 방이 없다")

	-- 자리: 키트 압착기(처음) 또는 앞서 지은 블록 압착기(다시 돌릴 때)의 피벗
	-- 자리의 기준은 늘 키트 압착기의 피벗(처음엔 방에, 다시 돌릴 땐 Snow_Cleared 에 있다)
	local old = room:FindFirstChild("Steam_Press")
	local built = room:FindFirstChild("Press_Moving")
	local kept = SS:FindFirstChild("Snow_Cleared") and SS.Snow_Cleared:FindFirstChild("Steam_Press_차펜공방")
	local pivot = if old then old:GetPivot() elseif kept then kept:GetPivot() else nil
	if built then
		pivot = pivot or built:GetPivot()
		built:Destroy()
	end
	if old then
		local cleared = SS:FindFirstChild("Snow_Cleared") or Instance.new("Folder")
		cleared.Name = "Snow_Cleared"
		cleared.Parent = SS
		old.Name = "Steam_Press_차펜공방"
		old.Parent = cleared
	end
	assert(pivot, "압착기 자리를 못 찾았다")
	-- 피벗의 돌림만 쓰고 높이는 바닥(키트 원점 = 바닥 가운데)
	local base = CFrame.new(pivot.Position) * pivot.Rotation

	local model = Instance.new("Model")
	model.Name = "Press_Moving"
	local n = 0
	local function P(name, parent, size, at, col, opt)
		opt = opt or {}
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		local cf = base * CFrame.new(at)
		if opt.rot then
			cf *= CFrame.Angles(math.rad(opt.rot[1]), math.rad(opt.rot[2]), math.rad(opt.rot[3]))
		end
		-- 원통 축은 로컬 X. "y" 세움, "z" 앞뒤, "x" 그대로
		if opt.cyl then
			p.Shape = Enum.PartType.Cylinder
			if opt.cyl == "y" then
				cf *= CFrame.Angles(0, 0, math.rad(90))
			elseif opt.cyl == "z" then
				cf *= CFrame.Angles(0, math.rad(90), 0)
			end
		end
		p.CFrame = cf
		p.Color = col[1]
		p.Material = col[2]
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		-- 움직이는 것·잔 장식은 부딪히지 않는다(사람이 끼지 않게)
		p.CanCollide = opt.solid == true
		p.CastShadow = col[2] ~= M.Neon
		p.Parent = parent
		n += 1
		return p
	end
	local V = Vector3.new

	-- 받침·기둥(부딪힘 있음)
	P("Base", model, V(8.4, 0.8, 6.4), V(0, 0.4, 0), IRON, { solid = true })
	P("BaseTop", model, V(7.6, 0.1, 5.6), V(0, 0.85, 0), IRONL)
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 3.3
		P("Pillar", model, V(1.4, 12, 4.4), V(x, 6.8, 0.3), IRON, { solid = true })
		P("PillarFace", model, V(1.0, 11, 0.1), V(x, 6.8, -1.95), IRONL)
		for k = 0, 3 do
			for _, dx in ipairs({ -0.3, 0.3 }) do
				P("Rivet", model, V(0.16, 0.16, 0.12), V(x + dx, 2.3 + k * 2.9, -2.05), BRASS)
			end
		end
	end
	-- 모루·아래 금형·달군 판
	P("Anvil", model, V(5.2, 3.2, 4.4), V(0, 2.4, 0), IRON, { solid = true })
	P("DieLow", model, V(4.2, 0.5, 3.4), V(0, 4.25, -0.2), IRONL)
	local plate = P("HotPlate", model, V(3.2, 0.24, 2.4), V(0, 4.62, -0.2), GLOW)
	local light = Instance.new("PointLight")
	light.Color = RGB(255, 140, 70)
	light.Brightness = 1.2
	light.Range = 12
	light.Shadows = false
	light.Parent = plate
	-- 윗 가로보·증기 실린더(가만히)
	P("Crosshead", model, V(8.0, 1.6, 4.8), V(0, 13.6, 0.3), IRON, { solid = true })
	P("CrossStrip", model, V(7.4, 0.3, 0.12), V(0, 13.6, -2.12), BRASS)
	P("RodGuide", model, V(0.35, 1.4, 1.4), V(0, 12.625, -0.2), BRASS, { cyl = "y" })
	P("Cylinder", model, V(3.8, 3.4, 3.4), V(0, 16.3, 0.3), COPPER, { cyl = "y" })
	for _, y in ipairs({ 14.6, 17.9 }) do
		P("Band", model, V(0.4, 3.7, 3.7), V(0, y, 0.3), BRASS, { cyl = "y" })
	end
	P("Cap", model, V(0.5, 3.2, 3.2), V(0, 18.45, 0.3), IRON, { cyl = "y" })
	P("Neck", model, V(0.3, 1.2, 1.2), V(0, 18.85, 0.3), COPPER, { cyl = "y" })
	P("NeckCap", model, V(0.15, 1.7, 1.7), V(0, 19.08, 0.3), BRASS, { cyl = "y" })
	-- 배기관: 실린더 옆에서 뒤로 돌아 기둥을 따라 내려간다
	P("Exhaust1", model, V(1.4, 0.56, 0.56), V(1.9, 16.0, 1.5), COPPER, { cyl = "x" })
	P("Exhaust2", model, V(3.2, 0.56, 0.56), V(2.6, 14.4, 1.5), COPPER, { cyl = "y" })
	-- 압력계(앞 왼쪽 가로보)·조종 손잡이
	P("Gauge", model, V(0.15, 1.1, 1.1), V(-2.3, 13.6, -2.2), BRASS, { cyl = "z" })
	P("GaugeFace", model, V(0.06, 0.9, 0.9), V(-2.3, 13.6, -2.3), WHITE, { cyl = "z" })
	P("GaugeNeedle", model, V(0.06, 0.4, 0.04), V(-2.25, 13.68, -2.34), IRON, { rot = { 0, 0, -35 } })
	P("LeverPin", model, V(0.6, 0.44, 0.44), V(-3.3, 5.0, -2.3), IRON, { cyl = "z" })
	P("Lever", model, V(0.2, 2.2, 0.2), V(-3.55, 6.05, -2.45), IRON, { rot = { 0, 0, 14 } })
	P("LeverKnob", model, V(0.52, 0.52, 0.52), V(-3.82, 7.15, -2.45), BRASS)
	-- 미끄럼판(앞으로 기울어 운반대에 판을 내린다)
	P("Chute", model, V(3.4, 0.15, 1.5), V(0, 4.37, -2.9), IRONL, { rot = { -14, 0, 0 } })
	for _, sx in ipairs({ -1, 1 }) do
		P("ChuteRail", model, V(0.12, 0.35, 1.5), V(sx * 1.75, 4.6, -2.9), BRASS, { rot = { -14, 0, 0 } })
	end
	-- 김: 금형 옆에서 찍을 때마다 훅
	local puff = P("SteamPuff", model, V(0.4, 0.4, 0.4), V(0, 5.6, -0.2), IRON)
	puff.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(RGB(240, 240, 244), RGB(210, 210, 216))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 5) })
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(4, 8)
	e.SpreadAngle = Vector2.new(70, 20)
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	e.EmissionDirection = Enum.NormalId.Front
	e.LightInfluence = 1
	e.Parent = puff

	-- 누름 뭉치(쉼 = 위, 찍으면 2.85 내려가 달군 판에 닿는다). 원래 틀보다 1.5 높이 들어 행정이 멀리서도 보이게.
	-- 피스톤 막대는 가로보를 지나 실린더 속까지 길게 — 내려가도 틈이 안 보인다
	local ram = Instance.new("Model")
	ram.Name = "Ram"
	ram.Parent = model
	P("DieUp", ram, V(4.2, 0.5, 3.4), V(0, 7.85, -0.2), IRONL)
	local ramBlock = P("RamBlock", ram, V(4.6, 1.6, 3.8), V(0, 8.9, -0.2), IRON)
	for _, sx in ipairs({ -1, 1 }) do
		P("RamPlate", ram, V(0.3, 1.6, 1.2), V(sx * 2.45, 8.9, -0.2), BRASS)
	end
	P("Rod", ram, V(6.0, 0.9, 0.9), V(0, 12.7, -0.2), IRONL, { cyl = "y" })
	P("RodCollar", ram, V(0.35, 1.4, 1.4), V(0, 9.875, -0.2), BRASS, { cyl = "y" })
	ram.PrimaryPart = ramBlock

	-- 플라이휠(+X 바깥, 굴대 축 X). 바퀴 테 12 토막, 살 6, 놋쇠 통
	P("Axle", model, V(1.3, 0.7, 0.7), V(4.3, 6.0, 0.3), IRONL, { cyl = "x" })
	local wheel = Instance.new("Model")
	wheel.Name = "Flywheel"
	wheel.Parent = model
	local hub = P("Hub", wheel, V(0.7, 1.2, 1.2), V(4.62, 6.0, 0.3), BRASS, { cyl = "x" })
	local R = 3.0
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local seg = 2 * R * math.sin(math.pi / 12) + 0.08
		P("Rim", wheel, V(0.5, 0.5, seg), V(4.62, 6.0 + (R - 0.25) * math.cos(a), 0.3 + (R - 0.25) * math.sin(a)), IRON, { rot = { math.deg(a), 0, 0 } })
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		P("Spoke", wheel, V(0.3, R - 0.6, 0.3), V(4.62, 6.0 + (R - 0.3) / 2 * math.cos(a), 0.3 + (R - 0.3) / 2 * math.sin(a)), IRON, { rot = { math.deg(a), 0, 0 } })
	end
	wheel.PrimaryPart = hub

	-- PrimaryPart 를 두면 피벗이 받침 가운데(0.4 위)로 잡혀 다시 돌릴 때마다 뜬다 — WorldPivot 만 쓴다
	model.WorldPivot = base
	model.Parent = room
	CS:AddTag(model, "SnowPress")

	-- 움직이는 클라이언트 스크립트(도시 폴더에 하나)
	local runner = city:FindFirstChild("SnowPressRun")
	if runner then
		runner:Destroy()
	end
	local s = Instance.new("Script")
	s.Name = "SnowPressRun"
	s.RunContext = Enum.RunContext.Client
	s.Source = PRESS_SCRIPT
	s.Parent = city
	local p = base.Position
	say("압착기: 부품 %d, 자리 %.1f %.1f %.1f", n, p.X, p.Y, p.Z)
end)
if not ok then
	say("ERR %s", tostring(err))
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/snow_press", table.concat(report, "\n"))
end)
print("snow_press", ok)
