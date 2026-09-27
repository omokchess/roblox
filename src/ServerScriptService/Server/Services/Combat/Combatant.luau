--!strict
-- 전투원 (플레이어 캐릭터 / NPC 공통 상태)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Combat.CombatConfig)
local StatusDefs = require(Shared.Combat.StatusDefs)
local MoveDefs = require(Shared.Combat.MoveDefs)

export type StatusEntry = { Stacks: number, Expire: number, NextTick: number, Amount: number, Source: any }

export type ActiveMove = {
	Serial: number,
	MoveId: string,
	Move: MoveDefs.Move,
	Start: number,
	ActiveStart: number,
	ActiveEnd: number,
	End: number,
	AimDir: Vector3,
	Lag: number,
	ChargeMult: number,
	ComboIndex: number,
	HitCount: { [any]: number },
	LastHit: { [any]: number },
	Fired: boolean, -- 투사체/범위/소환 발동 여부
	Target: any,
	Kind: string, -- "Light" | "Heavy" | "Skill" | "Enemy"
}

export type Stats = {
	MaxHealth: number,
	MaxStamina: number,
	MaxPoise: number,
	Defense: number,
	Power: number,
	WalkSpeed: number,
	HitRadius: number,
}

local Combatant = {}
Combatant.__index = Combatant

local nextId = 0

export type Combatant = typeof(setmetatable(
	{} :: {
		Id: number,
		Model: Model,
		Humanoid: Humanoid,
		Root: BasePart,
		Player: Player?,
		Team: string,
		Kind: string, -- "Player" | "Enemy"
		EnemyType: string?,
		Boss: boolean,
		Stats: Stats,
		Stamina: number,
		StaminaLockUntil: number,
		LastStaminaUse: number,
		Poise: number,
		LastPoiseHit: number,
		State: string,
		StateUntil: number,
		Move: ActiveMove?,
		Buffered: { kind: string, payload: any, lag: number, at: number }?,
		BlockStart: number,
		BlockReduction: number,
		IFrameStart: number,
		IFrameEnd: number,
		InvulnUntil: number,
		DodgeReadyAt: number,
		Statuses: { [string]: StatusEntry },
		Cooldowns: { [string]: number },
		ComboIndex: number,
		LastLightEnd: number,
		WeaponId: string?,
		WeaponKind: string?,
		SpeedScale: number,
		LastCombat: number,
		LastLag: number,
		Dead: boolean,
		ChargeStart: number?,
		AttrDirty: boolean,
		Brain: any,
		SpawnInfo: any,
		KnockbackScale: number,
	},
	Combatant
))

function Combatant.new(model: Model, humanoid: Humanoid, root: BasePart, stats: Stats, team: string, player: Player?): Combatant
	nextId += 1
	local self = setmetatable({
		Id = nextId,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Player = player,
		Team = team,
		Kind = if player then "Player" else "Enemy",
		EnemyType = nil :: string?,
		Boss = false,
		Stats = stats,
		Stamina = stats.MaxStamina,
		StaminaLockUntil = 0,
		LastStaminaUse = 0,
		Poise = 0,
		LastPoiseHit = 0,
		State = "Idle",
		StateUntil = 0,
		Move = nil :: ActiveMove?,
		Buffered = nil :: { kind: string, payload: any, lag: number, at: number }?,
		BlockStart = 0,
		BlockReduction = 0.8,
		IFrameStart = 0,
		IFrameEnd = 0,
		InvulnUntil = 0,
		DodgeReadyAt = 0,
		Statuses = {} :: { [string]: StatusEntry },
		Cooldowns = {} :: { [string]: number },
		ComboIndex = 0,
		LastLightEnd = -math.huge,
		WeaponId = nil :: string?,
		WeaponKind = nil :: string?,
		SpeedScale = 1,
		LastCombat = -math.huge,
		LastLag = 0,
		Dead = false,
		ChargeStart = nil :: number?,
		AttrDirty = true,
		Brain = nil :: any,
		SpawnInfo = nil :: any,
		KnockbackScale = 1,
	}, Combatant)
	model:SetAttribute("CombatId", self.Id)
	model:SetAttribute("Team", team)
	model:SetAttribute("MaxStamina", stats.MaxStamina)
	return self
end

-- ── 상태 ─────────────────────────────────────────────────
function Combatant.IsDisabled(self: Combatant, now: number): boolean
	if self.Dead then
		return true
	end
	if (self.State == "Staggered" or self.State == "Stunned") and now < self.StateUntil then
		return true
	end
	return self.Statuses.Stun ~= nil and self.Statuses.Stun.Expire > now
