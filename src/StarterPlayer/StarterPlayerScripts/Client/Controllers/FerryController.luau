--!strict
-- 연락선 클라이언트
--   * 배 모델을 로컬로 복제해 서버 시각 기반으로 60fps 이동 (모든 클라이언트가 같은 궤적)
--   * 배 위의 로컬 캐릭터를 배와 함께 이동 (플랫폼 운반)
--   * 다른 플레이어는 서버가 중계한 "배 기준 상대 위치"로 보정해 미끄러짐 없이 표시
--   * 도선판 개폐, 돛 부풂, 출항 종, 시간표 간판, 안내 UI, 바다 구조 버튼

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Util.Net)
local FerryConfig = require(Shared.Ferry.FerryConfig)
local FerryRoute = require(Shared.Ferry.FerryRoute)
local WorldData = require(Shared.World.WorldData)
local WorldConfig = require(Shared.World.WorldConfig)
local AssetLibrary = require(Shared.World.AssetLibrary)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer

local FerryController = {}

local route: FerryRoute.Route
local ship: Model? = nil
local anchor: BasePart? = nil
local hingeMotor: Motor6D? = nil
local hingeBase: CFrame = CFrame.identity
local sails: { { part: BasePart, base: Vector3, phase: number } } = {}
local lastShipCF: CFrame? = nil
local gangAngle = 80 -- 0 = 내림, 80 = 올림
local onShip = false
local lastRelaySend = 0
local relayed: { [Player]: { rel: CFrame, t: number, smooth: CFrame? } } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

-- UI
local gui: ScreenGui
local panel: Frame
local titleLabel: TextLabel
local infoLabel: TextLabel
local progress: UIKit.Bar
local rescueButton: TextButton
local swimTime = 0
local lastBellDeparture = -1

local function prepareShip(template: Model): Model
	local m = template:Clone()
	m.Name = "Ferry_Local"
	local root = m:FindFirstChild("Anchor") :: BasePart
	root.Anchored = true
	-- 도선판 힌지
	local hingeAtt = AssetLibrary.Marker(m, "GangplankHinge")
	local hingePart: BasePart? = nil
	if hingeAtt then
		local hp = Instance.new("Part")
		hp.Name = "GangHinge"
		hp.Size = Vector3.new(0.4, 0.4, 0.4)
		hp.Transparency = 1
		hp.CanCollide = false
		hp.CanQuery = false
		hp.CanTouch = false
		hp.Massless = true
		hp.Anchored = false
		hp.CFrame = hingeAtt.WorldCFrame
		hp.Parent = m
		local motor = Instance.new("Motor6D")
		motor.Name = "GangMotor"
		motor.Part0 = root
		motor.Part1 = hp
		motor.C0 = root.CFrame:ToObjectSpace(hingeAtt.WorldCFrame)
		motor.C1 = CFrame.identity
		motor.Parent = root
		hingeMotor = motor
		hingeBase = motor.C0
		hingePart = hp
	end
	local visual = m:FindFirstChild("Visual")
	local gangGroup = visual and visual:FindFirstChild("Gangplank")
	local sailGroup = visual and visual:FindFirstChild("Sails")
	local isMesh = AssetLibrary.IsMesh(m)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= root and d ~= hingePart then
			d.Anchored = false
			d.Massless = true
			local weldTo: BasePart = root
			local inGang = (gangGroup ~= nil and d:IsDescendantOf(gangGroup)) or d:GetAttribute("Group") == "Gangplank"
			if inGang and hingePart then
				weldTo = hingePart
			end
			local w = Instance.new("WeldConstraint")
			w.Part0 = weldTo
			w.Part1 = d
			w.Parent = d
			if isMesh and sailGroup and d:IsDescendantOf(sailGroup) then
				table.insert(sails, { part = d, base = d.Size, phase = math.random() * 6 })
			end
		end
	end
	-- 배 위에서는 콜라이더만 레이캐스트 대상
	local colliders = m:FindFirstChild("Colliders")
	if colliders then
		rayParams.FilterDescendantsInstances = { colliders }
	else
		rayParams.FilterDescendantsInstances = { m }
	end
	-- 선미 이름판
	local plate = AssetLibrary.Marker(m, "NamePlate")
	if plate then
		local p = Instance.new("Part")
		p.Name = "NamePlateFace"
		p.Size = Vector3.new((plate:GetAttribute("width") :: number?) or 10, (plate:GetAttribute("height") :: number?) or 1.6, 0.05)
		p.CFrame = plate.WorldCFrame * CFrame.new(0, 0, -0.06)
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Anchored = false
		p.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 50
		g.LightInfluence = 0.5
		g.Parent = p
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = Enum.Font.Fantasy
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(230, 196, 110)
		l.Text = (plate:GetAttribute("text") :: string?) or FerryConfig.ShipName
		l.Parent = g
	end
	m.PrimaryPart = root
	return m
