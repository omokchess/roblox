--!strict
--[[
	AirshipService — 설원 비행선(사용자 2026-11-23: "플레이어가 진짜 들어가서 탈 수 있도록").
	Studio 에서 tools/Snow_Town3.luau 가 지은 모델(태그 SnowAirship)을 받아 쓴다:
	  <태그 모델>
	    Sn3_Airship  곤돌라+기낭(안에 충돌 상자·Seat·DepartPad)   ← 한 몸(RigidMover)으로 날아간다
	    Sn3_AirDoor  미닫이 옆문(열린 자리에 놓여 있음, 속성 Travel = 닫힐 때 이동량 스터드, 로컬 +Z → -Z)
	    Sn3_AirProp  프로펠러 4(굴대 = 로컬 Z, 놓인 자리가 굴대)
	매여 있을 땐 전부 고정. DepartPad 의 ProximityPrompt "출발" → 10초 → 문 닫힘 → 항로(AirshipRoute) → 돌아와 문 열림.
	프로펠러는 날 때만 HingeConstraint 모터로 돈다. 항로·시간 계산은 shared/AirshipRoute(순수 함수, lune 시험).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AirshipRoute = require(ReplicatedStorage.Shared.AirshipRoute)
local RigidMover = require(script.Parent.RigidMover)

local AirshipService = {}

local DOOR_SECONDS = 1.6
local PROP_SPEED = 28 -- rad/s
local PROP_ACCEL = 8 -- rad/s²

local function partsOf(container: Instance): { BasePart }
	local list = {}
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function invisibleRoot(name: string, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.one
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = true
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function setup(holder: Model)
	local ship = holder:FindFirstChild("Sn3_Airship")
	if not ship or not ship:IsA("Model") then
		return
	end
	local pad = ship:FindFirstChild("DepartPad", true)
	if not pad or not pad:IsA("BasePart") then
		warn("AirshipService: DepartPad 없음")
		return
	end

	local root = invisibleRoot("ShipRoot", ship:GetPivot(), ship)
	local shipParts = partsOf(ship)
	table.insert(shipParts, root)

	-- 문: 문짝 파트 → DoorRoot 용접, DoorRoot ↔ root 는 Weld(C0 를 움직여 미닫이)
	local extras: { BasePart } = {}
	local doorWeld: Weld? = nil
	local doorOpenOffset = CFrame.identity
	local doorTravel = 8.6
	local doorRoot: Part? = nil
	local door = holder:FindFirstChild("Sn3_AirDoor")
	if door and door:IsA("Model") then
		doorTravel = (door:GetAttribute("Travel") :: number?) or 8.6
		local dr = invisibleRoot("DoorRoot", door:GetPivot(), door)
		doorRoot = dr
		for _, p in partsOf(door) do
			if p ~= dr then
				local w = Instance.new("WeldConstraint")
				w.Part0 = dr
				w.Part1 = p
				w.Parent = p
				table.insert(extras, p)
			end
		end
		table.insert(extras, dr)
		doorOpenOffset = root.CFrame:ToObjectSpace(dr.CFrame)
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = dr
		weld.C0 = doorOpenOffset
		weld.Parent = dr
		doorWeld = weld
	end

	-- 프로펠러: 파트 → PropRoot 용접, PropRoot ↔ root 는 HingeConstraint 모터(굴대 = 로컬 Z)
	local hinges: { HingeConstraint } = {}
	local axis = CFrame.Angles(0, math.pi / 2, 0) -- 어태치먼트 X 축 → Z 축
	for _, prop in holder:GetChildren() do
		if prop:IsA("Model") and prop.Name == "Sn3_AirProp" then
			local pr = invisibleRoot("PropRoot", prop:GetPivot(), prop)
			for _, p in partsOf(prop) do
				if p ~= pr then
					p.CanCollide = false
					p.Massless = true
					local w = Instance.new("WeldConstraint")
					w.Part0 = pr
					w.Part1 = p
					w.Parent = p
					table.insert(extras, p)
				end
			end
			table.insert(extras, pr)
			local a0 = Instance.new("Attachment")
			a0.CFrame = root.CFrame:ToObjectSpace(pr.CFrame) * axis
			a0.Parent = root
			local a1 = Instance.new("Attachment")
			a1.CFrame = axis
			a1.Parent = pr
			local h = Instance.new("HingeConstraint")
			h.Attachment0 = a0
			h.Attachment1 = a1
			h.ActuatorType = Enum.ActuatorType.Motor
			h.AngularVelocity = 0
			h.MotorMaxAcceleration = PROP_ACCEL
			h.MotorMaxTorque = 1e7
			h.Parent = pr
			table.insert(hinges, h)
		end
	end

	local mover = RigidMover.new(root, shipParts, extras)

	local function setDoor(alpha: number) -- 0 열림 · 1 닫힘
		if doorWeld and doorRoot then
			local off = CFrame.new(0, 0, -doorTravel * alpha) * doorOpenOffset
			doorWeld.C0 = off
			if doorRoot.Anchored then
				doorRoot.CFrame = root.CFrame * off
			end
		end
	end
	local function slideDoor(close: boolean)
		local from = if close then 0 else 1
		local started = os.clock()
		while true do
			local f = math.min((os.clock() - started) / DOOR_SECONDS, 1)
			local e = f * f * (3 - 2 * f)
			setDoor(if close then e else 1 - e)
			if f >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		setDoor(1 - from)
	end
	local function spin(on: boolean)
		for _, h in hinges do
			h.AngularVelocity = if on then PROP_SPEED else 0
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "비행선"
	prompt.ActionText = "출발"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local busy = false
	prompt.Triggered:Connect(function()
		if busy then
			return
		end
		busy = true
		prompt.Enabled = false
		task.spawn(function()
			for n = AirshipRoute.COUNTDOWN, 1, -1 do
				holder:SetAttribute("Countdown", n)
				task.wait(1)
			end
			holder:SetAttribute("Countdown", 0)
			slideDoor(true)
			task.wait(0.5)

			local moorCF = root.CFrame
			local _, baseYaw = moorCF:ToOrientation()
			local points, locked = AirshipRoute.build(moorCF.Position)
			local cum, total = AirshipRoute.cumulative(points)
			local yaw = baseYaw
			mover:Begin()
			spin(true)
			holder:SetAttribute("Flying", true)
			local started = os.clock()
			local last = started
			local slowed = false
			while true do
				RunService.Heartbeat:Wait()
				local now = os.clock()
				local t = now - started
				if t >= AirshipRoute.DURATION then
					break
				end
				if not slowed and t >= AirshipRoute.DURATION - AirshipRoute.RAMP then
					slowed = true
					spin(false)
				end
				local pos, want = AirshipRoute.at(points, cum, total, locked, baseYaw, t)
				yaw = AirshipRoute.stepAngle(yaw, want, AirshipRoute.MAX_TURN * (now - last))
				last = now
				mover:Move(CFrame.new(pos.x, pos.y, pos.z) * CFrame.Angles(0, yaw, 0))
			end
			spin(false)
			mover:End(moorCF)
			holder:SetAttribute("Flying", false)
			task.wait(0.5)
			slideDoor(false)
			busy = false
			prompt.Enabled = true
		end)
	end)
end

function AirshipService.Start()
	local function hook(holder: Instance)
		if holder:IsA("Model") then
			task.defer(setup, holder)
		end
	end
	for _, holder in CollectionService:GetTagged("SnowAirship") do
		hook(holder)
	end
	CollectionService:GetInstanceAddedSignal("SnowAirship"):Connect(hook)
end

return AirshipService
