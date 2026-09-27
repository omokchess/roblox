--!strict
-- 전투 서비스 (서버 권위)
--   * 요청 검증: 상태/스태미나/쿨다운/빈도 제한
--   * 기술 실행: 선딜→판정→후딜 타임라인, 콤보/입력 버퍼, 돌진
--   * 판정: 히트박스 + 지연 보상, 회피 무적, 방어/패링/가드 브레이크, 강인도/경직, 치명타/백어택/반격
--   * 상태이상 틱, 투사체, 지연 범위 공격, 넉백
--   * 모든 결과는 CombatEvent 로 브로드캐스트 → 클라이언트가 애니메이션/이펙트/UI 표시

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Util.Net)
local Signal = require(Shared.Util.Signal)
local CombatConfig = require(Shared.Combat.CombatConfig)
local MoveDefs = require(Shared.Combat.MoveDefs)
local WeaponDefs = require(Shared.Combat.WeaponDefs)
local StatusDefs = require(Shared.Combat.StatusDefs)
local Hitbox = require(Shared.Combat.Hitbox)
local DamageCalc = require(Shared.Combat.DamageCalc)

local Combatant = require(script.Parent.Combatant)
local LagCompensation = require(script.Parent.LagCompensation)
local ProjectileService = require(script.Parent.ProjectileService)
local WeaponService = require(script.Parent.WeaponService)

type Combatant = Combatant.Combatant
type Move = MoveDefs.Move

local CombatService = {}

CombatService.Died = Signal.new() :: Signal.Signal<Combatant, Combatant?>
CombatService.Damaged = Signal.new() :: Signal.Signal<Combatant, Combatant?, number>
-- 소환 훅 (EnemyService 가 설정)
CombatService.SummonHandler = nil :: ((owner: Combatant, enemyType: string, count: number) -> ())?

local combatants: { [number]: Combatant } = {}
local byModel: { [Model]: Combatant } = {}
local byPlayer: { [Player]: Combatant } = {}
local rng = Random.new()
local serial = 0
local loadouts: { [Player]: { string } } = {}
local requestTimes: { [Player]: { number } } = {}

type PendingArea = { id: number, owner: Combatant, spec: MoveDefs.AreaSpec, pos: Vector3, at: number, moveId: string }
local areas: { PendingArea } = {}
local areaSerial = 0

local eventRemote: RemoteEvent
local privateRemote: RemoteEvent

local function now(): number
	return workspace:GetServerTimeNow()
end

local function broadcast(kind: string, data: any)
	eventRemote:FireAllClients(kind, data)
end

local function private(c: Combatant, kind: string, data: any)
	if c.Player then
		privateRemote:FireClient(c.Player, kind, data)
	end
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-4 then
		return Vector3.new(0, 0, -1)
	end
	return f.Unit
end

-- ─────────────────────────────────────────────────────────────
-- 등록
-- ─────────────────────────────────────────────────────────────

function CombatService.Get(model: Instance?): Combatant?
	if not model then
		return nil
	end
	return byModel[model :: any]
end

function CombatService.GetById(id: number): Combatant?
	return combatants[id]
end

function CombatService.GetPlayer(player: Player): Combatant?
	return byPlayer[player]
end

function CombatService.All(): { [number]: Combatant }
	return combatants
end

function CombatService.Register(c: Combatant)
	combatants[c.Id] = c
	byModel[c.Model] = c
	if c.Player then
		byPlayer[c.Player] = c
	end
	c.Humanoid.Died:Connect(function()
		CombatService.Kill(c, nil)
	end)
	c.Model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			CombatService.Unregister(c)
		end
	end)
end

function CombatService.Unregister(c: Combatant)
	combatants[c.Id] = nil
	byModel[c.Model] = nil
	if c.Player and byPlayer[c.Player] == c then
		byPlayer[c.Player] = nil
	end
	LagCompensation.Forget(c.Id)
end

local function isHostile(a: Combatant, b: Combatant): boolean
	if a == b or b.Dead then
		return false
	end
	if a.Team ~= b.Team then
		return true
	end
	return CombatConfig.PvP and a.Kind == "Player" and b.Kind == "Player"
end

local function hostilesOf(owner: Combatant): { Combatant }
	local out = {}
	for _, c in combatants do
		if isHostile(owner, c) and c.Root.Parent then
			table.insert(out, c)
		end
	end
	return out
end

CombatService.Hostiles = hostilesOf

-- ─────────────────────────────────────────────────────────────
-- 이동 보조 (NPC: 서버, 플레이어: 소유 클라이언트)
-- ─────────────────────────────────────────────────────────────

