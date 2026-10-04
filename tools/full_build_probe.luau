--[[
	full_build_probe.luau — 2026-10-03. "레벨업 전부 + 카드 풀세팅" 기준 스킬 한 방 피해를 잰다(사용자: 특이점 한 방 25만).
	  lune run tools/full_build_probe.luau [직업] [무기공격력]
	그 직업 카드 전부를 6레벨로 들고, 스탯은 주 스탯(근거리 힘, 원거리 지력)에 몰아 준다.
	자원은 상한(카드가 올린 상한 포함)까지 채운다. 치명타 없음(난수 0.999), QTE 성공. 적 슬라임 여섯.
]]
local process = require("@lune/process")
local loadShared = require("./lune_env")
local GridBattle = loadShared("GridBattle")
local BattleSkills = loadShared("BattleSkills")
local BattleStatus = loadShared("BattleStatus")
local ClassResources = loadShared("ClassResources")
local AbilityCards = loadShared("AbilityCards/init")
AbilityCards.Register()

local classId = process.args[1] or "Quasar"
local power = tonumber(process.args[2] or "5000") :: number
local LEVEL = 6
-- 셋째 인자 "crit" 이면 치명타가 늘 터진다(난수 0)
local CRIT = process.args[3] == "crit"

local owned = {}
for _, module in AbilityCards.Modules do
	if module.ClassId == classId then
		for _, card in module.Cards do
			-- 결투사 필수 카드 가운데 공격 스킬을 막는 것이 있어 결투사는 필수 카드를 뺀다
			if not (classId == "Duelist" and card.Grade == "Essential") then
				table.insert(owned, { CardId = card.Id, Level = LEVEL })
			end
		end
	end
end

local function battle()
	local s = GridBattle.New(1, "시험", 50000, power, classId, 100, 999, owned, {
		Name = "풀세팅 시험",
		Enemies = { "Slime", "Slime", "Slime", "Slime", "Slime", "Slime" },
		HealthScale = 100000,
		PowerScale = 0.01,
	}, { Strength = 100, Intellect = 100, Agility = 50, Luck = 0 })
	s.Debug = { NoCooldown = true }
	return s
end

-- 자원 가득: 상한(거센 빛이면 질량 50), 붕괴 차징 3(과충전)
local FULL = { Mass = 50, Charge = 3, Wall = 13, Rage = 8, Focus = 10 }
local function fill(s)
	local ally = GridBattle.Ally(s)
	for _, id in ClassResources.ForClass(classId) do
		local n = FULL[id] or ClassResources.Cap(id) or 5
		ally.Status.Stacks[id] = n
	end
end

-- 적마다 남은 체력(한 대상 기준 피해를 보려고)
local function hps(s): { [string]: number }
	local t = {}
	for id, u in s.Units do
		if u.Side == "Enemy" then
			t[id] = u.Health
		end
	end
	return t
end

print(string.format("== %s · 카드 %d장 Lv%d · 무기 %d", classId, #owned, LEVEL, power))
local list = GridBattle.SkillList(battle())
if classId == "Duelist" then
	-- 강화 스킬(준비 자세 뒤 4번 칸)도 잰다
	table.insert(list, { Id = "PointBlank", Probe = "PointBlank" })
end
for i, entry in list do
	local skill = BattleSkills.ById(entry.Id)
	if skill and skill.Damage > 0 then
		local s = battle()
		fill(s)
		local stacks = {}
		for id, n in GridBattle.Ally(s).Status.Stacks do
			if n > 0 then
				table.insert(stacks, id .. "=" .. n)
			end
		end
		local h0 = hps(s)
		local ok, err = GridBattle.ResolveSkill(s, i, "Success", function()
			return if CRIT then 0 else 0.999
		end, entry.Probe)
		local h1 = hps(s)
		local total, top, hit = 0, 0, 0
		for id, h in h0 do
			local d = h - (h1[id] or h)
			if d > 0 then
				total += d
				top = math.max(top, d)
				hit += 1
			end
		end
		print(string.format("  %-16s 한 대상 %9d  (합 %9d · %d명)  재사용 %s %s", entry.Id, if ok then top else -1, total, hit, tostring(skill.Cooldown or 0), if ok then "" else tostring(err)))
	end
end
