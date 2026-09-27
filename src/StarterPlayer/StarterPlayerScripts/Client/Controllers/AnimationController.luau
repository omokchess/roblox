--!strict
-- 절차적 애니메이션 엔진 (에셋 업로드 없이 동작)
--   * PoseLibrary 클립(키프레임 회전)을 Motor6D.Transform 에 적용
--   * R15 / R6 / 크리처 리그 공통 (관절 이름 매핑 + C0 회전 켤레 변환)
--   * 기본 Animator(걷기 등) 출력 위에 레이어로 블렌딩, 무기 들기 오버레이
--   * 크리처는 속도 기반 절차적 보행 + 숨쉬기
--   * 히트스톱(타격 순간 정지)
-- 적용 시점: RunService.PreSimulation (Animator 가 Transform 을 쓴 직후)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PoseLibrary = require(Shared.Combat.PoseLibrary)
local MoveDefs = require(Shared.Combat.MoveDefs)
local WeaponDefs = require(Shared.Combat.WeaponDefs)
local MathUtil = require(Shared.Util.MathUtil)
local CombatBus = require(script.Parent.CombatBus)

type Clip = PoseLibrary.Clip

local AnimationController = {}

local R6_MAP: { [string]: string } = {
	RootJoint = "Root",
	Neck = "Neck",
	["Right Shoulder"] = "RightShoulder",
	["Left Shoulder"] = "LeftShoulder",
	["Right Hip"] = "RightHip",
	["Left Hip"] = "LeftHip",
}
local UPPER: { [string]: boolean } = {
	Waist = true,
	Neck = true,
	RightShoulder = true,
	RightElbow = true,
	RightWrist = true,
	LeftShoulder = true,
	LeftElbow = true,
	LeftWrist = true,
}
local IDENT = CFrame.identity

type Layer = {
	name: string,
	clip: Clip,
	time: number,
	speed: number,
	priority: number,
	fadeIn: number,
	fadeOut: number,
	stopping: boolean,
	stopTime: number,
	weightScale: number,
	started: number,
}

type Rig = {
	model: Model,
	motors: { [string]: Motor6D },
	rot: { [string]: CFrame },
	rotInv: { [string]: CFrame },
	r6: boolean,
	custom: boolean,
	layers: { Layer },
	hold: Layer?,
	holdKind: string?,
	freezeUntil: number,
	lastWritten: { [Motor6D]: CFrame },
	lastBase: { [Motor6D]: CFrame },
	phase: number,
	root: BasePart?,
	humanoid: Humanoid?,
	legScale: number,
	dead: boolean,
}

local rigs: { [Model]: Rig } = {}
local clipJoints: { [Clip]: { string } } = {}

local function jointsOf(clip: Clip): { string }
	local cached = clipJoints[clip]
	if cached then
		return cached
	end
	local set: { [string]: boolean } = {}
	for _, k in clip.Keys do
		for j in k.joints do
			set[j] = true
		end
	end
	local list = {}
	for j in set do
		table.insert(list, j)
	end
	clipJoints[clip] = list
	return list
end

local function buildRig(model: Model): Rig?
	local motors: { [string]: Motor6D } = {}
	local r6 = false
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and not d:FindFirstAncestor("SwampWeapon") then
			local name = d.Name
			if R6_MAP[name] then
				name = R6_MAP[name]
				r6 = true
			end
			motors[name] = d
		end
	end
	if next(motors) == nil then
		return nil
	end
	local rot, rotInv = {}, {}
	for name, m in motors do
		local r = m.C0.Rotation
		rot[name] = r
		rotInv[name] = r:Inverse()
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local custom = model:GetAttribute("EnemyType") ~= nil
	local rig: Rig = {
		model = model,
		motors = motors,
		rot = rot,
		rotInv = rotInv,
		r6 = r6,
		custom = custom,
		layers = {},
		hold = nil,
		holdKind = nil,
		freezeUntil = 0,
		lastWritten = {},
		lastBase = {},
		phase = 0,
		root = root,
		humanoid = hum,
		legScale = if hum then math.max(1, hum.HipHeight + 1) else 3,
		dead = false,
	}
	return rig
