--!strict
-- 로컬 플레이어 전투 입력 & 예측
--   좌클릭/R2: 약공격 (길게 누르면 충전 강공격)   F/L2: 방어(타이밍 맞추면 패링)
--   Q/B: 구르기   E/X, R/Y: 무기 기술   1·2·3/D패드: 무기 교체   T/휠클릭/R3: 대상 고정
-- 입력 즉시 애니메이션/돌진을 예측 재생하고 서버에 요청 → 서버가 거절하면 취소.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Util.Net)
local CombatConfig = require(Shared.Combat.CombatConfig)
local MoveDefs = require(Shared.Combat.MoveDefs)
local WeaponDefs = require(Shared.Combat.WeaponDefs)
local MathUtil = require(Shared.Util.MathUtil)
local CombatBus = require(script.Parent.CombatBus)
local AnimationController = require(script.Parent.AnimationController)
local LockOnController = require(script.Parent.LockOnController)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer

local CombatController = {}

-- 로컬 상태 (서버 상태의 예측 사본)
local localMoveEnd = 0
local localMoveActiveStart = 0
local localMoveActiveEnd = 0
local localMoveSerial = 0
local comboIndex = 0
local lastLightEnd = -math.huge
local disabledUntil = 0
local dodgeReadyAt = 0
local blocking = false
local pressStart: number? = nil
local charging = false
local cooldowns: { [string]: number } = {}
local buffered: { kind: string, payload: any }? = nil

local request: RemoteEvent

local function now(): number
	return workspace:GetServerTimeNow()
end

local function character(): (Model?, Humanoid?, BasePart?)
	local ch = player.Character
	if not ch then
		return nil, nil, nil
	end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	local root = ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or hum.Health <= 0 then
		return nil, nil, nil
	end
	return ch, hum, root
end

local function weapon(): WeaponDefs.WeaponDef?
	local ch = player.Character
	local id = ch and ch:GetAttribute("WeaponId") :: string?
	return id and WeaponDefs.Weapons[id]
end

local function stamina(): number
	local ch = player.Character
	return (ch and ch:GetAttribute("Stamina") :: number?) or 100
end

local function aimDirection(root: BasePart): Vector3
	local target = LockOnController.Target()
	local tr = target and target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if tr then
		return MathUtil.flatUnit(tr.Position - root.Position)
	end
	local cam = workspace.CurrentCamera
	return MathUtil.flatUnit(cam.CFrame.LookVector)
end

local function send(kind: string, extra: { [string]: any }?)
	local payload: { [string]: any } = { t = now() }
	if extra then
		for k, v in extra do
			payload[k] = v
		end
	end
	request:FireServer(kind, payload)
end

-- ── 이동 보조 (클라이언트 소유 캐릭터) ─────────────────
local function planeVelocity(root: BasePart, name: string): LinearVelocity
	local old = root:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local att = root:FindFirstChild("SwampMoveAtt") :: Attachment?
	if not att then
		local a = Instance.new("Attachment")
		a.Name = "SwampMoveAtt"
		a.Parent = root
		att = a
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = name
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.MaxForce = 4e5
	lv.Parent = root
	return lv
end

local function lunge(root: BasePart, dir: Vector3, distance: number, delay: number, duration: number, serial: number)
	task.delay(delay, function()
		if serial ~= localMoveSerial or not root.Parent then
			return
		end
		local lv = planeVelocity(root, "SwampLunge")
		local v = dir * (distance / math.max(0.05, duration))
		lv.PlaneVelocity = Vector2.new(v.X, v.Z)
		task.delay(duration, function()
			if lv.Parent then
				lv:Destroy()
			end
		end)
	end)
end

local function face(root: BasePart, hum: Humanoid, dir: Vector3, lockFor: number)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	hum.AutoRotate = false
	local serial = localMoveSerial
	task.delay(lockFor, function()
		if serial == localMoveSerial and hum.Parent then
			hum.AutoRotate = true
		end
	end)
end

-- ── 예측 실행 ────────────────────────────────────────────
local function canAct(t: number): boolean
	if t < disabledUntil then
		return false
	end
	local ch = player.Character
	local st = ch and ch:GetAttribute("CState")
	return st ~= "Staggered" and st ~= "Stunned" and st ~= "Dead"
