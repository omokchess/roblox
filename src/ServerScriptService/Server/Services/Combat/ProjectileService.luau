--!strict
-- 서버 권위 투사체: 매 틱 이동 + 레이캐스트(지형/건물) + 구체 판정(전투원).
-- 클라이언트는 같은 초기값으로 로컬 시뮬레이션해 그리기만 한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MoveDefs = require(Shared.Combat.MoveDefs)

local ProjectileService = {}

export type Projectile = {
	Id: number,
	Def: MoveDefs.ProjectileDef,
	DefId: string,
	Owner: any,
	Target: any,
	Pos: Vector3,
	Vel: Vector3,
	Traveled: number,
	Born: number,
}

local active: { [number]: Projectile } = {}
local nextId = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- 훅: CombatService 가 주입
local hooks: {
	candidates: (owner: any) -> { any },
	onHit: (p: Projectile, target: any, pos: Vector3) -> (),
	onEnd: (p: Projectile, pos: Vector3, hitSomething: boolean) -> (),
	onSpawn: (p: Projectile) -> (),
	characterFolders: () -> { Instance },
} = nil :: any

function ProjectileService.Init(h: any)
	hooks = h
end

function ProjectileService.Fire(owner: any, defId: string, origin: Vector3, direction: Vector3, target: any, now: number): Projectile?
	local def = MoveDefs.Projectiles[defId]
	if not def then
		return nil
	end
	nextId += 1
	local dir = if direction.Magnitude > 1e-4 then direction.Unit else Vector3.new(0, 0, -1)
	local p: Projectile = {
		Id = nextId,
		Def = def,
		DefId = defId,
		Owner = owner,
		Target = target,
		Pos = origin,
		Vel = dir * def.Speed + Vector3.new(0, def.Gravity * 0.12, 0),
		Traveled = 0,
		Born = now,
	}
	active[p.Id] = p
	hooks.onSpawn(p)
	return p
end

function ProjectileService.Step(dt: number)
	if next(active) == nil then
		return
	end
	rayParams.FilterDescendantsInstances = hooks.characterFolders()
	for id, p in active do
		local def = p.Def
		-- 유도
		if def.Homing and p.Target and p.Target.Root and not p.Target.Dead then
			local to = (p.Target.Root.Position - p.Pos)
			if to.Magnitude > 1 then
				local speed = p.Vel.Magnitude
				local cur = p.Vel.Unit
				local want = to.Unit
				local ang = math.acos(math.clamp(cur:Dot(want), -1, 1))
				local maxTurn = def.Homing * dt
				local f = if ang > 1e-4 then math.min(1, maxTurn / ang) else 1
				p.Vel = cur:Lerp(want, f).Unit * speed
			end
		end
		p.Vel -= Vector3.new(0, def.Gravity * dt, 0)
		local step = p.Vel * dt
		local from = p.Pos
		local to = from + step
		-- 전투원 판정 (선분-구)
		local hitTarget: any = nil
		local hitPos: Vector3? = nil
		for _, c in hooks.candidates(p.Owner) do
			local center = c.Root.Position
			local r = c.Stats.HitRadius + def.Radius
			local seg = to - from
			local L2 = seg:Dot(seg)
			local t = if L2 > 1e-9 then math.clamp((center - from):Dot(seg) / L2, 0, 1) else 0
			local closest = from + seg * t
			if (closest - center).Magnitude <= r then
				hitTarget = c
				hitPos = closest
				break
			end
		end
		if hitTarget and hitPos then
			active[id] = nil
			hooks.onHit(p, hitTarget, hitPos)
			hooks.onEnd(p, hitPos, true)
			continue
		end
		local ray = workspace:Raycast(from, step, rayParams)
		if ray then
			active[id] = nil
			hooks.onEnd(p, ray.Position, false)
			continue
		end
		p.Pos = to
		p.Traveled += step.Magnitude
		if p.Traveled >= def.Range or p.Pos.Y < -40 then
			active[id] = nil
			hooks.onEnd(p, p.Pos, false)
		end
	end
end

return ProjectileService