end

local function getRig(model: Model?): Rig?
	if not model then
		return nil
	end
	local rig = rigs[model]
	if rig then
		return rig
	end
	local built = buildRig(model)
	if built then
		rigs[model] = built
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				rigs[model] = nil
			end
		end)
	end
	return built
end

-- ── 클립 평가 ────────────────────────────────────────────
local function evaluate(clip: Clip, t: number): ({ [string]: CFrame }, Vector3?)
	local keys = clip.Keys
	local n = #keys
	local out: { [string]: CFrame } = {}
	if n == 0 then
		return out, nil
	end
	if clip.Loop then
		t = t % clip.Duration
	end
	if t <= keys[1].t then
		for j, cf in keys[1].joints do
			out[j] = cf
		end
		return out, keys[1].root
	end
	if t >= keys[n].t then
		for j, cf in keys[n].joints do
			out[j] = cf
		end
		return out, keys[n].root
	end
	local a, b = keys[1], keys[2]
	for i = 1, n - 1 do
		if keys[i + 1].t >= t then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local span = math.max(1e-4, b.t - a.t)
	local alpha = MathUtil.ease(b.ease, (t - a.t) / span)
	for _, j in jointsOf(clip) do
		local fa = a.joints[j] or IDENT
		local fb = b.joints[j] or IDENT
		out[j] = fa:Lerp(fb, alpha)
	end
	local root: Vector3? = nil
	if a.root or b.root then
		root = (a.root or Vector3.zero):Lerp(b.root or Vector3.zero, alpha)
	end
	return out, root
end

local function layerWeight(l: Layer, now: number): number
	local w = math.clamp(l.time / math.max(1e-3, l.fadeIn), 0, 1)
	if l.stopping then
		w *= math.clamp(1 - (now - l.stopTime) / math.max(1e-3, l.fadeOut), 0, 1)
	elseif not l.clip.Loop and not l.clip.Hold then
		local remain = l.clip.Duration - l.time
		if remain < l.fadeOut then
			w *= math.clamp(remain / l.fadeOut, 0, 1)
		end
	end
	return w * l.weightScale
end

-- ── 공개 API ─────────────────────────────────────────────
export type PlayOptions = { priority: number?, offset: number?, speed: number?, fadeIn: number?, fadeOut: number?, replaceBelow: number?, weight: number? }

function AnimationController.Play(model: Model?, clipName: string, opts: PlayOptions?): boolean
	local rig = getRig(model)
	local clip = PoseLibrary.Clips[clipName]
	if not rig or not clip or rig.dead then
		return false
	end
	local o: PlayOptions = opts or {}
	local priority = o.priority or 2
	local now = os.clock()
	-- 같은/낮은 우선순위의 액션 레이어는 빠르게 정리
	local replace = o.replaceBelow or priority
	for _, l in rig.layers do
		if l.priority <= replace and not l.stopping then
			l.stopping = true
			l.stopTime = now
			l.fadeOut = 0.08
		end
	end
	local layer: Layer = {
		name = clipName,
		clip = clip,
		time = math.clamp(o.offset or 0, 0, clip.Duration),
		speed = o.speed or 1,
		priority = priority,
		fadeIn = o.fadeIn or 0.06,
		fadeOut = o.fadeOut or 0.12,
		stopping = false,
		stopTime = 0,
		weightScale = o.weight or 1,
		started = now,
	}
	table.insert(rig.layers, layer)
	table.sort(rig.layers, function(a, b)
		return a.priority < b.priority
	end)
	return true
end

function AnimationController.Stop(model: Model?, clipName: string?, fade: number?)
	local rig = model and rigs[model]
	if not rig then
		return
	end
	local now = os.clock()
	for _, l in rig.layers do
		if (clipName == nil or l.name == clipName) and not l.stopping then
			l.stopping = true
			l.stopTime = now
			l.fadeOut = fade or 0.1
		end
	end
