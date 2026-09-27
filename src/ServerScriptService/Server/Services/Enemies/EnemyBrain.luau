--!strict
-- 적 AI 두뇌: 대기/배회 → 추적(경로탐색) → 교전(거리 유지·측면 이동·기술 선택) → 귀환
-- 보스는 아레나 안의 플레이어만 인식하고, 체력 구간마다 페이즈 전환.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyDefs = require(Shared.Combat.EnemyDefs)
local MoveDefs = require(Shared.Combat.MoveDefs)
local MathUtil = require(Shared.Util.MathUtil)

local CombatService = require(script.Parent.Parent.Combat.CombatService)

local EnemyBrain = {}
EnemyBrain.__index = EnemyBrain

export type Arena = { Center: Vector3, Radius: number }

export type Brain = typeof(setmetatable(
	{} :: {
		c: any,
		def: EnemyDefs.EnemyDef,
		home: Vector3,
		arena: Arena?,
		target: any,
		state: string,
		nextAttack: number,
		cooldowns: { [string]: number },
		wanderAt: number,
		waypoints: { PathWaypoint },
		wpIndex: number,
		lastPath: number,
		strafeDir: number,
		strafeUntil: number,
		phase: number,
		lostSince: number,
		rng: Random,
		engaged: boolean,
		onEngage: ((Brain, boolean) -> ())?,
	},
	EnemyBrain
))

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

function EnemyBrain.new(c: any, def: EnemyDefs.EnemyDef, home: Vector3, arena: Arena?): Brain
	local self = setmetatable({
		c = c,
		def = def,
		home = home,
		arena = arena,
		target = nil :: any,
		state = "Idle",
		nextAttack = 0,
		cooldowns = {} :: { [string]: number },
		wanderAt = 0,
		waypoints = {} :: { PathWaypoint },
		wpIndex = 0,
		lastPath = 0,
		strafeDir = 1,
		strafeUntil = 0,
		phase = 1,
		lostSince = 0,
		rng = Random.new(),
		engaged = false,
		onEngage = nil :: ((Brain, boolean) -> ())?,
	}, EnemyBrain)
	return self
end

local function flatDist(a: Vector3, b: Vector3): number
	local d = a - b
	return math.sqrt(d.X * d.X + d.Z * d.Z)
end

function EnemyBrain.HasLineOfSight(self: Brain, target: any): boolean
	local from = self.c.Root.Position + Vector3.new(0, 1.5, 0)
	local to = target.Root.Position + Vector3.new(0, 1.5, 0)
	local ignore: { Instance } = {}
	for _, other in CombatService.All() do
		table.insert(ignore, other.Model)
	end
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(from, to - from, rayParams)
	return hit == nil
end

function EnemyBrain.InArena(self: Brain, pos: Vector3): boolean
	local arena = self.arena
	if not arena then
		return true
	end
	return flatDist(pos, arena.Center) <= arena.Radius + 6
end

function EnemyBrain.FindTarget(self: Brain): any
	local best, bestD = nil, math.huge
	local myPos = self.c.Root.Position
	for _, other in CombatService.Hostiles(self.c) do
		if other.Kind ~= "Player" then
			continue
		end
		local pos = other.Root.Position
		local d = flatDist(pos, myPos)
		if d < self.def.AggroRange and d < bestD and self:InArena(pos) then
			if self.arena or self:HasLineOfSight(other) then
				best, bestD = other, d
			end
		end
	end
	return best
end