end

local function predictMove(moveId: string, kind: string, extra: { [string]: any }?)
	local ch, hum, root = character()
	if not ch or not hum or not root then
		return
	end
	local move = MoveDefs.Moves[moveId]
	if not move then
		return
	end
	local t = now()
	local dir = aimDirection(root)
	localMoveSerial += 1
	local total = move.Windup + move.Active + move.Recovery
	localMoveEnd = t + total
	localMoveActiveStart = t + move.Windup
	localMoveActiveEnd = t + move.Windup + move.Active
	if move.Cooldown then
		cooldowns[moveId] = t + move.Cooldown
	end
	if blocking then
		blocking = false
	end
	face(root, hum, dir, move.Windup + move.Active)
	CombatBus.Emit("Action", { i = ch:GetAttribute("CombatId"), m = moveId, t = t, d = dir, local_ = true })
	if move.Lunge then
		lunge(root, dir, move.Lunge, move.LungeStart or move.Windup * 0.5, move.LungeTime or 0.18, localMoveSerial)
	end
	local payload: { [string]: any } = { d = dir }
	if extra then
		for k, v in extra do
			payload[k] = v
		end
	end
	send(kind, payload)
end

local function tryLight()
	local w = weapon()
	if not w then
		return
	end
	local t = now()
	if not canAct(t) then
		return
	end
	if t < localMoveEnd then
		-- 입력 버퍼
		if localMoveEnd - t <= CombatConfig.Combo.BufferWindow then
			buffered = { kind = "Light", payload = nil }
		end
		return
	end
	if stamina() <= 0 then
		return
	end
	local idx = if t - lastLightEnd <= CombatConfig.Combo.ResetTime then (comboIndex % #w.Light) + 1 else 1
	comboIndex = idx
	predictMove(w.Light[idx], "Light", nil)
	lastLightEnd = localMoveEnd
end

local function tryHeavy(chargeTime: number)
	local w = weapon()
	if not w then
		return
	end
	local t = now()
	if not canAct(t) or t < localMoveEnd then
		return
	end
	comboIndex = 0
	lastLightEnd = -math.huge
	local ratio = math.clamp((chargeTime - CombatConfig.Heavy.MinCharge) / (CombatConfig.Heavy.MaxCharge - CombatConfig.Heavy.MinCharge), 0, 1)
	predictMove(w.Heavy, "Heavy", { ch = ratio })
	if ratio > 0.8 then
		CameraController.Punch(3)
	end
end

local function trySkill(slot: string)
	local w = weapon()
	if not w then
		return
	end
	local moveId = w.Skills[slot]
	if not moveId then
		return
	end
	local t = now()
	if not canAct(t) then
		return
	end
	if t < localMoveEnd then
		if localMoveEnd - t <= CombatConfig.Combo.BufferWindow then
			buffered = { kind = "Skill", payload = slot }
		end
		return
	end
	local cd = cooldowns[moveId]
	if cd and t < cd then
		return
	end
	local move = MoveDefs.Moves[moveId]
	if move.Stamina > 0 and stamina() <= 0 then
		return
	end
	comboIndex = 0
	predictMove(moveId, "Skill", { k = slot })
end

local function tryDodge()
	local ch, hum, root = character()
	if not ch or not hum or not root then
		return
	end
	local t = now()
	if not canAct(t) or t < dodgeReadyAt or stamina() <= 0 then
		return
	end
	-- 판정 중에는 불가, 선딜/후딜은 캔슬
	if t < localMoveEnd and t >= localMoveActiveStart - 0.03 and t <= localMoveActiveEnd then
		return
	end
	local cfg = CombatConfig.Dodge
	localMoveSerial += 1
	localMoveEnd = t + cfg.Duration
	localMoveActiveStart = t
	localMoveActiveEnd = t
	dodgeReadyAt = t + cfg.Duration + cfg.Cooldown - 0.2
	buffered = nil
	local move = hum.MoveDirection
	local dir: Vector3
	local clip = "Roll"
	if move.Magnitude > 0.1 then
		dir = MathUtil.flatUnit(move)
	else
		dir = -MathUtil.flatUnit(root.CFrame.LookVector)
		clip = "Backstep"
	end
	if clip == "Roll" then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	end
	hum.AutoRotate = false
	CombatBus.Emit("Dodge", { i = ch:GetAttribute("CombatId"), d = dir, t = t })
	if clip == "Backstep" then
		AnimationController.Play(ch, "Backstep", { priority = 3, replaceBelow = 3 })
	end
	send("Dodge", { d = dir })
	local lv = planeVelocity(root, "SwampDodge")
	local start = os.clock()
	local serial = localMoveSerial
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local e = os.clock() - start
		if e >= cfg.Duration or serial ~= localMoveSerial or not lv.Parent then
			if conn then
				conn:Disconnect()
			end
			if lv.Parent then
				lv:Destroy()
			end
			if hum.Parent then
				hum.AutoRotate = true
			end
			return
		end
		local k = 1 - (e / cfg.Duration) ^ 1.6
		local speed = cfg.Speed * (if clip == "Backstep" then 0.7 else 1) * (0.25 + 0.75 * k)
		lv.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
	end)
