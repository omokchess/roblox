--!strict
-- 적 스폰/리스폰/보스 아레나/소환 관리

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Util.Net)
local Signal = require(Shared.Util.Signal)
local EnemyDefs = require(Shared.Combat.EnemyDefs)
local WorldData = require(Shared.World.WorldData)

local CombatService = require(script.Parent.Parent.Combat.CombatService)
local Combatant = require(script.Parent.Parent.Combat.Combatant)
local WeaponService = require(script.Parent.Parent.Combat.WeaponService)
local RigBuilder = require(script.Parent.RigBuilder)
local EnemyBrain = require(script.Parent.EnemyBrain)

local EnemyService = {}

EnemyService.Defeated = Signal.new() :: Signal.Signal<any, any>

local brains: { [any]: EnemyBrain.Brain } = {}
local folder: Folder
local rng = Random.new()
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true

local function ground(pos: Vector3): Vector3
	local list: { Instance } = { folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	groundParams.FilterDescendantsInstances = list
	local hit = workspace:Raycast(pos + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), groundParams)
	if hit then
		return hit.Position
	end
	local h = WorldData.TerrainHeight(pos.X, pos.Z)
	return Vector3.new(pos.X, h or pos.Y, pos.Z)
end

export type SpawnOptions = {
	Home: Vector3?,
	Arena: EnemyBrain.Arena?,
	Respawn: boolean?,
	SpawnInfo: any,
	Minion: boolean?,
}

function EnemyService.Spawn(typeId: string, position: Vector3, opts: SpawnOptions?): any
	local o: SpawnOptions = opts or {}
	local def = EnemyDefs[typeId]
	if not def then
		warn("[Enemy] 알 수 없는 적:", typeId)
		return nil
	end
	local rig = RigBuilder.Build(def.Asset, def.DisplayName)
	if not rig then
		return nil
	end
	local model, hum, root = rig.Model, rig.Humanoid, rig.Root
	local g = ground(position)
	local rootOffset = root.Position.Y
	model:PivotTo(CFrame.new(g + Vector3.new(0, rootOffset + 0.2, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0))
	hum.MaxHealth = def.MaxHealth
	hum.Health = def.MaxHealth
	hum.WalkSpeed = def.WalkSpeed
	model:SetAttribute("EnemyType", typeId)
	model:SetAttribute("DisplayName", def.DisplayName)
	model:SetAttribute("Title", def.Title or "")
	model:SetAttribute("Boss", def.Boss)
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	if def.Weapon then
		local grip = model:FindFirstChild("WeaponGrip", true) :: Attachment?
		if grip and grip.Parent and grip.Parent:IsA("BasePart") then
			WeaponService.EquipNPC(model, def.Weapon, grip.Parent, grip.WorldCFrame * (def.WeaponGrip or CFrame.identity))
		end
	end
	local c = Combatant.new(model, hum, root, {
		MaxHealth = def.MaxHealth,
		MaxStamina = 100,
		MaxPoise = def.Poise,
		Defense = def.Defense,
		Power = def.Power,
		WalkSpeed = def.WalkSpeed,
		HitRadius = def.HitRadius,
	}, "Swamp", nil)
	c.EnemyType = typeId
	c.Boss = def.Boss
	c.KnockbackScale = if def.Boss then 0 elseif def.HitRadius > 3 then 0.25 else 1
	c.SpawnInfo = o.SpawnInfo
	CollectionService:AddTag(model, "SwampEnemy")
	CombatService.Register(c)
	local brain = EnemyBrain.new(c, def, o.Home or g, o.Arena)
	if def.Boss then
		brain.onEngage = function(_, on)
			Net.Event("CombatEvent"):FireAllClients("Boss", { i = c.Id, on = on })
		end
	end
	c.Brain = brain
	brains[c] = brain
	if o.Minion then
		model:SetAttribute("Minion", true)
	end
	return c
end

local function randomInRadius(center: Vector3, radius: number): Vector3
	local a = rng:NextNumber() * math.pi * 2
	local r = math.sqrt(rng:NextNumber()) * radius
	return center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

local function spawnFromInfo(info: any)
	local pos = if info.Boss then info.P else randomInRadius(info.P, info.Radius)
	local arena = if info.Boss then { Center = info.P, Radius = info.ArenaRadius or 34 } else nil
	EnemyService.Spawn(info.Type, pos, { Home = if info.Boss then info.P else nil, Arena = arena, SpawnInfo = info })
end

local function onDied(c: any, killer: any)
	local brain = brains[c]
	if not brain then
		return
	end
	brains[c] = nil
	brain:SetEngaged(false)
	EnemyService.Defeated:Fire(c, killer)
	-- 보스가 죽으면 소환수 정리
	if c.Boss then
		for other in brains do
			if other.Model:GetAttribute("Minion") then
				CombatService.Kill(other, nil)
			end
		end
	end
	task.delay(4, function()
		if c.Model.Parent then
			c.Model:Destroy()
		end
	end)
	local info = c.SpawnInfo
	if info then
		local def = EnemyDefs[info.Type]
		task.delay(def and def.RespawnTime or 30, function()
			spawnFromInfo(info)
		end)
	end
end

function EnemyService.Start()
	local existing = workspace:FindFirstChild("SwampEnemies")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "SwampEnemies"
	folder.Parent = workspace

	CombatService.Died:Connect(function(c, killer)
		if c.Kind == "Enemy" then
			onDied(c, killer)
		end
	end)
	CombatService.SummonHandler = function(owner: any, typeId: string, count: number)
		local brain = brains[owner]
		for _ = 1, count do
			local pos = randomInRadius(owner.Root.Position, 10)
			EnemyService.Spawn(typeId, pos, { Home = owner.Root.Position, Arena = brain and brain.arena, Minion = true })
		end
	end

	-- 월드 준비 후 스폰
	task.spawn(function()
		while workspace:GetAttribute("SwampWorldReady") ~= true do
			task.wait(0.5)
		end
		for _, info in WorldData.EnemySpawns() do
			for _ = 1, info.Count do
				spawnFromInfo(info)
				task.wait()
			end
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local t = workspace:GetServerTimeNow()
		for c, brain in brains do
			if c.Dead or not c.Model.Parent then
				continue
			end
			local ok, err = pcall(function()
				brain:Update(t)
			end)
			if not ok then
				warn("[EnemyBrain]", err)
			end
		end
	end)
end

return EnemyService