end

local function localRoot(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function stopLabel(name: string): string
	return FerryConfig.StopLabels[name] or name
end

-- ── UI ────────────────────────────────────────────────────
local function buildUI()
	gui = UIKit.ScreenGui("FerryUI", 5)
	panel = UIKit.Panel(gui, UDim2.fromOffset(360, 66), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0))
	panel.Visible = false
	titleLabel = UIKit.Label(panel, "", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 6), 17)
	infoLabel = UIKit.Label(panel, "", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 30), 14, UIKit.FontRegular, UIKit.Colors.SubText)
	progress = UIKit.Bar(panel, UDim2.new(1, -24, 0, 5), UDim2.new(0, 12, 1, -11), Color3.fromRGB(110, 190, 220))
	rescueButton = UIKit.Button(gui, "🛟  가까운 항구로 구조 요청", UDim2.fromOffset(260, 42), UDim2.new(0.5, -130, 0, 90), function()
		Net.Event("FerryRequest"):FireServer("Rescue")
		swimTime = 0
	end)
	rescueButton.Visible = false
end

local function nearestDockStop(pos: Vector3): (string?, number)
	local best, bestD = nil, math.huge
	for _, name in { "Mistmire", "Harbor" } do
		local s = route:StopS(name)
		if s then
			local p = route:PositionAt(s)
			local d = (Vector3.new(p.X, pos.Y, p.Z) - pos).Magnitude
			if d < bestD then
				best, bestD = name, d
			end
		end
	end
	return best, bestD
end

local function updateUI(state: FerryRoute.State)
	local hrp = localRoot()
	if not hrp then
		panel.Visible = false
		return
	end
	local ship_ = FerryConfig.ShipName
	if onShip then
		panel.Visible = true
		if state.Phase == "Docked" then
			titleLabel.Text = string.format("⛵ %s · <b>%s</b> 정박 중", ship_, stopLabel(state.At or ""))
			infoLabel.Text = string.format("%s행 출항까지 %s", stopLabel(state.To), UIKit.FormatTime(state.TimeToDeparture))
			progress:Set(1 - state.TimeToDeparture / state.Leg.Dwell, true)
		else
			titleLabel.Text = string.format("⛵ %s · <b>%s</b>행 항해 중", ship_, stopLabel(state.To))
			infoLabel.Text = string.format("도착까지 %s · %d kn", UIKit.FormatTime(state.TimeToArrival), math.floor(state.Speed * 0.6 + 0.5))
			progress:Set(state.Progress, true)
		end
		return
	end
	local stop, dist = nearestDockStop(hrp.Position)
	if stop and dist < FerryConfig.DockUiRange then
		panel.Visible = true
		if state.Phase == "Docked" and state.At == stop then
			titleLabel.Text = string.format("⚓ %s 선착장 · <b>탑승 가능</b>", stopLabel(stop))
			infoLabel.Text = string.format("%s행 출항까지 %s", stopLabel(state.To), UIKit.FormatTime(state.TimeToDeparture))
			progress:Set(1 - state.TimeToDeparture / state.Leg.Dwell, true)
		else
			-- 이 선착장까지 남은 시간 계산
			local eta = 0
			if state.Phase == "Sailing" and state.To == stop then
				eta = state.TimeToArrival
			else
				local st = state.Leg
				eta = (if state.Phase == "Docked" then state.TimeToDeparture + st.Travel else state.TimeToArrival)
				-- 다음 구간까지 합산
				local nextLeg = nil
				for _, lg in route.legs do
					if lg.From == state.To then
						nextLeg = lg
					end
				end
				if nextLeg and nextLeg.To == stop then
					eta += nextLeg.Dwell + nextLeg.Travel
				end
			end
			titleLabel.Text = string.format("⚓ %s 선착장", stopLabel(stop))
			infoLabel.Text = string.format("다음 %s 도착까지 %s", ship_, UIKit.FormatTime(eta))
			progress:Set(0, true)
		end
		return
	end
	panel.Visible = false
