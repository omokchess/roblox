--[[
	apply_config_edits.luau — 편집기에서 고친 설정을 **소스에 되먹인다**.

	흐름
	  1. `config_editor.html`을 브라우저로 연다
	  2. 카드·직업·스킬을 고치고 `수정본 내려받기` → `config_edits.json`
	  3. 그 파일을 프로젝트에 두고 이걸 돌린다

	  lune run tools/apply_config_edits.luau [config_edits.json] [--dry]

	`--dry`는 무엇이 바뀌는지 보여주기만 한다.

	--------------------------------------------------------------------------
	되먹이는 곳

	  cards       AbilityCards/*.luau      Name · Description · MaxLevel(카드별 레벨 상한)
	  cardLevels  AbilityCards/*.luau      Levels 사다리
	  classes     CharacterDefinitions.luau 직업 필드
	  classSkill  CharacterDefinitions.luau 직업의 대표 스킬
	  skills      BattleSkills.luau         전투 스킬

	--------------------------------------------------------------------------
	왜 블록을 먼저 찾는가

	`Description`은 여러 줄에 걸쳐 `..`로 이어 붙인 형태라 한 줄짜리 패턴으로는
	잡히지 않고, 잡아도 다음 항목까지 삼킨다. 그래서 **`Id = "..."`로 블록 범위를
	먼저 정하고 그 안에서만** 갈아 끼운다.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local CARD_DIR = "src/shared/AbilityCards/"
local CHARACTERS = "src/shared/CharacterDefinitions.luau"
local BATTLE_SKILLS = "src/shared/BattleSkills.luau"

--[[
	`--dry`면 파일을 건드리지 않는다. 쓰기를 하는 함수들보다 **먼저** 선언해야
	그 함수들이 이 값을 볼 수 있다(Luau의 지역 변수는 선언 위로 보이지 않는다).
]]
local dry = false
for _, arg in process.args do
	if arg == "--dry" then
		dry = true
	end
end

--=== Luau 값 만들기 ===--

--[[
	문자열을 Luau 리터럴로.

	줄바꿈은 `\n`으로 이스케이프한다(요청: "줄바꿈도 적용되도록"). 소스에 진짜
	줄바꿈을 넣으면 문자열이 그 자리에서 끊긴다.
]]
-- gsub 의 바꿀 글에 든 % 를 그대로 두게(설명에 "20%" 가 흔하다 — 안 그러면 "invalid use of '%'")
local function lit(text: string): string
	return (text:gsub("%%", "%%%%"))
end

local function quote(text: string): string
	local escaped = text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\r", ""):gsub("\n", "\\n")
	return '"' .. escaped .. '"'
end

local function numberLiteral(value: number): string
	if value % 1 == 0 then
		return tostring(math.floor(value))
	end
	return (string.format("%.4f", value):gsub("0+$", ""):gsub("%.$", ""))
end

--[[
	긴 문자열을 `..`로 이어 붙인 여러 줄로 만든다.

	stylua는 문자열을 쪼개지 못하므로 여기서 나눠 준다. `\n`이 들어간 자리는
	**거기서 줄을 끊는다** — 소스만 봐도 몇 줄짜리 설명인지 보이게 하려는 것이다.
]]
local function longString(prefix: string, text: string, indent: string): string
	local LIMIT = 74
	local chunks: { string } = {}

	for _, paragraph in { text } do
		local rest = paragraph
		while true do
			local head, tail = rest:match("^([^\n]*)\n(.*)$")
			if not head then
				break
			end
			table.insert(chunks, head .. "\n")
			rest = tail
		end
		table.insert(chunks, rest)
	end

	-- 줄 단위로 나눈 뒤, 그래도 긴 줄은 단어 경계에서 한 번 더 자른다.
	local pieces: { string } = {}
	for _, chunk in chunks do
		local ending = if chunk:sub(-1) == "\n" then "\n" else ""
		local body = if ending == "\n" then chunk:sub(1, -2) else chunk
		if (utf8.len(body) or #body) <= LIMIT then
			if body ~= "" or ending ~= "" then
				table.insert(pieces, body .. ending)
			end
		else
			local current = ""
			for word in body:gmatch("%S+") do
				local candidate = if current == "" then word else current .. " " .. word
				if (utf8.len(candidate) or #candidate) > LIMIT and current ~= "" then
					table.insert(pieces, current .. " ")
					current = word
				else
					current = candidate
				end
			end
			table.insert(pieces, current .. ending)
		end
	end

	if #pieces == 0 then
		pieces = { "" }
	end
	if #pieces == 1 then
		return prefix .. " = " .. quote(pieces[1]) .. ","
	end

	local lines = { prefix .. " = " .. quote(pieces[1]) }
	for index = 2, #pieces do
		table.insert(lines, indent .. "\t.. " .. quote(pieces[index]))
	end
	-- 소스는 CRLF다. 여기서 `\n`만 쓰면 여러 줄로 쪼갠 설명마다 그 줄만 어긋난다.
	return table.concat(lines, "\r\n") .. ","
end

--=== 블록 다루기 ===--

--[[
	`Id = "그것"`이 있는 표의 범위를 찾는다.

	블록의 끝은 **같은 들여쓰기의 `},`** 다. 안쪽 표(`Levels`, `Skill`, `Shape`)는
	더 깊이 들여쓰여 있으므로 그냥 지나간다.
]]
local function blockRange(source: string, id: string): (number?, number?, string?)
	local idStart = source:find('Id = "' .. id .. '"', 1, true)
	if not idStart then
		return nil, nil, nil
	end
	local lineStart = (source:sub(1, idStart):find("\n[^\n]*$") or 0) + 1
	local indent = source:sub(lineStart):match("^(\t*)") or "\t\t"
	local closer = "\n" .. indent:sub(1, -2) .. "},"
	local blockEnd = source:find(closer, idStart, true)
	if not blockEnd then
		return nil, nil, nil
	end
	return lineStart, blockEnd, indent
end

-- 블록 안의 `키 = 값,` 한 줄을 갈아 끼운다. 여러 줄 문자열도 통째로 바꾼다.
local function setField(block: string, indent: string, key: string, literal: string): (string, boolean)
	local pattern = "\n" .. indent .. key .. " = "
	local start = block:find(pattern, 1, true)
	if not start then
		return block, false
	end

	--[[
		값이 끝나는 곳은 **다음 필드가 시작하는 줄** 직전이다.
		`.. "이어 붙인 줄"`은 더 깊이 들여쓰여 있어 필드로 잡히지 않는다.
	]]
	local scan = start + #pattern
	local stop = nil
	while true do
		local nextLine = block:find("\n" .. indent .. "%a", scan)
		if not nextLine then
			break
		end
		stop = nextLine
		break
	end
	stop = stop or #block

	--[[
		소스는 CRLF다. `stop`은 다음 줄의 `\n`을 가리키는데, 그 바로 앞 `\r`은
		**지금 갈아 끼우는 값의 마지막 줄**에 속해 있었다 — 통째로 버려지는
		자리라 `block:sub(1,start)`에도, `block:sub(stop)`에도 안 걸려 조용히
		없어진다. 그 결과 이 필드의 마지막 줄만 LF로 남았다(stylua를 돌려야만
		드러나는 버그였다). `\r`이 있으면 자르는 자리를 한 칸 당겨 같이 넘긴다.
	]]
	if stop > 1 and block:sub(stop - 1, stop - 1) == "\r" then
		stop -= 1
	end

	return block:sub(1, start) .. indent .. literal .. block:sub(stop), true
end

local function patchFile(path: string, edits: { [string]: any }, apply: (block: string, indent: string, fields: any) -> (string, number)): number
	if not fs.isFile(path) then
		return 0
	end
	local source = fs.readFile(path)
	local touched = 0

	for id, fields in edits do
		local blockStart, blockEnd, indent = blockRange(source, id)
		if blockStart and blockEnd and indent then
			local block = source:sub(blockStart, blockEnd)
			local patched, count = apply(block, indent, fields)
			if count > 0 then
				source = source:sub(1, blockStart - 1) .. patched .. source:sub(blockEnd + 1)
				touched += count
				print(string.format("  %-34s %d칸", id, count))
			end
			edits[id] = nil
		end
	end

	if touched > 0 and not dry then
		fs.writeFile(path, source)
	end
	return touched
end

--=== 값 종류별 처리 ===--

local TEXT_FIELDS = { Name = true, Description = true, Role = true, Range = true }

-- Shape 표 안에 사는 값들. 없으면 Shape 안쪽에 끼워 넣어야 한다.
local SHAPE_KEYS = { Kind = true, Radius = true }

local function writeFields(block: string, indent: string, fields: any): (string, number)
	local count = 0
	for key, value in fields do
		if key == "Art" and tostring(value) == "" then
			-- 그림을 뗐다. 줄째로 지워 태그 문양으로 돌아가게 한다.
			local stripped = block:gsub("\n" .. indent .. "Art = [^\n]*", "", 1)
			if stripped ~= block then
				block = stripped
				count += 1
			end
			continue
		end
		local literal
		if TEXT_FIELDS[key] then
			literal = longString(key, tostring(value), indent)
		elseif type(value) == "number" then
			literal = key .. " = " .. numberLiteral(value) .. ","
		else
			literal = key .. " = " .. quote(tostring(value)) .. ","
		end
		local next, ok = setField(block, indent, key, literal)
		if not ok and (key == "Art" or key == "MaxLevel") then
			-- 아직 이 필드가 없던 카드다(그림 · 카드별 최대 레벨). `Id` 줄 뒤에 새로 끼운다.
			local after = block:find("\n", (block:find("\n" .. indent .. "Id = ", 1, true) or 0) + 1)
			if after then
				--[[
					소스는 CRLF다. 여기서 `\n`만 넣으면 이 줄만 LF로 남아 stylua가
					다시 손보고, 그 diff가 이 도구가 만든 것처럼 보인다 — 앞뒤 줄과
					같은 줄바꿈을 써야 한다.
				]]
				next = block:sub(1, after) .. indent .. literal .. "\r\n" .. block:sub(after + 1)
				ok = true
			end
		end
		if ok then
			block = next
			count += 1
		end
	end
	return block, count
end

--[[
	`Shape = { ... }` 안쪽 맨 끝에 새 조각을 끼워 넣는다.

	`Cells`·`Stages`는 값 자체가 `{ { X = .., Y = .. }, .. }`처럼 중괄호를
	품는다. 그래서 "닫는 중괄호까지"를 `[^}]*}`(중괄호가 아닌 글자들 다음
	첫 `}`) 같은 단순 패턴으로 찾으면, Shape 안에 이미 Cells나 Stages가 있을
	때 **그 안쪽 중괄호에서 먼저 멈춰** Shape를 통째로 잘라 버린다. `%b{}`(Lua
	표준 라이브러리의 균형 잡힌 괄호 매칭)로 Shape의 **진짜** 닫는 중괄호를
	찾아야 안전하다.

	`literal`은 언제나 `, `로 시작한다. 필드가 한 줄에 다 있으면(`{ Kind =
	"Line", Radius = 3 }`) 닫는 중괄호 바로 앞에 쉼표가 없어 그대로 이어
	붙이면 되지만, `stylua`가 여러 줄로 편 Shape(`Stages`가 있는 것처럼
	필드가 여럿이면 각 줄 끝에 쉼표를 남긴다)는 **이미 쉼표로 끝나 있어서**
	그대로 이어 붙이면 쉼표가 두 번 겹쳐 문법 오류가 난다(`a, , b`). 끼워 넣기
	전에 끝쪽 쉼표·공백을 먼저 걷어 내 언제나 쉼표가 정확히 하나만 남게 한다.
]]
local function insertIntoShape(text: string, literal: string): string
	local afterKeyword = text:find("Shape = {")
	if not afterKeyword then
		return text
	end
	local braceStart = afterKeyword + #"Shape = "
	local block = text:match("%b{}", braceStart)
	if not block then
		return text
	end
	local blockEnd = braceStart + #block - 1
	local body = block:sub(1, -2):gsub(",%s*$", "")
	local newBlock = body .. literal .. " }"
	return text:sub(1, braceStart - 1) .. newBlock .. text:sub(blockEnd + 1)
end

--[[
	**한 줄짜리 표**를 고친다. 전투 스킬이 이 모양이다.

	  { Id = "Veloce", Name = "벨로체", Damage = 18, Range = "Ranged", Shape = { ... } },

	블록 방식(`setField`)은 "줄 시작 + 들여쓰기 + 키"를 찾으므로 한 줄에 다 있는
	표에는 걸리지 않는다. 여기서는 `Id`가 든 균형 잡힌 `{}`를 통째로 잡고 그 안에서만
	`키 = 값`을 바꾼다. 값은 전부 문자열 하나 또는 숫자 하나라 이걸로 충분하다.
]]
local function patchInline(path: string, edits: { [string]: any }): number
	if not fs.isFile(path) then
		return 0
	end
	local source = fs.readFile(path)
	local touched = 0

	for id, fields in edits do
		local marker = source:find('Id = "' .. id .. '"', 1, true)
		if not marker then
			continue
		end
		-- Id 앞쪽에서 이 표를 여는 `{`를 찾는다.
		local open = source:sub(1, marker):find("{[^{]*$")
		if not open then
			continue
		end
		local block = source:match("%b{}", open)
		if not block then
			continue
		end

		local patched = block
		local count = 0
		for key, value in fields do
			--[[
				직접 찍은 범위. 편집기는 `[[dx,dy],…]` JSON 문자열로 보낸다.
				빈 문자열이면 지정을 **지운다** — 그때는 Kind·Radius가 다시 쓰인다.
			]]
			if key == "Cells" then
				local literal
				if value == "" or value == nil then
					literal = ""
				else
					local parts = {}
					for dx, dy in tostring(value):gmatch("%[(-?%d+),(-?%d+)%]") do
						table.insert(parts, string.format("{ X = %s, Y = %s }", dx, dy))
					end
					literal = ", Cells = { " .. table.concat(parts, ", ") .. " }"
				end
				-- 기존 Cells를 먼저 걷어 내고, 새 것이 있으면 Shape 안쪽에 넣는다.
				patched = patched:gsub(",%s*Cells = %b{}", "", 1)
				if literal ~= "" then
					patched = insertIntoShape(patched, literal)
				end
				count += 1
				continue
			end

			--[[
				조건부로 늘어나는 단계. 편집기는 `[[[dx,dy],…],[[dx,dy],…],…]`
				JSON 문자열로 보낸다 — `Cells`를 한 겹 더 감싼 배열이다. 빈 문자열이면
				지정을 지운다.
			]]
			if key == "Stages" then
				local literal
				if value == "" or value == nil then
					literal = ""
				else
					local text = tostring(value)
					-- 바깥 대괄호를 벗기고 나면 단계마다 하나씩 `%b[]`로 통째로 집힌다.
					local inner = text:sub(2, -2)
					local stageParts = {}
					for stageText in inner:gmatch("%b[]") do
						local cellParts = {}
						for dx, dy in stageText:gmatch("%[(-?%d+),(-?%d+)%]") do
							table.insert(cellParts, string.format("{ X = %s, Y = %s }", dx, dy))
						end
						table.insert(stageParts, "{ " .. table.concat(cellParts, ", ") .. " }")
					end
					literal = ", Stages = { " .. table.concat(stageParts, ", ") .. " }"
				end
				patched = patched:gsub(",%s*Stages = %b{}", "", 1)
				if literal ~= "" then
					patched = insertIntoShape(patched, literal)
				end
				count += 1
				continue
			end

			--[[
				겨누는 진영. 비우거나 "Foe"면 지운다(기본값이라 안 적어도 된다) —
				`Cells`와 달리 값이 단순 문자열이라 중괄호 매칭이 필요 없다.
			]]
			if key == "TargetSide" then
				patched = patched:gsub(',%s*TargetSide = "[^"]*"', "", 1)
				if value == "Ally" then
					patched = insertIntoShape(patched, ', TargetSide = "Ally"')
				end
				count += 1
				continue
			end

			--[[
				모션 단계. 앞뒤관통처럼 한 번 쓸 때 서로 다른 칸을 순서대로
				때리는 스킬(요청: "모션상 단계"). 형식은 `Stages`와 같은
				"칸 목록의 목록"이지만, `Shape` 안이 아니라 **스킬 자체**의
				형제 필드다(`Skill.Motions`) — 모션마다 독립된 `Shape`라서.
				모션 하나하나를 미니 Shape( `{ Kind = "Single", Cells = {...} }`)
				로 감싼다.
			]]
			if key == "Motions" then
				local literal
				if value == "" or value == nil then
					literal = ""
				else
					local text = tostring(value)
					local inner = text:sub(2, -2)
					local motionParts = {}
					for motionText in inner:gmatch("%b[]") do
						local cellParts = {}
						for dx, dy in motionText:gmatch("%[(-?%d+),(-?%d+)%]") do
							table.insert(cellParts, string.format("{ X = %s, Y = %s }", dx, dy))
						end
						table.insert(
							motionParts,
							string.format('{ Kind = "Single", Cells = { %s } }', table.concat(cellParts, ", "))
						)
					end
					literal = ", Motions = { " .. table.concat(motionParts, ", ") .. " }"
				end
				-- 스킬 표 전체(`patched`)의 맨 끝, 닫는 중괄호 바로 앞에 끼운다 — `Shape` 안이 아니다.
				patched = patched:gsub(",%s*Motions = %b{}", "", 1)
				if literal ~= "" then
					-- 끝쪽 쉼표·공백을 먼저 걷어 내야 `literal`의 쉼표와 겹치지 않는다(위 `insertIntoShape` 참고).
					local body = patched:sub(1, -2):gsub(",%s*$", "")
					patched = body .. literal .. " }"
				end
				count += 1
				continue
			end

			local replacement
			if type(value) == "number" then
				replacement = key .. " = " .. numberLiteral(value)
			else
				replacement = key .. " = " .. quote(tostring(value))
			end
			local next, hits
			if type(value) == "number" then
				next, hits = patched:gsub(key .. " = [%-%d%.]+", lit(replacement), 1)
			else
				next, hits = patched:gsub(key .. ' = "[^"]*"', lit(replacement), 1)
			end

			--[[
				없던 값은 **끼워 넣는다.**

				`Shape = { Kind = "Row" }`처럼 Radius가 아예 없는 스킬이 있다. 그때
				"바꿀 게 없다"고 넘어가면 편집기에서 범위 크기를 넣어도 조용히 사라진다.
				Shape에 속한 값은 Shape 안쪽에, 나머지는 Id 뒤에 넣는다.
			]]
			if hits == 0 then
				if SHAPE_KEYS[key] then
					next, hits = patched:gsub("(Shape = {[^}]*)}", "%1, " .. lit(replacement) .. " }", 1)
				else
					next, hits = patched:gsub('(Id = "' .. id .. '",)', "%1 " .. lit(replacement) .. ",", 1)
				end
			end

			if hits > 0 then
				patched = next
				count += 1
			end
		end

		if count > 0 then
			source = source:sub(1, open - 1) .. patched .. source:sub(open + #block)
			touched += count
			print(string.format("  %-34s %d칸", id, count))
		end
		edits[id] = nil
	end

	if touched > 0 and not dry then
		fs.writeFile(path, source)
	end
	return touched
end

--=== 실행 ===--

local input = process.args[1]
if input == nil or input == "" or input == "--dry" then
	input = "config_edits.json"
end

if not fs.isFile(input) then
	print(string.format("[config_edits] '%s'를 찾을 수 없습니다. 편집기에서 `수정본 내려받기`를 먼저 하세요.", input))
	process.exit(1)
end

local data = serde.decode("json", fs.readFile(input))
local applied = 0

-- 언제 저장한 것인지 먼저 알려 준다. 오래된 파일을 다시 먹이는 사고를 줄인다.
if data.savedAtLocal or data.savedAt then
	print(string.format("[config_edits] %s 에 저장된 수정본", tostring(data.savedAtLocal or data.savedAt)))
end

--=== 카드 이름·설명 ===--

if data.cards then
	print("[카드 글]")
	local pending = table.clone(data.cards)
	for _, entry in fs.readDir(CARD_DIR) do
		if entry:match("Cards%.luau$") then
			applied += patchFile(CARD_DIR .. entry, pending, writeFields)
		end
	end
	for id in pending do
		print(string.format("  [건너뜀] %s — 그런 Id의 카드가 없습니다", id))
	end
end

--=== 카드 레벨 사다리 ===--

if data.cardLevels then
	print("[카드 레벨]")
	--[[
		사다리는 통째로 다시 쓴다. 바뀐 칸만 고치려면 나머지 칸의 현재 값을 알아야
		하는데, 그건 소스를 파싱한다는 뜻이다. 대신 **원본 사다리를 읽어 바뀐 칸만
		덮어쓴 뒤** 줄 전체를 새로 만든다.
	]]
	local pending = table.clone(data.cardLevels)
	for _, entry in fs.readDir(CARD_DIR) do
		if not entry:match("Cards%.luau$") then
			continue
		end
		local path = CARD_DIR .. entry
		local source = fs.readFile(path)
		local touched = 0

		for id, slots in pending do
			local blockStart, blockEnd, indent = blockRange(source, id)
			if not (blockStart and blockEnd and indent) then
				continue
			end
			local block = source:sub(blockStart, blockEnd)
			--[[
				사다리가 아예 없던 카드도 받는다.

				편집기에서 숫자를 새로 감싸면 그 카드에 처음으로 사다리가 생긴다.
				"Levels가 없으니 건너뛴다"고 하면 그 작업이 조용히 사라진다.
			]]
			local existing = block:match("\n" .. indent .. "Levels = (%b{}),") or "{}"

			--[[
				기존 사다리를 숫자 배열로 되읽는다.

				바깥 `{}`를 먼저 벗겨야 한다 — 통째로 두면 `%b{}`의 첫 매치가 전체가
				되고, gmatch는 그 뒤부터 이어가므로 안쪽 묶음을 하나도 못 본다.
			]]
			local ladders: { { number } } = {}
			for group in existing:sub(2, -2):gmatch("%b{}") do
				local values: { number } = {}
				for token in group:gmatch("[-%d%.]+") do
					table.insert(values, tonumber(token) :: number)
				end
				if #values > 0 then
					table.insert(ladders, values)
				end
			end

			--[[
				칸을 채운다. **없던 사다리는 만든다.**

				새 사다리는 편집기가 보낸 값들로 채우고, 안 온 레벨은 가장 낮은 레벨의
				값으로 메운다 — 빈 칸이 남으면 그 레벨에서 글의 숫자가 사라진다.
			]]
			--[[
				글의 중괄호 값(= 1레벨 값). **새로 생기는 사다리의 1레벨**을 여기서 채운다 — 예전에는 비워 둔 채
				2~6레벨만 넣어 1레벨이 빠지고, 구멍 난 표를 돌며 순서까지 뒤섞였다(2026-09-28).
			]]
			local descStart = block:find("\n" .. indent .. "Description = ", 1, true)
			local braceValues: { number } = {}
			if descStart then
				local descStop = block:find("\n" .. indent .. "%a", descStart + 2) or #block
				for token in block:sub(descStart, descStop):gmatch("{([%d%.%-]+)}") do
					table.insert(braceValues, tonumber(token) :: number)
				end
			end
			for slot, levels in slots do
				local at = tonumber(slot) :: number
				local ladder = ladders[at]
				if not ladder then
					ladder = { braceValues[at] }
					ladders[at] = ladder
				end
				for level, value in levels do
					ladder[tonumber(level) :: number] = value
				end

				-- 구멍 메우기. 등급 상한은 모르므로 들어온 것 중 가장 높은 레벨까지 본다.
				local highest = 0
				for level in ladder do
					highest = math.max(highest, level)
				end
				local carry = ladder[1]
				for level = 1, highest do
					if ladder[level] == nil then
						ladder[level] = carry
					else
						carry = ladder[level]
					end
				end
			end

			local rendered = {}
			-- 슬롯에 구멍이 있을 수 있다(2·4·5번만 고친 카드). # 는 구멍에서 멈추므로 가장 큰 번호까지 돈다.
			local slotCount = #braceValues
			for index in ladders do
				slotCount = math.max(slotCount, index)
			end
			for index = 1, slotCount do
				local ladder = ladders[index] or { braceValues[index] }
				local cells = {}
				-- 숫자 순서대로(generalized iteration 은 순서를 보장하지 않는다)
				local highest = 0
				for level in ladder do
					highest = math.max(highest, level)
				end
				for level = 1, highest do
					table.insert(cells, numberLiteral(ladder[level] or ladder[1] or 0))
				end
				table.insert(rendered, "{ " .. table.concat(cells, ", ") .. " }")
			end

			local literal = "Levels = { " .. table.concat(rendered, ", ") .. " },"
			local patched, ok = setField(block, indent, "Levels", literal)
			--[[
				사다리가 **아예 없던** 카드는 setField 가 바꿀 줄을 못 찾는다. 예전에는 그대로 건너뛰어
				(2026-09-28 수정본에서 144장 중 137장) 편집기에서 넣은 레벨 수치가 조용히 사라졌다.
				Grade 줄 앞에 새로 끼운다(줄바꿈은 파일 것을 따른다).
			]]
			if not ok then
				local eol = if block:find("\r\n", 1, true) then "\r\n" else "\n"
				local at = block:find(eol .. indent .. "Grade = ", 1, true)
				if at then
					patched = block:sub(1, at - 1) .. eol .. indent .. literal .. block:sub(at)
					ok = true
				end
			end
			if ok then
				source = source:sub(1, blockStart - 1) .. patched .. source:sub(blockEnd + 1)
				touched += 1
				applied += 1
				print(string.format("  %-34s %s", id, literal:sub(1, 70)))
			end
			pending[id] = nil
		end

		if touched > 0 and not dry then
			fs.writeFile(path, source)
		end
	end
	for id in pending do
		print(string.format("  [건너뜀] %s — 그런 Id의 카드가 없습니다", id))
	end
end

--=== 카드 사다리의 키워드 이름표 ===--

if data.cardKeywords then
	print("[카드 키워드]")
	--[[
		편집기는 `카드Id#슬롯` 하나씩 보낸다. 카드 단위로 모아 `LevelKeywords`
		줄을 통째로 다시 쓴다 — 슬롯 하나만 고치려면 나머지 슬롯의 현재 값을 알아야
		하는데, 그건 소스를 파싱한다는 뜻이다.
	]]
	local byCard: { [string]: { [number]: string } } = {}
	for key, fields in data.cardKeywords do
		local cardId, slot = key:match("^(.+)#(%d+)$")
		if cardId then
			byCard[cardId] = byCard[cardId] or {}
			byCard[cardId][tonumber(slot) :: number] = tostring(fields.Keyword or "")
		end
	end

	for _, entry in fs.readDir(CARD_DIR) do
		if not entry:match("Cards%.luau$") then
			continue
		end
		local path = CARD_DIR .. entry
		local source = fs.readFile(path)
		local touched = 0

		for cardId, slots in byCard do
			local blockStart, blockEnd, indent = blockRange(source, cardId)
			if not (blockStart and blockEnd and indent) then
				continue
			end
			local block = source:sub(blockStart, blockEnd)

			-- 몇 칸짜리인지는 `Levels`가 정한다. 그만큼 채운다.
			local existing = block:match("\n" .. indent .. "Levels = (%b{})")
			local count = 0
			for _ in (existing or ""):sub(2, -2):gmatch("%b{}") do
				count += 1
			end
			if count == 0 then
				byCard[cardId] = nil
				continue
			end

			local current: { string } = {}
			local named = block:match("\n" .. indent .. "LevelKeywords = (%b{})")
			if named then
				for value in named:gmatch('"([^"]*)"') do
					table.insert(current, value)
				end
			end
			for slot, keyword in slots do
				current[slot] = keyword
			end

			local parts = {}
			local any = false
			for slot = 1, count do
				local keyword = current[slot] or ""
				table.insert(parts, string.format("%q", keyword))
				if keyword ~= "" then
					any = true
				end
			end

			local patched
			if any then
				local literal = "LevelKeywords = { " .. table.concat(parts, ", ") .. " },"
				local next, ok = setField(block, indent, "LevelKeywords", literal)
				if not ok then
					-- 아직 없는 카드면 Levels 줄 뒤에 새로 끼워 넣는다.
					-- 소스는 CRLF다 — `\n`만 넣으면 이 줄만 어긋나 stylua가 다시 손본다.
					next = block:gsub(
						"(\n" .. indent .. "Levels = %b{},)",
						"%1\r\n" .. indent .. literal:gsub("%%", "%%%%"),
						1
					)
				end
				patched = next
			else
				patched = block:gsub("\n" .. indent .. "LevelKeywords = %b{},", "", 1)
			end

			source = source:sub(1, blockStart - 1) .. patched .. source:sub(blockEnd + 1)
			touched += 1
			applied += 1
			print(string.format("  %-34s %d칸", cardId, count))
			byCard[cardId] = nil
		end

		if touched > 0 and not dry then
			fs.writeFile(path, source)
		end
	end
	for cardId in byCard do
		print(string.format("  [건너뜀] %s — 그런 Id의 카드가 없습니다", cardId))
	end
end

--=== 손으로 그린 그림 ===--

if data.artworks then
	print("[그림]")
	--[[
		`CardArtworks` 의 `ARTWORKS` 표를 통째로 다시 쓴다.

		편집기는 그림 하나를 JSON 문자열로 보낸다(도형이 여러 개라 칸 하나에 담기지
		않는다). 여기서 Luau 표로 편다.
	]]
	local path = "src/shared/CardArtworks.luau"
	local source = fs.readFile(path)

	-- 이미 있던 그림을 되읽는다. 이번에 안 온 것은 그대로 둬야 한다.
	local kept: { [string]: string } = {}
	local existing = source:match("local ARTWORKS: [^=]*= (%b{})")
	if existing then
		-- 이름이 한글일 수 있어 키는 늘 대괄호 꼴이다.
		for id, body in existing:gmatch('%[\"([^\"]+)\"%]%s*=%s*(%b{})') do
			kept[id] = body
		end
	end

	local count = 0
	for id, fields in data.artworks do
		local body = tostring(fields.Body or "")
		if body == "" then
			-- 빈 칸은 "이 그림 지웠다"는 뜻이다.
			kept[id] = nil
			print(string.format("  %-34s 지움", id))
			continue
		end
		local payload = serde.decode("json", body)
		local rows = {}
		for _, item in payload.shapes or {} do
			table.insert(
				rows,
				string.format(
					"\t\t\t{ X = %s, Y = %s, W = %s, H = %s, Rotation = %s, "
						.. "Color = %q, Corner = %s, Stroke = %s, ZIndex = %d, Transparency = %s },",
					-- 편집기가 기본값인 칸은 빼고 보낼 때가 있다(회전 0·테두리 0·투명 0 등) → 기본값으로 채운다
					numberLiteral(item.x or 0.5),
					numberLiteral(item.y or 0.5),
					numberLiteral(item.w or 0.3),
					numberLiteral(item.h or 0.3),
					numberLiteral(item.r or 0),
					tostring(item.c or "#ffffff"),
					numberLiteral(item.k or 0),
					numberLiteral(item.s or 0),
					math.floor(item.z or 6),
					numberLiteral(item.t or 0)
				)
			)
		end
		kept[id] = string.format(
			"{\n\t\tId = %q,\n\t\tName = %q,\n\t\tShapes = {\n%s\n\t\t},\n\t}",
			id,
			tostring(payload.name or id),
			table.concat(rows, "\n")
		)
		count += 1
		print(string.format("  %-34s 도형 %d개", id, #rows))
	end

	local names = {}
	for id in kept do
		table.insert(names, id)
	end
	table.sort(names)

	local blocks = {}
	for _, id in names do
		table.insert(blocks, string.format("\t[%q] = %s,", id, kept[id]))
	end
	local literal = if #blocks == 0 then "{}" else "{\n" .. table.concat(blocks, "\n") .. "\n}"
	source = source:gsub("(local ARTWORKS: [^=]*= )%b{}", "%1" .. literal:gsub("%%", "%%%%"), 1)
	if not dry then
		fs.writeFile(path, source)
	end
	applied += count
end

--=== 직업 패시브 ===--

if data.passives then
	print("[패시브]")
	local pending = table.clone(data.passives)
	applied += patchFile("src/shared/ClassPassives.luau", pending, writeFields)
	for id in pending do
		print(string.format("  [건너뜀] %s — 그런 패시브가 없습니다", id))
	end
end

--=== 키워드 사전 ===--

if data.keywords then
	print("[키워드]")
	local pending = table.clone(data.keywords)
	applied += patchFile("src/shared/Keywords.luau", pending, writeFields)
	for id in pending do
		print(string.format("  [건너뜀] %s — 그런 키워드가 없습니다", id))
	end
end

--=== 아이콘 도형 ===--

if data.icon then
	print("[아이콘]")
	--[[
		`CardArt`의 `SHAPE_OVERRIDES` 표를 통째로 다시 쓴다.

		편집기는 `태그#도형번호` 하나씩 보내지만, 표는 태그별로 묶여 있다. 부분
		치환으로는 표 모양이 금세 무너지므로 **원본 표를 읽어 합친 뒤 전부 새로**
		적는다.
	]]
	local path = "src/shared/CardArt.luau"
	local source = fs.readFile(path)
	local existing = source:match("local SHAPE_OVERRIDES: [^=]*= (%b{})")
	if not existing then
		print("  [건너뜀] SHAPE_OVERRIDES 표를 찾지 못했습니다")
	else
		-- 이미 적혀 있던 값을 되읽는다.
		local merged: { [string]: { [number]: { [string]: number } } } = {}
		for tag, body in existing:gmatch("(%w+)%s*=%s*(%b{})") do
			merged[tag] = {}
			for index, fields in body:gmatch("%[(%d+)%]%s*=%s*(%b{})") do
				local entry: { [string]: number } = {}
				for key, value in fields:gmatch("(%a+)%s*=%s*(-?[%d%.]+)") do
					entry[key] = tonumber(value) :: number
				end
				merged[tag][tonumber(index) :: number] = entry
			end
		end

		local touched = 0
		for key, fields in data.icon do
			local tag, index = key:match("^(%w+)#(%d+)$")
			if not tag then
				continue
			end
			merged[tag] = merged[tag] or {}
			local slot = tonumber(index) :: number
			merged[tag][slot] = merged[tag][slot] or {}
			for name, value in fields do
				merged[tag][slot][name] = tonumber(value) :: number
			end
			touched += 1
		end

		-- 태그와 번호를 정렬해 적는다. 순서가 흔들리면 diff가 매번 커진다.
		local tagNames = {}
		for tag in merged do
			table.insert(tagNames, tag)
		end
		table.sort(tagNames)

		local blocks = {}
		for _, tag in tagNames do
			local slots = {}
			for slot in merged[tag] do
				table.insert(slots, slot)
			end
			table.sort(slots)

			local entries = {}
			for _, slot in slots do
				local parts = {}
				for _, name in { "X", "Y", "W", "H", "Rotation" } do
					local value = merged[tag][slot][name]
					if value then
						table.insert(parts, name .. " = " .. numberLiteral(value))
					end
				end
				if #parts > 0 then
					table.insert(entries, string.format("\t\t[%d] = { %s },", slot, table.concat(parts, ", ")))
				end
			end
			if #entries > 0 then
				table.insert(blocks, string.format("\t%s = {\n%s\n\t},", tag, table.concat(entries, "\n")))
			end
		end

		local literal = if #blocks == 0 then "{}" else "{\n" .. table.concat(blocks, "\n") .. "\n}"
		source = source:gsub(
			"(local SHAPE_OVERRIDES: [^=]*= )%b{}",
			"%1" .. literal:gsub("%%", "%%%%"),
			1
		)
		if not dry then
			fs.writeFile(path, source)
		end
		applied += touched
		print(string.format("  %d칸 · 태그 %d종", touched, #blocks))
	end
end

--=== 직업 ===--

if data.classes then
	print("[직업]")
	local pending = table.clone(data.classes)
	applied += patchFile(CHARACTERS, pending, writeFields)
	for id in pending do
		print(string.format("  [건너뜀] %s — 그런 직업이 없습니다", id))
	end
end

--=== 직업의 대표 스킬 ===--

if data.classSkill then
	print("[대표 스킬]")
	local source = fs.readFile(CHARACTERS)
	local touched = 0
	for id, fields in data.classSkill do
		local blockStart, blockEnd, indent = blockRange(source, id)
		if not (blockStart and blockEnd and indent) then
			print(string.format("  [건너뜀] %s — 그런 직업이 없습니다", id))
			continue
		end
		local block = source:sub(blockStart, blockEnd)
		-- 대표 스킬은 직업 블록 안의 `Skill = { ... }`이라 한 단계 더 들여쓰여 있다.
		local inner = indent .. "\t"
		local patched, count = writeFields(block, inner, fields)
		if count > 0 then
			source = source:sub(1, blockStart - 1) .. patched .. source:sub(blockEnd + 1)
			touched += count
			applied += count
			print(string.format("  %-34s %d칸", id .. ".Skill", count))
		end
	end
	if touched > 0 and not dry then
		fs.writeFile(CHARACTERS, source)
	end
end

--=== 전투 스킬 ===--

if data.skills or data.skillShape then
	print("[전투 스킬]")
	--[[
		범위(`skillShape`)는 같은 스킬 표 **안쪽**의 `Shape`에 산다. 파일을 두 번
		읽고 쓰면 나중 것이 앞의 것을 덮으므로, 한 묶음으로 합쳐 한 번에 고친다.
	]]
	local pending = table.clone(data.skills or {})
	for id, shape in data.skillShape or {} do
		local entry = pending[id] or {}
		for key, value in shape do
			entry[key] = value
		end
		pending[id] = entry
	end
	applied += patchInline(BATTLE_SKILLS, pending)
	for id in pending do
		print(string.format("  [건너뜀] %s — 그런 스킬이 없습니다", id))
	end
end

print(string.format("[config_edits] %d칸 %s", applied, if dry then "바뀔 예정" else "반영됨"))
if not dry and applied > 0 then
	print("[config_edits] 이어서 `stylua src`와 `tools/check.ps1`을 돌리세요.")
end