end

function AnimationController.IsPlaying(model: Model?, clipName: string, within: number?): boolean
	local rig = model and rigs[model]
	if not rig then
		return false
	end
	for _, l in rig.layers do
		if l.name == clipName and not l.stopping and (within == nil or os.clock() - l.started < within) then
			return true
		end
	end
	return false
end

function AnimationController.Freeze(model: Model?, duration: number)
	local rig = getRig(model)
	if rig then
		rig.freezeUntil = math.max(rig.freezeUntil, os.clock() + duration)
	end
end

function AnimationController.SetHold(model: Model?, kind: string?)
	local rig = getRig(model)
	if not rig or rig.holdKind == kind then
		return
	end
	rig.holdKind = kind
	local clipName = kind and PoseLibrary.Holds[kind]
	local clip = clipName and PoseLibrary.Clips[clipName]
	if clip and clipName then
		rig.hold = {
			name = clipName,
			clip = clip,
			time = 0,
			speed = 1,
			priority = 0,
			fadeIn = 0.25,
			fadeOut = 0.2,
			stopping = false,
			stopTime = 0,
			weightScale = 1,
			started = os.clock(),
		}
	else
		rig.hold = nil
	end
end

-- ── 크리처 절차적 보행 ──────────────────────────────────
local function locomotion(rig: Rig, dt: number): ({ [string]: CFrame }, Vector3)
	local out: { [string]: CFrame } = {}
	local root = rig.root
	local speed = 0
	if root then
		local v = root.AssemblyLinearVelocity
		speed = Vector3.new(v.X, 0, v.Z).Magnitude
	end
	local amp = math.clamp(speed / 10, 0, 1)
	rig.phase += dt * speed / rig.legScale * 1.6
	local s = math.sin(rig.phase)
	local cs = math.cos(rig.phase)
	local hip = math.rad(34) * s * amp
	out.RightHip = CFrame.Angles(hip, 0, 0)
	out.LeftHip = CFrame.Angles(-hip, 0, 0)
	out.RightKnee = CFrame.Angles(-math.rad(50) * math.max(0, -s) * amp, 0, 0)
	out.LeftKnee = CFrame.Angles(-math.rad(50) * math.max(0, s) * amp, 0, 0)
	out.RightShoulder = CFrame.Angles(-hip * 0.7, 0, math.rad(6))
	out.LeftShoulder = CFrame.Angles(hip * 0.7, 0, -math.rad(6))
	out.RightElbow = CFrame.Angles(math.rad(20 + 15 * amp), 0, 0)
	out.LeftElbow = CFrame.Angles(math.rad(20 + 15 * amp), 0, 0)
	local breathe = math.sin(os.clock() * 2.2) * math.rad(2.5)
	out.Waist = CFrame.Angles(breathe - math.rad(6) * amp, math.rad(7) * s * amp, 0)
	out.Neck = CFrame.Angles(-breathe * 0.6, 0, 0)
	local bob = math.abs(cs) * 0.12 * rig.legScale * amp
	return out, Vector3.new(0, bob, 0)
end

-- ── 매 프레임 적용 ───────────────────────────────────────
local function conj(rig: Rig, joint: string, r: CFrame, offset: Vector3?): CFrame
	local rinv = rig.rotInv[joint]
	local rr = rig.rot[joint]
	if not rinv or not rr then
		return r
	end
	if offset then
		return rinv * CFrame.new(offset) * r * rr
	end
	return rinv * r * rr
end

