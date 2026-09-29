--[[
	card_sim.luau — 카드 효과 시뮬레이터(2026-09-28). run_system_tests 의 모듈 로더를 그대로 쓴다.

	Studio를 켜지 않고도 src/shared의 순수 로직 모듈이 사양대로인지 확인한다.
	PrototypeTests.RunSystems()를 **실제 모듈을 물려서** 그대로 돌린다.

	실행:  lune run tools/run_system_tests.luau
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local SHARED = "src/shared/"
WARNINGS = {} :: { string }

--=== Roblox 전역 최소 구현 ===--

local Color3 = {}
function Color3.fromRGB(r: number, g: number, b: number)
	return { R = r / 255, G = g / 255, B = b / 255 }
end
function Color3.new(r: number, g: number, b: number)
	return { R = r, G = g, B = b }
end

-- 결정적 선형 합동 생성기. Roblox Random의 인터페이스만 흉내낸다.
local Random = {}
Random.__index = Random
function Random.new(seed: number)
	return setmetatable({ state = (math.floor(seed) % 2147483647 + 2147483647) % 2147483647 + 1 }, Random)
end
function Random:_next(): number
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function Random:NextNumber(min: number?, max: number?): number
	local value = self:_next()
	if min and max then
		return min + value * (max - min)
	end
	return value
end
function Random:NextInteger(min: number, max: number): number
	return math.floor(min + self:_next() * (max - min + 1) - 1e-12)
end

--=== 모듈 로더 ===--
-- src/shared의 .luau를 읽어 script.Parent 방식 require를 해석해준다.

-- fs.readFile은 비동기라 메타메서드(__index) 안에서 부를 수 없다.
-- 그래서 shared의 모든 소스를 **하위 폴더까지** 미리 읽어 둔다.
--   src/shared/Foo.luau            → 키 "Foo"
--   src/shared/AbilityCards/Bar.luau → 키 "AbilityCards/Bar"
-- (Rojo가 폴더를 Folder 인스턴스로 만들기 때문에 트리를 그대로 흉내낸다)
local sources: { [string]: string } = {}
local folders: { [string]: boolean } = {}

local function readTree(dir: string, prefix: string)
	for _, entry in fs.readDir(dir) do
		local path = dir .. entry
		if fs.isDir(path) then
			folders[prefix .. entry] = true
			readTree(path .. "/", prefix .. entry .. "/")
		else
			local name = entry:match("^(.+)%.luau$")
			if name then
				sources[prefix .. name] = fs.readFile(path)
			end
		end
	end
end

readTree(SHARED, "")

local cache: { [string]: any } = {}
local loadShared
local makeProxy

-- 경로 하나를 나타내는 프록시. 인덱싱하면 하위 모듈이나 하위 폴더를 돌려준다.
function makeProxy(prefix: string, parent: any): any
	return setmetatable({}, {
		__index = function(_, name: string)
			-- script.Parent.Parent 같은 상위 참조
			if name == "Parent" and parent ~= nil then
				return parent
			end

			local full = if prefix == "" then name else prefix .. "/" .. name
			if sources[full] then
				return loadShared(full)
			end
			-- Rojo는 init.luau가 있는 폴더를 ModuleScript로 바꾼다.
			-- 즉 Shared.AbilityCards 는 폴더가 아니라 그 init 모듈이다.
			if sources[full .. "/init"] then
				return loadShared(full .. "/init")
			end
			if folders[full] then
				return makeProxy(full, nil)
			end
			error("shared 모듈을 찾을 수 없습니다: " .. full)
		end,
	})
end

local sharedProxy = makeProxy("", nil)

function loadShared(name: string): any
	if cache[name] then
		return cache[name]
	end

	local source = sources[name]
	if not source then
		error("shared 모듈을 찾을 수 없습니다: " .. name)
	end

	local env: any = {}
	for key, value in (getfenv and getfenv(1) or _G) :: any do
		env[key] = value
	end
	-- Lune 환경에 없는 전역 보강
	env.math = math
	env.table = table
	env.string = string
	env.warn = function(...)
		local parts = {}
		for _, v in { ... } do
			table.insert(parts, tostring(v))
		end
		table.insert(WARNINGS, table.concat(parts, " "))
	end
	env.Color3 = Color3
	env.Random = Random
	-- script.Parent.X 를 해석한다. 하위 폴더에 있는 모듈은
	-- script.Parent      = 그 폴더
	-- script.Parent.Parent = Shared
	-- 가 되도록 프록시를 엮는다.
	local dir = name:match("^(.*)/[^/]+$")
	local leaf = name:match("([^/]+)$")

	if leaf == "init" and dir then
		-- init 모듈은 자기 폴더가 곧 자신이다.
		--   script.KnightCards → 같은 폴더의 형제 모듈
		--   script.Parent      → 폴더의 상위 (보통 Shared)
		local grandDir = dir:match("^(.*)/[^/]+$")
		local outer = if grandDir then makeProxy(grandDir, sharedProxy) else sharedProxy
		env.script = makeProxy(dir, outer)
	else
		local parentProxy = if dir then makeProxy(dir, sharedProxy) else sharedProxy
		env.script = { Parent = parentProxy }
	end
	env.require = function(target: any)
		return target
	end

	local chunk = luau.load(source, {
		debugName = name,
		environment = env,
	})

	local result = chunk()
	cache[name] = result
	return result
end

--=== 시뮬레이션 ===--
--[[
	직업마다: 카드 없는 기준 전투 1판 + 카드 한 장(최대 레벨)씩 넣은 전투를 **같은 씨앗**으로 돌린다.
	적 셋(체력 20배), 14턴, 정해진 정책(적이 있는 줄로 이동 → 쓸 수 있는 가장 높은 번호 스킬, 스테미나가
	모자라면 명상/가드, 회피 등급은 턴마다 성공·부분·실패 돌림).
	보는 것: 처리기 오류(경고), 결과 지문(적 체력·내 체력·스테미나·자원·보정값)이 기준과 같은가.
	같으면 "변화 없음" — 조건이 이 정책에서 안 서는 카드일 수도 있으니 목록을 사람이 본다.
	  lune run tools/card_sim.luau [직업Id]
]]
local GridBattle = loadShared("GridBattle")
local AbilityCardDefinitions = loadShared("AbilityCardDefinitions")
local CardEffects = loadShared("CardEffects/init")
local BattleStatus = loadShared("BattleStatus")
loadShared("AbilityCards/init").Register()

local function lcg(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local GRADES = { "Success", "Partial", "Fail" }

--[[
	정책
	  default  적 줄로 이동(3턴마다 후열), 가장 높은 번호 스킬
	  hold     움직이지 않고, 짝수 턴엔 가드(공격 안 함)
	  kill     적 체력 보통(처치가 난다), 전열
	  low      내 체력 25%로 시작, 신앙심 45
]]
local function fight(classId: string, cards: { any }, turns: number, policy: string?): (string, { [string]: number })
	policy = policy or "default"
	local encounter = {
		Name = "sim",
		Enemies = { "Slime", "Slime", "Slime" },
		HealthScale = if policy == "kill" then 1.5 else 20,
		PowerScale = 1.5,
		Cells = { { 1, 2 }, { 2, 2 }, { 1, 1 } },
	}
	local stats = { Strength = 5, Intellect = 5, Agility = 5, Vitality = 5, Luck = 5, Faith = if policy == "low" then 45 else 20 }
	local state = GridBattle.New(1, "sim", 400, 14, classId, stats.Faith, nil, cards, encounter, stats)
	if policy == "low" then
		GridBattle.Ally(state).Health = 100
	end
	local rng = lcg(12345)
	local metrics = { Dealt = 0, Taken = 0 }
	for turn = 1, turns do
		if state.Outcome ~= "Ongoing" then
			break
		end
		-- 첫 적의 줄로
		local target = GridBattle.AliveEnemies(state)[1]
		local cell = target and GridBattle.CellOf(state, target.Id)
		if cell and policy ~= "hold" then
			GridBattle.MoveAlly(state, if policy == "default" and turn % 3 == 1 then 5 else 1, cell.Y)
		end
		if policy == "stance" or (policy == "long" and turn % 2 == 0) then
			GridBattle.ToggleStance(state)
		end
		local list = GridBattle.SkillList(state)
		local ally = GridBattle.Ally(state)
		local chosen = nil
		for index = #list, 1, -1 do
			local skill = list[index]
			local cost = GridBattle.StaminaCost(state, skill)
			if skill.Id ~= "Guard" and skill.Id ~= "Meditate" and (ally.Cooldowns[skill.Id] or 0) <= 0 and ally.Stamina >= cost then
				chosen = index
				break
			end
		end
		-- 직업마다 "할 일이 있는" 스킬 순서(PREFER). 빈 섞기·제 살 깎기만 반복하며 턴을 버리지 않게
		local prefer = PREFER[classId]
		if prefer then
			local stack = function(id: string): number
				return ally.Status.Stacks[id] or 0
			end
			for _, want in prefer(stack) do
				local found = nil
				for index, skill in list do
					if skill.Id == want and (ally.Cooldowns[skill.Id] or 0) <= 0 and ally.Stamina >= GridBattle.StaminaCost(state, skill) then
						found = index
					end
				end
				if found then
					chosen = found
					break
				end
			end
		end
		if policy == "hold" and turn % 2 == 0 then
			chosen = nil
		end
		if not chosen then
			for index, skill in list do
				if skill.Id == (if ally.Stamina < 20 then "Meditate" else "Guard") then
					chosen = index
				end
			end
		end
		if DEBUG_SKILLS then print("SK", classId, turn, list[chosen].Id, ally.Stamina, ally.Health) end
		GridBattle.ResolveSkill(state, chosen, "Success", rng, list[chosen].Id)
		if state.Outcome ~= "Ongoing" then
			break
		end
		for _, enemy in GridBattle.PlannedThreats(state) do
			GridBattle.ResolveDodge(state, enemy.Id, GRADES[turn % 3 + 1] :: any)
		end
		GridBattle.EndTurn(state)
		GridBattle.EnemyPlan(state, rng)
	end
	local ally = GridBattle.Ally(state)
	local parts = {}
	local enemyHp = 0
	for _, unit in state.Units do
		if unit.Side == "Enemy" then
			enemyHp += unit.Health
		end
	end
	table.insert(parts, string.format("E%d", enemyHp))
	table.insert(parts, string.format("A%d/%d S%d F%d T%d", ally.Health, ally.MaxHealth, math.floor(ally.Stamina), math.floor(ally.Faith), ally.Taunt))
	local ids = {}
	for id, amount in ally.Status.Stacks do
		if amount ~= 0 and string.sub(id, -7) ~= "Pending" then
			table.insert(ids, id .. "=" .. tostring(amount))
		end
	end
	table.sort(ids)
	table.insert(parts, table.concat(ids, ","))
	local mods = {}
	for _, modifier in ally.Status.Modifiers do
		table.insert(mods, string.format("%s%.3f", modifier.Kind, modifier.Value))
	end
	table.sort(mods)
	table.insert(parts, table.concat(mods, ","))
	table.insert(parts, "sh" .. tostring(ally.Status.Shield))
	metrics.EnemyHp = enemyHp
	metrics.AllyHp = ally.Health
	return table.concat(parts, " | "), metrics
end

--[[
	직업별 스킬 우선순위(자원을 보고 고른다). 없으면 "쓸 수 있는 가장 뒤 번호 스킬".
]]
PREFER = {
	Alchemist = function(stack): { string }
		local bottles = stack("PoisonBottle") + stack("FireBottle") + stack("OilBottle")
		if bottles >= 3 then
			return { "Poisoning", "Throw", "Grind" }
		elseif bottles > 0 then
			return { "Throw", "Mix", "Grind" }
		elseif stack("Extract") > 0 and stack("EmptyBottle") > 0 then
			return { "Mix", "Grind" }
		end
		return { "Grind" }
	end,
	WallBreaker = function(stack): { string }
		if stack("Ruin") >= 3 then
			return { "TearDown", "BringDown", "Cleave" }
		end
		return { "SelfCarve", "BringDown", "Cleave" }
	end,
}

--[[
	다른 카드가 깔아 줘야 켜지는 카드 → 그 짝. 짝만 든 전투와 둘 다 든 전투가 다르면 산 카드로 본다.
]]
COMBOS = {
	Berserker_R_Roar = "Berserker_R_Reckless", -- 받는 피해 증가 → 주는 피해
	Berserker_C_Trance = "Berserker_R_Reckless", -- 낮은 체력에서 받는 피해 증가를 덜 받는다
	Berserker_C_BloodVessel = "Berserker_C_Devour", -- 회복을 받으면 분노
	Berserker_R_Sweep = "Berserker_C_Ember", -- 분노가 상한일 때 분쇄
	Berserker_C_Headbutt = "Berserker_R_Sweep",
	Berserker_E_Undying = "Berserker_R_Reckless", -- 쓰러질 만큼 맞아야 켜진다
}

local only = process.args[1]
DEBUG_SKILLS = process.args[2] == "debug"
local classes = { "Musician", "Duelist", "Quasar", "Pulsar", "WallPilgrim", "WallMason", "WallBreaker", "Alchemist", "Berserker" }
local totalCards, totalWired, silent, errors = 0, 0, {}, 0
for _, classId in classes do
	if only and only ~= classId then
		continue
	end
	local POLICIES = { "default", "hold", "kill", "low", "long", "stance" }
	local baselines = {}
	for _, policy in POLICIES do
		baselines[policy] = fight(classId, {}, if policy == "long" then 30 else 14, policy)
	end
	local baseline, baseMetrics = fight(classId, {}, 14)
	local wired, count = 0, 0
	local rows = {}
	for _, grade in { "Essential", "Rare", "Common" } do
		for _, card in AbilityCardDefinitions.GetPool(classId, grade :: any) do
			count += 1
			if not CardEffects.IsWired(card.Id) then
				table.insert(rows, string.format("  [미구현] %s %s", card.Id, card.Name))
				continue
			end
			wired += 1
			table.clear(WARNINGS)
			local level = AbilityCardDefinitions.MaxLevelFor(card)
			local ok, result, metrics = pcall(fight, classId, { { CardId = card.Id, Level = level } }, 14)
			if not ok then
				errors += 1
				table.insert(rows, string.format("  [오류] %s %s: %s", card.Id, card.Name, tostring(result)))
			elseif #WARNINGS > 0 then
				errors += 1
				table.insert(rows, string.format("  [경고] %s %s: %s", card.Id, card.Name, WARNINGS[1]))
			elseif result == baseline and (function()
				-- 다른 정책에서라도 달라지면 산 카드다
				for _, policy in POLICIES do
					if policy ~= "default" then
						local okOther, other = pcall(fight, classId, { { CardId = card.Id, Level = level } }, if policy == "long" then 30 else 14, policy)
						if okOther and other ~= baselines[policy] then
							return false
						end
					end
				end
				-- 짝 카드가 있어야 켜지는 카드(COMBOS): 짝만 든 전투와 견준다
				local partner = COMBOS[card.Id]
				if partner then
					for _, policy in POLICIES do
						local turns = if policy == "long" then 30 else 14
						local okA, alone = pcall(fight, classId, { { CardId = partner, Level = 9 } }, turns, policy)
						local okB, both = pcall(fight, classId, { { CardId = partner, Level = 9 }, { CardId = card.Id, Level = level } }, turns, policy)
						if okA and okB and alone ~= both then
							return false
						end
					end
				end
				return true
			end)() then
				table.insert(silent, card.Id)
				table.insert(rows, string.format("  [변화 없음] %s %s%s", card.Id, card.Name, if card.Party then " (파티)" else ""))
			else
				table.insert(rows, string.format("  [ok] %s %s  적HP %+d  내HP %+d", card.Id, card.Name, metrics.EnemyHp - baseMetrics.EnemyHp, metrics.AllyHp - baseMetrics.AllyHp))
			end
		end
	end
	totalCards += count
	totalWired += wired
	print(string.format("%s: 카드 %d, 효과 있음 %d  (기준: %s)", classId, count, wired, baseline))
	for _, line in rows do
		print(line)
	end
end
print(string.format("[card_sim] 카드 %d, 효과 %d, 변화 없음 %d, 오류 %d", totalCards, totalWired, #silent, errors))