end

function Combatant.IsBusy(self: Combatant, now: number): boolean
	if self:IsDisabled(now) then
		return true
	end
	if self.Move and now < self.Move.End then
		return true
	end
	return self.State == "Dodging" and now < self.StateUntil
end

function Combatant.IsInvulnerable(self: Combatant, now: number): boolean
	if now < self.InvulnUntil then
		return true
	end
	return now >= self.IFrameStart and now <= self.IFrameEnd
end

function Combatant.HasSuperArmor(self: Combatant, now: number): boolean
	local mv = self.Move
	return mv ~= nil and mv.Move.SuperArmor == true and now <= mv.ActiveEnd
end

function Combatant.SetState(self: Combatant, state: string, duration: number?, now: number)
	self.State = state
	self.StateUntil = if duration then now + duration else math.huge
	self.AttrDirty = true
end

-- ── 스태미나 ─────────────────────────────────────────────
function Combatant.CanSpend(self: Combatant, now: number): boolean
	return now >= self.StaminaLockUntil and self.Stamina > 0
end

function Combatant.Spend(self: Combatant, amount: number, now: number)
	if amount <= 0 then
		return
	end
	self.Stamina = math.max(0, self.Stamina - amount)
	self.LastStaminaUse = now
	if self.Stamina <= 0 then
		self.StaminaLockUntil = now + CombatConfig.Stamina.ExhaustedLock
	end
	self.AttrDirty = true
end

function Combatant.Restore(self: Combatant, amount: number)
	self.Stamina = math.min(self.Stats.MaxStamina, self.Stamina + amount)
	self.AttrDirty = true
end

-- ── 상태이상 ─────────────────────────────────────────────
function Combatant.AddStatus(self: Combatant, id: string, now: number, stacks: number?, amount: number?, duration: number?, source: any): StatusEntry?
	local def = StatusDefs[id]
	if not def then
		return nil
	end
	local entry = self.Statuses[id]
	if not entry then
		entry = { Stacks = 0, Expire = 0, NextTick = now + (def.Tick or 1), Amount = 0, Source = source }
		self.Statuses[id] = entry
	end
	entry.Stacks = math.min(def.MaxStacks, entry.Stacks + (stacks or 1))
	entry.Expire = now + (duration or def.Duration)
	entry.Source = source
	if amount then
		entry.Amount += amount
	end
	self.AttrDirty = true
	return entry
end

function Combatant.RemoveStatus(self: Combatant, id: string)
	if self.Statuses[id] then
		self.Statuses[id] = nil
		self.AttrDirty = true
	end
end

function Combatant.HasStatus(self: Combatant, id: string, now: number): boolean
	local e = self.Statuses[id]
	return e ~= nil and e.Expire > now
end

-- 이동 속도 배율 (상태이상 / 방어 / 공격)
function Combatant.SpeedMultiplier(self: Combatant, now: number): number
	if self:IsDisabled(now) then
		return 0
	end
	local m = self.SpeedScale
	for id, e in self.Statuses do
		local def = StatusDefs[id]
		if def and def.SpeedMult and e.Expire > now then
			m *= def.SpeedMult
		end
	end
	if self.State == "Blocking" then
		m *= CombatConfig.Block.SpeedScale
	end
	local mv = self.Move
	if mv and now < mv.End and self.Kind == "Player" then
		m *= CombatConfig.AttackMoveSpeed
	end
	return m
end

-- 복제용 상태 문자열 "Poison:3:5.2;Slow:1:1.9"
function Combatant.StatusString(self: Combatant, now: number): string
	local parts = {}
	for id, e in self.Statuses do
		if e.Expire > now then
			local def = StatusDefs[id]
			local extra = if def and def.Kind == "Buildup" then math.floor(e.Amount) else e.Stacks
			table.insert(parts, string.format("%s:%d:%.1f", id, extra, e.Expire - now))
		end
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function Combatant.Replicate(self: Combatant, now: number)
	local m = self.Model
	m:SetAttribute("Stamina", math.floor(self.Stamina + 0.5))
	m:SetAttribute("Poise", 1 - math.clamp(self.Poise / math.max(1, self.Stats.MaxPoise), 0, 1))
	m:SetAttribute("CState", self.State)
	m:SetAttribute("Statuses", self:StatusString(now))
	m:SetAttribute("InCombat", now - self.LastCombat < CombatConfig.CombatTagTime)
	self.AttrDirty = false
end

return Combatant