end

local function updateScheduleBoards(state: FerryRoute.State)
	for _, p in CollectionService:GetTagged("FerryScheduleBoard") do
		local gui_ = p:FindFirstChild("SignGui")
		local label = gui_ and gui_:FindFirstChild("Text") :: TextLabel?
		if not label then
			continue
		end
		local stop = p:GetAttribute("Stop") :: string?
		if state.Phase == "Docked" and state.At == stop then
			label.Text = string.format("⛵ %s\n%s행 출항 %s 전", FerryConfig.ShipName, stopLabel(state.To), UIKit.FormatTime(state.TimeToDeparture))
		elseif state.Phase == "Sailing" and state.To == stop then
			label.Text = string.format("⛵ %s\n도착 %s 전", FerryConfig.ShipName, UIKit.FormatTime(state.TimeToArrival))
		else
			label.Text = string.format("⛵ %s\n%s 운항 중", FerryConfig.ShipName, stopLabel(state.To) .. "행")
		end
	end
end

local function playBells(state: FerryRoute.State)
	if state.Phase ~= "Docked" or state.TimeToDeparture > FerryConfig.BellBefore then
		return
	end
	local id = state.Leg.Start
	if lastBellDeparture == id then
		return
	end
	lastBellDeparture = id
	for _, dock in CollectionService:GetTagged("SwampFerryDock") do
		if dock:GetAttribute("Stop") == state.At then
			for _, d in dock:GetDescendants() do
				if d:IsA("Sound") and d.Parent and d.Parent.Name == "BellSound" then
					d:Play()
				end
			end
		end
	end
	if WorldConfig.Sounds.ShipHorn ~= "" and anchor then
		local s = Instance.new("Sound")
		s.SoundId = WorldConfig.Sounds.ShipHorn
		s.Volume = 1
		s.RollOffMaxDistance = 400
		s.Parent = anchor
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
end

-- ── 매 프레임 ─────────────────────────────────────────────
local function step(dt: number)
	if not ship or not anchor then
		return
	end
	local t = workspace:GetServerTimeNow()
	local state = route:StateAt(t)
	local cf = route:CFrameAt(t, state)
	local prev = lastShipCF or cf
	anchor.CFrame = cf
	lastShipCF = cf
	local delta = cf * prev:Inverse()

	-- 로컬 캐릭터 운반
	local hrp = localRoot()
	onShip = false
	if hrp then
		local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -FerryConfig.CarryRay, 0), rayParams)
		if hit then
			onShip = true
			hrp.CFrame = delta * hrp.CFrame
		end
	end

	-- 도선판
	local target = 80
	if state.Phase == "Docked" and state.SinceArrival > FerryConfig.GangplankDelay and state.TimeToDeparture > FerryConfig.GangplankLead then
		target = 0
	end
	local speed = 80 / FerryConfig.GangplankSwing
	if gangAngle < target then
		gangAngle = math.min(target, gangAngle + speed * dt)
	elseif gangAngle > target then
		gangAngle = math.max(target, gangAngle - speed * dt)
	end
	if hingeMotor then
		hingeMotor.C0 = hingeBase * CFrame.Angles(0, 0, math.rad(gangAngle))
	end

	-- 돛 부풂 (메시 버전만)
	local wind = 0.6 + 0.4 * (state.Speed / FerryConfig.MaxSpeed)
	for _, s in sails do
		local k = 1 + wind * (0.05 + 0.05 * math.sin(t * 0.8 + s.phase))
		s.part.Size = Vector3.new(s.base.X, s.base.Y, s.base.Z * k)
	end