local function applyVelocity(c: Combatant, velocity: Vector3, duration: number)
	if c.Player then
		private(c, "Knockback", { v = velocity, d = duration })
		return
	end
	local root = c.Root
	local att = root:FindFirstChild("KnockAtt") :: Attachment?
	if not att then
		local a = Instance.new("Attachment")
		a.Name = "KnockAtt"
		a.Parent = root
		att = a
	end
	local old = root:FindFirstChild("KnockVel")
	if old then
		old:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "KnockVel"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = velocity
	lv.MaxForce = 1e6 * root.AssemblyMass
	lv.Parent = root
	task.delay(duration, function()
		if lv.Parent then
			lv:Destroy()
		end
	end)
end

local function lungeNPC(c: Combatant, dir: Vector3, distance: number, duration: number)
	applyVelocity(c, flat(dir) * (distance / math.max(0.05, duration)), duration)
end

function CombatService.Knockback(target: Combatant, from: Vector3, horizontal: number, up: number)
	if (horizontal <= 0 and up <= 0) or target.Boss then
		return
	end
	local dir = flat(target.Root.Position - from)
	local scale = target.KnockbackScale
	local v = dir * math.min(horizontal, CombatConfig.KnockbackMax) * scale + Vector3.new(0, up * scale, 0)
	applyVelocity(target, v, 0.16)
end

-- ─────────────────────────────────────────────────────────────
-- 피해 / 사망 / 경직
-- ─────────────────────────────────────────────────────────────

function CombatService.Kill(c: Combatant, killer: Combatant?)
	if c.Dead then
		return
	end
	c.Dead = true
	c.Move = nil
	c.State = "Dead"
	c.AttrDirty = true
	if c.Humanoid.Health > 0 then
		c.Humanoid.Health = 0
	end
	broadcast("Died", { i = c.Id, k = killer and killer.Id })
	CombatService.Died:Fire(c, killer)
end

function CombatService.Damage(target: Combatant, amount: number, source: Combatant?, kind: string?)
	if target.Dead or amount <= 0 then
		return
	end
	local hum = target.Humanoid
	hum.Health = math.max(0, hum.Health - amount)
	target.LastCombat = now()
	if source then
		source.LastCombat = target.LastCombat
	end
	CombatService.Damaged:Fire(target, source, amount)
	if kind then
		broadcast("Tick", { v = target.Id, n = amount, k = kind })
	end
	if hum.Health <= 0 then
		CombatService.Kill(target, source)
	end
end

function CombatService.CancelMove(c: Combatant)
	if c.Move then
		c.Move = nil
		c.Buffered = nil
		c.AttrDirty = true
	end
end

function CombatService.Stagger(c: Combatant, duration: number, reason: string)
	if c.Dead then
		return
	end
	local t = now()
	CombatService.CancelMove(c)
	c:SetState("Staggered", duration, t)
	c.Poise = 0
	broadcast("Stagger", { i = c.Id, d = duration, r = reason })
end

-- ─────────────────────────────────────────────────────────────
-- 명중 처리
-- ─────────────────────────────────────────────────────────────

type HitSpec = {
	Damage: number,
	Poise: number,
	Knockback: number?,
	KnockUp: number?,
	Unblockable: boolean?,
	Unparryable: boolean?,
	Statuses: { MoveDefs.StatusApply }?,
	HitStop: number?,
	Shake: number?,
	ChargeMult: number?,
	MoveId: string?,
	Origin: Vector3, -- 넉백/방향 기준점
}

local function specFromMove(move: Move, moveId: string, origin: Vector3, chargeMult: number?): HitSpec
	return {
		Damage = move.Damage,
		Poise = move.Poise,
		Knockback = move.Knockback,
		KnockUp = move.KnockUp,
		Unblockable = move.Unblockable,
		Unparryable = move.Unparryable,
		Statuses = move.Statuses,
		HitStop = move.HitStop,
		Shake = move.Shake,
		ChargeMult = chargeMult,
		MoveId = moveId,
		Origin = origin,
	}
end

local function applyStatuses(target: Combatant, list: { MoveDefs.StatusApply }?, source: Combatant, t: number)
	if not list then
		return
	end
	for _, s in list do
		if s.Chance == nil or rng:NextNumber() <= s.Chance then
			local def = StatusDefs[s.Id]
			if def then
				if def.Kind == "Buildup" then
					target:AddStatus(s.Id, t, 0, s.Amount or 30, s.Duration, source)
				else
					target:AddStatus(s.Id, t, s.Stacks or 1, nil, s.Duration, source)
				end
				if def.Kind == "Stun" then
					CombatService.CancelMove(target)
					target:SetState("Stunned", s.Duration or def.Duration, t)
				end
			end
		end
	end
