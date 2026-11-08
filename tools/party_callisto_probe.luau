--[[
	party_callisto_probe.luau — 2026-11-08. 파티로 칼리스토와 싸우며 칼리스토가 준 피해를 한 대씩 적는다(0 피해 원인 찾기).
	  lune run tools/party_callisto_probe.luau [예시번호 1~3] [턴수]
]]
local loadShared = require("./lune_env")
local GridBattle = loadShared("GridBattle")
local PartyDefinitions = loadShared("PartyDefinitions")
local BattleStatus = loadShared("BattleStatus")
loadShared("AbilityCards/init").Register()

local args = { ... }
local pick = tonumber(args[1]) or 1
local turns = tonumber(args[2]) or 10
local seed = 7
local function rng(): number
	seed = (seed * 48271) % 2147483647
	return seed / 2147483647
end

local ex = PartyDefinitions.Examples()[pick]
local members = {}
for _, u in ex.Units do
	table.insert(members, { ClassId = u.ClassId, X = u.X, Y = u.Y, Cards = u.Cards, Name = u.ClassId, Health = 400, Power = 20, Stamina = 200 })
end
local s = GridBattle.NewParty(1, members, { Name = "칼리스토 탐사", Enemies = { "Callisto" }, HealthScale = 1, PowerScale = 1 })
print("예시", ex.Name)
local zero, total, sum, noted, seenSeq = 0, 0, 0, 0, 0
for t = 1, turns do
	if s.Outcome ~= "Ongoing" then
		break
	end
	GridBattle.EnemyPlan(s, rng)
	GridBattle.BeginTurn(s)
	while GridBattle.NextActor(s) do
		GridBattle.ResolveUnitSkill(s, GridBattle.NextActor(s) :: string, rng)
	end
	local shields = {}
	for _, a in GridBattle.Allies(s) do
		shields[a.Id] = BattleStatus.Stack and (a.Status.Shield or 0) or 0
	end
	local before = #s.Events
	local logBefore = #(s.Log or {})
	GridBattle.ResolveEnemyPhase(s, rng)
	for i = 1, #s.Events do
		local ev = s.Events[i]
		-- s.Events 는 턴마다 쌓인다 — 이미 본 사건(Seq)은 건너뛰어 새 것만 찍는다
		if ev.Seq <= seenSeq then
			continue
		end
		seenSeq = ev.Seq
		if ev.Kind == "EnemyAttack" and ev.Hits then
			for _, group in ev.Hits do
				for _, h in group do
					total += 1
					sum += h.Damage or 0
					if (h.Damage or 0) == 0 then
						zero += 1
						if h.Note then
							noted += 1
						end
					end
					print(string.format("T%d %s → %s  피해 %s  글 %s  등급 %s  보호막(전) %s  기믹 %s", t, tostring(ev.SkillId), tostring(h.Id), tostring(h.Damage), tostring(h.Note), tostring(h.Grade), tostring(shields[h.Id]), tostring(ev.Gimmick)))
				end
			end
		end
	end
	local log = s.Log or {}
	for i = logBefore + 1, #log do
		print("    로그: " .. tostring(log[i]))
	end
	local _ = before
	GridBattle.EndTurn(s)
end
print(string.format("맞음 %d · 칼리스토가 준 피해 합 %d · 0 피해 %d (효과 글 있음 %d)", total, sum, zero, noted))
