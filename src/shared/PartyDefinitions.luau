--!strict
--[[
	PartyDefinitions — 파티 전투 규칙(순수 로직). 2026-11-08, 사양: 파티전투_사양.md.

	수치(직업별 코스트·예시 프리셋)는 PartyBalance.luau(밸런싱 부서)가 가진다. 여기는 규칙만:
	  COST_LIMIT      파티 코스트 합 한계(8)
	  HOMING_PER_TURN 매 턴 받는 유도 수(3, 이월 없음)
	  Cost(classId)   직업 코스트(표에 없으면 nil)
	  ActionOrder     행동 순서 — 행(y) 1순위(위 → 아래), 열(x) 2순위(화면 왼쪽 = 뒤열 x=6 → 앞열 x=1)
	  Validate        파티 구성 검사(코스트 합 · 같은 직업 중복 · 칸 범위 · 칸 겹침)
	  Examples        예시 프리셋(PartyBalance.EXAMPLES)

	사용자(2026-11-08): "제일 위쪽 행에, 제일 왼쪽 열부터 차례대로 세자. 세는 순서는 행이 1순위, 열이 2순위."
	화면은 `[6][5][4][3][2][1] │ 적` 이라 제일 왼쪽 열 = x 가 큰 쪽(BattleArena.CellOffset 주석).
]]

local BattleGrid = require(script.Parent.BattleGrid)
local PartyBalance = require(script.Parent.PartyBalance)

local PartyDefinitions = {}

PartyDefinitions.COST_LIMIT = 8
PartyDefinitions.HOMING_PER_TURN = 3

export type Member = { ClassId: string, X: number, Y: number }

function PartyDefinitions.Cost(classId: string): number?
	return PartyBalance.COSTS[classId]
end

function PartyDefinitions.Examples(): { PartyBalance.Preset }
	return PartyBalance.EXAMPLES
end

--[[
	행동 순서. X·Y 를 가진 표(유닛·멤버)의 목록을 받아 새 목록으로 돌려준다(원본은 그대로).
	y 오름차순, 같은 y 에서는 x 내림차순. 칸이 같으면(있을 수 없지만) 원래 순서.
]]
function PartyDefinitions.ActionOrder<T>(units: { T }): { T }
	local indexed: { { Item: T, Index: number } } = {}
	for index, item in units do
		table.insert(indexed, { Item = item, Index = index })
	end
	table.sort(indexed, function(a, b)
		local ua: any, ub: any = a.Item, b.Item
		if ua.Y ~= ub.Y then
			return ua.Y < ub.Y
		end
		if ua.X ~= ub.X then
			return ua.X > ub.X
		end
		return a.Index < b.Index
	end)
	local sorted: { T } = {}
	for _, entry in indexed do
		table.insert(sorted, entry.Item)
	end
	return sorted
end

--[[
	파티 구성 검사. ok, 사유(한국어).
	막힌 칸 금지는 상태(GridBattle.PlaceUnit / NewParty)가 본다 — 여기는 구성만.
]]
function PartyDefinitions.Validate(units: { Member }): (boolean, string?)
	if #units == 0 then
		return false, "유닛이 한 명도 없습니다."
	end
	local total = 0
	local seenClass: { [string]: boolean } = {}
	local seenCell: { [string]: boolean } = {}
	for _, unit in units do
		local cost = PartyDefinitions.Cost(unit.ClassId)
		if cost == nil then
			return false, string.format("코스트가 정해지지 않은 직업입니다 (%s).", tostring(unit.ClassId))
		end
		total += cost
		if seenClass[unit.ClassId] then
			return false, string.format("같은 직업을 두 명 놓을 수 없습니다 (%s).", unit.ClassId)
		end
		seenClass[unit.ClassId] = true
		if unit.X ~= math.floor(unit.X) or unit.Y ~= math.floor(unit.Y) or unit.X < 1 or unit.X > BattleGrid.DEFAULT_WIDTH or unit.Y < 1 or unit.Y > BattleGrid.DEFAULT_HEIGHT then
			return false, string.format("격자 밖의 칸입니다 (%s: %s, %s).", unit.ClassId, tostring(unit.X), tostring(unit.Y))
		end
		local key = unit.X .. "," .. unit.Y
		if seenCell[key] then
			return false, string.format("두 유닛이 같은 칸에 있습니다 (%s).", key)
		end
		seenCell[key] = true
	end
	if total > PartyDefinitions.COST_LIMIT then
		return false, string.format("코스트 합이 한계를 넘었습니다 (%d/%d).", total, PartyDefinitions.COST_LIMIT)
	end
	return true, nil
end

return PartyDefinitions