end

local function setBlock(on: boolean)
	local ch = player.Character
	if not ch then
		return
	end
	local t = now()
	if on then
		if not canAct(t) or t < localMoveEnd or blocking then
			return
		end
		blocking = true
		CombatBus.Emit("Block", { i = ch:GetAttribute("CombatId"), on = true })
		send("BlockStart")
	else
		if not blocking then
			return
		end
		blocking = false
		CombatBus.Emit("Block", { i = ch:GetAttribute("CombatId"), on = false })
		send("BlockEnd")
	end
end

local function equip(index: number)
	local t = now()
	if t < localMoveEnd or not canAct(t) then
		return
	end
	send("Equip", { n = index })
end

-- ── 입력 바인딩 ──────────────────────────────────────────
local function onAttack(_: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		pressStart = os.clock()
		charging = false
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		local held = if pressStart then os.clock() - pressStart else 0
		pressStart = nil
		if charging then
			charging = false
			tryHeavy(held)
		elseif state == Enum.UserInputState.End then
			tryLight()
		end
	end
	return Enum.ContextActionResult.Pass
end

local function bindActions()
	ContextActionService:BindAction("SwampAttack", onAttack, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("SwampBlock", function(_, state)
		if state == Enum.UserInputState.Begin then
			setBlock(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setBlock(false)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
	ContextActionService:BindAction("SwampDodge", function(_, state)
		if state == Enum.UserInputState.Begin then
			tryDodge()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("SwampSkillE", function(_, state)
		if state == Enum.UserInputState.Begin then
			trySkill("E")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("SwampSkillR", function(_, state)
		if state == Enum.UserInputState.Begin then
			trySkill("R")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("SwampLock", function(_, state)
		if state == Enum.UserInputState.Begin then
			LockOnController.Toggle()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.T, Enum.UserInputType.MouseButton3, Enum.KeyCode.ButtonR3)
	ContextActionService:BindAction("SwampWeapons", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local map: { [Enum.KeyCode]: number } = {
			[Enum.KeyCode.One] = 1,
			[Enum.KeyCode.Two] = 2,
			[Enum.KeyCode.Three] = 3,
			[Enum.KeyCode.DPadLeft] = 1,
			[Enum.KeyCode.DPadUp] = 2,
			[Enum.KeyCode.DPadRight] = 3,
		}
		local n = map[input.KeyCode]
		if n then
			equip(n)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadRight)

	-- 모바일 버튼 배치
	local titles = { SwampAttack = "공격", SwampBlock = "방어", SwampDodge = "구르기", SwampSkillE = "기술1", SwampSkillR = "기술2", SwampLock = "고정" }
	local positions = {
		SwampAttack = UDim2.new(1, -120, 1, -150),
		SwampDodge = UDim2.new(1, -190, 1, -90),
		SwampBlock = UDim2.new(1, -60, 1, -210),
		SwampSkillE = UDim2.new(1, -190, 1, -180),
		SwampSkillR = UDim2.new(1, -130, 1, -240),
		SwampLock = UDim2.new(1, -60, 1, -290),
	}
	for name, title in titles do
		ContextActionService:SetTitle(name, title)
		local pos = positions[name]
		if pos then
			ContextActionService:SetPosition(name, pos)
		end
	end
end

-- ── 서버 피드백 ──────────────────────────────────────────
local function onPrivate(kind: string, data: any)
	local _, hum, root = character()
	if kind == "Knockback" and root and type(data) == "table" and typeof(data.v) == "Vector3" then
		local att = root:FindFirstChild("SwampMoveAtt") :: Attachment?
		if not att then
			local a = Instance.new("Attachment")
			a.Name = "SwampMoveAtt"
			a.Parent = root
			att = a
		end
		local old = root:FindFirstChild("SwampKnock")
		if old then
			old:Destroy()
		end
		local lv = Instance.new("LinearVelocity")
		lv.Name = "SwampKnock"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.VectorVelocity = data.v
		lv.MaxForce = 6e5
		lv.Parent = root
		if hum and data.v.Y > 8 then
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		task.delay(tonumber(data.d) or 0.16, function()
			if lv.Parent then
				lv:Destroy()
			end
		end)
	elseif kind == "Reject" then
		-- 예측 취소
		localMoveSerial += 1
		localMoveEnd = 0
		localMoveActiveEnd = 0
		buffered = nil
		AnimationController.CancelLocalAction()
		if hum then
			hum.AutoRotate = true
		end
		if type(data) == "table" and data.r == "cooldown" and data.m then
			cooldowns[data.m] = nil
		end
	end
end

local function onEvent(kind: string, data: any, isLocal: boolean)
	if isLocal or type(data) ~= "table" then
		return
	end
	if kind == "Stagger" and CombatBus.IsLocal(data.i) then
		local d = tonumber(data.d) or 0.8
		disabledUntil = now() + d
		localMoveSerial += 1
		localMoveEnd = 0
		buffered = nil
		blocking = false
		CameraController.Shake(0.5)
	elseif kind == "Hit" then
		if CombatBus.IsLocal(data.v) then
			CameraController.Shake(if data.b then 0.15 else 0.35 + (tonumber(data.sh) or 0) * 0.3)
		elseif CombatBus.IsLocal(data.a) then
			CameraController.Shake(0.08 + (tonumber(data.sh) or 0) * 0.35)
		end
	elseif kind == "Parry" and (CombatBus.IsLocal(data.v) or CombatBus.IsLocal(data.a)) then
		CameraController.Shake(0.4)
		CameraController.Punch(4)
	end
end

function CombatController.Cooldown(moveId: string): number
	local cd = cooldowns[moveId]
	return if cd then math.max(0, cd - now()) else 0
end

function CombatController.IsBlocking(): boolean
	return blocking
end

function CombatController.Start()
	request = Net.Event("CombatRequest")
	bindActions()
	CombatBus.Subscribe(onEvent)
	CombatBus.SubscribePrivate(onPrivate)
	-- 충전 감지 & 버퍼 실행
	RunService.Heartbeat:Connect(function()
		local t = now()
		if pressStart and not charging and os.clock() - pressStart >= CombatConfig.Heavy.MinCharge then
			local w = weapon()
			local ch = player.Character
			if w and ch and canAct(t) and t >= localMoveEnd then
				charging = true
				send("HeavyStart")
				CombatBus.Emit("Charge", { i = ch:GetAttribute("CombatId"), m = w.HeavyCharge, t = t })
			end
		end
		if buffered and t >= localMoveEnd then
			local b = buffered
			buffered = nil
			if b.kind == "Light" then
				tryLight()
			elseif b.kind == "Skill" then
				trySkill(b.payload)
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		localMoveEnd = 0
		localMoveSerial += 1
		comboIndex = 0
		blocking = false
		disabledUntil = 0
		cooldowns = {}
		LockOnController.Clear()
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		setBlock(false)
		pressStart = nil
		charging = false
	end)
end

return CombatController