end

-- 다른 플레이어 보정 (렌더 직전)
local function correctOthers(dt: number)
	if not lastShipCF then
		return
	end
	local now = os.clock()
	for plr, info in relayed do
		if plr.Parent == nil or now - info.t > 0.6 then
			relayed[plr] = nil
			continue
		end
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local smooth = info.smooth or info.rel
			smooth = smooth:Lerp(info.rel, math.min(1, dt * 12))
			info.smooth = smooth
			local target = lastShipCF * smooth
			-- 복제 위치와 크게 다르면(순간이동 등) 보정하지 않음
			if (target.Position - hrp.Position).Magnitude < 25 then
				hrp.CFrame = target
			end
		end
	end
end

local function relay()
	local now = os.clock()
	if now - lastRelaySend < 1 / FerryConfig.RelaySendRate then
		return
	end
	lastRelaySend = now
	local remote = Net.Unreliable("FerryRelative")
	local hrp = localRoot()
	if onShip and hrp and lastShipCF then
		remote:FireServer(lastShipCF:ToObjectSpace(hrp.CFrame))
	end
end

local function updateRescue(dt: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = localRoot()
	if not hum or not hrp then
		rescueButton.Visible = false
		return
	end
	local swimming = hum:GetState() == Enum.HumanoidStateType.Swimming
	local h = WorldData.TerrainHeight(hrp.Position.X, hrp.Position.Z)
	local deep = h == nil or h < -10
	local nearShip = lastShipCF ~= nil and (lastShipCF.Position - hrp.Position).Magnitude < 70
	if swimming and deep and not nearShip then
		swimTime += dt
	else
		swimTime = math.max(0, swimTime - dt * 2)
	end
	rescueButton.Visible = swimTime > FerryConfig.RescueSwimSeconds
end

function FerryController.Start()
	route = FerryRoute.new(require(Shared.World.Generated.FerryRouteData) :: any, WorldData.Offset())
	buildUI()
	task.spawn(function()
		local template = AssetLibrary.WaitFor(FerryConfig.Asset, 60)
		if not template then
			warn("[Ferry] 배 템플릿을 찾을 수 없음:", FerryConfig.Asset)
			return
		end
		local m = prepareShip(template)
		local root = m:FindFirstChild("Anchor") :: BasePart
		local t = workspace:GetServerTimeNow()
		root.CFrame = route:CFrameAt(t)
		lastShipCF = root.CFrame
		anchor = root
		m.Parent = workspace
		ship = m
	end)
	Net.Unreliable("FerryRelative").OnClientEvent:Connect(function(plr: Player, rel: CFrame?)
		if plr == player or typeof(plr) ~= "Instance" then
			return
		end
		if typeof(rel) == "CFrame" then
			local cur = relayed[plr]
			relayed[plr] = { rel = rel, t = os.clock(), smooth = cur and cur.smooth }
		else
			relayed[plr] = nil
		end
	end)
	RunService.PreSimulation:Connect(step)
	RunService.PreRender:Connect(correctOthers)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		relay()
		updateRescue(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			local state = route:StateAt(workspace:GetServerTimeNow())
			updateUI(state)
			updateScheduleBoards(state)
			playBells(state)
		end
	end)
end

function FerryController.IsOnShip(): boolean
	return onShip
end

function FerryController.ShipModel(): Model?
	return ship
end

return FerryController
