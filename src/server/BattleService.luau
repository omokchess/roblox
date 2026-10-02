--!strict
--[[
	BattleService — 격자 전투의 **입장과 세션**을 맡는 서버 권위 서비스. (2026-09-28)

	요청: "지금 전투 입장 관련 코드들은 싹다 없애줘(테스트용이랑 고대 대탑 입장 등, 전투 관련 코드는 남겨둘 것).
	       전투 입장 코드 너가 다시 짜줘. 디버깅 목적으로 짜는거니까, 웬만한 기능은 다 넣어주고.
	       레벨업 UI같은 것도 너가 그려줘."

	예전 `TowerService`(탑 입장·등반실·재접속 이어하기·개발용 OP 입장)는 지웠다. 전투 판정 쪽
	(GridAction: 이동·스킬·회피 대기열)은 그대로 옮겨 왔다 — 판정은 여전히 `GridBattle` 이 한다.

	--------------------------------------------------------------------------
	입장 길 두 가지
	  1. 디버그 패널의 "전투 시작"  → 설정(직업·레벨·적 편성·배율·전장)대로 바로 싸운다
	  2. 필드 만남 몹(Critical Adventure 방식, 사양 `오픈월드에서 전투에 돌입하는 방법`)
	     → 패널에서 내 앞에 슬라임을 세우고, 닿으면 그 자리에서 전투가 열린다

	전장
	  Sky    하늘 전장 칸(`SkyArena`) 하나를 배정. 남과 겹치지 않는다. 끝나면 원래 자리로 돌려보낸다
	  Field  지금 서 있는 곳(또는 만난 몹 자리)에 격자를 깐다. 지형 높이는 칸마다 맞춘다

	성장(레벨업·카드)은 **이 세션 안에서만** 굴린다(저장하지 않는다 — 디버그 빌드가 실제 프로필을 건드리지 않게).
	  이기면: 승수 +1 → 레벨 +1(5승마다 +2 더) → 스탯 포인트 3/레벨 → 카드 제시(CardDraft, 탑 층 규칙 그대로)
	  카드 그릇은 `PlayerProfile.NewTowerRun()` 을 그대로 쓴다(CardDraft 가 그 모양을 안다).

	권한: Studio, 또는 이 게임의 주인(CreatorId). 서버가 판정한다 — 리모트는 누구나 쏠 수 있다.

	리모트
	  클라 → BattleAction {Kind=...}   서버 → BattleState (세션 전체, 표 하나)
	  클라 → GridAction   {Kind="Move"|"Skill"|"Dodge"}   서버 → GridState (GridBattle.Snapshot)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityCardDefinitions = require(ReplicatedStorage.Shared.AbilityCardDefinitions)
local BattleGrid = require(ReplicatedStorage.Shared.BattleGrid)
local BattleArena = require(ReplicatedStorage.Shared.BattleArena)
local BattleStatus = require(ReplicatedStorage.Shared.BattleStatus)
local CardDraft = require(ReplicatedStorage.Shared.CardDraft)
local CharacterDefinitions = require(ReplicatedStorage.Shared.CharacterDefinitions)
local ClassResources = require(ReplicatedStorage.Shared.ClassResources)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local GridBattle = require(ReplicatedStorage.Shared.GridBattle)
local GroggyGauge = require(ReplicatedStorage.Shared.GroggyGauge)
local PlayerProfile = require(ReplicatedStorage.Shared.PlayerProfile)
local ProgressionDefinitions = require(ReplicatedStorage.Shared.ProgressionDefinitions)
local SkyArena = require(ReplicatedStorage.Shared.SkyArena)
local StatDefinitions = require(ReplicatedStorage.Shared.StatDefinitions)
local TowerRewardDefinitions = require(ReplicatedStorage.Shared.TowerRewardDefinitions)

local VALID_GRADES: { [string]: boolean } = { Success = true, Partial = true, Fail = true }
local AUTO_QTE: { [string]: boolean } = { Off = true, Success = true, Partial = true, Fail = true }
local MAX_LEVEL = 60
local MAX_ENEMIES = BattleGrid.DEFAULT_WIDTH * BattleGrid.DEFAULT_HEIGHT
-- 필드 만남 몹: 한 사람당 최대 수, 닿았다고 보는 거리
local MAX_ENCOUNTERS = 6
local TOUCH_RANGE = 5
-- 격자 가운데에서 아군·적 전열 칸까지(BattleArena: 중앙선 8 / 2 + 칸 반 3)
local FRONT_OFFSET = 7
-- 하늘 전장이 끝나면 쓰러짐 연출을 보여 준 뒤 돌려보낸다
local RETURN_DELAY = 3

export type Config = {
	ClassId: string,
	Enemies: { string },
	Cells: { { number } },
	HealthScale: number,
	PowerScale: number,
	Arena: string, -- "Sky" | "Field"
	God: boolean,
	AllyDamageScale: number,
	NoCooldown: boolean,
	AutoQte: string, -- 클라이언트가 QTE 를 건너뛸 때 쓸 등급 ("Off" 면 직접)
	WeaponPower: number, -- 0 이면 직업 기본 무기(BasicPower)
}

export type Session = {
	Config: Config,
	Run: PlayerProfile.TowerRun,
	Level: number,
	Stats: StatDefinitions.StatBlock,
	Points: number,
	Wins: number,
	Battle: GridBattle.State?,
	Threats: { any },
	Offered: { AbilityCardDefinitions.AbilityCard },
	Rng: Random,
	Arena: { Kind: string, X: number, Y: number, Z: number, Yaw: number, Slot: number?, FlatY: number?, BaseY: number? }?,
	ReturnCFrame: CFrame?,
	LevelUp: { From: number, To: number, Points: number, Seq: number }?,
	LevelUpSeq: number,
	BattleSeq: number,
	SpectatePacket: any?,
}

local BattleService = {}
BattleService.__index = BattleService

local function defaultConfig(): Config
	return {
		ClassId = "Duelist",
		Enemies = { "Slime" },
		Cells = {},
		HealthScale = 1,
		PowerScale = 1,
		Arena = "Sky",
		God = false,
		AllyDamageScale = 1,
		NoCooldown = false,
		AutoQte = "Off",
		WeaponPower = 0,
	}
end

--[[
	returnHome: 전투가 끝난 사람을 세계로 돌려보낼 때(하늘 전장에서 원래 자리를 모를 때) 부르는 함수.
	보통은 전투 직전 자리(ReturnCFrame)로 돌려보내고, 그게 없을 때만 스폰으로 보낸다.
]]
function BattleService.new(remotes: Folder, returnHome: ((Player) -> ())?)
	local self = setmetatable({}, BattleService)
	self.Remotes = remotes
	self.ReturnHome = returnHome
	self.Sessions = {} :: { [Player]: Session }
	-- 하늘 전장 칸 배정(두 방향: 칸 → 사람, 사람 → 칸)
	self.Slots = {} :: { [number]: Player }
	self.PlayerSlot = {} :: { [Player]: number }
	self:_buildSkyArenas()

	local encounters = workspace:FindFirstChild("BattleEncounters")
	if encounters then
		encounters:Destroy()
	end
	encounters = Instance.new("Folder")
	encounters.Name = "BattleEncounters"
	encounters.Parent = workspace
	self.Encounters = encounters

	-- 만남 몹에 닿았는지 0.2초마다 본다(Touched 는 고정 파트끼리 안 뜨고, 스치기만 해도 여러 번 뜬다)
	task.spawn(function()
		while self.Encounters.Parent do
			self:_checkEncounters()
			task.wait(0.2)
		end
	end)
	return self
end

--=== 권한 ===--

--[[
	2026-09-29 요청: "F2에서 쓸 수 있는 모든 행동 권한을 모든 유저가" — 아직 템도 없어 게임을 파악해 보는 게 중요하다.
	디버그 행동은 전부 그 사람 자기 세션(자기 전투·레벨·카드)에만 걸리므로 모두에게 연다.
	정식 출시 전에 false 로 돌리면 예전처럼 Studio·게임 주인만.
]]
local OPEN_DEBUG_TO_ALL = true

function BattleService:CanDebug(player: Player): boolean
	if OPEN_DEBUG_TO_ALL or RunService:IsStudio() then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

--=== 하늘 전장 ===--

--[[
	하늘에 전장 바닥을 SLOT_COUNT 개 지어 둔다. 전투 중엔 캐릭터를 고정하지만 레벨업 화면에서는
	풀어 주므로 발판이 있어야 떨어지지 않는다. 난간은 반투명(카메라 시야를 가리지 않게).
]]
function BattleService:_buildSkyArenas()
	for _, name in { "SkyArenas", "TowerChambers" } do
		local previous = workspace:FindFirstChild(name)
		if previous then
			previous:Destroy()
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "SkyArenas"
	folder.Parent = workspace
	for index = 1, SkyArena.SLOT_COUNT do
		local origin = SkyArena.SlotOrigin(index)
		local floor = Instance.new("Part")
		floor.Name = string.format("Arena%02d", index)
		floor.Anchored = true
		floor.Size = Vector3.new(SkyArena.FLOOR_LENGTH, SkyArena.FLOOR_THICKNESS, SkyArena.FLOOR_WIDTH)
		-- 윗면이 정확히 ZONE_Y. 격자 타일이 이 면을 레이캐스트로 찾는다.
		floor.Position = Vector3.new(origin.X, origin.Y - SkyArena.FLOOR_THICKNESS / 2, origin.Z)
		floor.Color = Color3.fromRGB(38, 32, 52)
		floor.Material = Enum.Material.Slate
		floor.TopSurface = Enum.SurfaceType.Smooth
		floor.Parent = folder
		local rails = {
			{ Vector3.new(SkyArena.FLOOR_LENGTH, 8, 2), Vector3.new(0, 4, SkyArena.FLOOR_WIDTH / 2) },
			{ Vector3.new(SkyArena.FLOOR_LENGTH, 8, 2), Vector3.new(0, 4, -SkyArena.FLOOR_WIDTH / 2) },
			{ Vector3.new(2, 8, SkyArena.FLOOR_WIDTH), Vector3.new(SkyArena.FLOOR_LENGTH / 2, 4, 0) },
			{ Vector3.new(2, 8, SkyArena.FLOOR_WIDTH), Vector3.new(-SkyArena.FLOOR_LENGTH / 2, 4, 0) },
		}
		for railIndex, spec in rails do
			local rail = Instance.new("Part")
			rail.Name = string.format("Rail%d", railIndex)
			rail.Anchored = true
			rail.Size = spec[1]
			rail.Position = Vector3.new(origin.X, origin.Y, origin.Z) + spec[2]
			rail.Color = Color3.fromRGB(120, 96, 170)
			rail.Material = Enum.Material.Neon
			rail.Transparency = 0.72
			rail.Parent = folder
		end
	end
end

function BattleService:_allocateSlot(player: Player): number?
	local existing = self.PlayerSlot[player]
	if existing then
		return existing
	end
	for index = 1, SkyArena.SLOT_COUNT do
		if not self.Slots[index] then
			self.Slots[index] = player
			self.PlayerSlot[player] = index
			return index
		end
	end
	return nil
end

function BattleService:_freeSlot(player: Player)
	local index = self.PlayerSlot[player]
	if index then
		self.Slots[index] = nil
		self.PlayerSlot[player] = nil
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- 캐릭터·전장·만남 몹을 빼고 아래로 쏴 땅 높이를 찾는다
--[[
	전장을 평평한 한 판으로(2026-09-29). 칸 자리 땅을 모두 재서 판 높이(FlatY)와 받침 바닥(BaseY)을 정한다.
	서버가 한 번 정해 BattleState.Arena 로 보내므로 싸우는 사람과 구경하는 사람이 같은 판을 그린다.
]]
function BattleService:_levelArena(arena: any)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { self.Encounters }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local layout = BattleArena.NewLayout(CFrame.new(arena.X, arena.Y, arena.Z) * CFrame.Angles(0, arena.Yaw or 0, 0))
	layout.RayHeight = if arena.Kind == "Field" then 14 else 30
	local top, bottom = BattleArena.StageHeight(layout, BattleGrid.DEFAULT_WIDTH, BattleGrid.DEFAULT_HEIGHT, params)
	arena.FlatY = top + 0.05
	arena.BaseY = bottom
end

function BattleService:_groundY(position: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { self.Encounters }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position.Y else position.Y - 3
end

--=== 세션 ===--

function BattleService:_session(player: Player): Session
	local session = self.Sessions[player]
	if not session then
		session = {
			Config = defaultConfig(),
			Run = PlayerProfile.NewTowerRun(),
			Level = 1,
			Stats = StatDefinitions.NewBlock(),
			Points = 0,
			Wins = 0,
			Battle = nil,
			Threats = {},
			Offered = {},
			Rng = Random.new(os.clock() * 1000 + player.UserId),
			Arena = nil,
			ReturnCFrame = nil,
			LevelUp = nil,
			LevelUpSeq = 0,
			BattleSeq = 0,
		}
		session.Run.Active = true
		self.Sessions[player] = session
	end
	return session
end

local function spentPoints(stats: StatDefinitions.StatBlock): number
	local total = 0
	for _, id in StatDefinitions.Order do
		total += stats.Main[id] or 0
	end
	return total
end

local function cardInfo(card: AbilityCardDefinitions.AbilityCard, level: number, shownLevel: number): any
	return {
		Id = card.Id,
		Name = card.Name,
		Grade = card.Grade,
		ClassId = card.ClassId,
		Tags = card.Tags,
		Art = card.Art,
		Level = level,
		MaxLevel = AbilityCardDefinitions.MaxLevelFor(card),
		Description = AbilityCardDefinitions.Describe(card, math.max(shownLevel, 1)),
		-- 파티 전제 카드 · 함께 들 수 없는 필수(이름) — 카드 위 띠로 보인다
		Party = card.Party == true,
		Excludes = (function()
			local names = {}
			for _, id in card.Excludes or {} do
				local other = AbilityCardDefinitions.Get(id)
				table.insert(names, if other then other.Name else id)
			end
			return names
		end)(),
	}
end

--=== 보내기 ===--

function BattleService:_publish(player: Player, message: string?)
	local session = self:_session(player)
	local run = session.Run
	local config = session.Config

	local owned = {}
	for _, progress in run.Cards do
		local card = AbilityCardDefinitions.Get(progress.CardId)
		if card then
			table.insert(owned, cardInfo(card, progress.Level, progress.Level))
		end
	end
	table.sort(owned, function(a, b)
		local order = { Essential = 1, Rare = 2, Common = 3 }
		if a.Grade ~= b.Grade then
			return (order[a.Grade] or 9) < (order[b.Grade] or 9)
		end
		return a.Name < b.Name
	end)

	-- 제시 카드는 **고르면 되는 레벨**의 수치로 보여 준다(지금 레벨 + 1)
	local offered = {}
	for _, card in session.Offered do
		local level = CardDraft.CardLevel(run, card.Id)
		table.insert(offered, cardInfo(card, level, level + 1))
	end

	local classes = {}
	for _, definition in CharacterDefinitions.All() do
		table.insert(classes, {
			Id = definition.Id,
			Name = definition.Name,
			Role = definition.Role,
			Color = definition.Color,
			BasicPower = definition.BasicPower,
		})
	end
	local class = CharacterDefinitions.Get(config.ClassId)

	self.Remotes.BattleState:FireClient(player, {
		CanDebug = self:CanDebug(player),
		Config = config,
		Classes = classes,
		EnemyTypes = (function()
			local list = {}
			for _, enemy in EnemyDefinitions.All() do
				table.insert(list, { Id = enemy.Id, Name = enemy.Name, MaxHealth = enemy.MaxHealth, Power = enemy.Power })
			end
			return list
		end)(),
		Level = session.Level,
		MaxLevel = MAX_LEVEL,
		Points = session.Points,
		Stats = session.Stats.Main,
		MaxHealth = ProgressionDefinitions.MaxHealthWithStats(session.Level, session.Stats),
		Power = if config.WeaponPower > 0 then config.WeaponPower else class.BasicPower,
		Wins = session.Wins,
		Owned = owned,
		Offer = if #offered > 0
			then {
				Cards = offered,
				Floor = run.Floor,
				Cost = run.Cost,
				RerollCost = TowerRewardDefinitions.RerollCost(run.RerollCount),
				Remaining = math.max(AbilityCardDefinitions.AcquireSlotsForFloor(run.Floor) - run.AcquiredThisFloor, 0),
			}
			else nil,
		LevelUp = session.LevelUp,
		InBattle = session.Battle ~= nil,
		Arena = session.Arena,
		BattleSeq = session.BattleSeq,
		Encounters = self:_encounterCount(player),
		Message = message,
	})
end

--[[
	전투 스냅샷. threats 는 이번에 아군을 노리는 적(회피 QTE 대기열의 맨 앞 하나).
	**항상 표 하나** — 경로마다 모양이 다르면 클라이언트가 그걸 다 갈라야 한다.
]]
function BattleService:_publishBattle(player: Player, threats: { any }?)
	local session = self:_session(player)
	if not session.Battle then
		self.Remotes.GridState:FireClient(player, nil)
		self:_publishSpectate(player, nil)
		return
	end
	local snapshot = GridBattle.Snapshot(session.Battle)
	snapshot.Threats = threats or {}
	snapshot.AutoQte = session.Config.AutoQte
	snapshot.BattleSeq = session.BattleSeq
	self.Remotes.GridState:FireClient(player, snapshot)
	self:_publishSpectate(player, snapshot)
end

--[[
	관전(2026-09-29 요청: 다른 플레이어가 전투하는 모습이 보이게).
	싸우는 사람의 전투는 그 사람 클라이언트에서만 그려져 남에게는 아무것도 안 보였다(슬라임·칸은 클라이언트 것,
	관절 움직임도 복제되지 않음). 그래서 스냅샷에서 **보는 데 필요한 것만** 추려 다른 모두에게 보낸다.
	받는 쪽(BattleSpectator)이 같은 연출기로 칸·슬라임·싸우는 사람 인형을 그린다. snapshot 이 nil 이면 끝.
]]
local function spectatePacket(player: Player, session: Session, snapshot: any): any
	local units = {}
	for id, u in snapshot.Units do
		units[id] = {
			Name = u.Name, Side = u.Side, X = u.X, Y = u.Y, Alive = u.Alive,
			Health = u.Health, MaxHealth = u.MaxHealth, Stunned = u.Stunned,
			-- 보스 부위(디버그): 관전하는 쪽도 같은 몸을 그린다
			Part = u.Part, Cells = u.Cells,
		}
	end
	-- 보스 판(구경하는 쪽도 칸마다 무슨 칸인지 보이게): 버프·버그·회복, 검은 칸, 이번 턴 예고 칸
	local board = nil
	if snapshot.Boss then
		local pending = {}
		for _, id in snapshot.Planned or {} do
			local u = snapshot.Units[id]
			if u and u.Plan and u.Plan.SkillId == "DeleteCells" then
				pending = u.Plan.Cells
			end
		end
		board = { Deleted = snapshot.Boss.Deleted, Mods = snapshot.Boss.Mods, Pending = pending }
	end
	return {
		UserId = player.UserId,
		Seq = session.BattleSeq,
		Arena = session.Arena,
		Board = board,
		ClassId = snapshot.AllyClassId,
		Units = units,
		Events = snapshot.Events,
		Outcome = snapshot.Outcome,
	}
end

function BattleService:_publishSpectate(player: Player, snapshot: any?)
	local session = self.Sessions[player]
	local packet = if snapshot and session and session.Arena
		then spectatePacket(player, session, snapshot)
		else { UserId = player.UserId, Seq = session and session.BattleSeq or 0 }
	if session then
		session.SpectatePacket = if snapshot then packet else nil
	end
	-- 시험: workspace 속성 SpectateSelf = true 면 싸우는 사람에게도 보내 옆에 관전 화면을 한 벌 더 그린다(혼자 확인용)
	local selfTest = workspace:GetAttribute("SpectateSelf") == true
	for _, other in Players:GetPlayers() do
		if other ~= player or selfTest then
			self.Remotes.BattleSpectate:FireClient(other, packet)
		end
	end
end

--=== 설정 ===--

local function clampNumber(value: any, lo: number, hi: number, fallback: number): number
	local n = tonumber(value)
	if not n or n ~= n then
		return fallback
	end
	return math.clamp(n, lo, hi)
end

-- 클라이언트가 보낸 설정 조각을 **검사해서** 받는다. 모르는 칸·틀린 값은 버린다.
function BattleService:_applyConfig(player: Player, patch: any): string?
	if typeof(patch) ~= "table" then
		return nil
	end
	local session = self:_session(player)
	local config = session.Config
	local note: string? = nil

	if type(patch.ClassId) == "string" and CharacterDefinitions.IsValid(patch.ClassId) and patch.ClassId ~= config.ClassId then
		config.ClassId = patch.ClassId
		-- 카드는 직업 것이다. 직업을 바꾸면 빌드를 새로 시작한다.
		session.Run = PlayerProfile.NewTowerRun()
		session.Run.Active = true
		session.Offered = {}
		note = string.format("%s — 카드 빌드를 비웠습니다.", CharacterDefinitions.Get(config.ClassId).Name)
	end
	if type(patch.Enemies) == "table" then
		local list = {}
		for _, id in patch.Enemies do
			if type(id) == "string" and EnemyDefinitions.IsValid(id) and #list < MAX_ENEMIES then
				table.insert(list, id)
			end
		end
		if #list > 0 then
			config.Enemies = list
			-- 칸 지정이 적 수보다 많으면 자른다
			while #config.Cells > #list do
				table.remove(config.Cells)
			end
		end
	end
	if type(patch.Cells) == "table" then
		local cells = {}
		local used: { [string]: boolean } = {}
		for _, cell in patch.Cells do
			if type(cell) == "table" and #cells < #config.Enemies then
				local x = math.floor(clampNumber(cell[1], 1, BattleGrid.DEFAULT_WIDTH, 1))
				local y = math.floor(clampNumber(cell[2], 1, BattleGrid.DEFAULT_HEIGHT, 1))
				local key = x .. "," .. y
				if not used[key] then
					used[key] = true
					table.insert(cells, { x, y })
				end
			end
		end
		config.Cells = cells
	end
	if patch.HealthScale ~= nil then
		config.HealthScale = clampNumber(patch.HealthScale, 0.001, 50, config.HealthScale)
	end
	if patch.PowerScale ~= nil then
		config.PowerScale = clampNumber(patch.PowerScale, 0, 50, config.PowerScale)
	end
	if patch.Arena == "Sky" or patch.Arena == "Field" then
		config.Arena = patch.Arena
	end
	if type(patch.God) == "boolean" then
		config.God = patch.God
	end
	if patch.AllyDamageScale ~= nil then
		config.AllyDamageScale = clampNumber(patch.AllyDamageScale, 0, 100, config.AllyDamageScale)
	end
	if type(patch.NoCooldown) == "boolean" then
		config.NoCooldown = patch.NoCooldown
	end
	if type(patch.AutoQte) == "string" and AUTO_QTE[patch.AutoQte] then
		config.AutoQte = patch.AutoQte
	end
	if patch.WeaponPower ~= nil then
		config.WeaponPower = math.floor(clampNumber(patch.WeaponPower, 0, 5000, config.WeaponPower))
	end

	-- 전투 중이면 판정 쪽 디버그 깃발은 바로 먹인다(편성·직업은 다음 전투부터)
	if session.Battle then
		session.Battle.Debug = {
			God = config.God,
			AllyDamageScale = config.AllyDamageScale,
			NoCooldown = config.NoCooldown,
		}
	end
	return note
end

--=== 전투 시작·끝 ===--

--[[
	설정대로 전투를 연다.
	fieldAt 이 오면(만남 몹) 그 자리에서, 아니면 설정의 전장(Sky/Field)에서.
]]
function BattleService:StartBattle(player: Player, fieldAt: CFrame?): (boolean, string?)
	local session = self:_session(player)
	local root = rootOf(player)
	if not root then
		return false, "캐릭터가 없습니다."
	end
	if session.Battle then
		return false, "이미 전투 중입니다."
	end
	local config = session.Config

	-- 전장
	local arenaKind = if fieldAt then "Field" else config.Arena
	if arenaKind == "Sky" then
		local slot = self:_allocateSlot(player)
		if not slot then
			return false, "하늘 전장이 모두 찼습니다. 필드 전장을 쓰세요."
		end
		local origin = SkyArena.SlotOrigin(slot)
		session.Arena = { Kind = "Sky", X = origin.X, Y = origin.Y, Z = origin.Z, Yaw = 0, Slot = slot }
		session.ReturnCFrame = root.CFrame
		local stand = SkyArena.SlotStand(slot)
		local position = Vector3.new(stand.X, stand.Y + 4, stand.Z)
		local character = player.Character :: Model
		character:PivotTo(CFrame.lookAt(position, Vector3.new(origin.X + 20, position.Y, origin.Z)))
	else
		-- 필드로 가면 잡아 둔 하늘 칸은 놓는다
		self:_freeSlot(player)
		-- 격자 가운데: 만남 몹이면 몹 쪽 전열이 몹 자리에 오게, 아니면 내 앞
		local center: Vector3
		local facing: Vector3
		if fieldAt then
			facing = fieldAt.LookVector
			center = fieldAt.Position - facing * FRONT_OFFSET
		else
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			facing = if look.Magnitude > 0.01 then look.Unit else Vector3.new(1, 0, 0)
			center = root.Position + facing * FRONT_OFFSET
		end
		local y = self:_groundY(center)
		-- 오른쪽(+X, 적 진영)이 facing 을 보게: CFrame.Angles(0, yaw, 0).RightVector = (cos, 0, −sin)
		local yaw = math.atan2(-facing.Z, facing.X)
		session.Arena = { Kind = "Field", X = center.X, Y = y, Z = center.Z, Yaw = yaw, Slot = nil }
		session.ReturnCFrame = nil
	end
	self:_levelArena(session.Arena)

	local class = CharacterDefinitions.Get(config.ClassId)
	local health = ProgressionDefinitions.MaxHealthWithStats(session.Level, session.Stats)
	local power = if config.WeaponPower > 0 then config.WeaponPower else class.BasicPower
	local faith = StatDefinitions.TotalValue(session.Stats, "Faith")
	-- 스탯(메인+서브 합) — 피해(힘·민첩·지력)·치명(운)에 쓴다
	local allyStats = {}
	for _, id in StatDefinitions.Order do
		allyStats[id] = StatDefinitions.TotalValue(session.Stats, id)
	end
	local battle = GridBattle.New(
		math.max(1, session.Wins + 1),
		player.DisplayName,
		health,
		power,
		config.ClassId,
		faith,
		nil,
		session.Run.Cards,
		{
			Name = if fieldAt then "필드 만남" else "시험 전투",
			Enemies = table.clone(config.Enemies),
			HealthScale = config.HealthScale,
			PowerScale = config.PowerScale,
			Cells = table.clone(config.Cells),
		},
		allyStats
	)
	battle.Debug = { God = config.God, AllyDamageScale = config.AllyDamageScale, NoCooldown = config.NoCooldown }
	session.Battle = battle
	session.Threats = {}
	session.BattleSeq += 1
	-- 첫 턴부터 예고가 보여야 라인을 보고 자리를 잡는다
	GridBattle.EnemyPlan(battle, function()
		return session.Rng:NextNumber()
	end)
	self:_publish(player, string.format("%s 전투 시작 — %s", if arenaKind == "Sky" then "하늘" else "필드", class.Name))
	self:_publishBattle(player)
	return true, nil
end

-- 전투를 치운다. 하늘 전장이었으면 잠시 뒤 원래 자리로.
function BattleService:_closeBattle(player: Player, delay: number)
	local session = self:_session(player)
	session.Battle = nil
	session.Threats = {}
	self:_publishBattle(player)
	local arena = session.Arena
	session.Arena = nil
	if arena and arena.Kind == "Sky" then
		local seq = session.BattleSeq
		local back = session.ReturnCFrame
		session.ReturnCFrame = nil
		task.delay(delay, function()
			-- 그 사이 새 전투를 시작했으면(재시작) 그 전투가 칸을 이어 쓴다 — 건드리지 않는다
			if not player.Parent or session.BattleSeq ~= seq or session.Battle then
				return
			end
			self:_freeSlot(player)
			local character = player.Character
			if back and character then
				character:PivotTo(back)
			elseif self.ReturnHome then
				self.ReturnHome(player)
			end
		end)
	end
end

--[[
	이겼다. 승수 → 레벨 → 스탯 포인트 → 카드 제시(탑 층 규칙: 코스트 +30, 리롤 가격 초기화,
	5의 배수 승이면 2장, 필수 카드 층이면 필수 먼저).
]]
function BattleService:_grantVictory(player: Player)
	local session = self:_session(player)
	local run = session.Run
	session.Wins += 1
	local gained = ProgressionDefinitions.LevelGainForFloor(session.Wins)
	local from = session.Level
	session.Level = math.min(MAX_LEVEL, session.Level + gained)
	local points = (session.Level - from) * StatDefinitions.POINTS_PER_LEVEL
	session.Points += points
	run.AcquiredThisFloor = 0
	local draft = CardDraft.BeginFloor(run, session.Config.ClassId, session.Wins, session.Rng:NextInteger(1, 2 ^ 30))
	session.Offered = draft.Cards
	session.LevelUpSeq += 1
	session.LevelUp = { From = from, To = session.Level, Points = points, Seq = session.LevelUpSeq }
end

function BattleService:_settle(player: Player): boolean
	local session = self:_session(player)
	local battle = session.Battle
	if not battle then
		return false
	end
	if battle.Outcome == "Victory" then
		-- 마지막 일격을 그릴 수 있게 끝나기 직전 상태를 먼저 보낸다
		self:_publishBattle(player)
		self:_grantVictory(player)
		self:_closeBattle(player, RETURN_DELAY)
		self:_publish(player, string.format("승리 — %d승", session.Wins))
		return true
	elseif battle.Outcome == "Defeat" then
		self:_publishBattle(player)
		self:_closeBattle(player, RETURN_DELAY)
		self:_publish(player, "패배")
		return true
	end
	return false
end

--=== 적 공격 대기열 ===--

-- 이번 턴에 아군을 실제로 노린 적을 줄 세운다(라인이 어긋난 적은 빠진다 — 비켜서면 빗나간다)
function BattleService:_queueThreats(player: Player)
	local session = self:_session(player)
	local battle = session.Battle
	if not battle then
		return
	end
	local threats = {}
	for _, enemy in GridBattle.PlannedThreats(battle) do
		local foeSkill = GridBattle.EnemySkill(enemy)
		table.insert(threats, {
			Id = enemy.Id,
			Name = enemy.Name,
			SkillId = foeSkill.Id,
			SkillName = foeSkill.Name,
			-- 보스 스킬 방어 규칙(회피만 / 회피·가드 불가). 판정은 서버가 강제하고, 클라이언트는 QTE 표시만 바꾼다
			DodgeOnly = foeSkill.DodgeOnly == true,
			Unavoidable = GridBattle.IsUnavoidable(battle, foeSkill),
		})
	end
	session.Threats = threats
	self:_pumpThreats(player)
end

-- 남은 적이 있으면 하나만 내려보내고, 다 끝났으면 턴을 마무리하고 다음 턴 예고
function BattleService:_pumpThreats(player: Player)
	local session = self:_session(player)
	local battle = session.Battle
	if not battle then
		return
	end
	local queue = session.Threats
	if #queue > 0 then
		self:_publishBattle(player, { queue[1] })
		return
	end
	GridBattle.EndTurn(battle)
	if self:_settle(player) then
		return
	end
	GridBattle.EnemyPlan(battle, function()
		return session.Rng:NextNumber()
	end)
	self:_publishBattle(player)
end

--=== 리모트: GridAction (전투 판정 — 예전 TowerService 에서 그대로 옮김) ===--

function BattleService:HandleGridAction(player: Player, request: any)
	if typeof(request) ~= "table" then
		return
	end
	local session = self:_session(player)
	local battle = session.Battle
	if not battle then
		return
	end
	local kind = tostring(request.Kind)

	if kind == "Move" then
		-- 스킬을 쓴 뒤(적 공격을 받는 중)에는 못 움직인다 — 끝날 칸을 바꿔 검수 칸·공격 범위를 속이지 못하게
		if #session.Threats > 0 or battle.Acted then
			self:_publishBattle(player)
			return
		end
		GridBattle.MoveAlly(battle, tonumber(request.X) or 1, tonumber(request.Y) or 1)
		self:_publishBattle(player)
	elseif kind == "Stance" then
		-- 결투사 태세 전환: 턴당 한 번, 행동을 쓰지 않는다
		if #session.Threats > 0 then
			return
		end
		local ok, message = GridBattle.ToggleStance(battle)
		if not ok and message then
			self:_publish(player, message)
		end
		self:_publishBattle(player)
	elseif kind == "Skill" then
		local grade = tostring(request.Grade)
		if not VALID_GRADES[grade] or #session.Threats > 0 then
			return
		end
		-- rng: 연금술사 `섞기` 처럼 결과가 갈리는 효과용. SkillId 는 번호가 밀려도 정확한 스킬을 집게.
		GridBattle.ResolveSkill(battle, request.SkillIndex, grade :: any, function()
			return session.Rng:NextNumber()
		end, if type(request.SkillId) == "string" then request.SkillId else nil)
		if self:_settle(player) then
			return
		end
		self:_queueThreats(player)
	elseif kind == "Dodge" then
		local grade = tostring(request.Grade)
		if not VALID_GRADES[grade] or #session.Threats == 0 then
			return
		end
		-- 대상은 서버가 고른다(대기열 맨 앞). 클라이언트 Id 를 믿으면 어긋날 때 턴이 멈춘다.
		local pending = table.remove(session.Threats, 1)
		GridBattle.ResolveDodge(battle, pending.Id, grade :: any)
		if self:_settle(player) then
			return
		end
		self:_pumpThreats(player)
	end
end

--=== 리모트: BattleAction (입장·디버그·성장) ===--

-- 디버그 권한 없이도 되는 것: 상태 받기, 레벨업 화면의 카드 고르기·리롤·건너뛰기, 스탯 찍기, 전투 포기
local PUBLIC: { [string]: boolean } = {
	Hello = true,
	Acquire = true,
	Reroll = true,
	SkipOffer = true,
	SpendStat = true,
	DismissLevelUp = true,
	End = true,
	Start = true,
	SetConfig = true,
	SpawnEncounter = true,
	ClearEncounters = true,
	Restart = true,
}

function BattleService:HandleAction(player: Player, request: any)
	if typeof(request) ~= "table" then
		return
	end
	local kind = tostring(request.Kind)
	if not PUBLIC[kind] and not self:CanDebug(player) then
		self:_publish(player, "디버그 권한이 없습니다.")
		return
	end
	local session = self:_session(player)
	local run = session.Run
	local battle = session.Battle
	local message: string? = nil

	if kind == "Hello" then
		message = nil
	elseif kind == "SetConfig" then
		message = self:_applyConfig(player, request.Config)
	elseif kind == "Start" then
		local ok, reason = self:StartBattle(player)
		if not ok then
			message = reason
		else
			return
		end
	elseif kind == "Restart" then
		if battle then
			self:_closeBattle(player, 0)
		end
		local ok, reason = self:StartBattle(player)
		if not ok then
			message = reason
		else
			return
		end
	elseif kind == "End" then
		if battle then
			self:_closeBattle(player, 0.2)
			message = "전투를 그만뒀습니다."
		end
	elseif kind == "Win" or kind == "Lose" then
		if not battle then
			return
		end
		if kind == "Win" then
			for _, enemy in GridBattle.AliveEnemies(battle) do
				GridBattle.DebugSetHealth(battle, enemy.Id, 0)
			end
		else
			GridBattle.DebugSetHealth(battle, GridBattle.ALLY_ID, 0)
		end
		session.Threats = {}
		if not self:_settle(player) then
			self:_publishBattle(player)
		end
		return
	elseif kind == "KillEnemy" or kind == "SetHealth" then
		if not battle or type(request.Id) ~= "string" then
			return
		end
		local unit = battle.Units[request.Id]
		if not unit then
			return
		end
		local value = if kind == "KillEnemy" then 0 else clampNumber(request.Value, 0, unit.MaxHealth, unit.Health)
		GridBattle.DebugSetHealth(battle, request.Id, value)
		-- 쓰러진 적의 공격은 대기열에서 뺀다
		for index = #session.Threats, 1, -1 do
			local target = battle.Units[session.Threats[index].Id]
			if not target or not target.Alive then
				table.remove(session.Threats, index)
			end
		end
		if not self:_settle(player) then
			self:_publishBattle(player, if #session.Threats > 0 then { session.Threats[1] } else nil)
		end
		return
	elseif kind == "HealAll" then
		if not battle then
			return
		end
		for id, unit in battle.Units do
			if unit.Alive and (unit.Side == "Ally" or request.Enemies == true) then
				GridBattle.DebugSetHealth(battle, id, unit.MaxHealth)
				unit.Groggy = GroggyGauge.New()
			end
		end
		self:_publishBattle(player)
		return
	elseif kind == "GiveStack" then
		if not battle or type(request.Id) ~= "string" then
			return
		end
		local ally = GridBattle.Ally(battle)
		local amount = math.floor(clampNumber(request.Amount, -99, 99, 1))
		local id = request.Id
		local allowed = false
		for _, resource in ClassResources.ForClass(battle.AllyClassId) do
			allowed = allowed or resource == id
		end
		if not allowed then
			return
		end
		if amount >= 0 then
			local cap = ClassResources.Cap(id)
			if table.find(ClassResources.NOTE_IDS, id) then
				local total = 0
				for _, noteId in ClassResources.NOTE_IDS do
					total += BattleStatus.Stack(ally.Status, noteId)
				end
				local room = ClassResources.NoteCap(BattleStatus.Stack(ally.Status, ClassResources.METER)) - total
				amount = math.min(amount, math.max(room, 0))
			end
			BattleStatus.AddStack(ally.Status, id, amount, cap)
		else
			BattleStatus.SpendStack(ally.Status, id, -amount)
		end
		self:_publishBattle(player)
		return
	elseif kind == "ApplyStatus" then
		if not battle then
			return
		end
		local amount = math.floor(clampNumber(request.Amount, 0, 999, 1))
		local targets = {}
		if request.Target == "Ally" then
			table.insert(targets, GridBattle.Ally(battle))
		else
			for _, enemy in GridBattle.AliveEnemies(battle) do
				table.insert(targets, enemy)
			end
		end
		for _, unit in targets do
			local status = unit.Status
			local what = tostring(request.Status)
			if what == "Bleed" then
				BattleStatus.AddBleed(status, amount)
			elseif what == "Poison" then
				BattleStatus.AddPoison(status, amount)
			elseif what == "Burn" then
				BattleStatus.AddBurn(status, amount)
			elseif what == "Oil" then
				BattleStatus.AddOil(status, amount)
			elseif what == "Shield" then
				BattleStatus.AddShield(status, amount)
			elseif what == "Groggy" then
				unit.Groggy.Value = math.clamp(unit.Groggy.Value + amount, 0, 100)
			elseif what == "Taunt" then
				unit.Taunt += amount
			end
		end
		self:_publishBattle(player)
		return
	elseif kind == "ClearCooldowns" then
		if battle then
			table.clear(GridBattle.Ally(battle).Cooldowns)
			self:_publishBattle(player)
		end
		return
	elseif kind == "SkipTurn" then
		-- 행동하지 않고 턴을 넘긴다(예고된 적 공격은 그대로 온다)
		if battle and #session.Threats == 0 and battle.Outcome == "Ongoing" then
			self:_queueThreats(player)
		end
		return
	elseif kind == "SetLevel" then
		local level = math.floor(clampNumber(request.Level, 1, MAX_LEVEL, session.Level))
		session.Level = level
		local total = ProgressionDefinitions.TotalStatPoints(level)
		if spentPoints(session.Stats) > total then
			session.Stats = StatDefinitions.NewBlock()
		end
		session.Points = total - spentPoints(session.Stats)
		message = string.format("레벨 %d (다음 전투부터)", level)
	elseif kind == "LevelUp" then
		-- 이긴 것처럼 성장만 준다(카드 제시·레벨·포인트). 전투 중에도 된다.
		self:_grantVictory(player)
		message = string.format("레벨 업 — %d승 판정", session.Wins)
	elseif kind == "DismissLevelUp" then
		session.LevelUp = nil
	elseif kind == "SpendStat" then
		local statId = tostring(request.StatId)
		if not StatDefinitions.Get(statId :: any) then
			return
		end
		local amount = math.floor(clampNumber(request.Amount, -100, 100, 1))
		-- 되돌리기(음수)는 디버그에서만. 레벨업 화면은 +1 만 보낸다.
		if amount < 0 and not self:CanDebug(player) then
			return
		end
		local current = session.Stats.Main[statId] or 0
		if amount > 0 then
			amount = math.min(amount, session.Points)
		else
			amount = math.max(amount, -current)
		end
		if amount == 0 then
			message = if session.Points <= 0 then "찍을 수 있는 포인트가 없습니다." else nil
		else
			session.Stats.Main[statId] = current + amount
			session.Points -= amount
		end
	elseif kind == "ResetStats" then
		session.Points += spentPoints(session.Stats)
		session.Stats = StatDefinitions.NewBlock()
	elseif kind == "ResetBuild" then
		session.Run = PlayerProfile.NewTowerRun()
		session.Run.Active = true
		session.Offered = {}
		session.Level = 1
		session.Stats = StatDefinitions.NewBlock()
		session.Points = 0
		session.Wins = 0
		session.LevelUp = nil
		message = "빌드를 처음으로 되돌렸습니다."
	elseif kind == "Reroll" then
		if #session.Offered == 0 then
			return
		end
		local draft = CardDraft.Reroll(run, session.Config.ClassId, session.Rng:NextInteger(1, 2 ^ 30))
		if draft.Ok then
			session.Offered = draft.Cards
		end
		message = draft.Reason
	elseif kind == "GiveCost" then
		run.Cost += math.floor(clampNumber(request.Amount, -9999, 9999, 30))
	elseif kind == "Acquire" then
		local cardId = tostring(request.CardId)
		local chosen: AbilityCardDefinitions.AbilityCard? = nil
		-- 제시한 목록 안에서만 고를 수 있다
		for _, card in session.Offered do
			if card.Id == cardId then
				chosen = card
			end
		end
		if not chosen then
			message = "제시된 카드가 아닙니다."
		else
			local ok, reason = CardDraft.Acquire(run, chosen, run.AcquiredThisFloor)
			if ok then
				run.AcquiredThisFloor += 1
				local remaining = AbilityCardDefinitions.AcquireSlotsForFloor(run.Floor) - run.AcquiredThisFloor
				if remaining > 0 then
					-- 필수 층에서 필수를 고른 직후면 다음 화면은 희귀·일반이다(AcquiredThisFloor 로 가른다)
					session.Offered = AbilityCardDefinitions.DrawForFloor(
						session.Config.ClassId,
						run.Floor,
						session.Rng:NextInteger(1, 2 ^ 30),
						CardDraft.MaxedCardIds(run),
						run.AcquiredThisFloor,
						run.Cards
					)
					message = string.format("%s 획득 — %d장 더", chosen.Name, remaining)
				else
					session.Offered = {}
					message = string.format("%s 획득", chosen.Name)
				end
			else
				message = reason
			end
		end
	elseif kind == "SkipOffer" then
		session.Offered = {}
		message = "카드를 고르지 않고 넘어갔습니다."
	elseif kind == "AddCard" then
		local card = AbilityCardDefinitions.Get(tostring(request.CardId))
		if not card or card.ClassId ~= session.Config.ClassId then
			message = "이 직업의 카드가 아닙니다."
		else
			local level = math.floor(clampNumber(request.Level, 1, AbilityCardDefinitions.MaxLevelFor(card), 1))
			local found = false
			for _, progress in run.Cards do
				if progress.CardId == card.Id then
					progress.Level = level
					found = true
				end
			end
			if not found then
				table.insert(run.Cards, { CardId = card.Id, Grade = card.Grade, Level = level })
			end
			message = string.format("%s Lv.%d%s", card.Name, level, if battle then " (다음 전투부터)" else "")
		end
	elseif kind == "RemoveCard" then
		for index = #run.Cards, 1, -1 do
			if run.Cards[index].CardId == request.CardId then
				table.remove(run.Cards, index)
			end
		end
	elseif kind == "ClearCards" then
		table.clear(run.Cards)
		message = "카드를 모두 뺐습니다."
	elseif kind == "RandomBuild" then
		-- 필수 1 · 희귀 3 · 일반 6, 레벨은 무작위(상한 안에서)
		table.clear(run.Cards)
		local rng = session.Rng
		for grade, count in { Essential = 1, Rare = 3, Common = 6 } do
			local pool = table.clone(AbilityCardDefinitions.GetPool(session.Config.ClassId, grade :: any))
			for _ = 1, math.min(count, #pool) do
				local card = table.remove(pool, rng:NextInteger(1, #pool))
				table.insert(run.Cards, {
					CardId = card.Id,
					Grade = card.Grade,
					Level = rng:NextInteger(1, AbilityCardDefinitions.MaxLevelFor(card)),
				})
			end
		end
		message = "무작위 빌드"
	elseif kind == "SpawnEncounter" then
		message = self:_spawnEncounter(player)
	elseif kind == "ClearEncounters" then
		for _, part in self.Encounters:GetChildren() do
			if part:GetAttribute("Owner") == player.UserId then
				part:Destroy()
			end
		end
	else
		return
	end
	self:_publish(player, message)
end

--=== 필드 만남 몹 ===--

function BattleService:_encounterCount(player: Player): number
	local count = 0
	for _, part in self.Encounters:GetChildren() do
		if part:GetAttribute("Owner") == player.UserId then
			count += 1
		end
	end
	return count
end

--[[
	내 앞 14스터드에 만남 몹을 세운다. 서버에는 보이지 않는 자리 표시만 두고(속성: 적·수·주인),
	모양(슬라임)과 흔들림은 클라이언트 `EncounterView` 가 그린다 — 전투 슬라임과 같은 틀이다.
]]
function BattleService:_spawnEncounter(player: Player): string?
	local root = rootOf(player)
	if not root then
		return nil
	end
	if self:_encounterCount(player) >= MAX_ENCOUNTERS then
		return string.format("만남 몹은 %d마리까지입니다.", MAX_ENCOUNTERS)
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local spot = root.Position + look * 14
	local y = self:_groundY(spot)
	local marker = Instance.new("Part")
	marker.Name = "Encounter"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(4, 3, 4)
	-- 몹은 나를 본다
	marker.CFrame = CFrame.lookAt(Vector3.new(spot.X, y + 1.5, spot.Z), Vector3.new(root.Position.X, y + 1.5, root.Position.Z))
	marker:SetAttribute("Owner", player.UserId)
	marker:SetAttribute("EnemyId", self:_session(player).Config.Enemies[1] or "Slime")
	marker:SetAttribute("Count", #self:_session(player).Config.Enemies)
	marker.Parent = self.Encounters
	return "만남 몹을 세웠습니다 — 닿으면 전투"
end

function BattleService:_checkEncounters()
	for _, marker in self.Encounters:GetChildren() do
		if not marker:IsA("BasePart") then
			continue
		end
		local owner = Players:GetPlayerByUserId(marker:GetAttribute("Owner") or 0)
		if not owner then
			marker:Destroy()
			continue
		end
		local session = self.Sessions[owner]
		local root = rootOf(owner)
		if not root or (session and session.Battle) then
			continue
		end
		local offset = root.Position - marker.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= TOUCH_RANGE and math.abs(offset.Y) < 8 then
			-- 몹이 나를 보는 방향 = 적 진영에서 아군 쪽. 전장은 내가 몹을 보게(내 → 몹) 편다.
			local toMob = Vector3.new(-offset.X, 0, -offset.Z)
			toMob = if toMob.Magnitude > 0.01 then toMob.Unit else -marker.CFrame.LookVector
			local at = CFrame.lookAt(marker.Position, marker.Position + toMob)
			marker:Destroy()
			local ok, reason = self:StartBattle(owner, at)
			if not ok then
				self:_publish(owner, reason)
			end
		end
	end
end

--=== 접속 ===--

function BattleService:Hello(player: Player)
	self:_publish(player)
	-- 늦게 들어온 사람도 지금 벌어지는 남의 전투를 본다
	for other, session in self.Sessions do
		if other ~= player and session.Battle and session.SpectatePacket then
			self.Remotes.BattleSpectate:FireClient(player, session.SpectatePacket)
		end
	end
end

function BattleService:Remove(player: Player)
	local session = self.Sessions[player]
	if session and session.Battle then
		session.Battle = nil
		self:_publishSpectate(player, nil)
	end
	self.Sessions[player] = nil
	self:_freeSlot(player)
	for _, part in self.Encounters:GetChildren() do
		if part:GetAttribute("Owner") == player.UserId then
			part:Destroy()
		end
	end
end

return BattleService
