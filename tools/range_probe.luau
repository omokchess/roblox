--[[
	range_probe.luau — 스킬 범위 미리보기(클라이언트가 칠하는 칸)와 실제 판정(맞은 적)을 견준다. (2026-09-29)
	직업마다 모든 스킬(강화 포함)을, 적을 한 라인의 1~6열에 가득 세우고 아군을 앞/뒤 열에 둔 채 쏜다.
	미리보기 칸에 선 적이 맞지 않았거나, 미리보기 밖의 적이 맞으면 보고한다.
	  lune run tools/range_probe.luau [직업Id]
]]
local process = require("@lune/process")
local loadShared = require("./lune_env")

local GridBattle = loadShared("GridBattle")
local BattleGrid = loadShared("BattleGrid")
local BattleSkills = loadShared("BattleSkills")
local BattleStatus = loadShared("BattleStatus")
local ClassResources = loadShared("ClassResources")
loadShared("AbilityCards/init").Register()

-- 강화 스킬을 열어 두는 자원
local OPEN = {
	Duelist = { ClassResources.READY, 1 },
}

local classes = { "Musician", "Duelist", "Quasar", "Pulsar", "WallPilgrim", "WallMason", "WallBreaker", "Alchemist", "Berserker" }
local only = process.args[1]
local problems = 0

local function setup(classId: string, allyX: number, lane: number)
	local state = GridBattle.New(1, "시험", 5000, 10, classId, 20, 999, {})
	state.Debug = { NoCooldown = true }
	-- 적을 모두 치우고 한 라인 1~6열에 새로 세운다(허수아비: 체력 크게)
	for _, e in GridBattle.AliveEnemies(state) do
		BattleGrid.Remove(state.Grid, e.Id)
		state.Units[e.Id] = nil
	end
	local template
	for _, u in state.Units do
		if u.Side == "Enemy" then
			template = u
		end
	end
	local proto = nil
	for id, u in state.Units do
		if u.Side ~= "Enemy" and id ~= state.AllyId then
			proto = u
		end
	end
	local _ = template or proto
	for x = 1, state.Grid.Width do
		for y = 1, state.Grid.Height do
			local id = string.format("dummy_%d_%d", x, y)
			local ok = BattleGrid.Place(state.Grid, id, "Enemy", x, y)
			if ok then
				state.Units[id] = {
					Id = id, Name = id, Side = "Enemy", Health = 100000, MaxHealth = 100000, Alive = true,
					Power = 1, SkillIndex = 1, Taunt = 0, Cooldowns = {},
					Status = BattleStatus.New(), Groggy = loadShared("GroggyGauge").New(),
				}
			end
		end
	end
	GridBattle.MoveAlly(state, allyX, lane)
	local open = OPEN[classId]
	if open then
		BattleStatus.AddStack(GridBattle.Ally(state).Status, open[1], open[2])
	end
	return state
end

for _, classId in classes do
	if only and only ~= classId then
		continue
	end
	local probe = setup(classId, 1, 2)
	for index, skill in GridBattle.SkillList(probe) do
		if skill.Damage <= 0 then
			continue
		end
		for _, allyX in { 1, 3, 6 } do
			local state = setup(classId, allyX, 2)
			local list = GridBattle.SkillList(state)
			local me = BattleGrid.CellOf(state.Grid, state.AllyId)
			-- 미리보기(BattleClient._paintTiles 와 같은 계산)
			local preview = {}
			local grow = GridBattle.AllyGrowCount(state, skill)
			for _, shape in BattleSkills.AllShapes(skill) do
				for _, cell in BattleSkills.Cells(state.Grid, "Ally", me.Y, shape, grow, me.X) do
					preview[cell.X .. "," .. cell.Y] = true
				end
			end
			local before = {}
			for id, u in state.Units do
				before[id] = u.Health
			end
			local ok, err = GridBattle.ResolveSkill(state, index, "Success", function()
				return 0.5
			end, skill.Id)
			if not ok then
				print(string.format("%-11s %-14s ally x%d  쓰지 못함: %s", classId, skill.Id, allyX, tostring(err)))
				continue
			end
			local hitCells, missed, extra = {}, {}, {}
			for id, u in state.Units do
				if u.Side == "Enemy" then
					local c = BattleGrid.CellOf(state.Grid, id) or { X = tonumber(id:match("_(%d+)_")), Y = tonumber(id:match("_(%d+)$")) }
					local key = c.X .. "," .. c.Y
					local hit = before[id] and u.Health < before[id]
					if hit then
						hitCells[key] = true
					end
					if preview[key] and not hit then
						table.insert(missed, key)
					elseif hit and not preview[key] then
						table.insert(extra, key)
					end
				end
			end
			local _ = list
			if process.args[2] == "v" then
				local pk, hk = {}, {}
				for k in preview do
					table.insert(pk, k)
				end
				for k in hitCells do
					table.insert(hk, k)
				end
				table.sort(pk)
				table.sort(hk)
				print(classId, skill.Id, "x" .. allyX, "미리보기", table.concat(pk, " "), "| 맞음", table.concat(hk, " "))
			end
			if #missed > 0 or #extra > 0 then
				problems += 1
				table.sort(missed)
				table.sort(extra)
				print(string.format("%-11s %-14s ally x%d  미리보기엔 있는데 안 맞음 [%s]  미리보기 밖인데 맞음 [%s]",
					classId, skill.Id, allyX, table.concat(missed, " "), table.concat(extra, " ")))
			end
		end
	end
end
print("어긋남", problems)