end

function CombatService.ApplyHit(attacker: Combatant, target: Combatant, spec: HitSpec, hitPos: Vector3?)
	if target.Dead then
		return
	end
	local t = now()
	local pos = hitPos or target.Root.Position
	if target:IsInvulnerable(t) then
		broadcast("Evade", { v = target.Id, a = attacker.Id })
		return
	end
	attacker.LastCombat = t
	target.LastCombat = t
	local frontal = DamageCalc.IsFrontal(spec.Origin, target.Root.CFrame, CombatConfig.Block.HalfAngle)

	-- 방어 / 패링
	if target.State == "Blocking" and frontal and not spec.Unblockable then
		local since = t - target.BlockStart
		local grace = if target.Player then CombatConfig.Block.ParryLatencyGrace + target.LastLag * 0.5 else 0
		if not spec.Unparryable and since <= CombatConfig.Block.ParryWindow + grace then
			target:AddStatus("Riposte", t, 1, nil, CombatConfig.Parry.RiposteWindow, target)
			target:Restore(15)
			if not attacker:HasSuperArmor(t) and not attacker.Boss then
				CombatService.Stagger(attacker, CombatConfig.Parry.AttackerStagger, "Parry")
			end
			broadcast("Parry", { a = attacker.Id, v = target.Id, p = pos })
			return
		end
		local dmg = DamageCalc.Compute({
			Base = spec.Damage,
			Power = attacker.Stats.Power,
			ChargeMult = spec.ChargeMult,
			Defense = target.Stats.Defense,
			BlockReduction = target.BlockReduction,
		})
		target:Spend(spec.Damage * CombatConfig.Block.StaminaPerDamage, t)
		CombatService.Damage(target, dmg, attacker, nil)
		broadcast("Hit", { a = attacker.Id, v = target.Id, n = dmg, b = true, p = pos, m = spec.MoveId, hs = (spec.HitStop or 0) * 0.5 })
		if target.Stamina <= 0 and not target.Dead then
			target.State = "Idle"
			CombatService.Stagger(target, CombatConfig.Block.GuardBreakStagger, "GuardBreak")
			broadcast("GuardBreak", { v = target.Id, p = pos })
		else
			CombatService.Knockback(target, spec.Origin, (spec.Knockback or 0) * 0.35, 0)
		end
		return
	end

	-- 일반 명중
	local crit = rng:NextNumber() < CombatConfig.Crit.Chance
	local back = DamageCalc.IsBehind(spec.Origin, target.Root.CFrame, CombatConfig.Backstab.HalfAngle)
	local riposte = attacker:HasStatus("Riposte", t)
	if riposte then
		attacker:RemoveStatus("Riposte")
	end
	local dmg = DamageCalc.Compute({
		Base = spec.Damage,
		Power = attacker.Stats.Power,
		ChargeMult = spec.ChargeMult,
		Crit = crit,
		Backstab = back,
		Riposte = riposte,
		Defense = target.Stats.Defense,
		Variance = rng:NextNumber(),
	})
	if dmg > 0 then
		CombatService.Damage(target, dmg, attacker, nil)
	end
	broadcast("Hit", {
		a = attacker.Id,
		v = target.Id,
		n = dmg,
		c = crit or nil,
		bk = back or nil,
		r = riposte or nil,
		p = pos,
		m = spec.MoveId,
		hs = spec.HitStop,
		sh = spec.Shake,
	})
	if target.Dead then
		return
	end
	applyStatuses(target, spec.Statuses, attacker, t)
	-- 강인도
	if spec.Poise > 0 and not target:HasSuperArmor(t) then
		target.Poise += spec.Poise * (if riposte then 2 else 1)
		target.LastPoiseHit = t
		if target.Poise >= target.Stats.MaxPoise then
			CombatService.Stagger(target, if target.Boss then 1.6 else CombatConfig.Poise.StaggerTime, "Poise")
		end
	end
	CombatService.Knockback(target, spec.Origin, spec.Knockback or 0, spec.KnockUp or 0)
end

-- ─────────────────────────────────────────────────────────────
-- 범위 공격 (지연 폭발)
-- ─────────────────────────────────────────────────────────────

local function groundAt(pos: Vector3, owner: Combatant): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { owner.Model }
	params.IgnoreWater = false
	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position else Vector3.new(pos.X, math.max(pos.Y - 3, 0), pos.Z)
end