local function stepRig(rig: Rig, dt: number, now: number)
	local frozen = now < rig.freezeUntil
	local adv = if frozen then dt * 0.03 else dt
	-- 레이어 시간 진행 & 정리
	local i = 1
	while i <= #rig.layers do
		local l = rig.layers[i]
		l.time += adv * l.speed
		local expired = (l.stopping and now - l.stopTime >= l.fadeOut)
			or (not l.clip.Loop and not l.clip.Hold and l.time >= l.clip.Duration)
		if expired then
			table.remove(rig.layers, i)
		else
			i += 1
		end
	end
	if rig.hold then
		rig.hold.time += adv
	end

	-- 기본 자세 (Animator 출력 또는 절차적 보행)
	local base: { [string]: CFrame } = {}
	local baseRoot: Vector3? = nil
	if rig.custom then
		if not rig.dead then
			base, baseRoot = locomotion(rig, dt)
		end
		for name in rig.motors do
			base[name] = conj(rig, name, base[name] or IDENT, if name == "Root" then baseRoot else nil)
		end
	else
		for name, m in rig.motors do
			local cur = m.Transform
			local last: any = rig.lastWritten[m]
			if last and (cur :: any) == last then
				base[name] = rig.lastBase[m] or IDENT -- Animator 가 이번 프레임에 안 씀
			else
				base[name] = cur
			end
		end
	end

	local final: { [string]: CFrame } = table.clone(base)
	local function applyLayer(l: Layer, w: number)
		if w <= 0.001 then
			return
		end
		local poses, rootOff = evaluate(l.clip, l.time)
		local upperOnly = l.clip.Layer == "Upper"
		for j, r in poses do
			if upperOnly and not UPPER[j] then
				continue
			end
			local target = j
			if rig.r6 and j == "Waist" then
				target = "Root"
			end
			if rig.motors[target] then
				local pose = conj(rig, target, r, if target == "Root" and not upperOnly then rootOff else nil)
				final[target] = (final[target] or IDENT):Lerp(pose, w)
			end
		end
		if rootOff and not upperOnly and rig.motors.Root and not poses.Root then
			final.Root = (final.Root or IDENT):Lerp(conj(rig, "Root", IDENT, rootOff), w)
		end
	end
	if rig.hold and not rig.dead then
		-- 액션 레이어가 강하게 덮고 있으면 들기 자세는 약하게
		applyLayer(rig.hold, 1)
	end
	for _, l in rig.layers do
		applyLayer(l, layerWeight(l, now))
	end
	for name, m in rig.motors do
		local f = final[name] or IDENT
		m.Transform = f
		rig.lastWritten[m] = f
		rig.lastBase[m] = base[name] or IDENT
	end
end

-- ── 전투 이벤트 → 애니메이션 ────────────────────────────
local predicted: { [string]: number } = {} -- 로컬 예측으로 시작한 클립 → 시각

local function blockClipFor(model: Model?): string?
	if not model then
		return nil
	end
	local wid = model:GetAttribute("WeaponId") :: string?
	local def = wid and WeaponDefs.Weapons[wid]
	return def and def.Block
end