function EnemyBrain.MoveTo(self: Brain, pos: Vector3, t: number)
	local hum = self.c.Humanoid :: Humanoid
	local root = self.c.Root :: BasePart
	local direct = (pos - root.Position)
	-- 가까우면 직접 이동, 멀거나 막혀 있으면 경로탐색
	local needPath = direct.Magnitude > 30
	if not needPath and self.target then
		needPath = not self:HasLineOfSight(self.target)
	end
	if needPath and t - self.lastPath > 1.5 then
		self.lastPath = t
		local path = PathfindingService:CreatePath({
			AgentRadius = math.max(2, self.def.HitRadius * 0.8),
			AgentHeight = math.max(5, self.def.HitRadius * 2.5),
			AgentCanJump = true,
			WaypointSpacing = 6,
			Costs = { Water = 4, Mud = 1.5 },
		})
		local ok = pcall(function()
			path:ComputeAsync(root.Position, pos)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			self.waypoints = path:GetWaypoints()
			self.wpIndex = 2
		else
			self.waypoints = {}
		end
	end
	if needPath and #self.waypoints >= self.wpIndex and self.wpIndex > 0 then
		local wp = self.waypoints[self.wpIndex]
		if flatDist(wp.Position, root.Position) < 3.5 then
			self.wpIndex += 1
			if self.wpIndex <= #self.waypoints then
				wp = self.waypoints[self.wpIndex]
			end
		end
		if wp.Action == Enum.PathWaypointAction.Jump then
			hum.Jump = true
		end
		hum:MoveTo(wp.Position)
	else
		hum:MoveTo(pos)
	end
end

function EnemyBrain.Face(self: Brain, pos: Vector3)
	local root = self.c.Root :: BasePart
	local dir = MathUtil.flatUnit(pos - root.Position)
	local cur = MathUtil.flatUnit(root.CFrame.LookVector)
	local f = math.min(1, 0.35)
	local nd = MathUtil.flatUnit(cur:Lerp(dir, f))
	root.CFrame = CFrame.lookAt(root.Position, root.Position + nd)
end

function EnemyBrain.CurrentMoves(self: Brain): { EnemyDefs.MoveChoice }
	local phases = self.def.Phases
	if phases then
		return phases[self.phase].Moves
	end
	return self.def.Moves
end

function EnemyBrain.CheckPhase(self: Brain, t: number)
	local phases = self.def.Phases
	if not phases then
		return
	end
	local hum = self.c.Humanoid :: Humanoid
	local ratio = hum.Health / math.max(1, hum.MaxHealth)
	local nextPhase = self.phase + 1
	local ph = phases[nextPhase]
	if ph and ratio <= ph.Threshold then
		self.phase = nextPhase
		if ph.SpeedScale then
			self.c.SpeedScale = ph.SpeedScale
		end
		self.c:AddStatus("Enraged", t, 1, nil, 99999, self.c)
		CombatService.CancelMove(self.c)
		if ph.OnEnter then
			CombatService.Perform(self.c, ph.OnEnter, { Aim = self.c.Root.CFrame.LookVector, Kind = "Enemy" })
		end
		self.nextAttack = t + 2.5
	end
end

function EnemyBrain.ChooseAttack(self: Brain, dist: number, t: number): string?
	local options = {}
	local reachPad = if self.target then self.target.Stats.HitRadius else 2
	for _, choice in self:CurrentMoves() do
		local cd = self.cooldowns[choice.Move]
		if cd and t < cd then
			continue
		end
		if dist - reachPad <= choice.MaxRange and dist >= choice.MinRange then
			table.insert(options, { w = choice.Weight, v = choice })
		end
	end
	local pick = MathUtil.weightedPick(options, self.rng)
	if not pick then
		return nil
	end
	if pick.Cooldown then
		self.cooldowns[pick.Move] = t + pick.Cooldown
	end
	return pick.Move
end

function EnemyBrain.SetEngaged(self: Brain, on: boolean)
	if self.engaged ~= on then
		self.engaged = on
		if self.onEngage then
			self.onEngage(self, on)
		end
	end
end

function EnemyBrain.Reset(self: Brain)
	local c = self.c
	local hum = c.Humanoid :: Humanoid
	hum.Health = hum.MaxHealth
	c.Statuses = {}
	c.Poise = 0
	c.SpeedScale = 1
	self.phase = 1
	self.target = nil
	self.state = "Return"
	self:SetEngaged(false)
end

function EnemyBrain.Update(self: Brain, t: number)
	local c = self.c
	if c.Dead then
		return
	end
	local hum = c.Humanoid :: Humanoid
	local root = c.Root :: BasePart
	self:CheckPhase(t)
	if c:IsBusy(t) then
		hum:MoveTo(root.Position)
		hum.AutoRotate = false
		return
	end
	hum.AutoRotate = true

	-- 귀환
	if self.state == "Return" then
		if flatDist(root.Position, self.home) < 6 then
			self.state = "Idle"
		else
			self:MoveTo(self.home, t)
			return
		end
	end

	-- 대상 유지/탐색
	local target = self.target
	if target then
		local tpos = target.Root.Position
		local tooFar = flatDist(tpos, root.Position) > self.def.AggroRange * 1.8
		local leashed = flatDist(root.Position, self.home) > self.def.LeashRange
		local outArena = not self:InArena(tpos)
		if target.Dead or target.Root.Parent == nil or tooFar or outArena then
			target = nil
		end
		if leashed then
			self:Reset()
			return
		end
	end
	if not target then
		target = self:FindTarget()
	end
	if target ~= self.target then
		self.target = target
		self.waypoints = {}
	end
	if not target then
		if self.engaged then
			if self.lostSince == 0 then
				self.lostSince = t
			elseif t - self.lostSince > 6 then
				self.lostSince = 0
				if self.def.Boss then
					self:Reset()
				else
					self:SetEngaged(false)
					self.state = "Return"
				end
			end
		end
		-- 배회
		if t >= self.wanderAt then
			self.wanderAt = t + self.rng:NextNumber(4, 9)
			local a = self.rng:NextNumber() * math.pi * 2
			local r = self.rng:NextNumber(4, 18)
			hum:MoveTo(self.home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		end
		return
	end
	self.lostSince = 0
	self:SetEngaged(true)

	local tpos = target.Root.Position
	local dist = flatDist(tpos, root.Position)
	-- 공격
	if t >= self.nextAttack then
		local moveId = self:ChooseAttack(dist, t)
		if moveId then
			local move = MoveDefs.Moves[moveId]
			local aim = MathUtil.flatUnit(tpos - root.Position)
			hum:MoveTo(root.Position)
			root.CFrame = CFrame.lookAt(root.Position, root.Position + aim)
			if CombatService.Perform(c, moveId, { Aim = aim, Target = target, Kind = "Enemy" }) then
				local phases = self.def.Phases
				local rate = if phases and phases[self.phase].AttackRate then phases[self.phase].AttackRate :: number else self.def.AttackRate
				self.nextAttack = t + move.Windup + move.Active + move.Recovery + rate * self.rng:NextNumber(0.75, 1.25)
				return
			end
		end
	end
	-- 거리 조절
	local keep = self.def.KeepAway
	if keep and dist < keep then
		local away = MathUtil.flatUnit(root.Position - tpos)
		hum:MoveTo(root.Position + away * 10)
	elseif dist > self.def.PreferredRange + target.Stats.HitRadius then
		self:MoveTo(tpos, t)
	else
		-- 측면 이동하며 기회 엿보기
		if t > self.strafeUntil then
			self.strafeUntil = t + self.rng:NextNumber(0.8, 2.0)
			self.strafeDir = if self.rng:NextNumber() < 0.5 then -1 else 1
		end
		local toT = MathUtil.flatUnit(tpos - root.Position)
		local side = Vector3.new(-toT.Z, 0, toT.X) * self.strafeDir
		hum:MoveTo(root.Position + side * 5)
		hum.AutoRotate = false
		self:Face(tpos)
	end
end

return EnemyBrain