function CombatService.ScheduleArea(owner: Combatant, spec: MoveDefs.AreaSpec, moveId: string, targetPos: Vector3?, aimDir: Vector3)
	local t = now()
	local positions: { Vector3 } = {}
	local origin = owner.Root.Position
	local step = spec.Step or 0
	if spec.At == "Self" then
		table.insert(positions, origin)
	elseif spec.At == "Target" then
		table.insert(positions, targetPos or origin + aimDir * 10)
	elseif spec.At == "Front" then
		table.insert(positions, origin + aimDir * (spec.Forward or 8))
	elseif spec.At == "Line" then
		for i = 1, spec.Count or 5 do
			table.insert(positions, origin + aimDir * ((spec.Forward or 4) + (i - 1) * (spec.Spacing or 6)))
		end
	elseif spec.At == "RandomAroundTarget" then
		local center = targetPos or origin
		table.insert(positions, center)
		for _ = 2, spec.Count or 5 do
			local a = rng:NextNumber() * math.pi * 2
			local r = math.sqrt(rng:NextNumber()) * (spec.Spread or 20)
			table.insert(positions, center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		end
	end
	for i, p in positions do
		areaSerial += 1
		local g = groundAt(p, owner)
		local at = t + spec.Delay + (i - 1) * step
		table.insert(areas, { id = areaSerial, owner = owner, spec = spec, pos = g, at = at, moveId = moveId })
		broadcast("Area", { id = areaSerial, p = g, r = spec.Radius, at = at, v = spec.Visual, o = owner.Id })
	end
end

local function resolveAreas(t: number)
	local i = 1
	while i <= #areas do
		local a = areas[i]
		if t >= a.at then
			table.remove(areas, i)
			broadcast("AreaBoom", { id = a.id, p = a.pos, r = a.spec.Radius, v = a.spec.Visual })
			if not a.owner.Dead or a.owner.Kind == "Enemy" then
				local spec: HitSpec = {
					Damage = a.spec.Damage,
					Poise = a.spec.Poise or 0,
					KnockUp = a.spec.KnockUp,
					Knockback = a.spec.Knockback,
					Unblockable = a.spec.Unblockable,
					Statuses = a.spec.Statuses,
					MoveId = a.moveId,
					Origin = a.pos,
				}
				for _, c in hostilesOf(a.owner) do
					local d = c.Root.Position - a.pos
					if Vector3.new(d.X, 0, d.Z).Magnitude <= a.spec.Radius + c.Stats.HitRadius * 0.6 and math.abs(d.Y) < 12 then
						CombatService.ApplyHit(a.owner, c, spec, c.Root.Position)
					end
				end
			end
		else
			i += 1
		end
	end
end

-- ─────────────────────────────────────────────────────────────
-- 기술 실행
-- ─────────────────────────────────────────────────────────────

export type PerformOptions = {
	Aim: Vector3?,
	Lag: number?,
	ComboIndex: number?,
	ChargeRatio: number?,
	Target: Combatant?,
	Kind: string?,
}

function CombatService.CanPerform(c: Combatant, moveId: string, t: number): (boolean, string?)
	local move = MoveDefs.Moves[moveId]
	if not move then
		return false, "unknown"
	end
	if c:IsDisabled(t) then
		return false, "disabled"
	end
	if c.Move and t < c.Move.End then
		return false, "busy"
	end
	if c.State == "Dodging" and t < c.StateUntil then
		return false, "dodging"
	end
	local cd = c.Cooldowns[moveId]
	if cd and t < cd then
		return false, "cooldown"
	end
	if move.Stamina > 0 and not c:CanSpend(t) then
		return false, "stamina"
	end
	return true, nil
end

function CombatService.Perform(c: Combatant, moveId: string, opts: PerformOptions?): boolean
	local o: PerformOptions = opts or {}
	local t = now()
	local ok, reason = CombatService.CanPerform(c, moveId, t)
	if not ok then
		private(c, "Reject", { m = moveId, r = reason })
		return false
	end
	local move = MoveDefs.Moves[moveId]
	if c.State == "Blocking" then
		c.State = "Idle"
		broadcast("Block", { i = c.Id, on = false })
	end
	c:Spend(move.Stamina, t)
	if move.Cooldown then
		c.Cooldowns[moveId] = t + move.Cooldown
	end
	local lag = math.clamp(o.Lag or 0, 0, CombatConfig.LagComp.MaxRewind)
	local start = t - lag
	serial += 1
	local aim = flat(o.Aim or c.Root.CFrame.LookVector)
	local mv: Combatant.ActiveMove = {
		Serial = serial,
		MoveId = moveId,
		Move = move,
		Start = start,
		ActiveStart = start + move.Windup,
		ActiveEnd = start + move.Windup + move.Active,
		End = start + move.Windup + move.Active + move.Recovery,
		AimDir = aim,
		Lag = lag,
		ChargeMult = DamageCalc.ChargeMult(o.ChargeRatio or 0),
		ComboIndex = o.ComboIndex or 0,
		HitCount = {},
		LastHit = {},
		Fired = false,
		Target = o.Target,
		Kind = o.Kind or move.Type,
	}
	c.Move = mv
	c.LastCombat = t
	c.AttrDirty = true
	broadcast("Action", { i = c.Id, m = moveId, t = start, d = aim, s = serial, c = mv.ComboIndex, ch = o.ChargeRatio })
	-- NPC 돌진은 서버가 직접
	if move.Lunge and c.Kind == "Enemy" then
		local ls = move.LungeStart or move.Windup * 0.5
		local lt = move.LungeTime or 0.18
		task.delay(math.max(0, mv.Start + ls - t), function()
			if c.Move == mv and not c.Dead then
				lungeNPC(c, mv.AimDir, move.Lunge :: number, lt)
			end
		end)
	end
	return true
end

-- 판정 단계 진행 (매 틱)
local function stepMove(c: Combatant, t: number)
	local mv = c.Move
	if not mv then
		return
	end
	local move = mv.Move
	-- NPC: 선딜 동안 대상 쪽으로 회전 추적
	if c.Kind == "Enemy" and t < mv.ActiveStart and mv.Target and mv.Target.Root then
		local want = flat(mv.Target.Root.Position - c.Root.Position)
		local maxTurn = math.rad(if c.Boss then 110 else 240) / CombatConfig.TickRate
		local cur = mv.AimDir
		local ang = math.acos(math.clamp(cur:Dot(want), -1, 1))
		local f = if ang > 1e-4 then math.min(1, maxTurn / ang) else 1
		mv.AimDir = flat(cur:Lerp(want, f))
		local p = c.Root.Position
		c.Root.CFrame = CFrame.lookAt(p, p + mv.AimDir)
	end
	if t >= mv.ActiveStart and not mv.Fired then
		mv.Fired = true
		if move.Projectile then
			local att = c.Model:FindFirstChild("CastPoint", true) :: Attachment?
			local origin = if att then att.WorldPosition else c.Root.Position + mv.AimDir * 2 + Vector3.new(0, 1.5, 0)
			local dir = mv.AimDir
			if mv.Target and mv.Target.Root then
				local tp = mv.Target.Root.Position
				local lead = (tp - origin)
				dir = lead.Unit
			end
			ProjectileService.Fire(c, move.Projectile, origin, dir, mv.Target, t)
		end
		if move.Area then
			local tp = if mv.Target and mv.Target.Root then mv.Target.Root.Position else nil
			CombatService.ScheduleArea(c, move.Area, mv.MoveId, tp, mv.AimDir)
		end
		if move.Summon and CombatService.SummonHandler then
			CombatService.SummonHandler(c, move.Summon.Type, move.Summon.Count)
		end
	end
	if move.Hitbox and t >= mv.ActiveStart and t <= mv.ActiveEnd + 1 / CombatConfig.TickRate then
		local rootPos = c.Root.Position
		local origin = CFrame.lookAt(rootPos, rootPos + mv.AimDir)
		local rewind = if c.Kind == "Player" then math.clamp(mv.Lag + CombatConfig.LagComp.InterpDelay, 0, CombatConfig.LagComp.MaxRewind) else 0
		local reach = Hitbox.Reach(move.Hitbox) + 12
		local maxHits = move.MultiHit or 1
		local interval = move.HitInterval or 0
		for _, target in hostilesOf(c) do
			local count = mv.HitCount[target] or 0
			if count >= maxHits then
				continue
			end
			if count > 0 and t - (mv.LastHit[target] or 0) < interval then
				continue
			end
			local tpos = target.Root.Position
			if (tpos - rootPos).Magnitude > reach then
				continue
			end
			local checkPos = if rewind > 0 then LagCompensation.PositionAt(target.Id, t - rewind, tpos) else tpos
			if Hitbox.Test(move.Hitbox, origin, checkPos, target.Stats.HitRadius, CombatConfig.HitRadiusSlack) then
				mv.HitCount[target] = count + 1
				mv.LastHit[target] = t
				CombatService.ApplyHit(c, target, specFromMove(move, mv.MoveId, rootPos, mv.ChargeMult), checkPos)
				if c.Move ~= mv then
					return -- 패링 등으로 취소됨
				end
			end
		end
	end
	if t >= mv.End then
		c.Move = nil
		c.AttrDirty = true
		if mv.Kind == "Light" then
			c.LastLightEnd = t
		end
		local buf = c.Buffered
		c.Buffered = nil
		if buf and t - buf.at < CombatConfig.Combo.BufferWindow + 0.2 then
			CombatService.HandleAction(c, buf.kind, buf.payload, buf.lag)
		end
	end
end

-- ─────────────────────────────────────────────────────────────
-- 상태이상 / 회복 틱
-- ─────────────────────────────────────────────────────────────

local function stepStatuses(c: Combatant, t: number, dt: number)
	for id, e in c.Statuses do
		local def = StatusDefs[id]
		if not def then
			c.Statuses[id] = nil
			continue
		end
		if def.Kind == "Buildup" then
			e.Amount -= (def.Decay or 10) * dt
			if e.Amount >= (def.Threshold or 100) then
				e.Amount = 0
				local dmg = math.floor(c.Stats.MaxHealth * (def.BurstPct or 0.1) + 0.5)
				CombatService.Damage(c, dmg, e.Source, id)
				c:AddStatus("Slow", t, 1, nil, 1.2, e.Source)
				broadcast("Burst", { v = c.Id, k = id, n = dmg })
			end
			if e.Amount <= 0 then
				c.Statuses[id] = nil
			end
			c.AttrDirty = true
		elseif def.Kind == "Dot" and t >= e.NextTick then
			e.NextTick = t + (def.Tick or 1)
			local dmg = math.max(1, math.floor(c.Stats.MaxHealth * (def.DamagePct or 0.01) * e.Stacks + 0.5))
			CombatService.Damage(c, dmg, e.Source, id)
		end
		if e.Expire <= t and c.Statuses[id] == e then
			c.Statuses[id] = nil
			c.AttrDirty = true
		end
	end
end

local function stepRegen(c: Combatant, t: number, dt: number)
	local cfg = CombatConfig.Stamina
	if c.Stamina < c.Stats.MaxStamina and t - c.LastStaminaUse >= cfg.RegenDelay then
		local rate = cfg.Regen * (if c.State == "Blocking" then cfg.BlockRegenScale else 1)
		if c.Move and t < c.Move.End then
			rate *= 0.3
		end
		c.Stamina = math.min(c.Stats.MaxStamina, c.Stamina + rate * dt)
		c.AttrDirty = true
	end
	if c.Poise > 0 and t - c.LastPoiseHit >= CombatConfig.Poise.RegenDelay then
		c.Poise = math.max(0, c.Poise - CombatConfig.Poise.RegenRate * dt)
		c.AttrDirty = true
	end
	if (c.State == "Staggered" or c.State == "Stunned" or c.State == "Dodging") and t >= c.StateUntil then
		c.State = "Idle"
		c.AttrDirty = true
	end
	-- 이동 속도
	local speed = c.Stats.WalkSpeed * c:SpeedMultiplier(t)
	if math.abs(c.Humanoid.WalkSpeed - speed) > 0.05 then
		c.Humanoid.WalkSpeed = speed
	end
end

-- ─────────────────────────────────────────────────────────────
-- 플레이어 요청
-- ─────────────────────────────────────────────────────────────

local function rateOk(player: Player): boolean
	local list = requestTimes[player]
	if not list then
		list = {}
		requestTimes[player] = list
	end
	local t = os.clock()
	while #list > 0 and t - list[1] > 1 do
		table.remove(list, 1)
	end
	if #list >= 24 then
		return false
	end
	table.insert(list, t)
	return true
end

local function aimFrom(payload: any, c: Combatant): Vector3
	local d = payload and payload.d
	if typeof(d) == "Vector3" and d.Magnitude > 0.01 then
		return flat(d)
	end
	return flat(c.Root.CFrame.LookVector)
end

function CombatService.HandleAction(c: Combatant, kind: string, payload: any, lag: number)
	local t = now()
	c.LastLag = lag
	local weapon = if c.WeaponId then WeaponDefs.Weapons[c.WeaponId] else nil
	-- 기술 진행 중이면 버퍼링
	if (kind == "Light" or kind == "Heavy" or kind == "Skill") and c.Move and t < c.Move.End then
		if c.Move.End - t <= CombatConfig.Combo.BufferWindow then
			c.Buffered = { kind = kind :: string, payload = payload, lag = lag, at = t }
		end
		return
	end
	if kind == "Light" then
		if not weapon then
			return
		end
		local chain = weapon.Light
		local idx = 1
		if t - c.LastLightEnd <= CombatConfig.Combo.ResetTime then
			idx = (c.ComboIndex % #chain) + 1
		end
		if CombatService.Perform(c, chain[idx], { Aim = aimFrom(payload, c), Lag = lag, ComboIndex = idx, Kind = "Light" }) then
			c.ComboIndex = idx
		end
	elseif kind == "HeavyStart" then
		if weapon and not c:IsBusy(t) then
			c.ChargeStart = t - lag
			broadcast("Charge", { i = c.Id, m = weapon.HeavyCharge, t = c.ChargeStart })
		end
	elseif kind == "Heavy" then
		if not weapon then
			return
		end
		local held = if c.ChargeStart then t - lag - c.ChargeStart else 0
		c.ChargeStart = nil
		local ratio = math.clamp((held - CombatConfig.Heavy.MinCharge) / (CombatConfig.Heavy.MaxCharge - CombatConfig.Heavy.MinCharge), 0, 1)
		c.ComboIndex = 0
		CombatService.Perform(c, weapon.Heavy, { Aim = aimFrom(payload, c), Lag = lag, ChargeRatio = ratio, Kind = "Heavy" })
	elseif kind == "Skill" then
		if not weapon then
			return
		end
		local slot = payload and payload.k
		local moveId = if type(slot) == "string" then weapon.Skills[slot] else nil
		if moveId then
			c.ComboIndex = 0
			CombatService.Perform(c, moveId, { Aim = aimFrom(payload, c), Lag = lag, Kind = "Skill" })
		end
	elseif kind == "Dodge" then
		CombatService.Dodge(c, aimFrom(payload, c), lag)
	elseif kind == "BlockStart" then
		if not c:IsBusy(t) and c.State ~= "Blocking" then
			c.State = "Blocking"
			c.BlockStart = t - lag
			c.AttrDirty = true
			broadcast("Block", { i = c.Id, on = true })
		end
	elseif kind == "BlockEnd" then
		if c.State == "Blocking" then
			c.State = "Idle"
			c.AttrDirty = true
			broadcast("Block", { i = c.Id, on = false })
		end
	elseif kind == "Equip" then
		local idx = payload and payload.n
		local player = c.Player
		if player and type(idx) == "number" and not c:IsBusy(t) then
			local list = loadouts[player] or WeaponDefs.Loadout
			local id = list[math.floor(idx)]
			if id and id ~= c.WeaponId then
				CombatService.EquipWeapon(c, id)
			end
		end
	end
end

function CombatService.Dodge(c: Combatant, dir: Vector3, lag: number): boolean
	local t = now()
	if c:IsDisabled(t) or t < c.DodgeReadyAt or not c:CanSpend(t) then
		private(c, "Reject", { m = "Dodge" })
		return false
	end
	local mv = c.Move
	if mv then
		-- 선딜/후딜 중에는 회피로 캔슬 가능, 판정 중에는 불가
		if t >= mv.ActiveStart - 0.03 and t <= mv.ActiveEnd then
			private(c, "Reject", { m = "Dodge" })
			return false
		end
		CombatService.CancelMove(c)
	end
	local cfg = CombatConfig.Dodge
	c:Spend(cfg.Cost, t)
	local start = t - math.clamp(lag, 0, CombatConfig.LagComp.MaxRewind)
	c.IFrameStart = start + cfg.IFrameStart
	c.IFrameEnd = start + cfg.IFrameEnd
	c.DodgeReadyAt = start + cfg.Duration + cfg.Cooldown - 0.2
	c.State = "Dodging"
	c.StateUntil = start + cfg.Duration
	c.AttrDirty = true
	c.Buffered = nil
	broadcast("Dodge", { i = c.Id, d = dir, t = start })
	if c.Kind == "Enemy" then
		applyVelocity(c, dir * cfg.Speed * 0.8, cfg.Duration * 0.6)
	end
	return true
end

function CombatService.EquipWeapon(c: Combatant, weaponId: string)
	if not c.Player then
		return
	end
	local def = WeaponService.EquipPlayer(c.Model, weaponId)
	if def then
		c.WeaponId = weaponId
		c.WeaponKind = def.Kind
		c.BlockReduction = def.BlockReduction
		c.SpeedScale = def.SpeedScale
		c.ComboIndex = 0
		broadcast("Equip", { i = c.Id, w = weaponId })
	end
end

-- ─────────────────────────────────────────────────────────────
-- 플레이어 캐릭터 등록
-- ─────────────────────────────────────────────────────────────

local function setupCharacter(player: Player, character: Model)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hum or not root then
		return
	end
	local cfg = CombatConfig.Player
	hum.MaxHealth = cfg.MaxHealth
	hum.Health = cfg.MaxHealth
	hum.WalkSpeed = cfg.WalkSpeed
	hum.BreakJointsOnDeath = true
	local c = Combatant.new(character, hum, root, {
		MaxHealth = cfg.MaxHealth,
		MaxStamina = cfg.MaxStamina,
		MaxPoise = cfg.MaxPoise,
		Defense = cfg.Defense,
		Power = cfg.Power,
		WalkSpeed = cfg.WalkSpeed,
		HitRadius = cfg.HitRadius,
	}, "Players", player)
	c.InvulnUntil = now() + CombatConfig.RespawnInvuln
	CombatService.Register(c)
	-- 무기: 캐릭터 파츠가 모두 로드될 때까지 잠깐 대기
	task.spawn(function()
		character:WaitForChild("RightHand", 5)
		local list = loadouts[player] or WeaponDefs.Loadout
		local last = player:GetAttribute("LastWeapon") :: string?
		local weaponId = if last and table.find(list, last) then last else list[1]
		CombatService.EquipWeapon(c, weaponId)
	end)
end

function CombatService.SetLoadout(player: Player, list: { string })
	loadouts[player] = list
end

-- ─────────────────────────────────────────────────────────────
-- 시작
-- ─────────────────────────────────────────────────────────────

function CombatService.Start()
	eventRemote = Net.Event("CombatEvent")
	privateRemote = Net.Event("CombatPrivate")

	ProjectileService.Init({
		candidates = function(owner: any)
			return hostilesOf(owner)
		end,
		characterFolders = function()
			local list: { Instance } = {}
			for _, c in combatants do
				table.insert(list, c.Model)
			end
			local ferry = workspace:FindFirstChild("Ferry_Local")
			if ferry then
				table.insert(list, ferry)
			end
			return list
		end,
		onSpawn = function(p: ProjectileService.Projectile)
			broadcast("Proj", { id = p.Id, k = p.DefId, o = p.Pos, v = p.Vel, t = p.Born, i = p.Owner.Id, tg = p.Target and p.Target.Id })
		end,
		onHit = function(p: ProjectileService.Projectile, target: any, pos: Vector3)
			local def = p.Def
			CombatService.ApplyHit(p.Owner, target, {
				Damage = def.Damage,
				Poise = def.Poise,
				Knockback = def.Knockback,
				Statuses = def.Statuses,
				MoveId = p.DefId,
				Origin = p.Owner.Root.Position,
				HitStop = 0.05,
			}, pos)
			if def.Pull and not target.Dead and not target.Boss then
				local ownerPos = p.Owner.Root.Position
				local to = ownerPos - target.Root.Position
				local dist = Vector3.new(to.X, 0, to.Z).Magnitude
				if dist > 6 then
					local speed = math.min(90, (dist - 4) / 0.22)
					applyVelocity(target, flat(to) * speed + Vector3.new(0, 10, 0), 0.22)
				end
			end
		end,
		onEnd = function(p: ProjectileService.Projectile, pos: Vector3, hit: boolean)
			broadcast("ProjEnd", { id = p.Id, p = pos, h = hit })
		end,
	})

	Net.Event("CombatRequest").OnServerEvent:Connect(function(player: Player, kind: any, payload: any)
		if type(kind) ~= "string" or not rateOk(player) then
			return
		end
		local c = byPlayer[player]
		if not c or c.Dead then
			return
		end
		local t = now()
		local sent = if type(payload) == "table" then tonumber(payload.t) else nil
		local lag = if sent then math.clamp(t - sent, 0, CombatConfig.LagComp.MaxRewind) else 0.08
		CombatService.HandleAction(c, kind, payload, lag)
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(char)
			setupCharacter(player, char)
		end)
		if player.Character then
			task.spawn(setupCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		local c = byPlayer[p]
		if c then
			local wid = c.WeaponId
			if wid then
				p:SetAttribute("LastWeapon", wid)
			end
			CombatService.Unregister(c)
		end
		loadouts[p] = nil
		requestTimes[p] = nil
	end)

	-- 메인 루프
	local acc, attrAcc = 0, 0
	local dtTick = 1 / CombatConfig.TickRate
	RunService.Heartbeat:Connect(function(dt: number)
		local t = now()
		local byId: { [number]: any } = {}
		for id, c in combatants do
			byId[id] = c
		end
		LagCompensation.Record(byId, t)
		ProjectileService.Step(dt)
		acc += dt
		attrAcc += dt
		if acc < dtTick then
			return
		end
		local step = acc
		acc = 0
		resolveAreas(t)
		for _, c in combatants do
			if c.Dead then
				continue
			end
			if not c.Root.Parent then
				continue
			end
			stepMove(c, t)
			stepStatuses(c, t, step)
			stepRegen(c, t, step)
		end
		if attrAcc >= 1 / CombatConfig.AttributeRate then
			attrAcc = 0
			for _, c in combatants do
				c:Replicate(t)
			end
		end
	end)
end

return CombatService