local function onEvent(kind: string, data: any, isLocal: boolean)
	if type(data) ~= "table" then
		return
	end
	local now = workspace:GetServerTimeNow()
	if kind == "Action" then
		local move = MoveDefs.Moves[data.m]
		local model = CombatBus.Model(data.i)
		if not move or not model then
			return
		end
		local mine = CombatBus.IsLocal(data.i)
		if mine and not isLocal then
			local at = predicted[move.Anim]
			if at and os.clock() - at < 0.6 then
				return -- 이미 예측 재생 중
			end
		end
		if mine and isLocal then
			predicted[move.Anim] = os.clock()
		end
		local offset = if isLocal then 0 else math.clamp(now - (data.t or now), 0, 0.3)
		AnimationController.Play(model, move.Anim, { priority = 2, offset = offset, replaceBelow = 3 })
	elseif kind == "Charge" then
		local model = CombatBus.Model(data.i)
		if CombatBus.IsLocal(data.i) and not isLocal then
			return
		end
		AnimationController.Play(model, data.m, { priority = 2, fadeIn = 0.12 })
	elseif kind == "Dodge" then
		local model = CombatBus.Model(data.i)
		if CombatBus.IsLocal(data.i) and not isLocal then
			return
		end
		AnimationController.Play(model, "Roll", { priority = 3, replaceBelow = 3, fadeIn = 0.03 })
	elseif kind == "Block" then
		local model = CombatBus.Model(data.i)
		if CombatBus.IsLocal(data.i) and not isLocal then
			return
		end
		local clip = blockClipFor(model)
		if clip then
			if data.on then
				AnimationController.Play(model, clip, { priority = 2, fadeIn = 0.06 })
			else
				AnimationController.Stop(model, clip, 0.12)
			end
		end
	elseif kind == "Stagger" then
		local model = CombatBus.Model(data.i)
		AnimationController.Play(model, "Stagger", { priority = 4, replaceBelow = 4, speed = 0.9 / math.max(0.3, data.d or 0.9) })
	elseif kind == "Hit" then
		local victim = CombatBus.Model(data.v)
		local attacker = CombatBus.Model(data.a)
		local hs = tonumber(data.hs) or 0
		if hs > 0 then
			AnimationController.Freeze(victim, hs)
			AnimationController.Freeze(attacker, hs)
		end
		if not data.b then
			local rig = victim and rigs[victim]
			local busy = false
			if rig then
				for _, l in rig.layers do
					if l.priority >= 2 and not l.stopping then
						busy = true
					end
				end
			end
			if not busy then
				AnimationController.Play(victim, "HitReact", { priority = 1, replaceBelow = 1, weight = 0.8 })
			end
		end
	elseif kind == "Parry" then
		AnimationController.Play(CombatBus.Model(data.v), "Parry", { priority = 2, replaceBelow = 2 })
	elseif kind == "Died" then
		local model = CombatBus.Model(data.i)
		local rig = getRig(model)
		if rig and rig.custom then
			AnimationController.Play(model, "Death", { priority = 5, replaceBelow = 5, fadeIn = 0.1 })
			rig.hold = nil
			task.delay(1.3, function()
				rig.dead = true
			end)
		end
	elseif kind == "Equip" then
		local model = CombatBus.Model(data.i)
		AnimationController.Play(model, "Equip", { priority = 1, replaceBelow = 1 })
	end
end

local function trackHold(model: Model)
	local function update()
		AnimationController.SetHold(model, model:GetAttribute("WeaponKind") :: string?)
	end
	model:GetAttributeChangedSignal("WeaponKind"):Connect(update)
	update()
	-- 기절 루프
	model:GetAttributeChangedSignal("CState"):Connect(function()
		if model:GetAttribute("CState") == "Stunned" then
			AnimationController.Play(model, "Stun", { priority = 4, replaceBelow = 3 })
		else
			AnimationController.Stop(model, "Stun", 0.2)
		end
	end)
end

function AnimationController.CancelLocalAction()
	local ch = Players.LocalPlayer.Character
	local rig = ch and rigs[ch]
	if not rig then
		return
	end
	local now = os.clock()
	for _, l in rig.layers do
		if l.priority >= 2 and l.priority < 4 and not l.stopping then
			l.stopping = true
			l.stopTime = now
			l.fadeOut = 0.1
		end
	end
end

function AnimationController.Start()
	CombatBus.Subscribe(onEvent)
	local function watchCharacter(ch: Model)
		task.spawn(function()
			ch:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.2)
			trackHold(ch)
		end)
	end
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(watchCharacter)
		if p.Character then
			watchCharacter(p.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	for _, m in CollectionService:GetTagged("SwampEnemy") do
		if m:IsA("Model") then
			getRig(m)
			trackHold(m)
		end
	end
	CollectionService:GetInstanceAddedSignal("SwampEnemy"):Connect(function(m)
		if m:IsA("Model") then
			task.wait(0.1)
			getRig(m)
			trackHold(m)
		end
	end)
	RunService.PreSimulation:Connect(function(dt: number)
		local now = os.clock()
		for model, rig in rigs do
			if model.Parent then
				stepRig(rig, dt, now)
			end
		end
	end)
end

return AnimationController
