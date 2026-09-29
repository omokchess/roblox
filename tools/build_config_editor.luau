--[[
	build_config_editor.luau — **게임 설정을 통째로 고치는 편집기 HTML**을 만든다.

	`build_card_catalog.luau`가 카드 도감이었다면 이쪽은 그것을 삼킨 상위 도구다.
	브라우저에서 고치고 JSON으로 내보내면 `apply_config_edits.luau`가 소스에 되먹인다.

	  lune run tools/build_config_editor.luau [출력경로]

	기본 출력은 `config_editor.html`.

	--------------------------------------------------------------------------
	고칠 수 있는 것

	  카드 306장   이름 · 설명 · **레벨별 수치**(사다리를 칸마다 직접 입력)
	  직업 9종     이름 · 역할 · 설명 · 최대 체력 · 이동속도 · 평타 위력
	               + 대표 스킬(이름 · 설명 · 위력 · 재사용 대기)
	  전투 스킬    직업별 1·2·3 스킬의 이름 · 피해량 · 근접/원거리

	--------------------------------------------------------------------------
	설명은 `<textarea>`다 (요청: "줄바꿈도 적용되도록")

	예전에는 contenteditable이라 줄바꿈이 브라우저 마음대로 `<div>`·`<br>`로 바뀌어
	JSON에 담기지 못했다. textarea는 값이 그냥 문자열이라 `\n`이 그대로 살아 있고,
	`JSON.stringify`가 `\n`으로 이스케이프해 준다. 되먹일 때도 Luau 문자열의
	`\n`으로 그대로 들어간다.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

--=== Roblox 흉내 ===--

local Color3 = {}
function Color3.fromRGB(r: number, g: number, b: number)
	return { R = r / 255, G = g / 255, B = b / 255 }
end
function Color3.new(r: number, g: number, b: number)
	return { R = r, G = g, B = b }
end

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
readTree("src/shared/", "")

local cache: { [string]: any } = {}
local loadShared, makeProxy
function makeProxy(prefix: string, parent: any): any
	return setmetatable({}, {
		__index = function(_, name: string)
			if name == "Parent" and parent ~= nil then
				return parent
			end
			local full = if prefix == "" then name else prefix .. "/" .. name
			if sources[full] then
				return loadShared(full)
			end
			if sources[full .. "/init"] then
				return loadShared(full .. "/init")
			end
			if folders[full] then
				return makeProxy(full, nil)
			end
			error("not found: " .. full)
		end,
	})
end
local sharedProxy = makeProxy("", nil)
function loadShared(name: string): any
	if cache[name] then
		return cache[name]
	end
	local env: any = {}
	for key, value in (getfenv and getfenv(1) or _G) :: any do
		env[key] = value
	end
	env.math, env.table, env.string = math, table, string
	env.warn = function() end
	env.Color3 = Color3
	local dir = name:match("^(.*)/[^/]+$")
	local leaf = name:match("([^/]+)$")
	if leaf == "init" and dir then
		local grand = dir:match("^(.*)/[^/]+$")
		env.script = makeProxy(dir, if grand then makeProxy(grand, sharedProxy) else sharedProxy)
	else
		env.script = { Parent = if dir then makeProxy(dir, sharedProxy) else sharedProxy }
	end
	env.require = function(target: any)
		return target
	end
	local result = luau.load(sources[name], { debugName = name, environment = env })()
	cache[name] = result
	return result
end

local CardArt = loadShared("CardArt")
local CardEffects = loadShared("CardEffects")
local AbilityCardDefinitions = loadShared("AbilityCardDefinitions")
local CharacterDefinitions = loadShared("CharacterDefinitions")
local BattleSkills = loadShared("BattleSkills")
local Keywords = loadShared("Keywords")
local ClassPassives = loadShared("ClassPassives")
local CardArtworks = loadShared("CardArtworks")
loadShared("AbilityCards/init").Register()

--=== 도우미 ===--

local function hex(color: any): string
	return string.format(
		"#%02x%02x%02x",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function num(value: number): string
	local text = string.format("%.2f", value)
	text = text:gsub("%.?0+$", "")
	return if text == "" or text == "-" then "0" else text
end

local function escape(text: string): string
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	text = text:gsub('"', "&quot;")
	return text
end

-- 짧은 JSON 문자열. 키워드 사전을 편집기로 보낼 때만 쓴다.
local function jsonText(text: string): string
	local escaped = text:gsub("\\", "\\\\"):gsub('"', '\\"')
	return '"' .. escaped .. '"'
end

local SIZE = 200

local function artSvg(card: any): string
	local art = CardArt.For(card)
	local order = {}
	for index, item in art.Shapes do
		table.insert(order, { Item = item, Index = index })
	end
	table.sort(order, function(a, b)
		if a.Item.ZIndex == b.Item.ZIndex then
			return a.Index < b.Index
		end
		return a.Item.ZIndex < b.Item.ZIndex
	end)

	local parts = {}
	for _, entry in order do
		local item = entry.Item
		local w, h = item.W * SIZE, item.H * SIZE
		local cx, cy = item.X * SIZE, item.Y * SIZE
		local attrs =
			string.format('x="%s" y="%s" width="%s" height="%s"', num(cx - w / 2), num(cy - h / 2), num(w), num(h))
		local radius = item.Corner * math.min(w, h)
		if radius > 0.05 then
			attrs ..= string.format(' rx="%s"', num(radius))
		end
		if item.Stroke > 0 then
			attrs ..= string.format(
				' fill="none" stroke="%s" stroke-width="%s"',
				hex(item.Color),
				num(item.Stroke * SIZE)
			)
		else
			attrs ..= string.format(' fill="%s"', hex(item.Color))
		end
		if item.Transparency > 0 then
			attrs ..= string.format(' opacity="%s"', num(1 - item.Transparency))
		end
		if item.Rotation ~= 0 then
			attrs ..= string.format(' transform="rotate(%s %s %s)"', num(item.Rotation), num(cx), num(cy))
		end
		table.insert(parts, "<rect " .. attrs .. "/>")
	end

	return string.format(
		'<svg viewBox="0 0 %d %d" style="background:%s">%s</svg>',
		SIZE,
		SIZE,
		hex(art.Background),
		table.concat(parts)
	)
end

--[[
	편집 칸 하나.

	`data-scope`·`data-key`·`data-field`가 이 값이 JSON 어디로 가는지를 말한다.
	되돌리기와 변경 판정을 위해 원문을 `data-orig`에 함께 싣는다.
]]
local function field(scope: string, key: string, name: string, label: string, value: string, kind: string): string
	local common = string.format(
		'data-scope="%s" data-key="%s" data-field="%s" data-orig="%s"',
		escape(scope),
		escape(key),
		escape(name),
		escape(value)
	)
	if kind == "text" then
		--[[
			설명 칸은 **겹쳐 놓은 두 층**이다.

			뒤에 색칠한 글을 그리고, 그 위에 배경이 비치는 textarea를 얹는다.
			textarea 자체는 글자에 색을 못 넣지만 줄바꿈·되돌리기·선택은 브라우저가
			해 주므로, 그 동작을 그대로 두고 색만 뒤에서 입힌다.

			아래 `kwbar`에는 글에 나온 키워드마다 레벨·수치 입력이 붙는다.
		]]
		return string.format(
			'<label class="fld"><span>%s</span>'
				.. '<div class="hl"><pre class="hlback" aria-hidden="true"></pre>'
				.. '<textarea class="f hltext" rows="3" spellcheck="false" %s>%s</textarea></div>'
				.. '<div class="kwbar"></div></label>',
			escape(label),
			common,
			escape(value)
		)
	end
	return string.format(
		'<label class="fld %s"><span>%s</span><input class="f" type="%s" value="%s" %s></label>',
		if kind == "number" then "narrow" else "",
		escape(label),
		if kind == "number" then "number" else "text",
		escape(value),
		common
	)
end

--[[
	정해진 값 중에서 고르는 칸.

	근/원거리와 범위 종류처럼 **후보가 정해져 있는 값**은 타이핑하게 두면 안 된다
	(요청). `"Meele"` 같은 오타가 조용히 들어가면 게임에서는 그냥 근거리로 접혀
	무엇이 잘못됐는지 드러나지 않는다.
]]
local function choice(
	scope: string,
	key: string,
	name: string,
	label: string,
	value: string,
	options: { { string } }
): string
	local rendered = {}
	for _, option in options do
		table.insert(
			rendered,
			string.format(
				'<option value="%s"%s>%s</option>',
				escape(option[1]),
				if option[1] == value then " selected" else "",
				escape(option[2])
			)
		)
	end
	return string.format(
		'<label class="fld"><span>%s</span><select class="f" data-scope="%s" data-key="%s"'
			.. ' data-field="%s" data-orig="%s">%s</select></label>',
		escape(label),
		escape(scope),
		escape(key),
		escape(name),
		escape(value),
		table.concat(rendered)
	)
end

--[[
	직접 찍은 범위를 `[[dx,dy],…]` JSON 한 줄로. 없으면 빈 문자열이다.

	이 값은 hidden input에 실려 편집기와 JSON 사이를 오간다. 표 형태로 풀어 놓으면
	"바뀌었나"를 비교하기 어려워서 문자열 하나로 다닌다.
]]
local function cellsJson(cells: { { X: number, Y: number } }?): string
	if not cells or #cells == 0 then
		return ""
	end
	local parts = {}
	for _, offset in cells do
		table.insert(parts, string.format("[%d,%d]", offset.X, offset.Y))
	end
	return "[" .. table.concat(parts, ",") .. "]"
end

--[[
	조건부로 늘어나는 단계를 `[[[dx,dy],…],[[dx,dy],…],…]` JSON 한 줄로.
	`cellsJson`과 같은 이유로 문자열 하나에 담는다 — `Stages`는 한 단계 더
	감싼 배열이라 형태만 다르다.
]]
local function stagesJson(stages: { { { X: number, Y: number } } }?): string
	if not stages or #stages == 0 then
		return ""
	end
	local stageParts = {}
	for _, stage in stages do
		local cellParts = {}
		for _, offset in stage do
			table.insert(cellParts, string.format("[%d,%d]", offset.X, offset.Y))
		end
		table.insert(stageParts, "[" .. table.concat(cellParts, ",") .. "]")
	end
	return "[" .. table.concat(stageParts, ",") .. "]"
end

--=== 카드 ===--

local CLASSES = {
	{ Id = "Musician", Name = "음악가" },
	{ Id = "Duelist", Name = "결투사" },
	{ Id = "Berserker", Name = "광전사" },
	{ Id = "Quasar", Name = "퀘이사" },
	{ Id = "Pulsar", Name = "펄서" },
	{ Id = "WallPilgrim", Name = "월 필그림" },
	{ Id = "WallMason", Name = "월 메이슨" },
	{ Id = "WallBreaker", Name = "월 브레이커" },
	{ Id = "Alchemist", Name = "연금술사" },
}

local GRADE_LABEL = { Essential = "필수", Rare = "희귀", Common = "일반" }

--[[
	고르는 값들. `BattleSkills.SkillRange`를 그대로 옮겼다.
	여기에 없는 값이 소스에 생기면 편집기가 그 스킬을 첫 항목으로 바꿔 버리므로,
	타입을 늘릴 때 이 표도 같이 늘려야 한다.

	범위 종류·범위 크기(`BattleGrid.ShapeKind`·`Radius`)를 고르는 칸은 뺐다
	(요청) — 격자에서 찍는 지정 범위가 있는데 굳이 둘 다 있을 필요가 없었다.
]]
local RANGE_OPTIONS = {
	{ "Melee", "근거리" },
	{ "Ranged", "원거리" },
	{ "Supporting", "서포팅" },
}

local cardSections = {}
local totalCards, wiredCards = 0, 0

for _, class in CLASSES do
	local rendered = {}
	local classCount = 0

	for _, grade in { "Essential", "Rare", "Common" } do
		for _, card in AbilityCardDefinitions.GetPool(class.Id, grade) do
			totalCards += 1
			classCount += 1
			local isWired = CardEffects.IsWired(card.Id)
			if isWired then
				wiredCards += 1
			end

			local tags = {}
			for _, tag in card.Tags do
				table.insert(tags, string.format('<em class="tag">%s</em>', escape(tag)))
			end

			--[[
				**레벨 사다리.** 칸 하나가 레벨 하나다.

				요청("원하는 카드의 레벨을 직접 정하기")대로 레벨별 값을 여기서 바로
				고친다. 설명의 `{1}`이 이 줄의 값을, `{2}`가 다음 줄의 값을 쓴다.
			]]
			local ladders = {}
			local maxLevel = AbilityCardDefinitions.MaxLevel(grade)
			if card.Levels then
				for slot, values in card.Levels do
					local boxes = {}
					for level = 1, maxLevel do
						table.insert(
							boxes,
							string.format(
								'<input class="lv" type="number" step="any" value="%s"'
									.. ' data-scope="cardLevels" data-key="%s" data-slot="%d" data-level="%d"'
									.. ' data-orig="%s" title="레벨 %d">',
								num(values[level] or 0),
								escape(card.Id),
								slot,
								level,
								num(values[level] or 0),
								level
							)
						)
					end
					--[[
						사다리마다 **어떤 키워드의 값인지** 잇는다 (요청: 하나에 여럿도 되게).

						값 자체는 카드마다 따로이므로 여기서 갖고 있는 것은 이름표뿐이다.
						여러 낱말을 이으므로 쉼표로 이어 하나의 문자열에 담는다("Id1,Id2") —
						저장칸은 임의의 문자열을 그대로 들고 있어야 해서 고르는 값이 정해진
						`<select>`가 아니라 숨은 `<input>`이다. 실제로 고르고 떼는 것은
						아래 글 밑의 낱말 칩 줄이 한다.
					]]
					local named = (card.LevelKeywords or {})[slot] or ""
					table.insert(
						ladders,
						string.format(
							'<div class="ladder"><b>{%d}</b>'
								.. '<input type="hidden" class="f" data-scope="cardKeywords"'
								.. ' data-key="%s#%d" data-field="Keyword" data-orig="%s" value="%s">'
								.. "%s</div>",
							slot,
							escape(card.Id),
							slot,
							escape(named),
							escape(named),
							table.concat(boxes)
						)
					)
				end
			end

			--[[
				**최대 레벨을 카드마다 정한다** (요청).

				등급표(필수 2 · 희귀·일반 6)가 기본값이지만, 이 칸을 고치면 그
				카드만 다른 사다리 길이를 쓴다. 늘리면 마지막 칸 값을 이어서
				채우고, 줄이면 뒤쪽 칸을 지운다 — `resizeLadder`가 한다.

				**레벨 미리보기**는 접어 둔다(요청) — 306장이 한 화면에 있어
				펼쳐 둔 글이 전부 차지하면 카드가 다시 커진다.
			]]
			local maxLevel = AbilityCardDefinitions.MaxLevel(grade)
			local levelOptions = {}
			for level = 1, maxLevel do
				table.insert(levelOptions, string.format('<option value="%d">Lv%d</option>', level, level))
			end
			local preview = string.format(
				'<div class="lvprev-wrap">%s'
					.. '<details class="lvprev-details"><summary>레벨 미리보기</summary>'
					.. '<label class="fld narrow"><span>미리보기 레벨</span>'
					.. '<select class="cardlv" data-maxlevel="%d">%s</select></label>'
					.. '<div class="lvprev" data-cardid="%s"></div></details></div>',
				field("cards", card.Id, "MaxLevel", "최대 레벨", tostring(maxLevel), "number"),
				maxLevel,
				table.concat(levelOptions),
				escape(card.Id)
			)

			table.insert(
				rendered,
				string.format(
					'<article class="card %s%s" data-id="%s" data-grade="%s" data-text="%s">'
						.. '<div class="art">%s'
						.. '<button type="button" class="artpick" data-pick-art="%s" title="그림 고르기">🖼</button>'
						.. '<input type="hidden" class="f" data-scope="cards" data-key="%s" data-field="Art"'
						.. ' data-orig="%s" value="%s"></div>'
						.. '<div class="body">'
						.. '<div class="row"><span class="grade">%s</span>%s</div>'
						.. "%s%s%s"
						.. '<footer>%s<span class="wire %s">%s</span></footer>'
						.. "</div></article>",
					grade:lower(),
					if isWired then " on" else "",
					escape(card.Id),
					grade,
					escape((card.Name .. " " .. card.Description .. " " .. table.concat(card.Tags, " ")):lower()),
					artSvg(card),
					escape(card.Id),
					escape(card.Id),
					escape(card.Art or ""),
					escape(card.Art or ""),
					GRADE_LABEL[grade],
					field("cards", card.Id, "Name", "이름", card.Name, "line"),
					field("cards", card.Id, "Description", "설명", card.Description, "text"),
					if #ladders > 0
						then string.format('<div class="ladders">%s</div>', table.concat(ladders))
						else "",
					preview,
					table.concat(tags),
					if isWired then "yes" else "no",
					if isWired then "전투 반영됨" else "미반영"
				)
			)
		end
	end

	table.insert(
		cardSections,
		string.format(
			'<section class="klass" data-class="%s"><h2>%s <small>%d장</small></h2>'
				.. '<div class="grid">%s</div></section>',
			escape(class.Id),
			escape(class.Name),
			classCount,
			table.concat(rendered)
		)
	)
end

--=== 직업 ===--

local classPanels = {}
for _, class in CLASSES do
	local definition = CharacterDefinitions.Get(class.Id)
	if not definition then
		continue
	end

	local skillRows = {}
	--[[
		스킬 한 줄을 그린다. `label`이 "N스킬"이면 기본 스킬, "강화 스킬"이면
		3번 오른쪽에 조건부로 열리는 그 직업의 강화 스킬이다(요청: "직업 능력에서
		강화스킬 표시도 해줘").
	]]
	local function renderSkillRow(skill, label)
		--[[
			직접 찍은 범위. 값은 `[[dx,dy],…]` JSON이고, 칸을 찍는 것은 6×3 격자
			창이 한다. **범위 종류·범위 크기를 고르는 칸은 뺐다** (요청) — 격자
			찍기가 이미 그 둘을 겸하므로 굳이 따로 고를 필요가 없었다. 그 두 칸이
			있던 자리에 이 단추를 옮겼다.

			`Stages`(조건부로 늘어나는 단계)·`TargetSide`(아군/상대 진영)·
			`Motions`(모션 단계)는 `Cells`와 짝을 이루는 별도 칸으로 둔다 —
			`Cells`의 저장 형식(평평한 `[[dx,dy],…]`)과 그걸 읽는
			`apply_config_edits.luau`를 안 건드리고 얹을 수 있다.

			`Motions`는 `skill.Motions`(스킬 하나에 딸린 추가 모션들, 앞뒤관통
			같은 것)를 담는다 — 형식은 `Stages`와 똑같은 "칸 목록의 목록"이라
			`stagesJson`을 그대로 재사용한다. 다른 점은 뜻뿐이다: `Stages`는
			자원이 쌓일수록 범위가 넓어지는 것(한 번의 타격)이고, `Motions`는
			몇 번 · 어디를 차례로 때리는가(여러 번의 타격)다.
		]]
		local buttonLabel
		if not skill.Shape.Cells then
			buttonLabel = "격자에서 찍기"
		else
			buttonLabel = string.format("%d칸", #skill.Shape.Cells)
			if skill.Shape.Stages and #skill.Shape.Stages > 0 then
				buttonLabel ..= string.format(" +%d단계", #skill.Shape.Stages)
			end
			if skill.Motions and #skill.Motions > 0 then
				buttonLabel ..= string.format(" · 모션 %d개", #skill.Motions + 1)
			end
			if skill.Shape.TargetSide == "Ally" then
				buttonLabel ..= " · 아군"
			end
		end
		local motionCells = {}
		for _, motion in skill.Motions or {} do
			table.insert(motionCells, motion.Cells or {})
		end
		local pickButton = string.format(
			'<label class="fld"><span>지정 범위</span>'
				.. '<button class="pick" type="button" data-pick="%s">%s</button>'
				.. '<input type="hidden" class="f cells" data-scope="skillShape" data-key="%s"'
				.. ' data-field="Cells" data-orig="%s" value="%s">'
				.. '<input type="hidden" class="f" data-scope="skillShape" data-key="%s"'
				.. ' data-field="Stages" data-orig="%s" value="%s">'
				.. '<input type="hidden" class="f" data-scope="skillShape" data-key="%s"'
				.. ' data-field="TargetSide" data-orig="%s" value="%s">'
				.. '<input type="hidden" class="f" data-scope="skills" data-key="%s"'
				.. ' data-field="Motions" data-orig="%s" value="%s"></label>',
			escape(skill.Id),
			buttonLabel,
			escape(skill.Id),
			escape(cellsJson(skill.Shape.Cells)),
			escape(cellsJson(skill.Shape.Cells)),
			escape(skill.Id),
			escape(stagesJson(skill.Shape.Stages)),
			escape(stagesJson(skill.Shape.Stages)),
			escape(skill.Id),
			escape(skill.Shape.TargetSide or ""),
			escape(skill.Shape.TargetSide or ""),
			escape(skill.Id),
			escape(stagesJson(motionCells)),
			escape(stagesJson(motionCells))
		)
		table.insert(
			skillRows,
			string.format(
				'<div class="skill"><b>%s</b><div class="skillgrid">%s%s%s%s%s</div>%s</div>',
				escape(label),
				field("skills", skill.Id, "Name", "이름", skill.Name, "line"),
				field("skills", skill.Id, "Damage", "피해량", num(skill.Damage), "number"),
				choice("skills", skill.Id, "Range", "공격 유형", skill.Range, RANGE_OPTIONS),
				--[[
					쿨타임(재사용 대기). md에 스킬마다 "재사용 대기 N턴"으로 이미
					적혀 있던 값인데, 실제로 막는 자리(`BattleSkills.Skill.Cooldown`
					→ `GridBattle`)는 있어도 편집기에 칸이 없었다(요청: "직업 능력
					탭에서 액티브 스킬 쿨타임 쓰는 칸이 없어"). 0이면 매 턴 그대로
					쓸 수 있다 — 대부분의 공용기(가드·명상 등)가 이 값이다.
				]]
				field("skills", skill.Id, "Cooldown", "쿨타임(턴)", num(skill.Cooldown or 0), "number"),
				pickButton,
				field("skills", skill.Id, "Description", "설명", skill.Description or "", "text")
			)
		)
	end

	for index, skill in BattleSkills.ForClass(class.Id) do
		renderSkillRow(skill, string.format("%d스킬", index))
	end
	for _, skill in BattleSkills.Upgrades() do
		if skill.ClassId == class.Id then
			renderSkillRow(skill, "강화 스킬")
		end
	end

	--[[
		이동속도·평타 위력·대표 스킬 칸은 뺐다 (요청).

		앞의 둘은 격자 전투에서 쓰이지 않고(이동은 칸 단위, 평타는 무기 공격력),
		대표 스킬은 `CharacterDefinitions`에만 남은 옛 전투 방식의 잔재다. 실제로
		전투에 나가는 것은 아래 `전투 스킬` 셋이다.
	]]
	--[[
		패시브. 이름과 설명을 여기서 고친다.
		전용 상태이상은 `Keywords` 를 가리키기만 한다 — 값은 키워드 탭에서 고친다.
	]]
	local kit = ClassPassives.Get(class.Id)
	local passiveList = {}
	local statusList = {}
	if kit then
		for _, passive in kit.Passives do
			table.insert(
				passiveList,
				string.format(
					'<div class="skill"><b>패시브</b><div class="skillgrid pasgrid">%s%s</div></div>',
					field("passives", passive.Id, "Name", "이름", passive.Name, "line"),
					field("passives", passive.Id, "Description", "설명", passive.Description, "text")
				)
			)
		end
		for _, keywordId in kit.StatusKeywords do
			local keyword = Keywords.Get(keywordId)
			if keyword then
				table.insert(
					statusList,
					string.format(
						'<div class="statrow" data-kw-id="%s"><span class="kind %s" style="background:%s22;color:%s">%s</span>'
							.. '<span class="sdesc">%s</span>'
							.. '<button class="chip gokw" data-kw="%s">키워드 탭에서 고치기</button></div>',
						escape(keyword.Id),
						escape(keyword.Kind:lower()),
						escape(keyword.Color),
						escape(keyword.Color),
						escape(keyword.Name),
						escape(keyword.Description),
						escape(keyword.Id)
					)
				)
			end
		end
	end
	local passiveRows = table.concat(passiveList)
	local statusRows = if #statusList > 0
		then table.concat(statusList)
		else '<p class="note">이 직업은 전용 상태이상이 없다.</p>'

	table.insert(
		classPanels,
		string.format(
			'<section class="klass panel" data-class="%s"><h2>%s</h2>'
				.. '<div class="fields">%s%s%s%s</div>'
				.. '<h3>전용 상태이상</h3><div class="kws">%s</div>'
				.. '<h3>패시브</h3><div class="skills">%s</div>'
				.. '<h3>전투 스킬</h3><div class="skills">%s</div>'
				.. "</section>",
			escape(class.Id),
			escape(definition.Name),
			field("classes", class.Id, "Name", "이름", definition.Name, "line"),
			field("classes", class.Id, "Role", "역할", definition.Role, "line"),
			field("classes", class.Id, "MaxHealth", "최대 체력", num(definition.MaxHealth), "number"),
			field("classes", class.Id, "Description", "설명", definition.Description, "text"),
			statusRows,
			passiveRows,
			table.concat(skillRows)
		)
	)
end


--=== 키워드 ===--

--[[
	키워드 사전 탭. 이름과 설명을 고칠 수 있다.

	카드 글의 `[낱말]`이 여기 실린 **이름**과 같아야 게임이 설명을 띄운다.
	그래서 이름을 고치면 그 낱말을 쓰는 카드 글도 함께 고쳐야 한다 — 편집기가
	대신 해 주지는 않는다.
]]
local KIND_LABEL = {
	Buff = "버프",
	Debuff = "디버프",
	Status = "상태이상",
	Resource = "직업 자원",
	Neutral = "중립",
}
local keywordRows = {}
for _, keyword in Keywords.All() do
	table.insert(
		keywordRows,
		string.format(
			'<div class="kw"><span class="kind %s">%s</span><div class="skillgrid kwgrid">%s%s</div></div>',
			escape(keyword.Kind:lower()),
			escape(KIND_LABEL[keyword.Kind] or keyword.Kind),
			field("keywords", keyword.Id, "Name", "이름", keyword.Name, "line"),
			field("keywords", keyword.Id, "Description", "설명", keyword.Description, "text")
		)
	)
end
local keywordPanel = string.format(
	'<section class="panel"><h2>키워드 <small>%d개</small></h2>'
		.. '<p class="note">카드 글의 <b>[낱말]</b>이 아래 이름과 같아야 게임이 설명을 띄운다.</p>'
		.. '<div class="kws">%s</div></section>',
	#Keywords.All(),
	table.concat(keywordRows)
)



-- 문양 이름표. 태그 Id만으로는 무슨 그림인지 안 읽힌다.
local KEYWORD_FOR_TAG: { [string]: string } = {
	Guard = "방어", Aegis = "이지스", Ward = "결계", Plating = "도금", Endure = "인내",
	Vanguard = "선봉", Anchor = "닻", Taunt = "도발", Precision = "정밀", Execute = "처형",
	Riposte = "반격", Judgment = "심판", Solo = "독주", Burn = "화상", Rage = "분노",
	Frenzy = "광란", Catalyst = "촉매", Overload = "과부하", Blood = "피", Brink = "벼랑",
	Sacrifice = "희생", Volley = "연사", Mark = "표식", Spread = "확산", Charge = "충전",
	Faith = "기도력", Melody = "음표", Chorus = "합창", Tempo = "박자표", Chain = "사슬",
	Brew = "조합", Construct = "축조",
}

--=== 아이콘 ===--

--[[
	문양 32개의 도형을 그대로 실어 보낸다.

	편집기는 이 좌표로 미리보기를 다시 그리므로, 게임과 같은 숫자를 본다.
	좌표는 **메달리온에 넣기 전** 문양 자신의 0~1 공간이다 — 여기 적는 값이 곧
	`SHAPE_OVERRIDES`에 들어갈 값이어야 하기 때문이다.

	그림자(어두운 아래 겹)는 **목록에서 뺀다.** 본체를 옮기면 CardArt가 짝지어
	같이 옮기므로, 편집기에 둘 다 보이면 같은 획이 두 줄로 보여 헷갈린다.
]]
local SHADOW_HEX = "#120e1e"
local iconRows = {}
local iconData = {}

for _, tag in CardArt.Tags() do
	local white = Color3.fromRGB(255, 255, 255)
	local grey = Color3.fromRGB(178, 178, 178)
	local seed = 0
	local shapes = CardArt.Glyph(tag, white, grey, function(stream: number): number
		-- 편집기는 변주가 없는 **기준 모습**을 보여준다. 카드마다 다른 값은 여기서 의미가 없다.
		seed += stream
		return 0.5
	end)

	local rows = {}
	local json = {}
	for index, item in shapes do
		local isShadow = hex(item.Color) == SHADOW_HEX
		table.insert(
			json,
			string.format(
				'{"i":%d,"x":%s,"y":%s,"w":%s,"h":%s,"r":%s,"c":"%s","k":%s,"s":%s,"z":%d,"a":%s,"d":%s}',
				index,
				num(item.X),
				num(item.Y),
				num(item.W),
				num(item.H),
				num(item.Rotation),
				hex(item.Color),
				num(item.Corner),
				num(item.Stroke),
				item.ZIndex,
				num(1 - item.Transparency),
				if isShadow then "true" else "false"
			)
		)
		if not isShadow then
			table.insert(
				rows,
				string.format(
					'<div class="shp"><b>%d</b>%s%s%s%s%s</div>',
					index,
					field("icon", tag .. "#" .. index, "X", "X", num(item.X), "number"),
					field("icon", tag .. "#" .. index, "Y", "Y", num(item.Y), "number"),
					field("icon", tag .. "#" .. index, "W", "너비", num(item.W), "number"),
					field("icon", tag .. "#" .. index, "H", "높이", num(item.H), "number"),
					field("icon", tag .. "#" .. index, "Rotation", "회전", num(item.Rotation), "number")
				)
			)
		end
	end

	table.insert(iconData, string.format('"%s":[%s]', tag, table.concat(json, ",")))
	table.insert(
		iconRows,
		string.format(
			'<section class="panel icon" data-tag="%s"><h2>%s <small>%s</small></h2>'
				.. '<div class="iconbody"><svg class="prev" data-tag="%s" viewBox="0 0 200 200"></svg>'
				.. '<div class="shps">%s</div></div></section>',
			escape(tag),
			escape(tag),
			escape(KEYWORD_FOR_TAG[tag] or ""),
			escape(tag),
			table.concat(rows)
		)
	)
end

local iconPanel = string.format(
	'<p class="note">숫자를 고치면 미리보기가 바로 바뀐다. 그림자 겹은 목록에 없다 — 본체를 옮기면 따라온다.</p>%s',
	table.concat(iconRows)
)
local iconJson = "{" .. table.concat(iconData, ",") .. "}"

--[[
	키워드 사전을 편집기로 보낸다.

	카드 글의 `[낱말]`을 그 키워드 색으로 칠하고, 수치를 붙일 수 있는 낱말이면
	옆에 레벨·% 입력을 띄우는 데 쓴다.
]]
local keywordJson = {}
for _, keyword in Keywords.All() do
	table.insert(
		keywordJson,
		string.format(
			'{"id":%s,"name":%s,"color":%s,"unit":%s,"kind":%s,"scalable":%s}',
			jsonText(keyword.Id),
			jsonText(keyword.Name),
			jsonText(keyword.Color),
			jsonText(keyword.Unit),
			jsonText(keyword.Kind),
			if keyword.Scalable then "true" else "false"
		)
	)
end

-- 자동 감싸기가 알아볼 스킬 이름. 백틱으로 감싼다.
local skillNameJson = {}
do
	local seen: { [string]: boolean } = {}
	local function add(skill)
		if not seen[skill.Name] then
			seen[skill.Name] = true
			table.insert(skillNameJson, jsonText(skill.Name))
		end
	end
	for _, class in CLASSES do
		for _, skill in BattleSkills.ForClass(class.Id) do
			add(skill)
		end
	end
	for _, skill in BattleSkills.Upgrades() do
		add(skill)
	end
	for _, skill in BattleSkills.Common() do
		add(skill)
	end
end

--[[
	그림 탭이 쓸 것들.

	  템플릿  등급마다 하나. 빈 화면에서 시작하지 않게 한다.
	  카드    어떤 카드에 그림을 붙일지 고르는 목록.
	  그림    이미 저장된 것.
]]
local function shapeJson(item): string
	return string.format(
		'{"x":%s,"y":%s,"w":%s,"h":%s,"r":%s,"c":%s,"k":%s,"s":%s,"z":%d,"t":%s}',
		num(item.X),
		num(item.Y),
		num(item.W),
		num(item.H),
		num(item.Rotation),
		jsonText(item.Color),
		num(item.Corner),
		num(item.Stroke),
		item.ZIndex,
		num(item.Transparency)
	)
end

local templateJson = {}
for _, grade in { "Essential", "Rare", "Common" } do
	local parts = {}
	for _, item in CardArtworks.Template(grade) do
		table.insert(parts, shapeJson(item))
	end
	table.insert(templateJson, string.format("%s:[%s]", jsonText(grade), table.concat(parts, ",")))
end

local artworkJson = {}
for _, artwork in CardArtworks.All() do
	local parts = {}
	for _, item in artwork.Shapes do
		table.insert(parts, shapeJson(item))
	end
	table.insert(
		artworkJson,
		string.format(
			'%s:{"name":%s,"shapes":[%s]}',
			jsonText(artwork.Id),
			jsonText(artwork.Name),
			table.concat(parts, ",")
		)
	)
end

local cardListJson = {}
for _, class in CLASSES do
	for _, grade in { "Essential", "Rare", "Common" } do
		for _, card in AbilityCardDefinitions.GetPool(class.Id, grade) do
			table.insert(
				cardListJson,
				string.format(
					'{"id":%s,"name":%s,"grade":%s,"class":%s,"art":%s}',
					jsonText(card.Id),
					jsonText(card.Name),
					jsonText(grade),
					jsonText(class.Name),
					jsonText(card.Art or "")
				)
			)
		end
	end
end

--=== HTML ===--

local classChips = { '<button class="chip on" data-class="all">전체</button>' }
for _, class in CLASSES do
	table.insert(classChips, string.format('<button class="chip" data-class="%s">%s</button>', class.Id, class.Name))
end

local gradeChips = { '<button class="chip on" data-grade="all">모든 등급</button>' }
for _, grade in { "Essential", "Rare", "Common" } do
	table.insert(gradeChips, string.format('<button class="chip" data-grade="%s">%s</button>', grade, GRADE_LABEL[grade]))
end

local html = [[<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>게임 설정 편집기 — De profundis</title>
<style>
:root { color-scheme: dark; }
* { box-sizing: border-box; }
body { margin: 0; background: #14141a; color: #e8e8ef;
       font: 12px/1.45 "Pretendard", "Malgun Gothic", system-ui, sans-serif; }
header.top { position: sticky; top: 0; z-index: 5; padding: 12px 20px 10px;
             background: rgba(20,20,26,.96); backdrop-filter: blur(8px);
             border-bottom: 1px solid #2a2a35; }
header.top h1 { margin: 0 0 9px; font-size: 16px; }
header.top h1 small { font-weight: 400; color: #8b8b9c; margin-left: 8px; font-size: 12px; }
.bar { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; margin-bottom: 6px; }
.chip { border: 1px solid #33333f; background: #1d1d25; color: #b9b9c8;
        border-radius: 999px; padding: 5px 12px; font-size: 12px; cursor: pointer; }
.chip:hover { border-color: #4a4a5c; color: #e8e8ef; }
.chip.on { background: #2f5fd0; border-color: #2f5fd0; color: #fff; }
.chip.act { background: #1d3a24; border-color: #2f6b3c; color: #a7e0b6; }
.chip.act:hover { background: #245030; color: #d6f5df; }
#q { flex: 1; min-width: 180px; border: 1px solid #33333f; background: #1d1d25;
     color: #e8e8ef; border-radius: 8px; padding: 6px 10px; font-size: 12px; }
#dirty { font-size: 12px; color: #8b8b9c; margin-left: 4px; }
#dirty.some { color: #e0c07a; }
main { padding: 14px 16px 70px; }
.tabhide { display: none !important; }
.klass h2 { font-size: 15px; margin: 24px 0 10px; color: #cfcfe0; }
.klass h2 small { color: #7d7d8e; font-weight: 400; margin-left: 6px; }
.klass h3 { font-size: 12px; margin: 16px 0 8px; color: #8b8b9c;
            text-transform: uppercase; letter-spacing: .05em; }
.grid { display: grid; gap: 12px;
        grid-template-columns: repeat(auto-fill, minmax(224px, 1fr)); }
.card { background: #1b1b23; border: 1px solid #2c2c38; border-radius: 12px;
        overflow: hidden; display: flex; flex-direction: column; }
.card.essential { border-color: #7a4bb8; }
.card.rare { border-color: #3a63b8; }
.card.dirty { border-color: #d0a24a; }
.card .art { line-height: 0; position: relative; }
.card svg { width: 100%; height: auto; display: block; }
/*
  카드 오른쪽 위 그림 고르기 단추(요청). 그림 위에 얹으므로 눈에 띄되 글자를
  가리지 않게 자리는 구석, 배경은 반투명으로 뒀다.
*/
.artpick { position: absolute; top: 6px; right: 6px; width: 26px; height: 26px;
  border-radius: 999px; border: 1px solid rgba(255,255,255,.35);
  background: rgba(20,20,26,.65); color: #fff; font-size: 13px; line-height: 1;
  cursor: pointer; display: flex; align-items: center; justify-content: center; }
.artpick:hover { background: rgba(20,20,26,.9); }
#artPickModal { position: fixed; inset: 0; background: rgba(8,8,12,.6);
  display: none; align-items: center; justify-content: center; z-index: 50; }
#artPickModal.open { display: flex; }
#artPickSheet { background: #16161d; border: 1px solid #2c2c38; border-radius: 12px;
  width: min(560px, 92vw); max-height: 80vh; display: flex; flex-direction: column; }
#artPickSheet header { display: flex; align-items: center; justify-content: space-between;
  padding: 12px 14px; border-bottom: 1px solid #2c2c38; }
#artPickList { padding: 10px; overflow-y: auto; display: grid;
  grid-template-columns: repeat(auto-fill, minmax(96px, 1fr)); gap: 8px; }
.artpick-item { border: 1px solid #2c2c38; border-radius: 8px; background: #1b1b23;
  cursor: pointer; padding: 6px; text-align: center; }
.artpick-item:hover { border-color: #2f5fd0; }
.artpick-item svg { width: 100%; height: auto; border-radius: 6px; display: block; }
.artpick-item span { display: block; font-size: 10px; color: #cfcfe0; margin-top: 4px;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.artpick-none { grid-column: 1 / -1; font-size: 11px; color: #8b8b9c; }
.card .body { padding: 8px 9px 9px; display: flex; flex-direction: column; gap: 7px; flex: 1; }
.card .row { display: flex; align-items: flex-start; gap: 8px; }
.card .row .fld { flex: 1; }
.grade { font-size: 10px; padding: 3px 6px; border-radius: 4px; margin-top: 15px;
         background: #4e5058; color: #fff; flex: none; }
.essential .grade { background: #60349a; }
.rare .grade { background: #264a96; }
.panel { background: #1b1b23; border: 1px solid #2c2c38; border-radius: 12px;
         padding: 4px 16px 18px; margin-bottom: 14px; }
.fields { display: grid; gap: 8px; grid-template-columns: repeat(auto-fit, minmax(168px, 1fr)); }
.skills { display: grid; gap: 9px; }
.skill { display: grid; gap: 9px; align-items: start; border: 1px solid #2c2c38;
         border-radius: 9px; padding: 10px 12px; grid-template-columns: 58px 1fr; }
.skillgrid { display: grid; gap: 8px; grid-column: 2;
             grid-template-columns: minmax(96px,1.2fr) 68px 84px 74px 140px; }
.skill > .fld { grid-column: 2; }
select.f { appearance: none; cursor: pointer;
           background-image: linear-gradient(45deg, transparent 50%, #7d7d8e 50%),
                             linear-gradient(135deg, #7d7d8e 50%, transparent 50%);
           background-position: calc(100% - 13px) 12px, calc(100% - 8px) 12px;
           background-size: 5px 5px, 5px 5px; background-repeat: no-repeat; padding-right: 22px; }
.skill b { font-size: 12px; color: #8b8b9c; padding-bottom: 7px; }
.fld { display: flex; flex-direction: column; gap: 3px; }
.fld > span { font-size: 10px; color: #7d7d8e; }
.f { width: 100%; border: 1px solid #33333f; background: #16161d; color: #e8e8ef;
     border-radius: 6px; padding: 5px 7px; font: inherit; font-size: 12px; }
textarea.f { resize: none; min-height: 58px; line-height: 1.45; overflow: hidden; }
.f:focus { outline: none; border-color: #2f5fd0; }
.f.chg { border-color: #d0a24a; background: #221d14; }
/*
  숫자 칸의 위아래 화살표를 뺀다(요청) — 칸이 좁아서 화살표가 숫자를 밀어내
  글자가 잘려 보였다. 자리표시자 값이 화살표를 누를 때만 필요했지, 타이핑은
  화살표 없이도 그대로 된다.
*/
input[type="number"]::-webkit-outer-spin-button,
input[type="number"]::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
input[type="number"] { -moz-appearance: textfield; appearance: textfield; }
.lvprev-wrap { border: 1px dashed #33333f; border-radius: 8px; padding: 7px 8px;
               display: flex; flex-direction: column; gap: 7px; }
.lvprev-wrap .fld { flex-direction: row; align-items: center; gap: 6px; }
.lvprev-wrap .fld > span { flex: none; }
.lvprev-wrap .fld.narrow { width: auto; }
.lvprev-wrap select.cardlv { width: auto; flex: none; padding: 3px 20px 3px 7px; font-size: 11px; }
.lvprev-wrap input.f { width: 56px; flex: none; }
.lvprev-details summary { cursor: pointer; font-size: 11px; color: #8b8b9c; list-style: none; }
.lvprev-details summary::-webkit-details-marker { display: none; }
.lvprev-details summary::before { content: "▸ "; }
.lvprev-details[open] summary::before { content: "▾ "; }
.lvprev-details[open] summary { margin-bottom: 6px; }
.lvprev { font-size: 11px; line-height: 1.5; color: #cfcfe0; margin-top: 6px; white-space: pre-wrap; }
.ladders { display: grid; gap: 5px; }
.ladder { display: flex; align-items: center; gap: 4px; }
.ladder b { font-size: 10px; color: #7d7d8e; width: 22px; flex: none; }
.lv { width: 100%; min-width: 0; border: 1px solid #33333f; background: #16161d;
      color: #e8e8ef; border-radius: 5px; padding: 3px 2px; font: inherit;
      font-size: 11px; text-align: center; }
.lv:focus { outline: none; border-color: #2f5fd0; }
.lv.chg { border-color: #d0a24a; background: #221d14; }
footer { display: flex; flex-wrap: wrap; gap: 5px; align-items: center; margin-top: auto; }
.tag { font-style: normal; font-size: 10px; color: #8e8ea2;
       border: 1px solid #34343f; border-radius: 4px; padding: 1px 5px; }
.wire { margin-left: auto; font-size: 10px; padding: 2px 6px; border-radius: 4px; }
.wire.yes { background: #1d4a2b; color: #8fe0a6; }
.wire.no { background: #3a2020; color: #d09a9a; }
.pick { border: 1px solid #33333f; background: #1d1d25; color: #b9b9c8;
        border-radius: 6px; padding: 5px 7px; font: inherit; font-size: 11px; cursor: pointer; }
.pick:hover { border-color: #4a4a5c; color: #e8e8ef; }
.pick.set { border-color: #2f6b3c; background: #1d3a24; color: #a7e0b6; }
#modal { position: fixed; inset: 0; z-index: 20; background: rgba(8,8,12,.72);
         display: none; align-items: center; justify-content: center; }
#modal.on { display: flex; }
/*
  범위 창은 **크기가 변해도 자리가 안 움직인다** (요청).
  좌표 줄이 길어지면 오른쪽으로 늘어나는 대신 아래로 접힌다.
*/
#sheet { background: #1b1b23; border: 1px solid #33333f; border-radius: 12px;
         padding: 16px 18px; width: 560px; max-width: 92vw; }
#mout { min-height: 34px; max-height: 132px; overflow-y: auto;
        display: flex; flex-wrap: wrap; gap: 4px 8px; align-items: flex-start;
        border: 1px solid #2c2c38; border-radius: 8px; padding: 7px 9px; }
#mout .co { color: #cfcfe0; white-space: nowrap; }
#sheet h4 { margin: 0 0 3px; font-size: 14px; }
#sheet .hint { color: #8b8b9c; font-size: 11px; margin-bottom: 11px; }
.board { display: flex; align-items: center; gap: 12px; margin-bottom: 11px; }
.side { display: grid; grid-template-columns: repeat(6, 30px); gap: 3px; }
.side .cap { grid-column: 1 / -1; font-size: 10px; color: #7d7d8e; margin-bottom: 1px; }
/*
  좌표 숫자가 드래그 중에 텍스트로 잡혀 파랗게 반전되지 않도록(요청) 이 칸
  전체를 선택 대상에서 뺀다. 격자 칠하기·말 옮기기 둘 다 마우스를 누른 채
  여러 칸을 지나가므로, 이게 없으면 드래그할 때마다 숫자가 하이라이트된다.
*/
.cell { width: 30px; height: 30px; border: 1px solid #33333f; background: #16161d;
        border-radius: 4px; cursor: pointer; font-size: 9px; color: #4e4e5c;
        display: flex; align-items: center; justify-content: center; touch-action: none;
        user-select: none; -webkit-user-select: none; }
.cell:hover { border-color: #4a4a5c; }
.cell.me { background: #1d3a24; border-color: #2f6b3c; color: #a7e0b6; cursor: grab; }
.cell.foe { background: #4a1f1f; border-color: #8c3b3b; color: #ffb9b9; cursor: grab; }
.cell.hit { background: #2f5fd0; border-color: #4b7bea; color: #fff; }
.cell.foe.hit { background: #7a2f5a; border-color: #b8508c; }
.cell.dragover { outline: 2px dashed #ffd166; outline-offset: -2px; }
.divider { width: 2px; align-self: stretch; background: #3a3a48; border-radius: 1px; }
.allytoggle { display: flex; align-items: center; gap: 6px; font-size: 11px; color: #b9b9c8;
              margin-bottom: 11px; cursor: pointer; }
#mpurpose { background: #1d1d25; color: #b9b9c8; border: 1px solid #33333f; border-radius: 6px;
            padding: 4px 8px; font-size: 11px; cursor: pointer; }
.side.active { outline: 1px dashed #4a4a5c; outline-offset: 4px; border-radius: 4px; }
.stagechip { border: 1px solid #33333f; background: #1d1d25; color: #b9b9c8; border-radius: 6px;
             padding: 4px 9px; font-size: 11px; cursor: pointer; }
.stagechip.on { border-color: #e8e8ef; color: #fff; }
.stagechip .swatch { display: inline-block; width: 9px; height: 9px; border-radius: 50%;
                      margin-right: 5px; vertical-align: -1px; }
.kws { display: grid; gap: 8px; }
.kw { display: grid; grid-template-columns: 68px 1fr; gap: 9px; align-items: start;
      border: 1px solid #2c2c38; border-radius: 9px; padding: 9px 11px; }
.kwgrid { grid-template-columns: minmax(120px,1fr) minmax(200px,2fr) !important; }
.kind { font-size: 10px; padding: 3px 5px; border-radius: 4px; text-align: center;
        background: #33333f; color: #b9b9c8; margin-top: 13px; }
.kind.buff { background: #1d3a24; color: #a7e0b6; }
.kind.debuff { background: #3a2020; color: #d09a9a; }
.kind.status { background: #3a3320; color: #ddc48a; }
.kind.resource { background: #202b3a; color: #9ec0e0; }
.kind.neutral { background: #2c2c38; color: #b8b8c8; }
.note { color: #8b8b9c; font-size: 11px; margin: 0 0 10px; }
.statrow { display: flex; align-items: center; gap: 9px; border: 1px solid #2c2c38;
           border-radius: 9px; padding: 7px 10px; margin-bottom: 6px; font-size: 11px; }
.statrow .sdesc { flex: 1; color: #b6b6c6; white-space: pre-wrap; }
.statrow .kind { margin-top: 0; min-width: 68px; }
.pasgrid { grid-template-columns: minmax(120px,1fr) minmax(240px,3fr) !important; }
.icon h2 small { color: #7d7d8e; font-weight: 400; }
.iconbody { display: grid; grid-template-columns: 150px 1fr; gap: 14px; align-items: start; }
svg.prev { width: 150px; height: 150px; border-radius: 12px; display: block; }
.shps { display: grid; gap: 6px; }
.shp { display: grid; grid-template-columns: 26px repeat(5, 1fr); gap: 6px; align-items: end; }
.shp b { font-size: 10px; color: #7d7d8e; padding-bottom: 6px; text-align: right; }
#live { font-size: 11px; color: #7d7d8e; margin-left: 6px; }
#live b { color: #a7e0b6; font-weight: 600; }
#live a { color: #7d7d8e; text-decoration: none; border-bottom: 1px dotted #4a4a5c; }
#live a:hover { color: #b9b9c8; }
#live.off b { color: #d09a9a; }
#live .why { color: #d09a9a; }
.f.mine { animation: none; }
.f.theirs { animation: theirs 1.4s ease-out; }
@keyframes theirs { 0% { border-color: #4b7bea; background: #17233d; } 100% {} }
.zoom { display: flex; align-items: center; gap: 5px; font-size: 11px; color: #8b8b9c; }
.zoom input { width: 96px; }
.zoom b { color: #b9b9c8; font-weight: 600; min-width: 32px; }
#drawer { position: fixed; top: 0; right: 0; width: 380px; max-width: 92vw; height: 100vh;
          background: #16161d; border-left: 1px solid #2c2c38; z-index: 30;
          transform: translateX(100%); transition: transform .18s ease; overflow: auto; padding: 14px; }
#drawer.on { transform: none; }
.dhead { display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px; }
.dhead b { font-size: 14px; }
.hrow { border: 1px solid #2c2c38; border-radius: 8px; padding: 8px 10px; margin-bottom: 6px; font-size: 11px; }
.hrow .top { display: flex; justify-content: space-between; gap: 8px; color: #8b8b9c; }
.hrow .who { color: #a7e0b6; }
.hrow .what { color: #e8e8ef; margin: 3px 0; word-break: break-all; }
.hrow .val { color: #b9b9c8; }
.hrow .val s { color: #7d6a6a; }
.hrow button { margin-top: 5px; }
.snaprow { display: flex; align-items: center; gap: 8px; border: 1px solid #2c2c38;
           border-radius: 8px; padding: 8px 10px; margin-bottom: 6px; font-size: 11px; }
.snaprow span { flex: 1; }
.snaprow small { color: #7d7d8e; }
/*
  설명 칸: 색칠한 글 위에 투명 textarea. 두 층의 글자 모양이 **완전히 같아야**
  글자가 어긋나 보이지 않는다 — 글꼴·크기·자간·여백·줄높이를 전부 맞춘다.
*/
.hl { position: relative; }
.hlback, .hltext {
  font: inherit; font-size: 12px; line-height: 1.45; letter-spacing: normal;
  padding: 5px 7px; border: 1px solid transparent; border-radius: 6px;
  white-space: pre-wrap; word-break: break-word; margin: 0;
}
/*
  **글 칸은 늘·줄어들지 스크롤은 안 한다** (요청: "줄바꿈 인식해서 칸이
  커지거나 작아지게, 스크롤 막대는 없애줘").

  칸 높이를 글 내용에 맞춰 JS가 매번 다시 잰다(`autoGrowTextarea`) — 그래서
  textarea 자체엔 세로 스크롤바가 뜰 일이 없다. `overflow: hidden`으로
  혹시 모를 한순간(칠하기 전)의 스크롤바 깜빡임도 막는다. 스크롤바가 없으니
  두 층(뒤 칠판·textarea)의 폭도 항상 같아 예전에 필요했던
  `scrollbar-gutter: stable`은 이제 필요 없다.
*/
.hlback { position: absolute; inset: 0; overflow: hidden; color: #e8e8ef;
          background: #16161d; border-color: #33333f; pointer-events: none; }
/*
  display: block 이어야 한다. textarea 는 기본이 inline-block 이라 글꼴
  베이스라인 아래로 4px 여백이 생기고, 그만큼 .hl 이 textarea 보다 커져
  뒤 층이 아래로 밀린다.
*/
.hltext { position: relative; display: block; background: transparent; color: transparent;
          caret-color: #e8e8ef; resize: none; min-height: 58px; width: 100%;
          overflow: hidden; }
.hltext:focus { outline: none; }
/*
  위층 textarea 는 **어떤 상태에서도 배경과 테두리가 없어야** 한다.

  .f 와 .f.chg 는 보통 칸을 위한 규칙이라 배경색을 칠하는데, 그게 여기서는
  아래 색칠 층을 통째로 덮는다. 수정한 칸이 노랗게 가려지던 것이 이것이었다.
  선택자에 요소 이름을 더해 우선순위로 눌러 둔다 — 규칙 순서에 기대지 않으려는 것이다.
  칠은 전부 뒤층(.hlback)이 맡는다.
*/
.hl textarea.hltext { background: transparent; border-color: transparent; }
.hl:focus-within .hlback { border-color: #2f5fd0; }
.hl:has(.hltext.chg) .hlback { border-color: #d0a24a; background: #221d14; }
/*
  낱말 하이라이트는 **.kwmark** 다. `.kw` 로 두면 키워드 사전 탭의 행(.kw)이
  쓰는 display:grid 를 물려받아 낱말이 블록이 되고 혼자 한 줄을 차지한다.
  실제로 그 버그를 밟았다 — 글이 두 번 찍힌 것처럼 보였다.
*/
/*
  하이라이트는 **글자 폭을 건드리지 않는 것만** 쓴다.
  padding 과 font-weight 는 글자를 넓혀서, 그 뒤 글자가 위층의 커서와 어긋난다.
  실제로 4px 밀렸다. 색과 배경만으로 충분히 눈에 띈다.
*/
.hlback .kwmark { border-radius: 3px; }
.hlback .kwmark.bad { color: #d09a9a; text-decoration: underline wavy #8c3b3b; }

/* 글 아래 붙는 키워드 줄. 낱말마다 레벨과 %를 여기서 정한다. */
/*
  칩 줄은 **카드 폭 안에 들어가야 한다** (요청: 크기가 크다).
  카드 한 장이 224px이라 슬롯 칩 하나가 그보다 넓으면 줄이 통째로 삐져나온다.
  글자와 칸을 한 급 줄이고 여백을 조인다.
*/
.kwbar { display: flex; flex-wrap: wrap; gap: 3px; margin-top: 4px; }
/*
  칸을 아무리 줄여도 글꼴·언어에 따라 넘칠 수 있다. 넘치면 **칩 안에서 접히게**
  둔다 — 카드 밖으로 삐져나가 옆 카드를 밀어내는 것보다 낫다.
*/
.kwchip { display: flex; align-items: center; gap: 2px; font-size: 9px; max-width: 100%;
          flex-wrap: wrap; border: 1px solid #33333f; border-radius: 999px;
          padding: 1px 3px 1px 6px; }
.kwchip .nm { font-weight: 600; }
.kwchip select, .kwchip input { border: 1px solid #33333f; background: #16161d;
  color: #e8e8ef; border-radius: 999px; font: inherit; font-size: 9px; padding: 1px 2px; }
.kwchip select { width: 30px; }
.kwchip input { width: 34px; text-align: center; }
.kwchip .un { color: #7d7d8e; }
.kwchip.flat { opacity: .65; }
.kwchip.slot { padding-left: 4px; width: 100%; box-sizing: border-box; }
.kwchip.slot select.kwlv, .kwchip.slot input.kwval { flex: 1; width: auto; min-width: 0; }
.kwchip .brace { font-weight: 700; font-size: 9px; }
.drawbody { display: grid; grid-template-columns: 320px 1fr; gap: 18px; align-items: start; }
#canvas { width: 320px; height: 320px; border-radius: 14px; display: block;
          background: #264a96; cursor: crosshair; touch-action: none; }
#canvas rect { cursor: move; }
#canvas rect.sel { outline: none; }
#shapeProps { display: grid; gap: 8px; grid-template-columns: repeat(auto-fit, minmax(88px, 1fr)); }
#artUsers { margin-top: 8px; }
#artUsers b { color: #b9b9c8; }
/*
  요청 정정: "내가 반투명하게 만들라 한 건 이 네모였는데"(선택 상자 점선
  사각형을 가리킴) — 처음엔 "불투명"으로 읽어 채움·굵기를 더 진하게
  만들었는데, 실제로는 거꾸로 **더 옅게, 반투명하게** 만들어 달라는
  뜻이었다. `opacity`를 걸어 테두리·채움을 통째로 옅게 낮췄다.
*/
.selbox { fill: rgba(255, 209, 102, 0.14); stroke: #ffd166; stroke-width: 2; stroke-dasharray: 4 3; pointer-events: none; opacity: 0.6; }
/* 크기·회전 손잡이(요청: 마우스로 조작). 커서 모양만 대략적인 방향을 알려준다 — 도형이 돌아간 채면 완전히 맞진 않지만 방향 감은 준다. */
.handle { fill: #ffd166; stroke: #1b1b23; stroke-width: 1; }
.handle.corner.tl, .handle.corner.br { cursor: nwse-resize; }
.handle.corner.tr, .handle.corner.bl { cursor: nesw-resize; }
.handle.rotate { cursor: grab; }
.handle-line { stroke: #ffd166; stroke-width: 1; pointer-events: none; }
.hidden { display: none !important; }
</style></head><body>
<header class="top">
<h1>게임 설정 편집기<small>]] .. string.format("카드 %d장 · 전투 반영 %d장", totalCards, wiredCards) .. [[</small></h1>
<div class="bar" id="tabBar">
<button class="chip on" data-tab="cards">카드</button>
<button class="chip" data-tab="classes">직업 · 능력</button>
<button class="chip" data-tab="keywords">키워드</button>
<button class="chip" data-tab="icons">아이콘</button>
<button class="chip" data-tab="draw">그림 그리기</button>
</div>
<div class="bar" id="classBar">]] .. table.concat(classChips) .. [[</div>
<div class="bar" id="gradeBar">]] .. table.concat(gradeChips) .. [[
<input id="q" type="search" placeholder="이름·설명·태그 검색"></div>
<div class="bar">
<button class="chip" id="onlyDirty">수정한 것만</button>
<button class="chip act" id="save">수정본 내려받기</button>
<button class="chip" id="load">수정본 불러오기</button>
<button class="chip" id="revert">전부 되돌리기</button>
<input id="file" type="file" accept="application/json" hidden>
<span id="dirty">수정 없음</span>
<span id="live"></span>
<label class="zoom">확대 <input id="zoom" type="range" min="60" max="180" step="5" value="100"><b id="zoomv">100%</b></label>
<button class="chip" id="histBtn">변경 이력</button>
<button class="chip" id="snapBtn">스냅샷</button>
</div>
</header>
<main>
<div id="tab-cards">]] .. table.concat(cardSections) .. [[</div>
<div id="tab-classes" class="tabhide">]] .. table.concat(classPanels) .. [[</div>
<div id="tab-keywords" class="tabhide">]] .. keywordPanel .. [[</div>
<div id="tab-icons" class="tabhide">]] .. iconPanel .. [[</div>
<div id="tab-draw" class="tabhide"><section class="panel">
<h2>그림 그리기 <small>도형을 끌어다 놓고 저장한다</small></h2>
<div class="bar">
<label class="fld"><span>그림 이름</span><input class="f" id="artName" value="새 그림"></label>
<label class="fld"><span>미리보기 등급</span><select class="f" id="artGrade">
<option value="Essential">필수</option><option value="Rare" selected>희귀</option><option value="Common">일반</option>
</select></label>
<button class="chip" id="artTemplate">이 등급 템플릿으로 시작</button>
<button class="chip act" id="artSave">그림 저장</button>
<select class="f" id="artOpen" style="width:150px"><option value="">저장된 그림 열기…</option></select>
</div>
<div class="drawbody">
<div>
<svg id="canvas" viewBox="0 0 200 200"></svg>
<p class="note" id="drawHint">도형을 끌어 옮긴다. 클릭하면 골라진다.</p>
<!--
  트레이싱용 배경 사진(요청: "사진같은거 반투명하게 넣어서 트레이싱같은거
  할 수 있게"). `art.shapes`가 아니라 그 자신만의 변수(`traceImage`)에
  산다 — 저장(`artSave`)은 `art.shapes`만 보내므로, 여기 안 담기는 이상
  저장된 그림·게임 어디에도 절대 실리지 않는다(요청: "넣은 사진은 반영
  안 되게"). 새로고침하면 사라진다 — 파일을 큰 데이터 URL로 저장소에
  남기지 않으려는 것이다(사진 하나가 몇 MB씩이라 다른 저장 데이터를
  밀어낼 수 있다).
-->
<div class="bar">
<label class="fld"><span>배경 사진(트레이싱용)</span><input type="file" id="traceFile" accept="image/*"></label>
<label class="fld narrow"><span>사진 투명도</span><input type="range" id="traceOpacity" min="5" max="95" value="35"></label>
<label class="fld narrow"><span>사진 크기</span><input type="range" id="traceScale" min="20" max="400" value="100"></label>
<button class="chip" id="traceClear">사진 지우기</button>
</div>
</div>
<div>
<h3>도형 넣기</h3>
<div class="bar" id="palette">
<button class="chip" data-add="rect">사각형</button>
<button class="chip" data-add="circle">원</button>
<button class="chip" data-add="bar">막대</button>
<button class="chip" data-add="diamond">마름모</button>
<button class="chip" data-add="triangle" title="Shape는 항상 둥근 사각형 하나라 진짜 삼각형은 못 그린다 — 얇은 막대 세 개로 테두리만 흉내 낸다. 셋 다 진짜 도형이라 게임에도 그대로 나간다.">삼각형(테두리)</button>
<button class="chip" data-add="rectline">속이 빈 사각형</button>
<button class="chip" data-add="ring">속이 빈 원(링)</button>
<button class="chip" data-add="barline">속이 빈 막대</button>
<button class="chip" data-add="diamondline">속이 빈 마름모</button>
</div>
<h3>고른 도형</h3>
<div id="shapeProps"><p class="note">도형을 고르세요.</p></div>
<h3>이 그림을 쓸 카드</h3>
<div class="bar">
<select class="f" id="artClassPick" style="width:120px"></select>
<select class="f" id="artGradePick" style="width:90px">
<option value="Essential">필수</option><option value="Rare">희귀</option><option value="Common">일반</option>
</select>
<select class="f" id="artCardPick" style="flex:1"></select>
<button class="chip act" id="artAssign">이 카드에 넣기</button>
</div>
<div id="artUsers" class="note"></div>
</div>
</div>
</section></div>
<script type="application/json" id="glyphs">]] .. iconJson .. [[</script>
<script type="application/json" id="keywords">[]] .. table.concat(keywordJson, ",") .. [[]</script>
<script type="application/json" id="skillnames">[]] .. table.concat(skillNameJson, ",") .. [[]</script>
<script type="application/json" id="templates">{]] .. table.concat(templateJson, ",") .. [[}</script>
<script type="application/json" id="artworks">{]] .. table.concat(artworkJson, ",") .. [[}</script>
<script type="application/json" id="cardlist">[]] .. table.concat(cardListJson, ",") .. [[]</script>
</main>
<!--
  `#modal`·`#drawer`는 `<main>`(id="zoomRoot") **밖**에 둔다 (요청: "묻지도
  따지지도 말고 화면 정중앙").

  확대·축소는 main에 CSS transform을 건다. transform이 걸린 조상은 그 안의
  position:fixed 자손에게 새 기준점이 된다 — 그러면 "화면 기준 고정"이 아니라
  "그 조상 기준 고정"이 되어, 확대 배율이나 main의 스크롤 위치에 따라 창이
  화면 중앙을 벗어나 버린다(요청한 버그가 이것이었다). main 밖에 두면 이 문제
  자체가 생기지 않는다.
-->
<div id="modal"><div id="sheet">
<h4 id="mtitle">범위 지정</h4>
<div class="hint">각 진영의 <b>왼쪽 아래가 (0,0)</b>. 붉은 칸이 기준점 (n,n)이고, 범위는 거기서의 상대 좌표로 저장된다.<br>
칠할 수 있는 진영의 빈 칸을 누르면 그 칸을 범위로 켜고 끄고, 누른 채 끌면 지나는 칸마다 켜지거나 꺼진다. <b>나·적 말은 끌어서 옮긴다.</b></div>
<label class="allytoggle"><input type="checkbox" id="mally"> 아군 진형에 스킬 사용 (버프·회복처럼 아군을 겨눈다)</label>
<div class="board">
<div class="side" id="myside"><span class="cap">내 진영</span></div>
<div class="divider"></div>
<div class="side" id="foeside"><span class="cap">적 진영</span></div>
</div>
<label class="allytoggle">색깔 있는 칸의 뜻:
<select id="mpurpose">
<option value="Grow">조건부로 늘어남 — 자원이 그 단계만큼 쌓이면 켜진다</option>
<option value="Motion">모션 단계 — 순서대로 따로 맞는다(예: 앞뒤관통)</option>
</select>
</label>
<div class="hint" id="mstagehint">
조건부로 늘어나는 범위가 있다면, 아래에서 단계를 고르고 그 색으로 칸을 찍는다 — 자원이 그 단계만큼 쌓이면 켜진다(요청: "색깔에 따라서 단계별 범위지정").
</div>
<div class="bar" id="stageBar"></div>
<div class="hint" id="mout">지정 없음</div>
<div class="bar">
<button class="chip act" id="mok">적용</button>
<button class="chip" id="mclear">범위 비우기</button>
<button class="chip" id="mcancel">취소</button>
</div>
</div></div>
<div id="artPickModal"><div id="artPickSheet">
<header><b>카드 그림 고르기</b><button class="chip" id="artPickClose">닫기</button></header>
<div id="artPickList"></div>
</div></div>
<aside id="drawer"><div class="dhead"><b id="dtitle">변경 이력</b><button class="chip" id="dclose">닫기</button></div>
<div id="dbody"></div></aside>
<!--
  Supabase JS는 CDN에서 받는다 — 이 페이지는 npm 빌드 과정이 없는 정적
  HTML 하나라, 번들러 없이 그대로 쓸 수 있는 것이 이 방식뿐이다.
-->
<!--
  `defer` — CDN이 느리거나 막혀도 편집기 자체(글 고치기·문법 강조 등)는
  기다리지 않고 바로 켜진다. 다 받아지면 아래 스크립트의 `__porcelainSupabaseReady`를
  불러 그때 클라우드에 붙는다(요청: "새로고침 했을 때 느린데").
-->
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"
        defer onload="window.__porcelainSupabaseReady && window.__porcelainSupabaseReady()"></script>
<script>
(function () {
  var STORE = "porcelain.configEdits.v2";
  var state = { tab: "cards", klass: "all", grade: "all", q: "", dirtyOnly: false };

  /*
    **anon key만 여기 산다.** RLS(행 단위 보안) 정책이 이 키로 할 수 있는 일을
    정하므로 브라우저에 실려도 된다 — 그게 이 키의 설계 목적이다. service_role
    key는 RLS를 통째로 건너뛰는 관리자 키라 정적 HTML에 절대 넣지 않는다.
    스키마·정책은 `supabase/schema.sql` 참고.
  */
  var SUPABASE_URL = "https://qynhcgineyysawgxfebq.supabase.co";
  var SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF5bmhjZ2luZXl5c2F3Z3hmZWJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEzODI2OTMsImV4cCI6MjA5Njk1ODY5M30.S98gSTEQEAHDoP4EZwMo15ci9Zn9ejd2FzgVbAKb7w4";
  /*
    Supabase JS를 `defer`로 받는 동안은 `sb`가 없다 — 편집기는 그래도 바로
    켜지고, 다 받아지면(또는 못 받으면) `tryConnectCloud`가 이어받는다.
  */
  var sb = null;
  /*
    편집 칸 목록은 **그때그때 훑는다.**

    한 번 담아 두면 나중에 만들어지는 칸(중괄호를 새로 감쌌을 때 생기는 사다리
    입력)이 목록에 없어 저장도 되돌리기도 안 된다. 306장이라도 querySelectorAll
    한 번은 눈에 띄지 않는다.
  */
  function fieldList() {
    return Array.prototype.slice.call(document.querySelectorAll(".f, .lv"));
  }

  //=== 변경 판정 ===//

  // 값은 문자열로만 비교한다. 숫자 칸은 "8"과 "8.0"이 달라 보이므로 한 번 정규화한다.
  function normal(el, raw) {
    var text = raw === undefined ? el.value : raw;
    if (el.type === "number") {
      if (text === "") return "";
      var value = parseFloat(text);
      return isNaN(value) ? text : String(value);
    }
    return text;
  }

  function changed(el) {
    return normal(el) !== normal(el, el.dataset.orig);
  }

  //=== 모으기 ===//

  // 바뀐 칸만 JSON으로 모은다. textarea는 값이 문자열이라 줄바꿈이 그대로 살아 있다.
  function collect() {
    var out = { version: 2, cards: {}, cardLevels: {}, classes: {}, classSkill: {}, skills: {} };
    fieldList().forEach(function (el) {
      if (!changed(el)) return;
      var scope = el.dataset.scope;
      var key = el.dataset.key;
      if (scope === "cardLevels") {
        var card = out.cardLevels[key] || (out.cardLevels[key] = {});
        var slot = card[el.dataset.slot] || (card[el.dataset.slot] = {});
        slot[el.dataset.level] = parseFloat(el.value);
        return;
      }
      var bucket = out[scope] || (out[scope] = {});
      var entry = bucket[key] || (bucket[key] = {});
      entry[el.dataset.field] = el.type === "number" ? parseFloat(el.value) : el.value;
    });
    Object.keys(out).forEach(function (scope) {
      if (scope !== "version" && Object.keys(out[scope]).length === 0) delete out[scope];
    });
    return out;
  }

  function ownerCard(el) {
    return el.closest(".card") || el.closest(".panel");
  }

  function refresh() {
    var count = 0;
    var dirtyOwners = new Set();
    fieldList().forEach(function (el) {
      var chg = changed(el);
      el.classList.toggle("chg", chg);
      if (chg) { count++; dirtyOwners.add(ownerCard(el)); }
    });
    document.querySelectorAll(".card, .panel").forEach(function (owner) {
      owner.classList.toggle("dirty", dirtyOwners.has(owner));
    });
    var label = document.getElementById("dirty");
    label.textContent = count === 0 ? "수정 없음" : count + "칸 수정됨";
    label.classList.toggle("some", count > 0);
    /*
      **언제나 이 컴퓨터에도 한 벌 남긴다** (요청: 따로 저장 안 해도 새로고침에
      살아 있게).

      예전에는 클라우드를 쓸 때(`LIVE`) 이 백업을 건너뛰었다. 그래서 클라우드가
      한 번 삐끗하면 — 인터넷이 끊겼거나 표가 없거나 — 그때까지 고친 것이
      새로고침과 함께 통째로 사라졌다. 백업은 이 브라우저 안에만 남고 공짜다.
    */
    try { localStorage.setItem(STORE, JSON.stringify(collect())); } catch (e) {}
    apply();
  }

  // 저장해 둔 수정본을 칸에 다시 씌운다.
  function restore(data) {
    if (!data) return;
    /*
      **두 번 씌운다.**

      슬롯 칸(사다리)은 글의 중괄호를 보고 그때그때 만들어진다. 한 번만 씌우면,
      불러온 글이 새로 만든 슬롯의 칸들은 아직 없어서 값이 갈 곳이 없다.
      씌우고 → 사다리 칸만 만들고(칠하기는 화면에 보일 때로 미룸) → 한 번 더
      씌운다. 마지막 `redrawAll()`은 지금 보이는 카드만 새 값으로 다시 칠한다 —
      안 보이는 카드는 사다리 칸에 이미 맞는 값이 들어가 있으니, 나중에 화면에
      들어올 때 그 값 그대로 칠해진다.
    */
    assign(data);
    ensureAllLadders();
    assign(data);
    mergeArtworksFromData(data);
    redrawAll();
    refresh();
  }

  /*
    **클라우드가 들고 있는 그림도 이 브라우저의 `ARTWORKS`에 합친다** (요청한
    버그: "그림 그리기 후 이미지가 카드에 입력되지 않아"의 진짜 뿌리).

    그림을 저장하면 `artworks` scope로 클라우드에 올라가지만, 그 값을 다시
    읽어 `ARTWORKS`(그림 목록·카드 썸네일이 보는 곳)에 채워 넣는 자리가
    없었다 — 그린 사람의 그 브라우저에만 살아 있고, 남이 새로고침하면(또는
    그 카드를 처음 보면) 그림이 사라진 것처럼 보였다.
  */
  function mergeArtworksFromData(data) {
    if (!data || !data.artworks || typeof ARTWORKS === "undefined") return;
    Object.keys(data.artworks).forEach(function (id) {
      var entry = data.artworks[id];
      var body = entry && entry.Body;
      if (typeof body !== "string") return;
      try {
        var parsed = JSON.parse(body);
        if (parsed && typeof parsed.name === "string" && Array.isArray(parsed.shapes)) {
          ARTWORKS[id] = parsed;
        }
      } catch (e) {}
    });
    if (typeof fillArtList === "function") fillArtList();
  }

  /*
    불러온 JSON은 **손으로 고쳤을 수도, 옛 형식일 수도** 있다. 모양이 어긋난
    자리는 조용히 건너뛴다 — 한 칸이 이상하다고 나머지 수백 칸까지 못 씌우면
    안 된다.
  */
  function assign(data) {
    if (!data || typeof data !== "object") return;
    fieldList().forEach(function (el) {
      try {
        var scope = el.dataset.scope;
        var key = el.dataset.key;
        if (!scope || !key) return;
        var bucket = data[scope];
        if (!bucket || typeof bucket !== "object") return;
        if (scope === "cardLevels") {
          var card = bucket[key];
          if (!card || typeof card !== "object") return;
          var slot = card[el.dataset.slot];
          if (!slot || typeof slot !== "object") return;
          var value = slot[el.dataset.level];
          if (value !== undefined && value !== null) el.value = value;
          return;
        }
        var entry = bucket[key];
        if (!entry || typeof entry !== "object") return;
        var next = entry[el.dataset.field];
        if (next === undefined || next === null) return;
        /*
          **설명 칸을 빈 글로 지우지 않는다** (요청한 버그: "새로고침 하면
          키워드·직업 설명이 안 보여").

          진짜로 설명을 빈 칸으로 만든 사람은 거의 없다 — 오래된 이 컴퓨터
          백업이 낡았거나, 어디선가 테스트하다 남은 값일 가능성이 훨씬 크다.
          원래 값(`data-orig`)이 있던 자리가 빈 값으로 씌워지려 하면 그 칸은
          손대지 않는다. 정말 지우고 싶으면 칸에서 직접 지우면 된다.
        */
        if (next === "" && el.classList.contains("hltext") && el.dataset.orig) return;
        el.value = next;
      } catch (e) {
        try { console.error("[porcelain] assign", el && el.dataset, e); } catch (e2) {}
      }
    });
  }

  // 값이 통째로 바뀌었을 때 화면을 맞춘다.
  function redrawAll() {
    // 아직 화면에 안 보여 안 칠해진 카드는 그대로 둔다 — 스크롤로 다가올 때
    // 최신 값으로 칠해진다(사다리 칸의 값 자체는 `ensureAllLadders`가 이미
    // 맞춰 놨다).
    document.querySelectorAll('textarea.hltext[data-painted="1"]').forEach(refreshCardText);
    document.querySelectorAll(".card").forEach(function (card) {
      if (card.dataset.id) syncKeywordBars(card.dataset.id);
    });
    document.querySelectorAll("svg.prev").forEach(drawIcon);
    // 불러온 값 중 카드 그림(Art)이 있으면 썸네일도 그 그림으로 맞춘다.
    if (typeof paintCardArt === "function") {
      document.querySelectorAll(".card").forEach(function (card) {
        var input = card.querySelector('input[data-scope="cards"][data-field="Art"]');
        if (input) paintCardArt(card, input.value);
      });
    }
    // 직업 능력 탭의 전용 상태이상 줄도 지금 키워드 값으로 맞춘다.
    if (typeof syncAllStatusRows === "function") syncAllStatusRows();
    // "격자에서 찍기" 단추 글씨도 복원된 값으로 다시 센다(안 하면 저장된 범위가 없는 것처럼 보인다).
    if (typeof refreshAllPickButtons === "function") refreshAllPickButtons();
  }

  //=== 필터 ===//

  function apply() {
    ["cards", "classes", "keywords", "icons", "draw"].forEach(function (name) {
      document.getElementById("tab-" + name).classList.toggle("tabhide", state.tab !== name);
    });
    document.getElementById("gradeBar").style.display = state.tab === "cards" ? "" : "none";
    document.getElementById("classBar").style.display =
      (state.tab === "keywords" || state.tab === "icons" || state.tab === "draw") ? "none" : "";

    document.querySelectorAll("section.klass").forEach(function (section) {
      var classOk = state.klass === "all" || section.dataset.class === state.klass;
      if (section.classList.contains("panel")) {
        section.classList.toggle("hidden", !classOk
          || (state.dirtyOnly && !section.classList.contains("dirty")));
        return;
      }
      var shown = 0;
      section.querySelectorAll(".card").forEach(function (card) {
        var ok = classOk
          && (state.grade === "all" || card.dataset.grade === state.grade)
          && (!state.dirtyOnly || card.classList.contains("dirty"))
          && (state.q === "" || card.dataset.text.indexOf(state.q) >= 0);
        card.classList.toggle("hidden", !ok);
        if (ok) shown++;
      });
      section.classList.toggle("hidden", shown === 0);
    });

    /*
      `display:none`인 동안엔 `scrollHeight`가 0이라 `autoGrowTextarea`가 칸을
      3줄 높이로 찌그러뜨려 놓는다(요청한 버그: "클릭해야 반영, 새로고침하면
      다시 3줄"). 탭·필터가 바뀌어 칸이 실제로 보이게 될 때마다 다시 잰다.
    */
    document.querySelectorAll('textarea.hltext[data-painted="1"]').forEach(function (area) {
      if (area.offsetParent !== null) autoGrowTextarea(area);
    });
  }

  function bind(barId, key, target) {
    var bar = document.getElementById(barId);
    bar.addEventListener("click", function (event) {
      var chip = event.target.closest(".chip");
      if (!chip) return;
      bar.querySelectorAll(".chip").forEach(function (other) { other.classList.remove("on"); });
      chip.classList.add("on");
      state[target] = chip.dataset[key];
      apply();
    });
  }
  bind("tabBar", "tab", "tab");
  bind("classBar", "class", "klass");
  bind("gradeBar", "grade", "grade");

  document.getElementById("q").addEventListener("input", function (event) {
    state.q = event.target.value.trim().toLowerCase();
    apply();
  });

  //=== 버튼 ===//

  function onEdit(event) {
    var el = event.target;
    if (!el.classList || (!el.classList.contains("f") && !el.classList.contains("lv"))) return;
    if (el.dataset.scope === "icon") {
      var svg = document.querySelector('svg.prev[data-tag="' + el.dataset.key.split("#")[0] + '"]');
      if (svg) drawIcon(svg);
    }
    if (el.dataset.scope === "cardLevels") syncKeywordBars(el.dataset.key);
    /*
      범위 관련 칸은 화면에 값이 안 보이고(hidden) **단추 글씨가 유일한 표시**다.
      격자 창 말고 다른 길로 값이 바뀌어도(되돌리기·동업자의 수정) 그 글씨가
      따라오게, 값이 바뀌는 길목인 여기서 다시 센다.
    */
    if (el.dataset.scope === "skillShape" || el.dataset.field === "Motions") {
      var pickBtn = el.parentNode && el.parentNode.querySelector(".pick");
      if (pickBtn && typeof refreshPickButton === "function") refreshPickButton(pickBtn);
    }
    if (el.dataset.scope === "cardKeywords" || el.dataset.scope === "cardUnits") {
      var owner = el.closest(".card");
      var area = owner && owner.querySelector("textarea.hltext");
      if (area) paintKeywordBar(area);
    }
    if (el.dataset.scope === "cards" && el.dataset.field === "MaxLevel") {
      var newMax = Math.max(1, Math.min(20, parseInt(el.value, 10) || 1));
      el.value = newMax;
      var card = el.closest(".card");
      card.querySelectorAll(".ladders .ladder .lv").forEach(function (box, index, all) {
        // 슬롯마다 한 번만 손대면 되므로, 그 슬롯의 첫 칸일 때만 부른다.
        if (box.dataset.level === "1") resizeLadder(card.dataset.id, Number(box.dataset.slot), newMax);
      });
      var pick = card.querySelector(".cardlv");
      if (pick) {
        var kept = Math.min(Number(pick.value) || 1, newMax);
        var opts = "";
        for (var level = 1; level <= newMax; level++) {
          opts += '<option value="' + level + '">Lv' + level + "</option>";
        }
        pick.innerHTML = opts;
        pick.value = kept;
        pick.dataset.maxlevel = String(newMax);
      }
      var textArea = card.querySelector("textarea.hltext");
      if (textArea) refreshCardText(textArea); // 슬롯 칩의 Lv 선택 칸 수도 다시 그린다
    }
    var owningCard = el.closest(".card");
    if (owningCard) renderPreview(owningCard);
    push(el);
    refresh();
  }
  document.addEventListener("input", onEdit);
  // select는 브라우저에 따라 input이 뜨지 않는다. change로도 받는다.
  document.addEventListener("change", onEdit);

  document.getElementById("onlyDirty").addEventListener("click", function (event) {
    state.dirtyOnly = !state.dirtyOnly;
    event.target.classList.toggle("on", state.dirtyOnly);
    apply();
  });

  /*
    저장은 **같은 파일을 고쳐 쓰는 것**이 기본이다 (요청).

    한 번 파일을 고르면 그 손잡이(handle)를 들고 있다가 다음부터는 대화상자 없이
    덮어쓴다. 받을 때마다 config_edits(1).json, (2)... 가 쌓이면 어느 것이 최신인지
    알 수 없게 된다.

    파일 시스템 접근 API가 없는 브라우저에서는 예전처럼 내려받기로 접는다.
  */
  var fileHandle = null;

  function stamp(edits) {
    var now = new Date();
    edits.savedAt = now.toISOString();
    // 사람이 읽는 쪽도 같이 넣는다. ISO만 있으면 파일을 열었을 때 언제 것인지 안 읽힌다.
    edits.savedAtLocal = now.getFullYear() + "-"
      + String(now.getMonth() + 1).padStart(2, "0") + "-"
      + String(now.getDate()).padStart(2, "0") + " "
      + String(now.getHours()).padStart(2, "0") + ":"
      + String(now.getMinutes()).padStart(2, "0");
    return edits;
  }

  function fellBack(edits) {
    var url = URL.createObjectURL(new Blob([JSON.stringify(edits, null, 2)], { type: "application/json" }));
    var link = document.createElement("a");
    link.href = url;
    link.download = "config_edits.json";
    link.click();
    URL.revokeObjectURL(url);
  }

  function noteSaved(edits) {
    var label = document.getElementById("dirty");
    label.textContent = label.textContent + " · " + edits.savedAtLocal + " 저장됨";
  }

  document.getElementById("save").addEventListener("click", async function () {
    var edits = collect();
    if (Object.keys(edits).length <= 1) { alert("수정한 것이 없습니다."); return; }
    /*
      Supabase는 파일을 대신 써 주지 않는다(예전 로컬 서버와 다른 점). Supabase에
      쌓인 값은 이 버튼으로 **직접 받아서** `apply_config_edits.luau`에 먹여야
      소스에 반영된다 — 그래서 LIVE라고 이 버튼을 막지 않는다.
    */
    stamp(edits);
    var body = JSON.stringify(edits, null, 2);

    if (!window.showSaveFilePicker) { fellBack(edits); noteSaved(edits); return; }
    try {
      if (!fileHandle) {
        fileHandle = await window.showSaveFilePicker({
          suggestedName: "config_edits.json",
          types: [{ description: "JSON", accept: { "application/json": [".json"] } }]
        });
      }
      var writable = await fileHandle.createWritable();
      await writable.write(body);
      await writable.close();
      noteSaved(edits);
    } catch (e) {
      // 사용자가 대화상자를 닫은 것은 오류가 아니다.
      if (e && e.name === "AbortError") return;
      fellBack(edits);
      noteSaved(edits);
    }
  });

  /*
    불러온 내용을 화면에 씌우고 **클라우드에도 올린다** (요청한 버그).

    예전에는 화면만 바뀌어서, 새로고침하면 불러온 것이 통째로 사라지고 예전
    값이 돌아왔다 — 파일을 불러온 사람만 잠깐 다르게 보였을 뿐이다.
  */
  function restoreAndSync(data, label) {
    if (!data || typeof data !== "object") {
      alert("이 파일에는 수정 내용이 없습니다.");
      return;
    }
    restore(data);
    if (!LIVE) return;
    syncLocalToCloud(label)
      .then(function () { setTimeout(refresh, 400); })
      .catch(function (err) {
        noteFailure(err, "불러온 내용을 올리지 못했습니다");
        alert("화면에는 불러왔지만 클라우드 저장에 실패했습니다.\n\n" + describeError(err));
      });
  }

  document.getElementById("load").addEventListener("click", async function () {
    if (window.showOpenFilePicker) {
      try {
        var picked = await window.showOpenFilePicker({
          types: [{ description: "JSON", accept: { "application/json": [".json"] } }]
        });
        fileHandle = picked[0];
        var text = await (await fileHandle.getFile()).text();
        restoreAndSync(JSON.parse(text), "불러온 내용 올리는 중");
        return;
      } catch (e) {
        if (e && e.name === "AbortError") return;
        alert("읽을 수 없는 파일입니다: " + (e && e.message ? e.message : e));
        return;
      }
    }
    document.getElementById("file").click();
  });
  document.getElementById("file").addEventListener("change", function (event) {
    var file = event.target.files && event.target.files[0];
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function () {
      try { restoreAndSync(JSON.parse(reader.result), "불러온 내용 올리는 중"); }
      catch (e) { alert("읽을 수 없는 파일입니다: " + (e && e.message ? e.message : e)); }
    };
    reader.onerror = function () { alert("파일을 읽지 못했습니다."); };
    try { reader.readAsText(file); } catch (e) { alert("파일을 읽지 못했습니다: " + e.message); }
    event.target.value = "";
  });

  document.getElementById("revert").addEventListener("click", function () {
    if (!confirm(LIVE
      ? "모든 수정을 버리고 원문으로 되돌립니다.\n함께 보는 사람들의 화면에서도 사라집니다."
      : "모든 수정을 버리고 원문으로 되돌립니다.")) return;
    fieldList().forEach(function (el) { el.value = el.dataset.orig; });
    if (typeof refreshAllPickButtons === "function") refreshAllPickButtons();
    refresh();
    // 화면만 되돌리면 새로고침 때 클라우드 값이 다시 돌아온다. 거기서도 지운다.
    if (LIVE) {
      syncLocalToCloud("되돌리는 중")
        .then(function () { setTimeout(refresh, 400); })
        .catch(function (err) { noteFailure(err, "되돌리기를 클라우드에 반영하지 못했습니다"); });
    }
  });


  //=== 범위 지정 격자 (요청) ===//

  /*
    6x3 격자 두 판. 왼쪽이 내 진영, 오른쪽이 적 진영이다.

    좌표는 **각 진영의 왼쪽 아래가 (0,0)** 이고 오른쪽·위로 커진다.
    저장되는 것은 절대 좌표가 아니라 **기준점 (n,n)에서의 상대 좌표**다.
    보통 기준점은 상대(적)지만, "아군 진형에 스킬 사용"을 켜면 기준점이
    **캐스터 자신**으로 바뀌고 칠하는 진영도 내 진영으로 바뀐다(요청).
  */
  var W = 6, H = 3;
  //--- 조건부로 늘어나는 단계 색(요청: "색깔 지정을 하고, 그 색깔에 따라서
  //    단계별 범위지정"). 0번은 기본(항상 켜진) 범위, 1~5번이 자원이 쌓일
  //    때마다 차례로 켜지는 단계다. `BattleSkills.GrowDivisor`로 보정된
  //    "몇 번째 단계인가"를 이 색으로 표시한다.
  var STAGE_COLORS = [
    { bg: "#2f5fd0", border: "#4b7bea" },
    { bg: "#2f7a5a", border: "#3fae82" },
    { bg: "#a37a1f", border: "#d9a53a" },
    { bg: "#7a3fa3", border: "#a860d9" },
    { bg: "#1f8ca3", border: "#3ad0e0" },
    { bg: "#a33f6e", border: "#d95a99" },
  ];
  var MAX_STAGES = STAGE_COLORS.length - 1;
  function emptyStages() { return STAGE_COLORS.slice(1).map(function () { return []; }); }
  /*
    **두 목적을 동시에 들고 있는다.** 예전에는 지금 보고 있는 목적 하나만
    들고 있다가 적용할 때 그 필드만 썼다 — 그러면 "모션을 고치는 중"일 때
    조건부 단계는 손도 안 댄 옛 값 그대로 남고, 진영을 아군으로 바꾸거나
    범위를 비워도 안 보이는 쪽은 그대로 남아 **기준점이 달라진 좌표가 조용히
    살아남았다.** 이제 열 때 둘 다 읽고, 적용할 때 둘 다 쓴다.

    `hits`(0단계)는 둘이 함께 쓴다 — 조건부에서는 "항상 켜진 기본 범위"이고
    모션에서는 "1번 모션"인데, 둘 다 `Shape.Cells` 한 곳에 저장되는 같은 값이다.
  */
  var picker = {
    target: null, stagesTarget: null, sideTarget: null, motionsTarget: null,
    mode: "Foe", stage: 0,
    // purpose: 색깔 있는 단계가 "조건부로 늘어남"(Grow)인지 "모션 단계"(Motion,
    // 요청: "모션상 단계... 결투사의 앞뒤관통의 경우에 써야됨")인지.
    purpose: "Grow",
    me: [0, 1], foe: [0, 1], hits: [],
    growStages: emptyStages(), motionStages: emptyStages(),
  };
  // 지금 목적이 쓰는 단계 배열. `hits`(0단계)는 목적과 무관하게 공유한다.
  function stagesOf(purpose) {
    return (purpose || picker.purpose) === "Motion" ? picker.motionStages : picker.growStages;
  }

  function buildSide(id, isFoe) {
    var host = document.getElementById(id);
    for (var row = H - 1; row >= 0; row--) {
      for (var col = 0; col < W; col++) {
        var cell = document.createElement("div");
        cell.className = "cell";
        cell.dataset.x = col;
        cell.dataset.y = row;
        cell.dataset.foe = isFoe ? "1" : "";
        cell.textContent = col + "," + row;
        host.appendChild(cell);
      }
    }
  }
  buildSide("myside", false);
  buildSide("foeside", true);

  function sameCell(a, b) { return a[0] === b[0] && a[1] === b[1]; }

  // 지금 고른 단계가 쓰는 목록. 0단계(기본)는 picker.hits, 그 위는 지금 목적의 단계 배열.
  function activeList() { return picker.stage === 0 ? picker.hits : stagesOf()[picker.stage - 1]; }

  // 어느 진영의 빈 칸이 지금 칠할 수 있는 칸인지 — "아군 진형에 스킬 사용" 여부를 따른다.
  function isPaintable(cell) { return (cell.dataset.foe ? "Foe" : "Ally") === picker.mode; }

  // 탭 이름은 목적(purpose)에 따라 다르다 — "기본/1단계.." (조건부) 또는 "모션1/모션2.." (모션).
  function stageLabel(i) {
    if (picker.purpose === "Motion") return i === 0 ? "모션1" : "모션" + (i + 1);
    return i === 0 ? "기본" : i + "단계";
  }
  function buildStageBar() {
    var bar = document.getElementById("stageBar");
    var html = "";
    for (var i = 0; i <= MAX_STAGES; i++) {
      html += '<button type="button" class="stagechip' + (i === picker.stage ? " on" : "") + '" data-stage="' + i + '">'
        + '<span class="swatch" style="background:' + STAGE_COLORS[i].border + '"></span>'
        + stageLabel(i) + "</button>";
    }
    bar.innerHTML = html;
    document.getElementById("mstagehint").textContent = picker.purpose === "Motion"
      ? "모션이 여럿이라면(예: 앞뒤관통), 아래에서 순서를 고르고 그 색으로 칸을 찍는다 — 모션마다 따로 맞는다."
      : "조건부로 늘어나는 범위가 있다면, 아래에서 단계를 고르고 그 색으로 칸을 찍는다 — 자원이 그 단계만큼 쌓이면 켜진다(요청: \"색깔에 따라서 단계별 범위지정\").";
  }
  buildStageBar();
  document.getElementById("stageBar").addEventListener("click", function (event) {
    var btn = event.target.closest(".stagechip");
    if (!btn) return;
    picker.stage = +btn.dataset.stage;
    document.querySelectorAll("#stageBar .stagechip").forEach(function (b) { b.classList.toggle("on", b === btn); });
  });
  document.getElementById("mpurpose").addEventListener("change", function (event) {
    // 둘 다 메모리에 들고 있으므로 보는 쪽만 바꾸면 된다 — 다시 읽어올 필요가 없다.
    picker.purpose = event.target.value;
    picker.stage = 0;
    buildStageBar();
    paintBoard();
  });

  function paintBoard() {
    document.getElementById("myside").classList.toggle("active", picker.mode === "Ally");
    document.getElementById("foeside").classList.toggle("active", picker.mode === "Foe");
    document.querySelectorAll("#modal .cell").forEach(function (cell) {
      var x = +cell.dataset.x, y = +cell.dataset.y, foe = !!cell.dataset.foe;
      cell.classList.remove("me", "foe");
      cell.style.background = "";
      cell.style.borderColor = "";
      cell.style.color = "";
      cell.style.boxShadow = "";
      if (!foe && sameCell([x, y], picker.me)) cell.classList.add("me");
      if (foe && sameCell([x, y], picker.foe)) cell.classList.add("foe");
      var isPawn = cell.classList.contains("me") || cell.classList.contains("foe");
      /*
        칸을 찍은 목록은 좌표만 들고 있어 진영을 모른다 — 실제로는 지금 칠할
        수 있는 진영에서만 의미가 있는데, 두 진영이 같은 (x,y) 범위를 쓰다
        보니 진영 검사 없이 좌표만 맞춰 칠하면 **양쪽에 똑같이** 켜져
        보였다(요청한 버그: "양 진영에 동시에 되는데? 거울마냥").
      */
      if ((foe ? "Foe" : "Ally") !== picker.mode) return;
      var stages = stagesOf();
      var stageIndex = picker.hits.some(function (h) { return sameCell(h, [x, y]); }) ? 0 : -1;
      if (stageIndex < 0) {
        for (var i = 0; i < stages.length; i++) {
          if (stages[i].some(function (h) { return sameCell(h, [x, y]); })) { stageIndex = i + 1; break; }
        }
      }
      if (stageIndex < 0) return;
      /*
        **기준점 칸도 켜진 게 보여야 한다.** 기준점(말)이 곧 (n,n)인데, 그
        (n,n)이야말로 단일 대상 스킬이 가장 흔히 찍는 칸이다. 예전에는 말 색이
        덮어써서, 켜져 있어도 화면상 아무 표시가 없었다 — 찍혔는지 아닌지
        알 길이 없었다. 말 칸은 말 색을 그대로 두고 **안쪽 테두리**로 단계
        색을 덧그려, 둘 다 한눈에 보이게 한다.
      */
      if (isPawn) {
        cell.style.boxShadow = "inset 0 0 0 3px " + STAGE_COLORS[stageIndex].border;
        return;
      }
      cell.style.background = STAGE_COLORS[stageIndex].bg;
      cell.style.borderColor = STAGE_COLORS[stageIndex].border;
      cell.style.color = "#fff";
    });
    /*
      좌표는 **항상 n 표기**로 적는다 (요청).
      기준점이 (n,n)이므로 오른쪽 한 칸은 (n+1,n), 아래 한 칸은 (n,n-1)이다.
    */
    function axis(delta) {
      if (delta === 0) return "n";
      return "n" + (delta > 0 ? "+" : "-") + Math.abs(delta);
    }
    var ref = picker.mode === "Ally" ? picker.me : picker.foe;
    function describe(list) {
      return list.map(function (h) {
        var dx = h[0] - ref[0], dy = h[1] - ref[1];
        return '<span class="co">(' + axis(dx) + "," + axis(dy) + ")</span>";
      }).join("");
    }
    var lines = [];
    if (picker.hits.length > 0) {
      lines.push("<div>기준점 (n,n) 기준 " + picker.hits.length + "칸" + describe(picker.hits) + "</div>");
    }
    stagesOf().forEach(function (stage, i) {
      if (stage.length > 0) {
        lines.push("<div>" + stageLabel(i + 1) + " +" + stage.length + "칸" + describe(stage) + "</div>");
      }
    });
    document.getElementById("mout").innerHTML =
      lines.length === 0 ? "지정 없음 — 소스에 정의된 원래 범위가 그대로 쓰인다" : lines.join("");
  }

  /*
    **나·적 말은 끌어서 옮기고, 칠할 수 있는 진영의 빈 칸은 눌러 끌면 훑어 칠한다** (요청).

    말 칸에서 손을 떼지 않고 옮기면 그 말이 움직이고, 칠할 수 있는 진영의 빈 칸에서
    누른 채 끌면 지나는 칸마다 지금 고른 단계의 범위가 켜지거나 꺼진다 — 시작 칸이
    지금 꺼져 있으면 켜는 방향으로, 켜져 있으면 끄는 방향으로 훑는다(지우기도 되게).
    움직이지 않고 눌렀다 떼면(클릭) 그 한 칸만 토글한다 — 옛날과 같다.

    두 드래그를 가르는 건 손을 뗄 때까지 **손가락이 움직였는가**뿐이다. 말
    드래그는 옮긴 자리가 같은 진영(내 말은 내 진영, 적 말은 적 진영) 밖이면
    되돌린다.

    드래그가 실제로 일어났으면 그 뒤에 브라우저가 마저 쏘는 click을 죽인다 —
    안 그러면 마지막으로 지나간 칸에서 클릭까지 한 번 더 처리된 것처럼 겹친다.
  */
  var DRAG_SLOP = 4;
  var drag = null;
  var suppressClick = false;

  function cellAtPoint(clientX, clientY) {
    var el = document.elementFromPoint(clientX, clientY);
    return el && el.closest && el.closest("#modal .cell");
  }

  /*
    지금 고른 단계에만 켜고 끈다. 다른 단계에 이미 있는 칸이어도 안 건드린다
    — 모션끼리는 같은 칸을 겹쳐 때릴 수 있어야 한다(요청: "모션 1 모션 2
    이런식으로 할 때, 격자가 서로 겹칠 수 있게도 해줘" — 예: 같은 적을 두
    모션이 다 때리는 것). 예전엔 다른 단계에서 빼내 옮겨 왔는데, 그러면
    겹쳐 때리는 걸 표현할 수 없었다.
  */
  function setCell(x, y, on) {
    var list = activeList();
    var at = list.findIndex(function (h) { return sameCell(h, [x, y]); });
    if (on && at < 0) list.push([x, y]);
    else if (!on && at >= 0) list.splice(at, 1);
  }

  /*
    **기준점을 옮기면 찍어 둔 범위도 같이 따라간다.**

    저장되는 값은 기준점에서 잰 상대 좌표다. 그래서 말만 옮기고 칸을 그 자리에
    두면, 화면은 그대로인데 **저장되는 좌표가 통째로 달라진다** — (n+1,n)로
    찍어 둔 것이 말을 두 칸 옮겼다고 조용히 (n-1,n)이 되어 버렸다. 말은
    "적이 여기 서 있다고 치자"는 눈금일 뿐이므로, 눈금을 옮기면 그 눈금에
    맞춰 그린 모양도 함께 움직이는 것이 맞다. 옮긴 만큼 모든 칸을 밀어 준다.
  */
  function movePawn(kind, to) {
    var from = picker[kind];
    var dx = to[0] - from[0], dy = to[1] - from[1];
    picker[kind] = to;
    // 그 진영을 겨누고 있을 때만 따라간다 — 안 쓰는 쪽 말은 눈금 구실도 안 한다.
    if ((kind === "foe") !== (picker.mode === "Foe")) return;
    if (dx === 0 && dy === 0) return;
    [picker.hits].concat(picker.growStages, picker.motionStages).forEach(function (list) {
      list.forEach(function (h) { h[0] += dx; h[1] += dy; });
    });
  }

  document.getElementById("modal").addEventListener("pointerdown", function (event) {
    var cell = event.target.closest(".cell");
    if (!cell) return;
    var kind = cell.classList.contains("me") ? "me" : cell.classList.contains("foe") ? "foe" : null;
    if (kind) {
      drag = { type: "move", kind: kind, moved: false, x: event.clientX, y: event.clientY };
    } else if (isPaintable(cell)) {
      // 칠할 수 있는 진영의 빈 칸. 지금 고른 단계에서 꺼져 있으면 켜는 방향, 켜져 있으면 끄는 방향으로 훑는다.
      var on = !activeList().some(function (h) { return sameCell(h, [+cell.dataset.x, +cell.dataset.y]); });
      drag = {
        type: "paint", on: on, moved: false, x: event.clientX, y: event.clientY,
        startX: +cell.dataset.x, startY: +cell.dataset.y, seen: {},
      };
    } else {
      return; // 칠할 수 없는 진영의 빈 칸은 드래그·클릭 다 할 게 없다.
    }
    cell.setPointerCapture(event.pointerId);
  });

  document.getElementById("modal").addEventListener("pointermove", function (event) {
    if (!drag) return;
    var justStarted = !drag.moved
      && (Math.abs(event.clientX - drag.x) > DRAG_SLOP || Math.abs(event.clientY - drag.y) > DRAG_SLOP);
    if (justStarted) drag.moved = true;
    if (!drag.moved) return;
    if (drag.type === "move") {
      document.querySelectorAll("#modal .cell.dragover").forEach(function (c) { c.classList.remove("dragover"); });
      var over = cellAtPoint(event.clientX, event.clientY);
      if (over && !!over.dataset.foe === (drag.kind === "foe")) over.classList.add("dragover");
      return;
    }
    /*
      **드래그를 시작한 칸도 칠한다.** 손을 뗀 뒤에야 "옮겨 다녔다"는 게
      확정되므로, 그 확정되는 순간(justStarted) 놓쳤던 시작 칸을 먼저 채워
      넣는다 — 안 그러면 누르고 바로 옆 칸으로 끈 첫 칸만 안 칠해진다.
    */
    if (justStarted) {
      drag.seen[drag.startX + "," + drag.startY] = true;
      setCell(drag.startX, drag.startY, drag.on);
      drag.lastX = drag.x;
      drag.lastY = drag.y;
    }
    /*
      **지나간 자리를 이어서 훑는다.**

      pointermove는 손이 빠르면 띄엄띄엄 온다 — 한 번에 세 칸을 건너뛴 좌표가
      오면 그 사이 칸은 아무도 안 밟은 것이 되어 **빠르게 그으면 중간이 뚫린
      채로 칠해졌다.** 지난 좌표에서 지금 좌표까지 촘촘히 훑어(칸 크기의
      3분의 1 간격) 사이에 걸친 칸을 모두 채운다.
    */
    var fromX = drag.lastX === undefined ? event.clientX : drag.lastX;
    var fromY = drag.lastY === undefined ? event.clientY : drag.lastY;
    var dx = event.clientX - fromX, dy = event.clientY - fromY;
    var steps = Math.max(1, Math.ceil(Math.max(Math.abs(dx), Math.abs(dy)) / 10));
    for (var i = 1; i <= steps; i++) {
      var over = cellAtPoint(fromX + (dx * i) / steps, fromY + (dy * i) / steps);
      if (over && isPaintable(over)) {
        var key = over.dataset.x + "," + over.dataset.y;
        if (!drag.seen[key]) {
          drag.seen[key] = true;
          setCell(+over.dataset.x, +over.dataset.y, drag.on);
        }
      }
    }
    drag.lastX = event.clientX;
    drag.lastY = event.clientY;
    paintBoard();
  });

  function endDrag(event) {
    if (!drag) return;
    document.querySelectorAll("#modal .cell.dragover").forEach(function (c) { c.classList.remove("dragover"); });
    if (drag.moved) {
      suppressClick = true;
      /*
        보통은 이 뒤로 브라우저가 click을 한 번 더 쏘고, 그때 아래 click
        리스너가 이 표시를 내린다. 그런데 포인터가 캡처된 채로 취소되는(
        pointercancel) 등 click이 아예 안 오는 경우도 있다 — 그러면 표시가
        영영 안 내려가 **다음번 진짜 클릭까지 조용히 씹힌다.** 짧게 예약해
        두어, click이 안 와도 스스로 내려가게 한다.
      */
      setTimeout(function () { suppressClick = false; }, 0);
      if (drag.type === "move") {
        var over = cellAtPoint(event.clientX, event.clientY);
        if (over && !!over.dataset.foe === (drag.kind === "foe")) {
          movePawn(drag.kind, [+over.dataset.x, +over.dataset.y]);
          paintBoard();
        }
      }
      // 칠하기는 pointermove에서 지나는 대로 이미 다 칠했다 — 여기서 더 할 게 없다.
    }
    drag = null;
  }
  document.getElementById("modal").addEventListener("pointerup", endDrag);
  document.getElementById("modal").addEventListener("pointercancel", endDrag);

  document.getElementById("modal").addEventListener("click", function (event) {
    if (suppressClick) { suppressClick = false; return; }
    var cell = event.target.closest(".cell");
    if (!cell) {
      if (event.target === this) closePicker();
      return;
    }
    if (isPaintable(cell)) {
      var x = +cell.dataset.x, y = +cell.dataset.y;
      var on = !activeList().some(function (h) { return sameCell(h, [x, y]); });
      setCell(x, y, on);
      paintBoard();
    }
  });

  /*
    단추 글씨(`3칸 +2단계 · 모션 2개 · 아군`)를 **지금 칸에 든 값에서** 다시 만든다.

    이 글씨는 편집기를 만들 때 소스 값으로 한 번 구워 넣는데, 클라우드에
    저장해 둔 범위는 그 뒤에 칸으로 들어온다 — 다시 세는 사람이 없어서
    **새로고침하면 범위가 멀쩡히 있는데도 단추는 "격자에서 찍기"(빈 상태)**
    라고 떠 있었다. 저장이 날아간 것처럼 보이는 가장 나쁜 종류의 표시였다.
    이제 복원·원격 반영이 끝난 뒤 이 함수로 모든 단추를 다시 센다.
  */
  function refreshPickButton(button) {
    if (!button) return;
    var box = button.parentNode;
    function valueOf(field) {
      var el = box.querySelector('[data-field="' + field + '"]');
      return el ? el.value : "";
    }
    function countOf(field) {
      var raw = valueOf(field);
      if (!raw) return 0;
      try { return JSON.parse(raw).length; } catch (e) { return 0; }
    }
    var cells = countOf("Cells");
    var stageCount = countOf("Stages");
    var motionCount = countOf("Motions");
    var ally = valueOf("TargetSide") === "Ally";
    if (cells === 0 && stageCount === 0 && motionCount === 0 && !ally) {
      button.textContent = "격자에서 찍기";
      button.classList.remove("set");
      return;
    }
    /*
      찍은 칸이 없어도 단계·모션은 있을 수 있다 — 그때 1번 모션(기본 범위)은
      소스에 적힌 범위를 그대로 쓴다. 그런 걸 "격자에서 찍기"(= 아무것도 없음)로
      적으면 "격자에서 찍기 · 모션 3개"처럼 앞뒤가 안 맞는 말이 된다.
    */
    var label = cells === 0 ? "기본 범위" : cells + "칸";
    if (stageCount > 0) label += " +" + stageCount + "단계";
    if (motionCount > 0) label += " · 모션 " + (motionCount + 1) + "개";
    if (ally) label += " · 아군";
    button.textContent = label;
    button.classList.toggle("set", cells > 0);
  }
  function refreshAllPickButtons() {
    document.querySelectorAll("button.pick").forEach(refreshPickButton);
  }

  // 칸 목록의 목록(JSON)을 기준점 기준 절대 좌표 단계 배열로. `Stages`·`Motions`가 같은 형식이다.
  function readStages(holder, ref) {
    var out = emptyStages();
    if (holder && holder.value) {
      try {
        JSON.parse(holder.value).forEach(function (stage, i) {
          if (!out[i]) return;
          stage.forEach(function (offset) {
            var ox = ref[0] + offset[0], oy = ref[1] + offset[1];
            out[i].push([ox, oy]);
          });
        });
      } catch (e) {}
    }
    return out;
  }

  function openPicker(button) {
    var holder = button.parentNode.querySelector(".cells");
    var stagesHolder = button.parentNode.querySelector('[data-field="Stages"]');
    var sideHolder = button.parentNode.querySelector('[data-field="TargetSide"]');
    var motionsHolder = button.parentNode.querySelector('[data-field="Motions"]');
    picker.target = holder;
    picker.stagesTarget = stagesHolder;
    picker.sideTarget = sideHolder;
    picker.motionsTarget = motionsHolder;
    picker.hits = [];
    picker.stage = 0;
    picker.purpose = "Grow"; // 열 때마다 조건부 단계부터 보여준다 — 모션은 아래에서 목적을 바꿔 편집한다.
    /*
      기준점(말)은 화면 그리기용일 뿐 저장되는 값이 아니다 — 저장은 언제나
      그 기준점에서 잰 **상대 좌표**라, 기준점이 어디 있든 되살리면 같은
      모양이 나온다. 그런데 열 때마다 (0,1)로 되돌리면, 보기 편하라고
      끌어다 둔 자리가 적용할 때마다 사라진다(요청한 버그: "범위 지정 후에
      위치가 다시 (0,1)로 이동해"). 그래서 여기서 다시 안 정한다 — `picker`
      선언에서 (0,1)로 한 번만 잡고, 그 뒤로는 마지막으로 둔 자리를 그대로
      다음 열 때도 쓴다.
    */
    picker.mode = (sideHolder && sideHolder.value === "Ally") ? "Ally" : "Foe";
    var ref = picker.mode === "Ally" ? picker.me : picker.foe;
    if (holder.value) {
      try {
        // 저장된 것은 상대 좌표다. 기준점을 (0,1)에 두고 되살린다.
        JSON.parse(holder.value).forEach(function (offset) {
          var ox = ref[0] + offset[0], oy = ref[1] + offset[1];
          picker.hits.push([ox, oy]);
        });
      } catch (e) {}
    }
    picker.growStages = readStages(stagesHolder, ref);
    picker.motionStages = readStages(motionsHolder, ref);
    document.getElementById("mally").checked = picker.mode === "Ally";
    document.getElementById("mpurpose").value = "Grow";
    document.getElementById("mtitle").textContent = button.dataset.pick + " — 범위 지정";
    buildStageBar();
    document.getElementById("modal").classList.add("on");
    paintBoard();
  }

  function closePicker() {
    document.getElementById("modal").classList.remove("on");
    picker.target = null;
    picker.stagesTarget = null;
    picker.sideTarget = null;
    picker.motionsTarget = null;
  }

  document.addEventListener("click", function (event) {
    var button = event.target.closest(".pick");
    if (button) openPicker(button);
  });

  document.getElementById("mally").addEventListener("change", function (event) {
    /*
      진영을 바꾸면 기준점도(적 → 캐스터 자신) 달라져, 이전에 찍어 둔 칸을
      그대로 두면 엉뚱한 좌표가 된다 — 다시 그리게 비운다(요청: "'아군 진형에
      스킬 사용' 누르면 아군 진형에 범위 지정"). **조건부·모션 둘 다** 비운다 —
      한쪽만 비우면 안 보이는 쪽에 옛 진영 기준 좌표가 그대로 남아 있다가
      새 기준점에 맞춰 엉뚱하게 되살아난다.
    */
    picker.mode = event.target.checked ? "Ally" : "Foe";
    clearAllCells();
    paintBoard();
  });

  function clearAllCells() {
    picker.hits = [];
    picker.growStages = emptyStages();
    picker.motionStages = emptyStages();
  }

  document.getElementById("mcancel").addEventListener("click", closePicker);
  document.getElementById("mclear").addEventListener("click", function () {
    // "범위 비우기"는 보이는 것만이 아니라 이 스킬의 범위를 통째로 비운다.
    clearAllCells();
    paintBoard();
  });
  document.getElementById("mok").addEventListener("click", function () {
    if (!picker.target) return;
    // closePicker()가 picker.*를 지우므로 먼저 붙들어 둔다.
    var target = picker.target;
    var stagesTarget = picker.stagesTarget;
    var sideTarget = picker.sideTarget;
    var motionsTarget = picker.motionsTarget;
    var mode = picker.mode;
    var purpose = picker.purpose;
    var ref = mode === "Ally" ? picker.me : picker.foe;
    function toOffsets(list) {
      return list.map(function (h) {
        var dx = h[0] - ref[0], dy = h[1] - ref[1];
        return [dx, dy];
      });
    }
    // 뒤쪽의 빈 단계는 잘라내 저장을 깔끔히 한다(중간 단계가 비어 있는 건 그대로 둔다 — 그 단계에서
    // 새로 켜지는 칸이 없다는 뜻일 수 있다).
    function stagesJson(stages) {
      var rows = stages.map(toOffsets);
      while (rows.length > 0 && rows[rows.length - 1].length === 0) rows.pop();
      return rows.length === 0 ? "" : JSON.stringify(rows);
    }
    var offsets = toOffsets(picker.hits);

    /*
      **네 칸을 언제나 다 쓴다.** 예전에는 지금 보고 있는 목적의 칸만 썼는데,
      그러면 안 보이는 쪽(모션을 볼 땐 조건부 단계)이 손도 안 댄 옛 값으로
      남아, 진영을 바꾸거나 범위를 비워도 **옛 기준점 기준 좌표가 조용히
      살아남았다.** 이제 둘 다 메모리에 들고 있으니 둘 다 그대로 쓰면 된다.
    */
    target.value = offsets.length === 0 ? "" : JSON.stringify(offsets);
    if (sideTarget) sideTarget.value = mode === "Ally" ? "Ally" : "";
    if (stagesTarget) stagesTarget.value = stagesJson(picker.growStages);
    if (motionsTarget) motionsTarget.value = stagesJson(picker.motionStages);

    refreshPickButton(target.parentNode.querySelector(".pick"));
    closePicker();
    /*
      `.value`를 직접 씌우기만 하면 `input` 이벤트가 안 뜬다 — 다른 모든 칸이
      타고 가는 `onEdit`(클라우드로 `push`, 로컬 `refresh`)이 이 칸만 못 타서,
      찍은 범위가 화면엔 보여도 실제로는 저장이 안 된 채 남았다. 그러다 다음
      동기화(새로고침·남의 수정 반영)에서 서버에 있던 옛 값으로 되돌아가는 게
      "저장했을 때 위치가 지맘대로 바뀐다"는 버그였다(요청한 다른 버그의 원인과
      같아서, 여기서 같이 고친다).
    */
    [target, sideTarget, stagesTarget, motionsTarget].forEach(function (el) {
      if (el) el.dispatchEvent(new Event("input", { bubbles: true }));
    });
  });


  //=== 아이콘 미리보기 ===//

  /*
    편집기가 게임과 **같은 계산**을 한다. 문양 좌표를 메달리온 비율만큼 줄여 넣고,
    일반 등급의 액자를 뒤에 깐다. 숫자를 고치면 그 자리에서 다시 그린다.
  */
  var INSET = ]] .. string.format("%.5f", CardArt.INSET) .. [[;
  var FRAME = [
    [0.5, 0.5, 0.84, 0.84, 0, "#ffffff", 0.5, 0, 2, 0.28],
    [0.5, 0.5, 0.78, 0.78, 0, "#2a2c30", 0.5, 0, 3, 1],
    [0.5, 0.5, 0.8, 0.8, 0, "#ffffff", 0.5, 0.022, 4, 1]
  ];
  var glyphs = {};
  try { glyphs = JSON.parse(document.getElementById("glyphs").textContent); } catch (e) {}

  function rectOf(x, y, w, h, rot, color, corner, stroke, alpha) {
    var S = 200;
    var W = w * S, H = h * S, cx = x * S, cy = y * S;
    var a = 'x="' + (cx - W / 2) + '" y="' + (cy - H / 2) + '" width="' + W + '" height="' + H + '"';
    var rx = corner * Math.min(W, H);
    if (rx > 0.05) a += ' rx="' + rx + '"';
    if (stroke > 0) a += ' fill="none" stroke="' + color + '" stroke-width="' + stroke * S + '"';
    else a += ' fill="' + color + '"';
    if (alpha < 1) a += ' opacity="' + alpha + '"';
    if (rot) a += ' transform="rotate(' + rot + ' ' + cx + ' ' + cy + ')"';
    return "<rect " + a + "/>";
  }

  // 이 태그의 도형에 지금 편집기에 적힌 값을 먹인다.
  function currentShapes(tag) {
    var base = (glyphs[tag] || []).map(function (item) {
      return { i: item.i, x: item.x, y: item.y, w: item.w, h: item.h, r: item.r,
               c: item.c, k: item.k, s: item.s, z: item.z, a: item.a, d: item.d };
    });
    base.forEach(function (item, at) {
      if (item.d) return;
      var box = document.querySelector('[data-scope="icon"][data-key="' + tag + "#" + item.i + '"][data-field="X"]');
      if (!box) return;
      function grab(name, fallback) {
        var el = document.querySelector('[data-scope="icon"][data-key="' + tag + "#" + item.i + '"][data-field="' + name + '"]');
        var value = el && el.value !== "" ? parseFloat(el.value) : fallback;
        return isNaN(value) ? fallback : value;
      }
      var next = { x: grab("X", item.x), y: grab("Y", item.y), w: grab("W", item.w),
                   h: grab("H", item.h), r: grab("Rotation", item.r) };
      // 앞이 이 획의 그림자면 같이 옮긴다. CardArt와 같은 규칙이다.
      var ahead = base[at - 1];
      if (ahead && ahead.d
        && Math.abs(ahead.w - item.w) < 1e-6 && Math.abs(ahead.h - item.h) < 1e-6
        && Math.abs(ahead.r - item.r) < 1e-6) {
        ahead.x = next.x; ahead.y = next.y + 0.018; ahead.w = next.w; ahead.h = next.h; ahead.r = next.r;
      }
      item.x = next.x; item.y = next.y; item.w = next.w; item.h = next.h; item.r = next.r;
    });
    return base;
  }

  function drawIcon(svg) {
    var tag = svg.dataset.tag;
    var parts = FRAME.map(function (f) {
      return { z: f[8], html: rectOf(f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[9]) };
    });
    currentShapes(tag).forEach(function (item) {
      var x = 0.5 + (item.x - 0.5) * INSET;
      var y = 0.5 + (item.y - 0.5) * INSET;
      parts.push({ z: item.z, html: rectOf(x, y, item.w * INSET, item.h * INSET, item.r,
                                           item.c, item.k, item.s * INSET, item.a) });
    });
    parts.sort(function (a, b) { return a.z - b.z; });
    svg.innerHTML = parts.map(function (part) { return part.html; }).join("");
    svg.style.background = "#4e5058";
  }

  function drawAllIcons() {
    document.querySelectorAll("svg.prev").forEach(drawIcon);
  }
  drawAllIcons();





  //=== 카드 글의 키워드 (요청) ===//

  /*
    글에 적힌 `[낱말]`을 **그 키워드의 색으로** 칠하고, 수치를 붙일 수 있는
    낱말이면 아래에 레벨 선택 + % 입력을 띄운다. 레벨마다 값을 따로 정한다.

    사전에 없는 낱말은 붉은 물결로 표시한다 — 오타를 그 자리에서 알아채야
    나중에 "왜 색이 안 붙지"를 헤매지 않는다.
  */
  var KEYWORDS = [];
  try { KEYWORDS = JSON.parse(document.getElementById("keywords").textContent); } catch (e) {}
  var kwByName = {};
  var kwById = {};
  KEYWORDS.forEach(function (k) { kwByName[k.name] = k; kwById[k.id] = k; });

  function esc(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  // 뒤 층에 색칠한 글을 그린다.
  function paintHighlight(area) {
    var back = area.parentNode.querySelector(".hlback");
    if (!back) return;
    var html = esc(area.value).replace(/\[([^\x5d]+)\x5d/g, function (whole, name) {
      var keyword = kwByName[name];
      if (!keyword) return '<span class="kwmark bad">[' + esc(name) + "]</span>";
      return '<span class="kwmark" style="color:' + keyword.color + ';background:'
        + keyword.color + '22">[' + esc(name) + "]</span>";
    });
    // 마지막 줄이 개행이면 높이가 한 줄 모자라 보인다.
    back.innerHTML = html + "\n";
    syncScroll(area);
  }

  /*
    두 층의 스크롤을 맞춘다.

    글이 길어지면 브라우저가 **입력을 처리한 뒤에** textarea 를 커서 쪽으로 스크롤한다.
    그래서 이 자리에서 한 번 맞추는 것만으로는 늦고, 다음 프레임에 한 번 더 맞춘다.
    안 그러면 아래층만 위에 머물러 글이 통째로 어긋나 보인다.
  */
  function syncScroll(area) {
    var back = area.parentNode.querySelector(".hlback");
    if (!back) return;
    back.scrollTop = area.scrollTop;
    back.scrollLeft = area.scrollLeft;
    function again() {
      back.scrollTop = area.scrollTop;
      back.scrollLeft = area.scrollLeft;
    }
    // rAF 는 탭이 가려지면 돌지 않는다. 타이머로 한 번 더 받쳐 둔다.
    requestAnimationFrame(again);
    setTimeout(again, 0);
  }

  /*
    카드의 사다리는 슬롯 번호로 저장된다. 이 카드에서 그 키워드가 몇 번 슬롯인지
    찾는다 — `LevelKeywords`를 편집기가 들고 있지 않으므로, 이미 화면에 있는
    사다리의 키워드 선택칸에서 읽는다.
  */
  // 이 낱말을 이은 슬롯 전부를(순서대로) 돌려준다 — 글에 같은 낱말이 여러 번
  // 나올 때, 몇 번째로 나왔는지에 맞는 슬롯을 고르려면 전부 알아야 한다.
  function slotsOfKeyword(cardId, keywordId) {
    var picks = document.querySelectorAll('[data-scope="cardKeywords"][data-key^="'
      + CSS.escape(cardId) + '#"]');
    var slots = [];
    for (var i = 0; i < picks.length; i++) {
      // 한 슬롯에 여럿이 이어질 수 있다("Id1,Id2") — 정확히 같은지가 아니라 포함되는지를 본다.
      var ids = picks[i].value ? picks[i].value.split(",") : [];
      if (ids.indexOf(keywordId) >= 0) slots.push(picks[i].dataset.key.split("#")[1]);
    }
    return slots;
  }

  function levelBoxes(cardId, slot) {
    return document.querySelectorAll('[data-scope="cardLevels"][data-key="'
      + CSS.escape(cardId) + '"][data-slot="' + slot + '"]');
  }

  /*
    **가운데 중괄호를 지우면(또는 새로 끼우면) 그 뒤 번호가 통째로 밀린다.**

    슬롯 번호는 "몇 번째 중괄호인가"일 뿐이다. 예전에는 지워진 자리를 항상
    **맨 뒤** 번호로 취급해 지웠다 — `{2}`와 `{5}`가 있을 때 앞의 `{2}`를 지우면
    실제로는 `{2}`의 사다리가 `{5}`의 값을 물려받고, 뒤에 남아야 할 `{5}`의
    사다리가 대신 사라졌다(요청한 버그).

    직전 글과 지금 글을 비교해 **어디가 바뀌었는지**(공통 앞부분·뒷부분을 뺀
    가운데)를 찾고, 그 자리의 중괄호 개수가 늘거나 준 만큼 뒤쪽 슬롯 번호를
    통째로 밀거나 당긴다. 값 자체는 안 건드리고 이름표(슬롯 번호)만 옮기므로
    안 지워진 사다리의 내용은 그대로 남는다.
  */
  function reshapeLaddersForTextChange(cardId, oldText, newText) {
    var minLen = Math.min(oldText.length, newText.length);
    var i = 0;
    while (i < minLen && oldText[i] === newText[i]) i++;
    var j = 0;
    while (j < minLen - i
      && oldText[oldText.length - 1 - j] === newText[newText.length - 1 - j]) j++;

    var braceRe = /\{[0-9.]+\}/g;
    var oldBefore = (oldText.slice(0, i).match(braceRe) || []).length;
    var oldMid = (oldText.slice(i, oldText.length - j).match(braceRe) || []).length;
    var newMid = (newText.slice(i, newText.length - j).match(braceRe) || []).length;
    var delta = newMid - oldMid;
    // 바뀐 폭이 크면(불러오기·붙여넣기 등) 한 번의 편집으로 보기 어렵다 —
    // 그럴 땐 건드리지 않고 아래의 "범위 밖 지우기"에 맡긴다.
    if (delta === 0 || Math.abs(delta) > 5) return;

    var card = document.querySelector('.card[data-id="' + CSS.escape(cardId) + '"]');
    if (!card) return;
    var editStart = oldBefore + 1;
    var removeCount = delta < 0 ? -delta : 0;
    var removeTo = editStart + removeCount - 1;

    var ladders = card.querySelector(".ladders");
    if (ladders) {
      Array.from(ladders.querySelectorAll(".ladder")).forEach(function (row) {
        var slot = Number(row.dataset.slot);
        if (slot >= editStart && slot <= removeTo) row.remove();
      });
      var rows = Array.from(ladders.querySelectorAll(".ladder")).sort(function (a, b) {
        var diff = Number(a.dataset.slot) - Number(b.dataset.slot);
        return delta > 0 ? -diff : diff;
      });
      rows.forEach(function (row) {
        var slot = Number(row.dataset.slot);
        if (slot <= removeTo) return;
        var next = slot + delta;
        row.dataset.slot = String(next);
        var brace = row.querySelector("b");
        if (brace) brace.textContent = "{" + next + "}";
        row.querySelectorAll(".lv").forEach(function (input) { input.dataset.slot = String(next); });
      });
    }

    document.querySelectorAll('[data-scope="cardKeywords"][data-key^="'
      + CSS.escape(cardId) + '#"]').forEach(function (pick) {
      var slot = Number(pick.dataset.key.split("#")[1]);
      if (slot >= editStart && slot <= removeTo) { pick.remove(); return; }
      if (slot > removeTo) pick.dataset.key = cardId + "#" + (slot + delta);
    });
  }

  /*
    글 아래 **슬롯 줄**을 다시 그린다.

    중괄호 하나가 슬롯 하나다. 슬롯마다 "무엇의 값인가"(키워드)와 "레벨별 얼마"를
    그 자리에서 정한다. 글에 있지만 슬롯과 이어지지 않은 낱말은 색 칩으로만 둔다.
  */
  function paintKeywordBar(area) {
    var bar = area.closest("label").querySelector(".kwbar");
    if (!bar) return;
    var card = area.closest(".card");
    if (!card) { bar.innerHTML = ""; return; }
    var cardId = card.dataset.id;
    var maxLevel = maxLevelOf(cardId);

    // 중괄호를 순서대로 모은다. 안의 숫자는 레벨 1의 값으로 본다.
    var braces = area.value.match(/\{[0-9.]+\}/g) || [];

    /*
      **`lastText`를 먼저 갈아 끼운 뒤에 옮긴다.**

      `paintKeywordBar`가 한 번의 입력에 두 번 불릴 때가 있다(`input` 리스너가
      여럿이라 서로 물려 재진입한다). 갱신을 나중에 하면 두 번째 호출이 아직
      낡은 `lastText`를 보고 **같은 자리를 두 번** 옮기려다 값을 잃었다(요청한
      버그: "{2}를 지웠는데 {5} 설정이 먼저 사라져"). 먼저 갈아 끼워 두면 재진입한
      호출은 "달라진 게 없다"고 보고 조용히 넘어간다.
    */
    var prevText = area.dataset.lastText;
    area.dataset.lastText = area.value;
    if (prevText !== undefined && prevText !== area.value) {
      reshapeLaddersForTextChange(cardId, prevText, area.value);
    }

    /*
      **중괄호를 지우면 그 슬롯 설정도 바로 사라진다** (요청).

      슬롯 번호는 중괄호가 글에 나온 순서다. 위 `reshapeLaddersForTextChange`가
      가운데 지워진 자리를 알아서 당기지만, 큰 폭으로 바뀌어 그게 손을 놓은
      경우(불러오기 등)를 대비해 범위 밖에 남은 칸은 여기서 마저 지운다.
    */
    var ladders = card.querySelector(".ladders");
    if (ladders) {
      ladders.querySelectorAll(".ladder").forEach(function (row) {
        if (Number(row.dataset.slot) > braces.length) row.remove();
      });
    }
    document.querySelectorAll('[data-scope="cardKeywords"][data-key^="'
      + CSS.escape(cardId) + '#"]').forEach(function (pick) {
      var slotNum = Number(pick.dataset.key.split("#")[1]);
      if (slotNum > braces.length) pick.remove();
    });

    var levels = "";
    for (var i = 1; i <= maxLevel; i++) levels += '<option value="' + i + '">Lv' + i + "</option>";

    var chips = braces.map(function (brace, index) {
      var slot = index + 1;
      var shown = brace.slice(1, -1);
      /*
        **사각형은 중괄호를 치는 순간 생긴다** (요청).

        예전에는 이 칩의 값 칸을 건드려야 비로소 레벨별 사각형이 생겼다. 이제
        글에 `{n}`이 나타나는 즉시 그 자리에 레벨 수만큼 사각형을 채워 둔다 —
        값은 전부 지금 친 숫자로 시작하고, 레벨마다 원하는 만큼 고쳐 쓴다.
      */
      ensureLadder(cardId, slot, maxLevel, shown);
      return '<span class="kwchip slot">'
        + '<b class="brace">{' + esc(shown) + "}</b>"
        + '<select class="kwlv" data-card="' + cardId + '" data-slot="' + slot + '">' + levels + "</select>"
        + '<input class="kwval" type="number" step="any" data-card="' + cardId
        + '" data-slot="' + slot + '" data-level="1" value="' + esc(levelValue(cardId, slot, 1, shown)) + '"></span>';
    });

    /*
      **어떤 숫자가 무슨 뜻인지는 이제 글에 이은 낱말 색으로만 읽는다** (요청:
      "카드랑 숫자랑 잇는 기능은 굳이 없어도 문맥상 알아들을 수 있다"). 슬롯에
      낱말을 이어 붙이는 기능은 뺐다 — 값 칸(위)은 그대로 남는다.
    */
    var seen = {};
    (area.value.match(/\[([^\x5d]+)\x5d/g) || []).forEach(function (mark) {
      var name = mark.slice(1, -1);
      if (seen[name] || !kwByName[name]) return;
      seen[name] = true;
      var keyword = kwByName[name];
      chips.push('<span class="kwchip flat" style="border-color:' + keyword.color + '66">'
        + '<span class="nm" style="color:' + keyword.color + '">' + esc(name) + "</span></span>");
    });

    bar.innerHTML = chips.join("");
    /*
      방금 만든 사각형은 아직 "수정됨" 표시·저장 목록에 안 잡혀 있다.
      `refresh()`가 `fieldList()`를 다시 훑어야 새 칸이 그 안에 들어간다.
    */
    refresh();
  }

  /*
    슬롯의 그 레벨 값.

    이미 있는 사다리 칸이 있으면 그 값을, 없으면 중괄호에 적힌 값을 쓴다.
    (중괄호를 새로 감쌌을 때는 아직 사다리가 없다)
  */
  function levelValue(cardId, slot, level, fallback) {
    var boxes = levelBoxes(cardId, slot);
    if (boxes.length >= level) return boxes[level - 1].value;
    return fallback;
  }

  //=== 카드별 최대 레벨 (요청) ===//

  /*
    이 카드가 지금 쓰는 레벨 상한. 등급표(필수 2 · 희귀·일반 6)가 서버가 처음
    채워 넣는 값이고, "최대 레벨" 칸을 고치면 그 카드만 다른 값을 쓴다. 사다리
    길이·Lv 선택 칸 수를 정하는 **단 하나의 출처**다.
  */
  function maxLevelOf(cardId) {
    var el = document.querySelector('[data-scope="cards"][data-key="' + CSS.escape(cardId) + '"][data-field="MaxLevel"]');
    var value = el ? parseInt(el.value, 10) : NaN;
    return value > 0 ? value : 6;
  }

  /*
    사다리 길이를 새 최대 레벨에 맞춘다.

    늘어나면 **마지막 칸 값을 이어서** 채운다 — 빈 칸(0)보다 지금 흐름을 그대로
    끄는 편이 고치기 쉽다. 줄어들면 뒤쪽 칸을 지운다. `fieldList`는 그때그때
    다시 훑으므로 지우거나 늘려도 저장·되돌리기가 따로 손볼 게 없다.
  */
  function resizeLadder(cardId, slot, newMax) {
    var boxes = levelBoxes(cardId, slot);
    if (boxes.length === 0 || boxes.length === newMax) return;
    if (boxes.length > newMax) {
      for (var i = boxes.length - 1; i >= newMax; i--) boxes[i].remove();
      return;
    }
    var row = boxes[0].closest(".ladder");
    if (!row) return;
    var seed = boxes[boxes.length - 1].value;
    for (var level = boxes.length + 1; level <= newMax; level++) {
      var input = document.createElement("input");
      input.className = "lv";
      input.type = "number";
      input.step = "any";
      input.value = seed;
      input.dataset.scope = "cardLevels";
      input.dataset.key = cardId;
      input.dataset.slot = String(slot);
      input.dataset.level = String(level);
      input.dataset.orig = "";
      input.title = "레벨 " + level;
      row.appendChild(input);
    }
  }

  function ensureLadder(cardId, slot, maxLevel, seedValue) {
    var boxes = levelBoxes(cardId, slot);
    /*
      이미 사다리가 있는데 최대 레벨이 그 뒤에 바뀌었으면(다른 사람의 realtime
      수정 등, `assign()`은 칸 값만 조용히 바꿔서 사람이 직접 고칠 때 쓰는
      `resizeLadder` 경로를 안 탄다) 길이를 맞춘다 — 요청한 버그: "레벨 버그
      또 생겼어"(최대 레벨은 2인데 사다리는 6칸 그대로).
    */
    if (boxes.length > 0) {
      resizeLadder(cardId, slot, maxLevel);
      return levelBoxes(cardId, slot);
    }
    var card = document.querySelector('.card[data-id="' + CSS.escape(cardId) + '"]');
    var host = card.querySelector(".ladders");
    if (!host) {
      host = document.createElement("div");
      host.className = "ladders";
      card.querySelector(".kwbar").before(host);
    }
    var row = document.createElement("div");
    row.className = "ladder";
    row.dataset.slot = String(slot);
    var cells = '<b>{' + slot + "}</b>";
    for (var i = 1; i <= maxLevel; i++) {
      /*
        `data-orig`을 **씨앗 값과 같게** 둔다 (요청한 버그: "3542칸 수정됨").

        중괄호를 씌운 뒤로 카드를 열기만 해도 사다리가 저절로 생기는데,
        예전에는 원래 값을 빈 문자열로 두어 그 3천여 칸이 전부 "수정됨"으로
        잡혔다 — 진짜 고친 것이 그 속에 묻혔고, 내려받는 JSON에도 그대로
        딸려 나갔다.

        모든 레벨이 글의 중괄호 값과 같은 사다리는 **사다리가 없는 것과 완전히
        같다** — `Describe`가 사다리를 못 찾으면 중괄호 안 숫자를 그대로 쓴다.
        그러니 "안 고친 것"으로 보는 게 맞다. 한 칸이라도 손대면 그때 수정됨이 된다.
      */
      cells += '<input class="lv" type="number" step="any" value="' + seedValue + '"'
        + ' data-scope="cardLevels" data-key="' + esc(cardId) + '" data-slot="' + slot + '"'
        + ' data-level="' + i + '" data-orig="' + esc(String(seedValue)) + '" title="레벨 ' + i + '">';
    }
    row.innerHTML = cells;
    host.appendChild(row);
    return levelBoxes(cardId, slot);
  }

  /*
    **모든 카드의 사다리 칸만** 만든다 — 칠하기(문법 강조·미리보기)는 건드리지
    않는다.

    `restore()`(불러오기)가 값을 씌우려면 사다리 칸이 있어야 하는데, 칠하기까지
    306장 전부 다시 하면 첫 로딩 최적화가 무의미해진다. 사다리 칸 자체는 만드는
    비용이 훨씬 싸므로, 이것만 전부 만들고 칠하기는 화면에 보일 때(스크롤)
    그대로 미룬다.
  */
  function ensureAllLadders() {
    document.querySelectorAll(".card").forEach(function (card) {
      var area = card.querySelector("textarea.hltext");
      var cardId = card.dataset.id;
      if (!area || !cardId) return;
      var maxLevel = maxLevelOf(cardId);
      (area.value.match(/\{[0-9.]+\}/g) || []).forEach(function (brace, index) {
        ensureLadder(cardId, index + 1, maxLevel, brace.slice(1, -1));
      });
    });
  }

  //=== 레벨 미리보기 (요청: "선택한 카드 레벨을 직접 바꿀 수 있는 기능") ===//

  /*
    `AbilityCardDefinitions.Describe`와 같은 계산이다.
      `{n}`     그 슬롯 사다리의, 고른 레벨 값으로 바뀐다.
      `[낱말]`   사다리가 이어져 있으면 "낱말 값단위"로, 아니면 대괄호만 벗는다.
    사다리가 아직 없는 슬롯(방금 친 숫자)은 글에 적힌 값을 그대로 보여준다.
  */
  function substitutedText(card, level) {
    var area = card.querySelector("textarea.hltext");
    if (!area) return "";
    var slot = 0;
    var text = area.value.replace(/\{([0-9.\-]+)\}/g, function (whole, shown) {
      slot++;
      var boxes = levelBoxes(card.dataset.id, slot);
      var box = boxes[level - 1];
      return box ? box.value : shown;
    });
    var keywordOccurrence = {};
    text = text.replace(/\[([^\x5d]+)\x5d/g, function (whole, name) {
      var keyword = kwByName[name];
      if (!keyword) return whole;
      var slots = slotsOfKeyword(card.dataset.id, keyword.id);
      var n = (keywordOccurrence[keyword.id] || 0);
      keywordOccurrence[keyword.id] = n + 1;
      var linkedSlot = slots[n];
      if (!linkedSlot) return name;
      var boxes = levelBoxes(card.dataset.id, linkedSlot);
      var box = boxes[level - 1];
      if (!box) return name;
      return name + " " + box.value + (keyword.unit || "");
    });
    return text;
  }

  /*
    실제 게임 클라이언트(`TowerBattleController:_breakSentences`)와 같은 규칙 —
    문장 끝에서 줄을 바꾼다.
  */
  function breakSentencesLikeGame(text) {
    return text.replace(/([다요])\.\s+/g, "$1.\n").replace(/(\.)\s+/g, "$1\n").replace(/\s+$/, "");
  }

  /*
    실제 게임 클라이언트(`TowerBattleController:_highlightNumbers`)와 같은
    규칙으로 색을 입힌다 — 미리보기가 인게임과 다르게 보이면 편집기가 거짓말을
    하는 셈이다(요청: "미리보기에서도 실제 인게임에 보이는것처럼").

    숫자·퍼센트는 노랑, `[키워드]`는 하늘색 — 실제 게임이 쓰는 RGB와 같다.
    백틱으로 감싼 스킬 이름(예: `크레셴도`)은 굵게, 백틱 자체는 지운다 — 게임
    쪽도 이번에 같이 고쳤다(요청한 버그: "스킬도 `크레셴도`같이 써져").
  */
  function highlightForPreview(text) {
    var escaped = esc(text);
    var keywords = [];
    escaped = escaped.replace(/(\[[^\x5d]+\])/g, function (whole) {
      keywords.push(whole);
      return "" + "K".repeat(keywords.length) + "";
    });
    var skills = [];
    escaped = escaped.replace(/`([^`]+)`/g, function (whole, name) {
      skills.push(name);
      return "" + "S".repeat(skills.length) + "";
    });
    escaped = escaped.replace(/(\d+\.?\d*%?)/g, '<b style="color:#ffcd5a">$1</b>');
    keywords.forEach(function (kw, index) {
      escaped = escaped.replace("" + "K".repeat(index + 1) + "",
        '<span style="color:#78c8ff">' + kw + "</span>");
    });
    skills.forEach(function (name, index) {
      escaped = escaped.replace("" + "S".repeat(index + 1) + "", "<b>" + name + "</b>");
    });
    return escaped;
  }

  function renderPreview(card) {
    var pick = card.querySelector(".cardlv");
    var out = card.querySelector(".lvprev");
    if (!pick || !out) return;
    var text = breakSentencesLikeGame(substitutedText(card, Number(pick.value) || 1));
    out.innerHTML = highlightForPreview(text);
  }

  document.addEventListener("change", function (event) {
    var el = event.target;
    if (!el.classList || !el.classList.contains("cardlv")) return;
    var card = el.closest(".card");
    // 슬롯마다 따로였던 Lv 선택을 전부 고른 레벨로 맞춘다 — 그래야 사다리 칸도
    // 같은 레벨의 값을 보여주고, 그 자리에서 고칠 수 있다.
    card.querySelectorAll(".kwlv").forEach(function (lv) {
      if (lv.value !== el.value) {
        lv.value = el.value;
        lv.dispatchEvent(new Event("change", { bubbles: true }));
      }
    });
    renderPreview(card);
  });

  function refreshCardText(area) {
    area.dataset.painted = "1";
    paintHighlight(area);
    paintKeywordBar(area);
    autoGrowTextarea(area);
    var card = area.closest(".card");
    if (card) renderPreview(card);
  }

  /*
    카드 306장을 한 번에 다 칠하면(문법 강조 + 슬롯 줄) 첫 로딩이 오래 걸린다 —
    화면 밖 카드는 스크롤로 다가올 때 칠한다. "전체" 탭이 기본값이라 필터로는
    수를 줄일 수 없어서, 실제로 보이는지(IntersectionObserver)로 나눈다.
  */
  var paintObserver = ("IntersectionObserver" in window)
    ? new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          paintObserver.unobserve(entry.target);
          var area = entry.target.querySelector("textarea.hltext");
          if (area) refreshCardText(area);
        });
      }, { rootMargin: "400px 0px" })
    : null;

  /*
    **손으로 늘리는 대신, 글대로 저절로 늘고 준다** (요청: "줄바꿈 인식해서
    칸이 커지거나 작아지게, 스크롤 막대는 없애줘").

    손으로 늘린 크기를 기억해 두는 자리였는데, 그보다 아예 **칸이 글 길이를
    따라가면** 늘렸다 잊는 일도, 새로고침 때마다 안 맞는 일도 없어진다.
    한 줄이 몇 줄인지는 글꼴·폭마다 달라 미리 셀 수 없다 — 높이를 `auto`로
    비웠다 `scrollHeight`(실제로 필요한 높이)를 읽어 그대로 씌우는, 자동 늘림
    칸의 표준 수법을 쓴다. `auto`로 비우는 순서가 중요하다 — 안 비우면 글을
    지워도 이전의 큰 높이가 그대로 남아 줄어들지 않는다.
  */
  function autoGrowTextarea(area) {
    area.style.height = "auto";
    area.style.height = area.scrollHeight + "px";
  }

  document.querySelectorAll("textarea.hltext").forEach(function (area) {
    area.addEventListener("scroll", function () { syncScroll(area); });
  });

  if (paintObserver) {
    document.querySelectorAll(".card").forEach(function (card) { paintObserver.observe(card); });
    /*
      **카드 밖의 `.hltext`는 늦출 이유가 없다** (요청한 버그: "새로고침 하면
      키워드·직업 설명이 안 보여").

      `.hltext`는 글자색이 투명이고 뒤에 깔린 `.hlback`이 실제로 보이는 색을
      그린다 — 칠(`refreshCardText`)이 안 된 칸은 값이 멀쩡히 들어 있어도
      화면엔 빈 칸으로 보인다. 카드 306장은 스크롤로 다가올 때 칠하는 게
      맞지만, 키워드(40여 개)·직업(9개) 탭의 설명 칸은 `.card`에 안 담겨
      있어 그 관찰 대상에서 통째로 빠져 있었다 — 수도 적으니 그냥 바로 칠한다.
    */
    document.querySelectorAll("textarea.hltext").forEach(function (area) {
      if (!area.closest(".card")) refreshCardText(area);
    });
  } else {
    document.querySelectorAll("textarea.hltext").forEach(refreshCardText);
  }

  /*
    키워드 줄은 **사다리 칸의 얼굴**이다. 여기서 고친 값은 그 레벨의 사다리 칸에
    그대로 들어가고, 사다리 칸을 직접 고쳐도 여기 값이 따라온다. 값이 두 곳에
    따로 살면 어느 쪽이 진짜인지 알 수 없어진다.
  */
  document.addEventListener("input", function (event) {
    var el = event.target;
    if (el.classList && el.classList.contains("hltext")) {
      refreshCardText(el);
      return;
    }
    if (el.classList && el.classList.contains("kwval")) {
      var card = el.closest(".card");
      var maxLevel = card ? maxLevelOf(card.dataset.id) : 6;
      // 씨앗은 글의 중괄호 값이다. 지금 고치는 레벨의 값으로 전 레벨을 덮으면 안 된다.
      var brace = el.closest(".kwchip").querySelector(".brace");
      var seed = brace ? brace.textContent.replace(/[{}]/g, "") : el.value;
      var boxes = ensureLadder(el.dataset.card, el.dataset.slot, maxLevel, seed);
      var box = boxes[Number(el.dataset.level) - 1];
      if (box) {
        box.value = el.value;
        box.dispatchEvent(new Event("input", { bubbles: true }));
      }
    }
  });

  document.addEventListener("change", function (event) {
    var el = event.target;
    if (!el.classList || !el.classList.contains("kwlv")) return;
    // 레벨을 바꾸면 그 레벨의 값이 입력칸에 뜬다.
    var chip = el.closest(".kwchip");
    var value = chip.querySelector(".kwval");
    var boxes = levelBoxes(el.dataset.card, el.dataset.slot);
    var box = boxes[Number(el.value) - 1];
    value.dataset.level = el.value;
    value.value = box ? box.value : "";
  });

  // 사다리 칸을 직접 고쳤을 때 키워드 줄도 따라오게 한다.
  function syncKeywordBars(cardId) {
    document.querySelectorAll('.card[data-id="' + CSS.escape(cardId) + '"] .kwchip').forEach(function (chip) {
      var value = chip.querySelector(".kwval");
      if (!value) return;
      var boxes = levelBoxes(value.dataset.card, value.dataset.slot);
      var box = boxes[Number(value.dataset.level) - 1];
      if (box && document.activeElement !== value) value.value = box.value;
    });
  }

  //=== 자동 감싸기 (요청) ===//

  /*
    글을 치는 동안 **뜻이 있는 말을 자동으로 감싼다.**

      키워드      [가하는 피해량 증가]
      숫자        {3}  {1.2}   (소수도 된다)
      스킬 이름   `다지기`

    감싼 뒤 커서는 **닫는 기호 바깥**에 둔다. 안에 남으면 이어 친 글자가 괄호
    속으로 들어간다(요청: "괄호 안에 글씨를 또 쓰는 일이 없어야 함").

    이미 감싸진 것은 건드리지 않는다.
  */
  var SKILLNAMES = [];
  try { SKILLNAMES = JSON.parse(document.getElementById("skillnames").textContent); } catch (e) {}

  var TICK = String.fromCharCode(96);

  // 긴 이름부터 본다. "가하는 피해량 증가"가 "피해량"보다 먼저 잡혀야 한다.
  var WRAPS = [];
  KEYWORDS.forEach(function (k) { WRAPS.push({ text: k.name, open: "[", close: "]" }); });
  SKILLNAMES.forEach(function (n) { WRAPS.push({ text: n, open: TICK, close: TICK }); });
  WRAPS.sort(function (a, b) { return b.text.length - a.text.length; });

  // 그 자리가 이미 어떤 기호 안인지. 안이면 감싸지 않는다.
  function insideWrapper(text, at) {
    var ticks = 0;
    for (var i = 0; i < at; i++) if (text[i] === TICK) ticks++;
    if (ticks % 2 === 1) return true;

    var pairs = [ ["[", "]"], ["{", "}"] ];
    for (var k = 0; k < pairs.length; k++) {
      var open = pairs[k][0], close = pairs[k][1];
      var back = text.lastIndexOf(open, at - 1);
      if (back < 0) continue;
      var shut = text.indexOf(close, back);
      if (shut < 0 || shut >= at) return true;
    }
    return false;
  }

  /*
    커서 바로 왼쪽에서 감쌀 것을 찾는다.
    돌려주는 것은 [시작, 끝, 여는 기호, 닫는 기호] 이다.
  */
  /*
    `mode`: 안 주면 낱말·숫자 둘 다 본다.
      "numbers"  숫자만 본다 — 카드 글의 "한 글자 물러나 돌아보는" 자리 전용.
                 낱말은 "다 친 그 순간"에만 감싸야 하는데, 그 자리에서도 낱말을
                 찾다 보니 이미 감싼 낱말 뒤에 방금 친 글자가 겹쳐 보이던 버그가
                 있었다(요청: "[가하는 피해량]량"으로 써짐).
      "words"    낱말만 본다 — 숫자는 안 본다. 카드 밖(키워드·직업 능력)에는
                 "레벨"이 없어 `{n}`이 아무 뜻도 없다(요청: "숫자에 중괄호
                 써지지 않게").
  */
  function findWrap(text, at, mode) {
    if (at <= 0 || insideWrapper(text, at)) return null;

    if (mode !== "numbers") {
      // 낱말·스킬 이름
      for (var i = 0; i < WRAPS.length; i++) {
        var w = WRAPS[i];
        var from = at - w.text.length;
        if (from < 0) continue;
        if (text.slice(from, at) !== w.text) continue;
        return [from, at, w.open, w.close];
      }
    }
    if (mode === "words") return null;

    // 숫자. 유리수도 받는다 (1, 1.2, 0.5).
    var start = at;
    while (start > 0 && /[0-9.]/.test(text[start - 1])) start--;
    if (start === at) return null;
    var chunk = text.slice(start, at);
    if (!/^[0-9]+(\.[0-9]+)?$/.test(chunk)) return null;
    // 앞이 글자면 낱말의 일부다 (예: 16분음표).
    if (start > 0 && /[0-9A-Za-z가-힣]/.test(text[start - 1])) return null;
    return [start, at, "{", "}"];
  }

  // 주어진 글에서 한 번 감싼 결과. 못 감싸면 null.
  function wrapAt(text, at, mode) {
    var found = findWrap(text, at, mode);
    if (!found) return null;
    var from = found[0], to = found[1], open = found[2], close = found[3];
    return {
      text: text.slice(0, from) + open + text.slice(from, to) + close + text.slice(to),
      caret: to + open.length + close.length
    };
  }

  /*
    언제 감싸나.

    낱말·스킬은 **다 친 그 순간**. 숫자는 뒤에 숫자가 더 올 수 있으므로 숫자가
    아닌 글자를 친 **다음**에 그 앞을 돌아본다.
  */
  /*
    **괄호를 직접 칠 때는 반대쪽 하나만 넣는다** (요청).

    예전에는 닫는 대괄호를 치면 그 앞의 낱말을 양쪽 다 감싸 버려서, 방금 친
    그 괄호가 갈 곳을 잃고 뒤에 하나 더 남는 찌꺼기가 됐다.
    (여기 그 예를 그대로 적을 수 없다 — 닫는 대괄호 두 개는 이 Luau 긴 문자열을
    그 자리에서 끝내 버린다.)

      닫는 괄호를 치면  →  **여는 괄호만** 낱말 앞에 넣는다
      여는 괄호를 치면  →  **닫는 괄호만** 커서 뒤에 넣고 그 사이에 커서를 둔다
  */
  var OPENER_FOR = { "]": "[", "}": "{" };
  var CLOSER_FOR = { "[": "]", "{": "}" };

  function applyEdit(area, text, caret) {
    area.value = text;
    area.setSelectionRange(caret, caret);
    area.dispatchEvent(new Event("input", { bubbles: true }));
  }

  /*
    **한글은 조합 중에 건드리지 않는다** (요청한 버그: "키워드 쓸 때 중복해서
    써짐").

    한글은 자모가 모여 한 음절이 될 때까지 `compositionstart`~`compositionend`
    사이 여러 단계를 거친다. 그 중간 단계에서도 `keyup`은 계속 뜨는데, 그때의
    `textarea.value`는 아직 다 갖춰지지 않은 상태다 — 그 자리에서 낱말을
    찾아 감싸 버리면, 음절이 마저 완성되는 다음 단계에서 또 한 번 낱말로
    잡혀 두 번 감싸이거나 글자가 겹쳐 보였다. 조합이 끝난 뒤(`compositionend`)
    한 번만 보면 이 문제가 없다. 괄호·숫자처럼 조합 없이 바로 찍히는 글자는
    그대로 `keyup`에서 본다.
  */
  var composing = false;
  document.addEventListener("compositionstart", function (event) {
    if (event.target.classList && event.target.classList.contains("hltext")) composing = true;
  });
  document.addEventListener("compositionend", function (event) {
    composing = false;
    runAutoWrap(event.target);
  });

  function runAutoWrap(area) {
    if (!area.classList || !area.classList.contains("hltext")) return;
    if (area.selectionStart !== area.selectionEnd) return;

    // 카드 밖(키워드·직업 능력)에는 "레벨"이 없다 — 숫자는 감싸지 않는다(요청).
    var wordMode = area.closest(".card") ? undefined : "words";

    var at = area.selectionStart;
    var text = area.value;
    var typed = text[at - 1] || "";

    /*
      여는 괄호를 쳤다. 짝만 뒤에 붙이고 커서는 괄호 사이에 둔다 — 이어서 치는
      글자가 바로 괄호 안으로 들어간다. 이미 짝이 있으면 두 번 넣지 않는다.
    */
    if (CLOSER_FOR[typed]) {
      if (wordMode === "words" && typed === "{") return;
      var closer = CLOSER_FOR[typed];
      if (text[at] === closer) return;
      applyEdit(area, text.slice(0, at) + closer + text.slice(at), at);
      return;
    }

    /*
      닫는 괄호를 쳤다. 그 앞의 낱말·숫자를 찾아 **여는 괄호만** 앞에 넣는다.
      방금 친 닫는 괄호가 그대로 짝이 된다.
    */
    if (OPENER_FOR[typed]) {
      if (wordMode === "words" && typed === "}") return;
      var head = text.slice(0, at - 1);
      var spot = findWrap(head, head.length, wordMode);
      if (!spot) return;
      var from = spot[0];
      applyEdit(area, text.slice(0, from) + OPENER_FOR[typed] + text.slice(from), at + 1);
      return;
    }

    /*
      **숫자를 치는 중이면 손대지 않는다.**
      "30"의 3에서 감싸 버리면 0이 괄호 밖으로 밀려 {3}0 이 된다.
      숫자가 아닌 글자를 친 뒤에야 그 앞의 숫자 전체를 감싼다.
    */
    if (/[0-9.]/.test(typed)) return;

    var done = null;
    // 방금 친 글자를 잠깐 떼고 그 앞을 본다 — 숫자 뒤에 %나 공백을 친 경우.
    var head2 = text.slice(0, at - 1);
    var wrapped = wrapAt(head2, head2.length, wordMode === "words" ? "words" : "numbers");
    if (wrapped) done = { text: wrapped.text + text.slice(at - 1), caret: wrapped.caret + 1 };
    if (!done) done = wrapAt(text, at, wordMode);
    if (!done) return;

    applyEdit(area, done.text, done.caret);
  }

  document.addEventListener("keyup", function (event) {
    var area = event.target;
    if (!area.classList || !area.classList.contains("hltext")) return;
    if (composing || event.isComposing) return;
    if (event.key && event.key.indexOf("Arrow") === 0) return;
    runAutoWrap(area);
  });


  //=== 그림 그리기 (요청) ===//

  /*
    도형을 **끌어다 놓아** 카드 그림을 만든다.

    좌표는 게임과 같은 0~1 공간이고, 저장하면 \`CardArtworks\` 에 들어간다.
    카드가 그 그림을 가리키면 태그 문양 대신 그것이 나온다 — 가리키지 않은 카드는
    예전대로라서 306장을 다 그리지 않아도 된다.

    액자와 바탕은 여기서 그리지 않는다. 등급을 보고 게임이 깔아 주므로, 여기서도
    미리보기로만 같은 것을 깔아 어떻게 보일지 맞춰 준다.
  */
  var TEMPLATES = {}, ARTWORKS = {}, CARDLIST = [];
  try { TEMPLATES = JSON.parse(document.getElementById("templates").textContent); } catch (e) {}
  try { ARTWORKS = JSON.parse(document.getElementById("artworks").textContent); } catch (e) {}
  try { CARDLIST = JSON.parse(document.getElementById("cardlist").textContent); } catch (e) {}

  var GRADE_BG = { Essential: "#60349a", Rare: "#264a96", Common: "#4e5058" };
  var GRADE_DISC = { Essential: "#341c54", Rare: "#142852", Common: "#2a2c30" };
  var ART_SCALE = ]] .. string.format("%.5f", CardArt.INSET) .. [[;

  /*
    **자동으로 깔리는 등급 장식**(요청: "너가 그린 이 카드처럼").

    `CardArt.luau`는 살(필수)·원판·테두리 링·귀퉁이 보석(필수)을 손으로
    그렸든 안 그렸든 **등급만 보고 모든 카드에 자동으로** 얹는다. 그림
    그리기 캔버스는 그걸 몰라서, 그리는 동안 화면과 실제 카드에 나오는
    결과가 달랐다 — 여기서 `CardArt.luau`와 같은 수식으로 그 자동 층을
    구해, 캔버스에는 **참고용(만질 수 없음)**으로 비쳐 보이게 하고 템플릿
    에는 넣지 않는다(넣으면 자동 층과 겹쳐 두 배로 진해진다).
  */
  var GRADE_CFG = {
    Essential: { rims: 2, spokes: 8, gems: true },
    Rare: { rims: 2, spokes: 0, gems: false },
    Common: { rims: 1, spokes: 0, gems: false }
  };
  var MEDALLION = 0.78;

  function scaleColor(hex, factor) {
    var r = parseInt(hex.slice(1, 3), 16), g = parseInt(hex.slice(3, 5), 16), b = parseInt(hex.slice(5, 7), 16);
    function ch(v) { return Math.max(0, Math.min(255, Math.floor(v * factor))).toString(16).padStart(2, "0"); }
    return "#" + ch(r) + ch(g) + ch(b);
  }

  function autoDecorShapes(g) {
    var cfg = GRADE_CFG[g] || GRADE_CFG.Common;
    var shapes = [];
    for (var i = 1; i <= cfg.spokes; i++) {
      shapes.push({ x: 0.5, y: 0.5, w: 0.05, h: 1.16, r: (i / cfg.spokes) * 180, c: "#ffffff", k: 0.5, s: 0, t: 0.78 });
    }
    shapes.push({ x: 0.5, y: 0.5, w: MEDALLION + 0.06, h: MEDALLION + 0.06, r: 0, c: "#ffffff", k: 0.5, s: 0, t: 0.72 });
    shapes.push({
      x: 0.5, y: 0.5, w: MEDALLION, h: MEDALLION, r: 0,
      c: scaleColor(GRADE_BG[g] || GRADE_BG.Common, 0.55), k: 0.5, s: 0, t: 0
    });
    for (var idx = 1; idx <= cfg.rims; idx++) {
      var size = MEDALLION + 0.02 - (idx - 1) * 0.12;
      shapes.push({ x: 0.5, y: 0.5, w: size, h: size, r: 0, c: "#ffffff", k: 0.5, s: 0.022, t: idx === 1 ? 0 : 0.55 });
    }
    if (cfg.gems) {
      [ [0.115, 0.115], [0.885, 0.115], [0.115, 0.885] ].forEach(function (spot) {
        shapes.push({ x: spot[0], y: spot[1], w: 0.1, h: 0.1, r: 45, c: "#ffffff", k: 0.04, s: 0, t: 0.25 });
        shapes.push({ x: spot[0], y: spot[1], w: 0.05, h: 0.05, r: 45, c: "#ffffff", k: 0.04, s: 0, t: 0 });
      });
    }
    /*
      **오른쪽 아래는 등급 보석이 아니라 "두 번째 태그" 자리다** (요청: "우하단
      마름모가 누락된 것 같다").

      `CardArt.luau`는 카드에 태그가 둘이면 그 태그 색으로 여기에 작은 마름모를
      더 얹는다 — 등급이 아니라 **카드마다** 다르므로 이 템플릿은 정확한 색을
      모른다. 회색으로 "여기 태그 배지가 올 수도 있다"만 옅게 비쳐 보인다 —
      태그가 하나뿐인 카드는 실제로 비어 있다.
    */
    shapes.push({ x: 0.855, y: 0.845, w: 0.2, h: 0.2, r: 45, c: "#9a9aa8", k: 0.06, s: 0, t: 0.55 });
    shapes.push({ x: 0.855, y: 0.845, w: 0.15, h: 0.15, r: 45, c: "#9a9aa8", k: 0.05, s: 0, t: 0.35 });
    return shapes;
  }

  function autoDecorHTML(g) {
    return autoDecorShapes(g).map(function (item) { return svgRectAt(item, -1, 1, true); }).join("");
  }

  var art = { shapes: [], picked: -1, id: "" };

  /*
    팔레트에서 꺼내는 도형들. 전부 사각형과 링으로 만든다(게임과 같은 제약).

    `Stroke`가 0보다 크면 속이 빈 도형이다 — `svgRectAt`이 그때
    `fill="none" stroke=...`으로 그린다. 원의 속 빈 짝이 `ring`이었는데,
    사각형·막대·마름모도 짝을 갖췄다(요청). 크기는 속이 찬 짝과 같게 두어
    나란히 놓고 비교하기 쉽게 했다. 막대만 조금 두껍게(0.1 → 0.14) 한다 —
    0.1 높이에 선 굵기 0.03이면 속이 거의 안 남아 찬 막대와 구별이 안 된다.
  */
  var STOCK = {
    rect:        { W: 0.34, H: 0.34, Corner: 0.06, Stroke: 0,     Rotation: 0 },
    circle:      { W: 0.34, H: 0.34, Corner: 0.5,  Stroke: 0,     Rotation: 0 },
    bar:         { W: 0.5,  H: 0.1,  Corner: 0.5,  Stroke: 0,     Rotation: 0 },
    diamond:     { W: 0.3,  H: 0.3,  Corner: 0.04, Stroke: 0,     Rotation: 45 },
    ring:        { W: 0.44, H: 0.44, Corner: 0.5,  Stroke: 0.035, Rotation: 0 },
    rectline:    { W: 0.34, H: 0.34, Corner: 0.06, Stroke: 0.03,  Rotation: 0 },
    barline:     { W: 0.5,  H: 0.14, Corner: 0.5,  Stroke: 0.03,  Rotation: 0 },
    diamondline: { W: 0.3,  H: 0.3,  Corner: 0.04, Stroke: 0.03,  Rotation: 45 }
  };

  function grade() { return document.getElementById("artGrade").value; }

  /*
    `scale`가 `ART_SCALE`(문양이 메달리온 안으로 줄어드는 비율)이면 손으로
    그린 문양, `1`이면 등급이 자동으로 까는 층(원판·테두리·살·보석 — 줄지
    않고 원래 크기 그대로 깔린다)이다. `auto`면 `data-shape`(고르기 대상)
    대신 클릭이 안 통하는 참고용 표시만 남긴다.
  */
  function svgRectAt(item, index, scale, auto) {
    var S = 200;
    var x = 0.5 + (item.x - 0.5) * scale, y = 0.5 + (item.y - 0.5) * scale;
    var w = item.w * scale * S, h = item.h * scale * S;
    var cx = x * S, cy = y * S;
    var a = 'x="' + (cx - w / 2) + '" y="' + (cy - h / 2) + '" width="' + w + '" height="' + h + '"';
    var rx = item.k * Math.min(w, h);
    if (rx > 0.05) a += ' rx="' + rx + '"';
    if (item.s > 0) a += ' fill="none" stroke="' + item.c + '" stroke-width="' + item.s * scale * S + '"';
    else a += ' fill="' + item.c + '"';
    if (item.t > 0) a += ' opacity="' + (1 - item.t) + '"';
    if (item.r) a += ' transform="rotate(' + item.r + ' ' + cx + ' ' + cy + ')"';
    return "<rect " + a + (auto ? ' class="autodecor" style="pointer-events:none"' : ' data-shape="' + index + '"') + "/>";
  }

  function svgRect(item, index) {
    return svgRectAt(item, index, ART_SCALE, false);
  }

  /*
    트레이싱용 배경 사진 (요청: "쌩 판에다 그리기 조금 빡센데, 사진같은거
    반투명하게 넣어서 트레이싱같은거 할 수 있게").

    `traceImage`는 데이터 URL 문자열(또는 없으면 null)이고, `art`·저장소
    어디에도 안 닿는다 — 이 파일 안의 지역 변수 하나뿐이다. 그래서 "저장된
    그림을 불러오기"·"카드에 넣기" 같은 다른 동작이 이 값을 볼 일이 자체가
    없다(요청: "넣은 사진은 반영 안 되게").
  */
  var traceImage = null;
  document.getElementById("traceFile").addEventListener("change", function (event) {
    var file = event.target.files && event.target.files[0];
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function () {
      traceImage = reader.result;
      drawCanvas();
    };
    reader.onerror = function () { alert("사진을 읽지 못했습니다."); };
    reader.readAsDataURL(file);
  });
  document.getElementById("traceOpacity").addEventListener("input", function () {
    if (traceImage) drawCanvas();
  });
  // 사진 크기(요청: "이미지 크기도 조절할 수 있게"). 100%가 카드를 딱 채우는 크기고, 중심을 기준으로 커지거나 준다.
  document.getElementById("traceScale").addEventListener("input", function () {
    if (traceImage) drawCanvas();
  });
  document.getElementById("traceClear").addEventListener("click", function () {
    traceImage = null;
    document.getElementById("traceFile").value = "";
    drawCanvas();
  });
  function traceLayerHTML() {
    if (!traceImage) return "";
    var opacity = document.getElementById("traceOpacity").value / 100;
    /*
      크기는 가운데를 고정점으로 키우거나 줄인다 — 100%가 액자를 딱 채우는
      200×200이고, 그보다 크게 하면 액자 밖은 어차피 clip-path가 잘라 낸다
      (그래서 카드 안쪽만 보고 맞추면 된다). 자체 비율은 `preserveAspectRatio`
      가 그대로 지킨다.
    */
    var scale = document.getElementById("traceScale").value / 100;
    var size = 200 * scale;
    var offset = (200 - size) / 2;
    return '<clipPath id="traceClip"><rect x="0" y="0" width="200" height="200" rx="80"/></clipPath>'
      + '<image href="' + traceImage + '" x="' + offset + '" y="' + offset
      + '" width="' + size + '" height="' + size + '"'
      + ' preserveAspectRatio="xMidYMid slice" opacity="' + opacity + '"'
      + ' clip-path="url(#traceClip)" style="pointer-events:none"/>';
  }

  // 게임과 같은 액자를 깐다. 무엇이 가려지는지 그리면서 알 수 있어야 한다.
  function frameOf(g) {
    return '<rect x="16" y="16" width="168" height="168" rx="84" fill="#ffffff" opacity="0.28"/>'
      + '<rect x="22" y="22" width="156" height="156" rx="78" fill="' + GRADE_DISC[g] + '"/>'
      + '<rect x="20" y="20" width="160" height="160" rx="80" fill="none" stroke="#ffffff" stroke-width="4.4"/>'
      + autoDecorHTML(g);
  }

  function drawCanvas() {
    var svg = document.getElementById("canvas");
    var g = grade();
    svg.style.background = GRADE_BG[g];
    var order = art.shapes.map(function (item, i) { return { item: item, i: i }; });
    order.sort(function (a, b) { return (a.item.z - b.item.z) || (a.i - b.i); });
    /*
      사진은 액자(원판이 불투명이라 사진이 그 뒤에 있으면 안 보인다) **위**,
      실제로 그리는 도형들 **아래**에 둔다 — 액자 윤곽과 반투명 사진을 같이
      보면서, 그 위에 도형을 얹어 트레이싱한다.
    */
    var body = frameOf(g) + traceLayerHTML() + order.map(function (e) { return svgRect(e.item, e.i); }).join("");

    /*
      고른 도형에 점선 상자 + **크기·기울기를 마우스로 다루는 손잡이** (요청).

      네 모서리는 크기, 위쪽에 뗀 손잡이는 회전이다. 손잡이는 도형을 그린
      좌표(회전 전) 그대로 그리고, 선택 상자와 똑같이 `rotate(r cx cy)`를
      씌운다 — 손잡이마다 회전된 위치를 따로 계산할 필요가 없다.
    */
    if (art.picked >= 0 && art.shapes[art.picked]) {
      var it = art.shapes[art.picked];
      var S = 200, INSET = ]] .. string.format("%.5f", CardArt.INSET) .. [[;
      var cx = (0.5 + (it.x - 0.5) * INSET) * S, cy = (0.5 + (it.y - 0.5) * INSET) * S;
      var w = it.w * INSET * S, h = it.h * INSET * S;
      var spin = it.r ? ' transform="rotate(' + it.r + ' ' + cx + ' ' + cy + ')"' : "";
      body += '<rect class="selbox" x="' + (cx - w / 2 - 3) + '" y="' + (cy - h / 2 - 3)
        + '" width="' + (w + 6) + '" height="' + (h + 6) + '"' + spin + "/>";

      CORNERS.forEach(function (c) {
        var hx = cx + c.sx * w / 2, hy = cy + c.sy * h / 2;
        body += '<rect class="handle corner ' + c.name + '" data-handle="' + c.name + '"'
          + ' x="' + (hx - HANDLE / 2) + '" y="' + (hy - HANDLE / 2)
          + '" width="' + HANDLE + '" height="' + HANDLE + '"' + spin + "/>";
      });
      var ry = cy - h / 2 - 18;
      body += '<line class="handle-line" x1="' + cx + '" y1="' + (cy - h / 2) + '" x2="' + cx + '" y2="' + ry + '"' + spin + "/>"
        + '<circle class="handle rotate" data-handle="rotate" cx="' + cx + '" cy="' + ry + '" r="6"' + spin + "/>";
    }
    svg.innerHTML = body;
    drawProps();
  }

  var HANDLE = 8;
  var CORNERS = [
    { name: "tl", sx: -1, sy: -1 }, { name: "tr", sx: 1, sy: -1 },
    { name: "bl", sx: -1, sy: 1 }, { name: "br", sx: 1, sy: 1 },
  ];

  // (dx,dy)를 원점 기준 deg도만큼 돌린다. SVG의 rotate()와 같은 방향(시계 방향)이다.
  function rotateVec(dx, dy, deg) {
    var rad = deg * Math.PI / 180;
    var cos = Math.cos(rad), sin = Math.sin(rad);
    return { x: dx * cos - dy * sin, y: dx * sin + dy * cos };
  }

  var PROP_ROWS = [
    ["x", "X"], ["y", "Y"], ["w", "너비"], ["h", "높이"], ["r", "회전"],
    ["k", "둥글기"], ["s", "테두리"], ["z", "순서"], ["t", "투명도"]
  ];

  function drawProps() {
    var box = document.getElementById("shapeProps");
    var it = art.shapes[art.picked];
    if (!it) { box.innerHTML = '<p class="note">도형을 고르세요.</p>'; return; }
    box.innerHTML = PROP_ROWS.map(function (row) {
      // 대괄호를 겹쳐 쓰지 않는다 — Luau 긴 문자열이 그 자리에서 닫힌다.
      var key = row[0];
      return '<label class="fld narrow"><span>' + row[1] + '</span>'
        + '<input class="f prop" type="number" step="any" data-prop="' + key + '" value="' + it[key] + '"></label>';
    }).join("")
      + '<label class="fld"><span>색</span><input class="f prop" type="color" data-prop="c" value="' + it.c + '"></label>'
      + '<div class="bar"><button class="chip" id="shapeUp">앞으로</button>'
      + '<button class="chip" id="shapeCopy">복제</button>'
      + '<button class="chip" id="shapeDel">지우기</button></div>';
  }

  /*
    요청: "삼각형 추가좀". `Shape`는 늘 둥근 사각형 하나뿐이다(게임의
    Frame + UICorner도 같은 제약이라 세모난 조각이 없다) — 그래서 진짜
    (변이 세 개인) 삼각형은 이 도형 체계로 표현할 방법이 없다. 대신 얇은
    막대 세 개를 변으로 이어 붙여 삼각형 **테두리**를 흉내 낸다 — 셋 다
    진짜 `Shape` 사각형이라, 다른 도형과 똑같이 게임에 그대로 나간다
    (편집기가 보여주는 것과 실제로 저장·반영되는 것이 어긋나지 않는다는
    원칙을 이 도형도 그대로 지킨다).

    정삼각형(중심 (0.5,0.5), 꼭짓점까지 반지름 0.28)의 세 변 — 중점·길이·
    기울기를 미리 계산해 둔 값이다.
  */
  var TRIANGLE_EDGES = [
    { x: 0.621, y: 0.43, r: 60 },
    { x: 0.5, y: 0.64, r: 180 },
    { x: 0.379, y: 0.43, r: -60 }
  ];

  function addShape(kind) {
    snapshotUndo();
    var top = 6;
    art.shapes.forEach(function (item) { top = Math.max(top, item.z); });
    if (kind === "triangle") {
      TRIANGLE_EDGES.forEach(function (edge, i) {
        art.shapes.push({ x: edge.x, y: edge.y, w: 0.485, h: 0.02, r: edge.r,
          c: "#ffffff", k: 0.5, s: 0, z: top + 1 + i, t: 0 });
      });
      art.picked = art.shapes.length - 1;
      drawCanvas();
      return;
    }
    var stock = STOCK[kind] || STOCK.rect;
    art.shapes.push({ x: 0.5, y: 0.5, w: stock.W, h: stock.H, r: stock.Rotation,
      c: "#ffffff", k: stock.Corner, s: stock.Stroke, z: top + 1, t: 0 });
    art.picked = art.shapes.length - 1;
    drawCanvas();
  }

  document.getElementById("palette").addEventListener("click", function (event) {
    var chip = event.target.closest("[data-add]");
    if (chip) addShape(chip.dataset.add);
  });

  //--- 마우스로 옮기기·크기·기울기 다루기 (요청) ---//

  var ART_INSET = ]] .. string.format("%.5f", CardArt.INSET) .. [[;

  // 화면 좌표를 도형이 쓰는 0~1 공간으로. x·y·w·h가 전부 이 공간의 숫자다.
  function pointToItem(event, box) {
    var fx = (event.clientX - box.left) / box.width, fy = (event.clientY - box.top) / box.height;
    return { x: 0.5 + (fx - 0.5) / ART_INSET, y: 0.5 + (fy - 0.5) / ART_INSET };
  }
  function round3(n) { return Math.round(n * 1000) / 1000; }

  //--- 되돌리기 (요청: Ctrl+Z) ---//

  var undoStack = [];
  // 도형을 건드리기 **직전**에 지금 모양을 남긴다. 되돌리기는 그 직전으로 돌아간다.
  function snapshotUndo() {
    undoStack.push(JSON.stringify(art.shapes));
    if (undoStack.length > 50) undoStack.shift();
  }
  function undoLastEdit() {
    if (undoStack.length === 0) return;
    art.shapes = JSON.parse(undoStack.pop());
    art.picked = -1;
    drawCanvas();
  }

  var interaction = null;
  document.getElementById("canvas").addEventListener("pointerdown", function (event) {
    var box = this.getBoundingClientRect();
    var handle = event.target.closest("[data-handle]");

    if (handle && art.picked >= 0) {
      snapshotUndo();
      var it = art.shapes[art.picked];
      var kind = handle.dataset.handle;
      if (kind === "rotate") {
        interaction = { mode: "rotate", cx: it.x, cy: it.y };
      } else {
        var corner = CORNERS.filter(function (c) { return c.name === kind; })[0];
        /*
          크기는 **잡지 않은 반대쪽 모서리를 고정점**으로 늘고 준다. 회전된
          도형이라 고정점도 회전된 자리에 있다 — 지금 크기·회전으로 한 번
          계산해 두고, 끄는 동안은 그 고정점만 기준으로 삼는다.
        */
        var half = rotateVec(corner.sx * it.w / 2, corner.sy * it.h / 2, it.r);
        interaction = {
          mode: "resize", sx: corner.sx, sy: corner.sy, r: it.r,
          anchor: { x: it.x - half.x, y: it.y - half.y },
        };
      }
      this.setPointerCapture(event.pointerId);
      return;
    }

    var target = event.target.closest("[data-shape]");
    if (!target) { art.picked = -1; drawCanvas(); return; }
    art.picked = Number(target.dataset.shape);
    snapshotUndo();
    var it = art.shapes[art.picked];
    var p = pointToItem(event, box);
    // 잡은 지점과 도형 중심의 차이를 기억한다. 그래야 끌 때 튀지 않는다.
    interaction = { mode: "move", dx: it.x - p.x, dy: it.y - p.y };
    this.setPointerCapture(event.pointerId);
    drawCanvas();
  });

  document.getElementById("canvas").addEventListener("pointermove", function (event) {
    if (!interaction || art.picked < 0) return;
    var box = this.getBoundingClientRect();
    var p = pointToItem(event, box);
    var it = art.shapes[art.picked];

    if (interaction.mode === "move") {
      it.x = round3(p.x + interaction.dx);
      it.y = round3(p.y + interaction.dy);
    } else if (interaction.mode === "resize") {
      // 고정점 기준 상대 위치를 회전 반대로 되돌리면, 회전을 신경 안 써도 되는
      // 보통의 가로세로 크기 계산이 된다.
      var local = rotateVec(p.x - interaction.anchor.x, p.y - interaction.anchor.y, -interaction.r);
      var newW = Math.max(0.02, local.x * interaction.sx);
      var newH = Math.max(0.02, local.y * interaction.sy);
      var half = rotateVec(interaction.sx * newW / 2, interaction.sy * newH / 2, interaction.r);
      it.w = round3(newW);
      it.h = round3(newH);
      it.x = round3(interaction.anchor.x + half.x);
      it.y = round3(interaction.anchor.y + half.y);
    } else if (interaction.mode === "rotate") {
      // "위"(회전 0도)가 손잡이 기준 자리이므로 90도를 더해 맞춘다.
      var deg = Math.atan2(p.y - interaction.cy, p.x - interaction.cx) * 180 / Math.PI + 90;
      it.r = Math.round(deg);
    }
    drawCanvas();
  });
  document.getElementById("canvas").addEventListener("pointerup", function () { interaction = null; });

  //--- 고른 도형 다루기 ---//

  // 칸 하나를 고칠 때마다 남기면 글자 하나마다 되돌릴 자리가 생겨 너무 잘다 —
  // 그 칸에 처음 들어올 때 딱 한 번만 남긴다.
  document.getElementById("shapeProps").addEventListener("focusin", function (event) {
    if (event.target.closest(".prop") && art.picked >= 0) snapshotUndo();
  });

  document.getElementById("shapeProps").addEventListener("input", function (event) {
    var el = event.target.closest(".prop");
    if (!el || art.picked < 0) return;
    var it = art.shapes[art.picked];
    it[el.dataset.prop] = el.type === "number" ? parseFloat(el.value) : el.value;
    // 속성 칸을 다시 그리면 타이핑이 끊긴다. 화면만 새로 그린다.
    var keep = art.picked;
    var svg = document.getElementById("canvas");
    art.picked = keep;
    var order = art.shapes.map(function (item, i) { return { item: item, i: i }; });
    order.sort(function (a, b) { return (a.item.z - b.item.z) || (a.i - b.i); });
    svg.innerHTML = frameOf(grade()) + order.map(function (e) { return svgRect(e.item, e.i); }).join("");
  });

  // 지우기·복제는 단추와 단축키(Backspace·Ctrl+C/V)가 같은 길을 탄다.
  function deleteSelectedShape() {
    if (art.picked < 0) return;
    snapshotUndo();
    art.shapes.splice(art.picked, 1);
    art.picked = -1;
    drawCanvas();
  }
  function duplicateShape(source) {
    snapshotUndo();
    var copy = Object.assign({}, source);
    copy.x = round3(copy.x + 0.05); copy.y = round3(copy.y + 0.05); copy.z += 1;
    art.shapes.push(copy);
    art.picked = art.shapes.length - 1;
    drawCanvas();
  }

  document.getElementById("shapeProps").addEventListener("click", function (event) {
    if (art.picked < 0) return;
    if (event.target.id === "shapeDel") {
      deleteSelectedShape();
    } else if (event.target.id === "shapeCopy") {
      duplicateShape(art.shapes[art.picked]);
    } else if (event.target.id === "shapeUp") {
      snapshotUndo();
      art.shapes[art.picked].z += 1;
      drawCanvas();
    }
  });

  document.getElementById("artGrade").addEventListener("change", drawCanvas);
  document.getElementById("artTemplate").addEventListener("click", function () {
    snapshotUndo();
    art.shapes = (TEMPLATES[grade()] || []).map(function (item) { return Object.assign({}, item); });
    art.picked = -1;
    /*
      **여기가 새 그림의 시작이다.** `art.id`를 그대로 두면, `artSave`가
      `art.id || artIdFrom(name)`로 id를 고르므로 — 이미 한 번이라도 저장한
      적이 있으면 그 뒤로는 이름을 뭐라고 새로 적든 **항상 그 예전 id를
      재사용해 덮어쓴다**(요청한 버그: "저장된 그림 개수 자체가 어느 이상
      늘어나지 않는다" — 세션 안에서 두 번째 저장부터는 전부 첫 그림 위에
      덮어써졌다). id를 비우고 이름 칸도 되돌려, 다음 저장이 **지금 이름으로
      새 항목**을 만들게 한다.
    */
    art.id = "";
    document.getElementById("artName").value = "새 그림";
    showUsers();
    drawCanvas();
  });

  /*
    **키보드 단축키** (요청: Backspace·Ctrl+Z·Ctrl+C·Ctrl+V·화살표·WASD).

    그림 그리기 탭이 켜져 있을 때만 듣고, 글자·색 칸에 커서가 있으면
    그 칸의 원래 동작(진짜 텍스트 되돌리기·복사 등)을 그대로 둔다 — 안 그러면
    카드 설명을 고치다 Ctrl+Z를 눌렀는데 그림이 지워지는 사고가 난다.
  */
  // WASD도 화살표와 같은 자리를 쓴다(요청). 글자 키라 대소문자를 가리지 않게
  // 찾는 쪽에서 소문자로 낮춰 본다.
  // 한 번에 옮기는 양(요청: "0.005단위로 움직이게").
  var ARROW_STEP = {
    ArrowLeft: [-0.005, 0], ArrowRight: [0.005, 0], ArrowUp: [0, -0.005], ArrowDown: [0, 0.005],
    a: [-0.005, 0], d: [0.005, 0], w: [0, -0.005], s: [0, 0.005]
  };
  var artClipboard = null;

  document.addEventListener("keydown", function (event) {
    var tab = document.getElementById("tab-draw");
    if (!tab || tab.classList.contains("tabhide")) return;
    var focused = document.activeElement;
    if (focused && (focused.tagName === "INPUT" || focused.tagName === "TEXTAREA" || focused.isContentEditable)) return;

    var ctrl = event.ctrlKey || event.metaKey;
    if (ctrl && event.key.toLowerCase() === "z") {
      event.preventDefault();
      undoLastEdit();
      return;
    }
    if (ctrl && event.key.toLowerCase() === "c") {
      if (art.picked < 0) return;
      event.preventDefault();
      artClipboard = Object.assign({}, art.shapes[art.picked]);
      return;
    }
    if (ctrl && event.key.toLowerCase() === "v") {
      if (!artClipboard) return;
      event.preventDefault();
      duplicateShape(artClipboard);
      return;
    }
    if (event.key === "Backspace" || event.key === "Delete") {
      if (art.picked < 0) return;
      event.preventDefault();
      deleteSelectedShape();
      return;
    }
    var step = ARROW_STEP[event.key] || ARROW_STEP[event.key.toLowerCase()];
    if (step) {
      if (art.picked < 0) return;
      event.preventDefault();
      snapshotUndo();
      var it = art.shapes[art.picked];
      /*
        **0.005 눈금에 먼저 맞추고 옮긴다** (요청: "보정도 0.005단위로").

        마우스로 끌면 0.001 단위 잔값이 남는다. 그 상태에서 화살표·WASD로
        옮기면 0.001이 계속 따라다녀 눈금이 어긋난다 — 옮기기 전에 먼저
        가까운 0.005로 반올림해 그 뒤로는 항상 눈금에 딱 맞게 한다.
      */
      it.x = round3(Math.round(it.x * 200) / 200 + step[0]);
      it.y = round3(Math.round(it.y * 200) / 200 + step[1]);
      drawCanvas();
    }
  });

  //--- 저장 · 열기 · 카드에 넣기 ---//

  function artIdFrom(name) {
    // 사람이 읽는 이름과 별개로, 안정된 Id 를 만든다.
    var base = name.replace(/[^0-9A-Za-z가-힣]+/g, "_").replace(/^_+|_+$/g, "");
    return base || ("art" + Date.now());
  }

  function pushArt(id, name) {
    var payload = { name: name, shapes: art.shapes };
    commitChanges([
      { scope: "artworks", key: id, field: "Body", value: JSON.stringify(payload) }
    ], me || "누군가").catch(function (err) { noteFailure(err, "그림을 저장하지 못했습니다"); });
  }

  document.getElementById("artSave").addEventListener("click", function () {
    if (art.shapes.length === 0) { alert("도형이 하나도 없습니다."); return; }
    var name = document.getElementById("artName").value.trim() || "새 그림";
    var id = art.id || artIdFrom(name);
    art.id = id;
    ARTWORKS[id] = { name: name, shapes: art.shapes.map(function (i) { return Object.assign({}, i); }) };
    if (LIVE) pushArt(id, name);
    fillArtList();
    alert('"' + name + '" 저장했습니다. 아래에서 카드에 넣을 수 있습니다.');
  });

  function fillArtList() {
    var pick = document.getElementById("artOpen");
    pick.innerHTML = '<option value="">저장된 그림 열기…</option>'
      + Object.keys(ARTWORKS).map(function (id) {
        return '<option value="' + id + '">' + esc(ARTWORKS[id].name) + "</option>";
      }).join("");
    showUsers();
  }

  document.getElementById("artOpen").addEventListener("change", function () {
    var found = ARTWORKS[this.value];
    if (!found) return;
    art.id = this.value;
    art.shapes = found.shapes.map(function (i) { return Object.assign({}, i); });
    art.picked = -1;
    document.getElementById("artName").value = found.name;
    drawCanvas();
    showUsers();
  });

  // 카드 고르기: 직업 → 등급 → 카드
  function fillCards() {
    var klass = document.getElementById("artClassPick").value;
    var g = document.getElementById("artGradePick").value;
    var pick = document.getElementById("artCardPick");
    pick.innerHTML = CARDLIST.filter(function (c) { return c.class === klass && c.grade === g; })
      .map(function (c) { return '<option value="' + c.id + '">' + esc(c.name) + "</option>"; }).join("");
  }
  (function () {
    var seen = {};
    document.getElementById("artClassPick").innerHTML = CARDLIST.filter(function (c) {
      if (seen[c.class]) return false;
      seen[c.class] = true;
      return true;
    }).map(function (c) { return '<option>' + esc(c.class) + "</option>"; }).join("");
    document.getElementById("artClassPick").addEventListener("change", fillCards);
    document.getElementById("artGradePick").addEventListener("change", fillCards);
    fillCards();
    fillArtList();
    drawCanvas();
  })();

  function showUsers() {
    var users = CARDLIST.filter(function (c) { return c.art && c.art === art.id; });
    document.getElementById("artUsers").innerHTML = art.id
      ? (users.length ? "<b>이 그림을 쓰는 카드</b> " + users.map(function (c) { return esc(c.name); }).join(", ")
                      : "아직 이 그림을 쓰는 카드가 없다.")
      : "";
  }

  /*
    카드에 그림을 넣는다 — **여기 한 곳**에서만 한다.

    예전에는 클라우드(`commitChanges`)로만 보냈다. 그 값을 들고 있는 화면
    쪽 칸(`data-field="Art"`)도, 카드 썸네일도 따로 안 건드려서, 저장은 됐어도
    화면에는 안 보였다(요청한 버그: "그림 그리기 후 이미지가 카드에 입력되지
    않아"). 이제 칸 값을 바꿔 평소 저장 흐름(`input`)을 타게 하고, 썸네일도
    그 자리에서 다시 그린다.
  */
  function applyArtToCard(cardId, artId) {
    var card = document.querySelector('.card[data-id="' + CSS.escape(cardId) + '"]');
    if (!card) return null;
    var input = card.querySelector('input[data-scope="cards"][data-field="Art"]');
    if (input) {
      input.value = artId || "";
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.dispatchEvent(new Event("change", { bubbles: true }));
    }
    paintCardArt(card, artId);
    var target = CARDLIST.filter(function (c) { return c.id === cardId; })[0];
    if (target) target.art = artId || "";
    return target;
  }

  // 카드 썸네일을 그린다 — artId가 있으면 그 그림, 없으면(지우기) 처음 그대로 되돌린다.
  function paintCardArt(card, artId) {
    var box = card.querySelector(".art");
    var btn = box.querySelector(".artpick");
    var input = box.querySelector('input[data-field="Art"]');
    var found = artId && ARTWORKS[artId];
    if (found) {
      var svg = box.querySelector("svg");
      if (svg) svg.outerHTML = artworkSvgHTML(found.shapes, card.dataset.grade);
    } else if (box.dataset.defaultSvg) {
      var current = box.querySelector("svg");
      if (current) current.outerHTML = box.dataset.defaultSvg;
    }
    // 되돌릴 원본을 처음 한 번만 남겨 둔다.
    if (!box.dataset.defaultSvg) {
      var svgNow = box.querySelector("svg");
      if (svgNow && !found) box.dataset.defaultSvg = svgNow.outerHTML;
    }
    box.appendChild(btn);
    if (input) box.appendChild(input);
  }

  // 저장된 그림 하나를 카드 틀(등급 배경)에 얹어 그린 SVG 문자열.
  function artworkSvgHTML(shapes, grade) {
    var g = GRADE_BG[grade] ? grade : "Common";
    var order = shapes.map(function (item, i) { return { item: item, i: i }; });
    order.sort(function (a, b) { return (a.item.z - b.item.z) || (a.i - b.i); });
    var body = frameOf(g) + order.map(function (e) { return svgRect(e.item, e.i); }).join("");
    return '<svg viewBox="0 0 200 200" style="background:' + GRADE_BG[g] + '">' + body + "</svg>";
  }

  //=== 카드 위 그림 고르기 (요청: "오른쪽 위 사진 모양 버튼") ===//

  var artPickTarget = null;

  function openArtPicker(cardId) {
    artPickTarget = cardId;
    var list = document.getElementById("artPickList");
    var ids = Object.keys(ARTWORKS);
    var card = document.querySelector('.card[data-id="' + CSS.escape(cardId) + '"]');
    var grade = card ? card.dataset.grade : "Common";
    if (ids.length === 0) {
      list.innerHTML = '<p class="artpick-none">아직 저장된 그림이 없다 — "그림 그리기" 탭에서 먼저 그려 저장하세요.</p>';
    } else {
      /*
        **이름만이 아니라 생김새도 보여준다** (요청: "카드 이미지 이름만
        나오면 안되고, 직접 그린 카드마다 어떻게 생겼는지 나와야 해").
      */
      list.innerHTML = '<div class="artpick-item" data-art-id="">'
        + '<svg viewBox="0 0 200 200" style="background:#26262f"></svg><span>그림 없음(기본)</span></div>'
        + ids.map(function (id) {
          return '<div class="artpick-item" data-art-id="' + esc(id) + '">'
            + artworkSvgHTML(ARTWORKS[id].shapes, grade)
            + "<span>" + esc(ARTWORKS[id].name) + "</span></div>";
        }).join("");
    }
    document.getElementById("artPickModal").classList.add("open");
  }

  function closeArtPicker() {
    artPickTarget = null;
    document.getElementById("artPickModal").classList.remove("open");
  }

  document.addEventListener("click", function (event) {
    var btn = event.target.closest(".artpick");
    if (btn) {
      var cardId = btn.closest(".card").dataset.id;
      openArtPicker(cardId);
      return;
    }
    if (event.target.id === "artPickClose" || event.target.id === "artPickModal") {
      closeArtPicker();
      return;
    }
    var item = event.target.closest(".artpick-item");
    if (item && artPickTarget) {
      var artId = item.dataset.artId;
      var target = applyArtToCard(artPickTarget, artId);
      if (LIVE) {
        commitChanges([
          { scope: "cards", key: artPickTarget, field: "Art", value: artId }
        ], me || "누군가").catch(function (err) { noteFailure(err, "카드에 그림을 넣지 못했습니다"); });
      }
      closeArtPicker();
    }
  });

  document.getElementById("artAssign").addEventListener("click", function () {
    if (!art.id) { alert("먼저 그림을 저장하세요."); return; }
    var cardId = document.getElementById("artCardPick").value;
    if (!cardId) return;
    var target = applyArtToCard(cardId, art.id);
    if (LIVE) {
      commitChanges([
        { scope: "cards", key: cardId, field: "Art", value: art.id }
      ], me || "누군가").catch(function (err) { noteFailure(err, "카드에 그림을 넣지 못했습니다"); });
    }
    showUsers();
    alert(target ? '"' + target.name + '" 에 넣었습니다.' : "넣었습니다.");
  });

  //=== 확대·축소 (요청) ===//

  /*
    글꼴 크기를 키우면 표 폭이 같이 흔들려 배치가 매번 달라진다. 대신 본문 전체를
    **통째로 확대**한다.

    `transform: scale()`는 원래 크기로 그린 화면을 그림처럼 늘려 붙이는
    것이라 글자가 흐려진다(요청한 버그: "글 칸 안에 글들의 해상도가
    낮아지는데"). CSS `zoom`은 브라우저가 그 배율로 **다시 배치·렌더링**해
    글자가 또렷하다 — 폭도 스스로 다시 계산되니 `width` 보정도 필요 없다.
  */
  var main = document.querySelector("main");
  main.id = "zoomRoot";
  function setZoom(percent) {
    var scale = percent / 100;
    main.style.zoom = scale === 1 ? "" : String(scale);
    document.getElementById("zoomv").textContent = percent + "%";
    try { localStorage.setItem("porcelain.zoom", percent); } catch (e) {}
  }
  var zoomBox = document.getElementById("zoom");
  zoomBox.addEventListener("input", function () { setZoom(Number(this.value)); });
  try {
    var savedZoom = Number(localStorage.getItem("porcelain.zoom"));
    if (savedZoom >= 60 && savedZoom <= 180) { zoomBox.value = savedZoom; }
  } catch (e) {}
  setZoom(Number(zoomBox.value));

  //=== 서랍: 변경 이력 · 스냅샷 (DB가 있어서 되는 것들) ===//

  var drawer = document.getElementById("drawer");
  function openDrawer(title) {
    document.getElementById("dtitle").textContent = title;
    drawer.classList.add("on");
  }
  document.getElementById("dclose").addEventListener("click", function () {
    drawer.classList.remove("on");
  });

  function when(at) {
    var d = new Date(at);
    return String(d.getMonth() + 1) + "/" + d.getDate() + " "
      + String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
  }

  function show(value) {
    if (value === null || value === undefined) return "<s>(원래대로)</s>";
    return String(value).replace(/</g, "&lt;").slice(0, 90);
  }

  function renderHistory(rows) {
    if (!rows || rows.length === 0) {
      document.getElementById("dbody").innerHTML = '<p class="note">아직 바뀐 것이 없습니다.</p>';
      return;
    }
    document.getElementById("dbody").innerHTML = rows.map(function (row) {
      var place = row.key + (row.sub ? " [" + row.field + ":" + row.sub + "]" : " · " + row.field);
      return '<div class="hrow"><div class="top"><span class="who">' + row.who + "</span><span>"
        + when(row.at) + '</span></div><div class="what">' + place
        + '</div><div class="val">' + show(row.before) + " → " + show(row.after)
        + '</div><button class="chip" data-undo="' + row.id + '">이 변경 되돌리기</button></div>';
    }).join("");
  }

  function loadHistory() {
    sb.from("history").select("*").order("id", { ascending: false }).limit(60)
      .then(function (res) { if (res.error) throw res.error; renderHistory(res.data); })
      .catch(function (err) { document.getElementById("dbody").innerHTML = "<p class=\"note\">이력을 불러오지 못했습니다. " + esc(describeError(err)) + "</p>"; });
  }

  function renderSnapshots(rows) {
    var head = '<div class="bar"><button class="chip act" id="snapNew">지금 상태 저장</button></div>';
    var body = (rows || []).map(function (row) {
      return '<div class="snaprow"><span>' + row.name + "<br><small>" + row.who + " · "
        + when(row.at) + '</small></span><button class="chip" data-restore="' + row.id + '">복원</button></div>';
    }).join("");
    document.getElementById("dbody").innerHTML = head
      + (body || '<p class="note">저장해 둔 지점이 없습니다.</p>');
  }

  function loadSnapshots() {
    sb.from("snapshots").select("id,name,who,at").order("id", { ascending: false }).limit(50)
      .then(function (res) { if (res.error) throw res.error; renderSnapshots(res.data); })
      .catch(function (err) { document.getElementById("dbody").innerHTML = "<p class=\"note\">스냅샷을 불러오지 못했습니다. " + esc(describeError(err)) + "</p>"; });
  }

  /*
    상태이상 줄의 단추. 키워드 탭으로 넘어가 그 낱말을 찾아 준다.
    값이 사는 곳이 한 군데뿐이라는 것을 화면으로도 보여 준다.
  */
  document.addEventListener("click", function (event) {
    var go = event.target.closest(".gokw");
    if (!go) return;
    var chip = document.querySelector('#tabBar [data-tab="keywords"]');
    if (chip) chip.click();
    var box = document.querySelector('[data-scope="keywords"][data-key="'
      + CSS.escape(go.dataset.kw) + '"][data-field="Name"]');
    if (box) {
      box.closest(".kw").scrollIntoView({ block: "center" });
      box.focus();
    }
  });

  /*
    **"직업 능력" 탭의 전용 상태이상 줄이 키워드 탭과 따로 논다** (요청한 버그:
    "왜 키워드 탭에서 고친대로 쓰이지 않는거야").

    이 줄은 빌드할 때 `keyword.Name`·`keyword.Description`을 그 자리에 그대로
    찍어 넣은 글자일 뿐이라, 키워드 탭에서 값을 고쳐도 이 글자는 안 바뀐다 —
    두 칸이 같은 값을 따로 들고 있는 게 아니라, 한쪽은 그때 스냅샷일 뿐이다.
    키워드 탭 칸이 바뀔 때마다 이 줄도 같이 새로 그려 **한 군데(키워드 탭
    칸)만 진짜고 여기는 그걸 비추기만** 하게 한다.
  */
  function syncStatusRow(keywordId) {
    var rows = document.querySelectorAll('.statrow[data-kw-id="' + CSS.escape(keywordId) + '"]');
    if (rows.length === 0) return;
    var nameBox = document.querySelector('[data-scope="keywords"][data-key="'
      + CSS.escape(keywordId) + '"][data-field="Name"]');
    var descBox = document.querySelector('[data-scope="keywords"][data-key="'
      + CSS.escape(keywordId) + '"][data-field="Description"]');
    rows.forEach(function (row) {
      var kindEl = row.querySelector(".kind");
      var descEl = row.querySelector(".sdesc");
      if (nameBox && kindEl) kindEl.textContent = nameBox.value;
      // 숫자·키워드 하이라이트도 실제 게임과 같은 규칙으로 입힌다(요청).
      if (descBox && descEl) descEl.innerHTML = highlightForPreview(descBox.value);
    });
  }

  function syncAllStatusRows() {
    var seen = {};
    document.querySelectorAll(".statrow[data-kw-id]").forEach(function (row) {
      var id = row.dataset.kwId;
      if (seen[id]) return;
      seen[id] = true;
      syncStatusRow(id);
    });
  }

  document.addEventListener("input", function (event) {
    var el = event.target;
    if (el.dataset && el.dataset.scope === "keywords"
      && (el.dataset.field === "Name" || el.dataset.field === "Description")) {
      syncStatusRow(el.dataset.key);
    }
  });

  document.getElementById("histBtn").addEventListener("click", function () {
    if (!LIVE) { alert("변경 이력은 Supabase가 설정됐을 때만 볼 수 있습니다."); return; }
    openDrawer("변경 이력");
    loadHistory();
  });
  document.getElementById("snapBtn").addEventListener("click", function () {
    if (!LIVE) { alert("스냅샷은 Supabase가 설정됐을 때만 쓸 수 있습니다."); return; }
    openDrawer("스냅샷");
    loadSnapshots();
  });

  // 이력 줄 하나를 되돌린다. 되돌린 것 자체도 이력에 남는다(예전 서버의 /undo와 같다).
  function undoHistoryRow(id) {
    return sb.from("history").select("*").eq("id", id).single().then(function (res) {
      var row = res.data;
      if (!row) return;
      return commitChanges([{
        scope: row.scope, key: row.key, field: row.field,
        sub: row.sub === "" ? null : row.sub,
        value: row.before === null ? null : row.before,
      }], me + " (되돌림)");
    }).then(function () { loadHistory(); });
  }

  // 스냅샷으로 되돌아간다. 지금 있는 칸을 전부 지우고 그 시점 칸을 다시 넣는다.
  async function restoreSnapshot(id) {
    var snap = (await sb.from("snapshots").select("*").eq("id", id).single()).data;
    if (!snap) return;
    var target = snap.body;
    var changes = [];
    var current = (await sb.from("edits").select("scope,key,field,sub")).data || [];
    current.forEach(function (row) {
      changes.push({ scope: row.scope, key: row.key, field: row.field, sub: row.sub === "" ? null : row.sub, value: null });
    });
    Object.keys(target).forEach(function (scope) {
      if (scope === "version" || scope === "savedAt" || scope === "savedAtLocal") return;
      if (typeof target[scope] !== "object" || target[scope] === null) return;
      Object.keys(target[scope]).forEach(function (key) {
        var entry = target[scope][key];
        if (typeof entry !== "object" || entry === null) return;
        Object.keys(entry).forEach(function (field) {
          var value = entry[field];
          if (value !== null && typeof value === "object") {
            Object.keys(value).forEach(function (sub) {
              changes.push({ scope: scope, key: key, field: field, sub: sub, value: value[sub] });
            });
          } else {
            changes.push({ scope: scope, key: key, field: field, value: value });
          }
        });
      });
    });
    await commitChanges(changes, me + ' (스냅샷 "' + snap.name + '" 복원)');
    if (channel) channel.send({ type: "broadcast", event: "reload", payload: {} });
    var loaded = await loadState();
    applyingRemote = true;
    fieldList().forEach(function (el) { el.value = el.dataset.orig; });
    restore(loaded);
    applyingRemote = false;
    loadHistory();
  }

  drawer.addEventListener("click", function (event) {
    var undo = event.target.closest("[data-undo]");
    if (undo) {
      undoHistoryRow(Number(undo.dataset.undo));
      return;
    }
    var pick = event.target.closest("[data-restore]");
    if (pick) {
      if (!confirm("이 지점으로 되돌립니다. 지금 값들이 그때 값으로 바뀝니다.")) return;
      restoreSnapshot(Number(pick.dataset.restore));
      return;
    }
    if (event.target.id === "snapNew") {
      /*
        **날짜·시간을 앞에 자동으로 붙인다** (요청: `yyyy/mm/dd/hh:mm - 수정 내용`).

        `prompt()`는 기본값을 채워도 브라우저가 그 글자를 전부 선택해 둬서,
        한 글자만 쳐도 통째로 지워진다(요청한 버그) — 커서만 뒤로 보낼 방법이
        없다. 그래서 기본값에 넣지 않고, **빈칸에 수정 내용만 받아** 저장할
        때 앞에 붙인다.
      */
      var pad2 = function (n) { return String(n).padStart(2, "0"); };
      var now = new Date();
      var stamp = now.getFullYear() + "/" + pad2(now.getMonth() + 1) + "/" + pad2(now.getDate())
        + "/" + pad2(now.getHours()) + ":" + pad2(now.getMinutes());
      var typed = (prompt("이 지점의 이름 (앞에 " + stamp + " 이 자동으로 붙습니다)", "") || "").trim();
      if (!typed) return;
      var name = stamp + " - " + typed;
      loadState().then(function (loaded) {
        return sb.from("snapshots").insert({ name: name, body: loaded, who: me, at: Date.now() });
      }).then(function (res) {
        if (res && res.error) throw res.error;
        loadSnapshots();
      }).catch(function (err) {
        alert("스냅샷을 저장하지 못했습니다.\n\n" + describeError(err));
      });
    }
  });

  //=== 여럿이 함께 고치기 (Supabase) ===//

  /*
    Supabase 프로젝트가 설정돼 있으면 켜진다 — `file://`로 열어도 된다(로컬
    서버가 필요 없다). 표는 `edits`(지금 값) · `history`(내력) ·
    `snapshots`(이름 붙인 지점) 셋. 실시간 전달은 Supabase Realtime(Postgres
    변경분을 그대로 밀어 준다)이고, "누가 지금 보고 있나"는 Realtime
    Presence를 쓴다 — 예전처럼 8초마다 살아있다고 알리는 신호를 직접 안 보내도
    브라우저 탭이 붙어 있는 동안 자동으로 유지된다.

    충돌은 **칸 단위 마지막 쓰기 우선**이다. 다른 칸을 고치는 것은 서로 방해하지
    않고, 지금 타이핑 중인 칸에는 남의 값을 덮어쓰지 않는다.
  */
  var LIVE = false;
  var me = "";
  var applyingRemote = false;
  var channel = null;

  function fieldKeyOf(el) {
    if (el.dataset.scope === "cardLevels") {
      return ["cardLevels", el.dataset.key, el.dataset.slot, el.dataset.level];
    }
    return [el.dataset.scope, el.dataset.key, el.dataset.field];
  }

  // 서버에 보낼 모양으로. 레벨 칸은 슬롯·레벨이 키 안에 들어간다.
  function changeOf(el) {
    var changed = normal(el) !== normal(el, el.dataset.orig);
    var value = el.type === "number" ? (el.value === "" ? null : parseFloat(el.value)) : el.value;
    if (el.dataset.scope === "cardLevels") {
      // 카드 > 슬롯 > 레벨. 내보내는 JSON과 같은 모양으로 보낸다.
      return { scope: "cardLevels", key: el.dataset.key, field: el.dataset.slot,
               sub: el.dataset.level, value: changed ? value : null };
    }
    return { scope: el.dataset.scope, key: el.dataset.key, field: el.dataset.field,
             value: changed ? value : null };
  }

  function elementFor(change) {
    if (change.scope === "cardLevels") {
      return document.querySelector('[data-scope="cardLevels"][data-key="' + CSS.escape(change.key)
        + '"][data-slot="' + change.field + '"][data-level="' + change.sub + '"]');
    }
    return document.querySelector('[data-scope="' + change.scope + '"][data-key="'
      + CSS.escape(change.key) + '"][data-field="' + change.field + '"]');
  }

  /*
    칸 하나를 고친다. 읽기·쓰기·이력을 **한 번에** 하는 `apply_edit` 함수를
    부른다 — 그 셋을 브라우저에서 나눠 하면 빠르게 칠 때 서로 끼어들어 옛
    값이 최신 값을 덮는다(`supabase/schema.sql`의 주석 참고). 값이 그대로면
    함수 쪽에서 알아서 아무것도 안 쓴다.
  */
  function commitChanges(changes, who) {
    var jobs = changes.filter(function (change) {
      return change.scope && change.key && change.field;
    }).map(function (change) {
      return sb.rpc("apply_edit", {
        p_scope: change.scope,
        p_key: change.key,
        p_field: change.field,
        p_sub: change.sub === undefined || change.sub === null ? "" : String(change.sub),
        p_value: change.value === undefined ? null : change.value,
        p_who: who,
      });
    });
    return Promise.all(jobs).then(function (results) {
      var failed = results.filter(function (r) { return r && r.error; });
      if (failed.length) throw failed[0].error;
      return results;
    });
  }

  // `edits` 표의 행들을 편집기가 쓰는 중첩 모양으로 편다. 예전 서버의 buildState()와 같다.
  function buildStateFromRows(rows) {
    var out = {};
    rows.forEach(function (row) {
      if (!out[row.scope]) out[row.scope] = {};
      if (!out[row.scope][row.key]) out[row.scope][row.key] = {};
      if (!row.sub) {
        out[row.scope][row.key][row.field] = row.value;
      } else {
        if (!out[row.scope][row.key][row.field]) out[row.scope][row.key][row.field] = {};
        out[row.scope][row.key][row.field][row.sub] = row.value;
      }
    });
    return out;
  }

  function loadState() {
    return sb.from("edits").select("*").then(function (res) {
      if (res.error) throw res.error;
      return buildStateFromRows(res.data);
    });
  }

  /*
    오류를 **사람이 읽고 바로 조치할 수 있는 말**로 바꾼다.

    Supabase가 주는 원문은 "Could not find the function public.apply_edit" 처럼
    원인은 맞지만 무엇을 해야 하는지가 없다. 실제로 이 편집기가 멈추는 이유는
    거의 다 "schema.sql을 아직 안 돌렸다" 하나였다.
  */
  function describeError(err) {
    if (!err) return "알 수 없는 오류";
    var text = err.message || err.hint || String(err);
    if (/apply_edit|Could not find the function/i.test(text)) {
      return "apply_edit 함수가 없습니다. Supabase SQL Editor에서 supabase/schema.sql을 실행하세요.";
    }
    if (/schema cache|does not exist|relation .* does not exist/i.test(text)) {
      return "표가 없습니다. Supabase SQL Editor에서 supabase/schema.sql을 실행하세요.";
    }
    if (/JWT|apikey|Invalid API key/i.test(text)) return "키가 올바르지 않습니다. anon key를 확인하세요.";
    if (/Failed to fetch|NetworkError|network/i.test(text)) return "인터넷 연결을 확인하세요.";
    if (/row-level security|permission denied/i.test(text)) {
      return "권한이 막혀 있습니다. schema.sql의 정책 부분을 다시 실행하세요.";
    }
    return text;
  }

  function noteFailure(err, what) {
    lastErrorText = (what ? what + ": " : "") + describeError(err);
    try { console.error("[porcelain]", what || "", err); } catch (e) {}
    setLive(false);
  }

  /*
    지금 화면의 수정 상태를 **클라우드와 똑같이 맞춘다** (요청한 버그).

    "수정본 불러오기"로 파일을 열거나 "전부 되돌리기"를 눌러도 그동안은 화면만
    바뀌고 클라우드는 그대로였다. 그래서 새로고침하면 불러온 내용이 사라지고
    예전 값이 되돌아왔다.

    지금 수정된 칸은 올리고, 클라우드에는 있는데 지금은 수정 상태가 아닌 칸은
    지운다(값 null). 이미 같은 값인 칸은 `apply_edit`이 알아서 건너뛴다.
  */
  function syncLocalToCloud(label) {
    if (!LIVE) return Promise.resolve(0);
    var wanted = {};
    var changes = [];
    fieldList().forEach(function (el) {
      if (!changed(el)) return;
      var change = changeOf(el);
      wanted[[change.scope, change.key, change.field, change.sub || ""].join("|")] = true;
      changes.push(change);
    });

    return sb.from("edits").select("scope,key,field,sub").then(function (res) {
      if (res.error) throw res.error;
      /*
        **클라우드 값을 한 번도 못 받았으면 지우지 않는다.**

        아직 남의 수정이 화면에 안 올라온 상태에서 "지금 화면에 없으니 지운다"를
        하면, 접속하자마자 파일을 불러온 사람이 **남이 해 둔 작업을 통째로
        날려 버린다.** 올리기만 하고 지우기는 건너뛴다.
      */
      if (cloudLoaded) {
        (res.data || []).forEach(function (row) {
          var id = [row.scope, row.key, row.field, row.sub || ""].join("|");
          if (wanted[id]) return;
          // 클라우드에만 남아 있는 수정 — 지금 화면 기준으로는 원문이므로 지운다.
          changes.push({ scope: row.scope, key: row.key, field: row.field, sub: row.sub, value: null });
        });
      }
      return commitInChunks(changes, label);
    });
  }

  /*
    한 번에 수천 건을 보내면 브라우저도 Supabase도 버거워한다. 끊어 보내면서
    진행 상황을 보여 준다 — 오래 걸릴 때 멈춘 것처럼 보이지 않게.
  */
  function commitInChunks(changes, label) {
    var CHUNK = 25;
    var done = 0;
    var box = document.getElementById("dirty");
    function step(index) {
      if (index >= changes.length) {
        if (box && label) box.textContent = label + " 완료 (" + done + "칸)";
        return done;
      }
      var slice = changes.slice(index, index + CHUNK);
      return commitChanges(slice, me).then(function () {
        done += slice.length;
        if (box && label) box.textContent = label + " " + done + " / " + changes.length + "…";
        return step(index + CHUNK);
      });
    }
    return Promise.resolve(step(0));
  }

  /*
    **타이핑이 멎은 뒤에 한 번만 보낸다** (디바운스).

    예전에는 글자 하나마다 보냈다. "공명 원딜"을 치면 한글 조합 중간 단계까지
    포함해 이력이 열 몇 줄씩 쌓여 "이 변경 되돌리기"가 쓸모없어졌고, 요청이
    서로 앞질러 도착하면서 값이 어긋났다.

    칸마다 따로 센다 — 다른 칸을 고치는 것은 서로 기다리지 않는다. 보낼 때
    값을 **그 시점에 다시 읽으므로**, 기다리는 동안 더 친 글자도 함께 나간다.
  */
  var PUSH_DELAY = 400;
  var pushTimers = {};
  var pushTargets = {};

  function pushKeyOf(el) {
    return fieldKeyOf(el).join("|");
  }

  /*
    **못 보낸 것을 적어 둔다** (요청: 따로 저장 안 해도 그대로 남게).

    인터넷이 끊겼거나 클라우드가 삐끗해 저장이 실패하면, 예전에는 그걸로 끝이라
    새로고침하면 그 편집이 사라졌다. 여기 적어 두면 다음에 들어왔을 때 값을 다시
    씌우고 **알아서 재시도**한다.
  */
  var UNSENT = "porcelain.unsent.v1";

  function readUnsent() {
    try { return JSON.parse(localStorage.getItem(UNSENT) || "{}"); } catch (e) { return {}; }
  }
  function writeUnsent(map) {
    try { localStorage.setItem(UNSENT, JSON.stringify(map)); } catch (e) {}
  }
  function markUnsent(key, change) {
    var map = readUnsent();
    map[key] = change;
    writeUnsent(map);
  }
  function clearUnsent(key) {
    var map = readUnsent();
    if (!(key in map)) return;
    delete map[key];
    writeUnsent(map);
  }

  function flushPush(key) {
    var el = pushTargets[key];
    delete pushTargets[key];
    delete pushTimers[key];
    if (!el || !LIVE) return;
    if (!el.isConnected) return; // 화면에서 사라진 칸(사다리를 줄였을 때 등)은 보내지 않는다.
    var change = changeOf(el);
    commitChanges([change], me)
      .then(function () { clearUnsent(key); setLive(true); })
      .catch(function (err) { markUnsent(key, change); noteFailure(err, "저장하지 못했습니다"); });
  }

  // 적어 둔 것을 다시 보낸다. 성공한 것만 지운다.
  function retryUnsent() {
    if (!LIVE) return Promise.resolve();
    var map = readUnsent();
    var keys = Object.keys(map);
    if (keys.length === 0) return Promise.resolve();
    return commitChanges(keys.map(function (k) { return map[k]; }), me)
      .then(function () { writeUnsent({}); setLive(true); })
      .catch(function (err) { noteFailure(err, "못 보낸 수정을 다시 보내지 못했습니다"); });
  }

  function push(el) {
    if (!LIVE || applyingRemote) return;
    var key = pushKeyOf(el);
    pushTargets[key] = el;
    if (pushTimers[key]) clearTimeout(pushTimers[key]);
    pushTimers[key] = setTimeout(function () { flushPush(key); }, PUSH_DELAY);
  }

  // 칸을 빠져나가거나 창을 닫을 때는 기다리지 않고 바로 보낸다.
  function flushAllPushes() {
    Object.keys(pushTimers).forEach(function (key) {
      clearTimeout(pushTimers[key]);
      flushPush(key);
    });
  }
  document.addEventListener("focusout", function (event) {
    var key = event.target && event.target.dataset && event.target.dataset.scope ? pushKeyOf(event.target) : null;
    if (key && pushTimers[key]) {
      clearTimeout(pushTimers[key]);
      flushPush(key);
    }
  });
  /*
    `beforeunload`만으로는 놓친다 — 탭을 바로 닫거나 휴대폰에서 앱을 내리면 안
    오는 경우가 있다. 화면이 가려지는 순간(`visibilitychange` → hidden)과
    `pagehide`에서도 밀어낸다. 셋 다 걸어 두면 어느 하나는 잡힌다.
  */
  window.addEventListener("beforeunload", flushAllPushes);
  window.addEventListener("pagehide", flushAllPushes);
  document.addEventListener("visibilitychange", function () {
    if (document.visibilityState === "hidden") flushAllPushes();
  });

  /*
    접속 표시.

    예전에는 저장이 실패해 "연결 끊김"을 켜도, 곧바로 들어오는 presence 신호가
    `setLive(true)`로 덮어 **실패가 눈에 안 보였다** — 실제로 값이 저장되지
    않는데도 "함께 보는 중"으로 보였다. 이제 저장 실패는 따로 기억해 두고,
    presence가 갱신돼도 그 표시를 지우지 않는다.
  */
  var lastPeople = [];
  var saveBroken = false;
  var lastErrorText = "";
  // 클라우드 값을 한 번이라도 제대로 받았는지. 남의 수정을 지우기 전에 이걸 본다.
  var cloudLoaded = false;

  function setLive(ok, people) {
    var box = document.getElementById("live");
    if (!box) return;
    if (!LIVE) { box.textContent = ""; return; }
    if (people) lastPeople = people;
    if (!ok) saveBroken = true;
    else if (ok === true && arguments.length === 1) { saveBroken = false; lastErrorText = ""; }

    box.classList.toggle("off", saveBroken);
    if (saveBroken) {
      // 무엇이 잘못됐는지 말해 준다 — "연결 끊김"만 띄우면 고칠 방법이 안 보인다.
      box.innerHTML = '<b>저장 실패</b> <span class="why"></span> · <a href="#" id="retryLive">다시 시도</a>';
      var why = box.querySelector(".why");
      if (why) why.textContent = lastErrorText || "";
      return;
    }
    var names = lastPeople.map(function (person) { return person.who; });
    box.innerHTML = "<b>함께 보는 중</b> " + (names.length ? names.join(", ") : me)
      + ' · <a href="#" id="rename">이름 바꾸기</a>';
  }

  // 남이 바꾼 칸을 화면에 얹는다.
  function applyRemote(changes) {
    applyingRemote = true;
    changes.forEach(function (change) {
      var el = elementFor(change);
      if (!el) return;
      // 지금 내가 치고 있는 칸은 건드리지 않는다. 글자가 튀면 그게 더 큰 사고다.
      if (document.activeElement === el) return;
      var next = change.value;
      el.value = next === null || next === undefined ? el.dataset.orig : next;
      el.classList.remove("theirs");
      void el.offsetWidth;
      el.classList.add("theirs");
      if (el.dataset.scope === "icon") {
        var svg = document.querySelector('svg.prev[data-tag="' + el.dataset.key.split("#")[0] + '"]');
        if (svg) drawIcon(svg);
      }
      if (el.classList.contains("hltext")) refreshCardText(el);
      if (el.dataset.scope === "cardLevels") syncKeywordBars(el.dataset.key);
      // 키워드·숫자 유형은 칩에만 보인다. 남이 고쳤으면 칩을 다시 그려야 보인다.
      if (el.dataset.scope === "cardKeywords" || el.dataset.scope === "cardUnits") {
        var card = el.closest(".card");
        var text = card && card.querySelector("textarea.hltext");
        if (text) paintKeywordBar(text);
      }
      if (el.dataset.scope === "cards" && el.dataset.field === "Art") {
        var artCard = el.closest(".card");
        if (artCard) paintCardArt(artCard, el.value);
      }
      if (el.dataset.scope === "keywords" && (el.dataset.field === "Name" || el.dataset.field === "Description")) {
        syncStatusRow(el.dataset.key);
      }
    });
    applyingRemote = false;
    refresh();
  }

  // Realtime이 주는 한 줄(edits 표의 postgres_changes 행)을 위 changeOf()와 같은 모양으로.
  function changeFromRow(payload) {
    var row = payload.new && Object.keys(payload.new).length ? payload.new : payload.old;
    return {
      scope: row.scope, key: row.key, field: row.field, sub: row.sub,
      value: payload.eventType === "DELETE" ? null : row.value,
      who: payload.new ? payload.new.who : null,
    };
  }

  function startCloud() {
    /*
      이름은 **시작할 때 묻지 않는다.**

      예전에는 prompt 로 물으면서 빈 값이면 while 을 돌았다. 취소하거나 브라우저가
      prompt 를 막으면 페이지가 통째로 얼어붙어, 서버 값을 받아 오는 코드까지
      가지도 못했다 — 불러온 값이 안 보이던 원인이 이것이다.

      이제 저장된 이름이 없으면 임시 이름을 주고, 위쪽 이름을 눌러 바꾸게 한다.
      시작을 막는 것이 없다.
    */
    me = localStorage.getItem("porcelain.who") || "";
    if (!me) {
      me = "익명" + Math.floor(100 + Math.random() * 900);
      localStorage.setItem("porcelain.who", me);
    }

    /*
      들어올 때: 클라우드 값을 씌우고 → 지난번에 **못 보낸 수정**이 있으면 그걸
      다시 씌운 뒤 재시도한다(그게 더 나중 것이다).

      클라우드를 못 받으면 이 컴퓨터에 남겨 둔 백업으로라도 화면을 되살린다 —
      "따로 저장 안 해도 그대로"가 인터넷이 끊긴 날에도 지켜지게.
    */
    loadState().then(function (loaded) {
      applyingRemote = true;
      restore(loaded);
      var unsent = readUnsent();
      var keys = Object.keys(unsent);
      if (keys.length > 0) {
        keys.forEach(function (k) {
          var el = elementFor(unsent[k]);
          if (el) el.value = unsent[k].value === null ? el.dataset.orig : unsent[k].value;
        });
        redrawAll();
      }
      applyingRemote = false;
      cloudLoaded = true;
      setLive(true);
      refresh();
      if (keys.length > 0) retryUnsent();
    }).catch(function (err) {
      noteFailure(err, "값을 불러오지 못했습니다");
      try {
        var backup = localStorage.getItem(STORE);
        if (backup) {
          applyingRemote = true;
          restore(JSON.parse(backup));
          applyingRemote = false;
        }
      } catch (e) {}
    });

    /*
      **접속자가 들어올 때마다 쌓이던 것** (요청한 버그).

      presence 키를 안 주면 Supabase가 연결마다 새 키를 만든다. 그래서 새로고침
      할 때마다 "다른 사람"으로 한 명씩 늘었고, 나간 자리는 서버가 알아챌 때까지
      남아 있었다. 이 브라우저에 고정 키를 하나 두면 **다시 들어와도 같은 자리를
      덮어쓴다** — 늘지 않는다.
    */
    var presenceKey = "";
    try {
      presenceKey = localStorage.getItem("porcelain.presence") || "";
      if (!presenceKey) {
        presenceKey = "p" + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
        localStorage.setItem("porcelain.presence", presenceKey);
      }
    } catch (e) {
      presenceKey = "p" + Math.random().toString(36).slice(2, 10);
    }

    channel = sb.channel("porcelain-edits", { config: { presence: { key: presenceKey } } });
    channel.on("postgres_changes", { event: "*", schema: "public", table: "edits" }, function (payload) {
      var change = changeFromRow(payload);
      if (change.who === me) return; // 내가 한 것은 이미 반영돼 있다.
      applyRemote([change]);
    });
    channel.on("postgres_changes", { event: "INSERT", schema: "public", table: "history" }, function () {
      if (drawer.classList.contains("on") && document.getElementById("dtitle").textContent === "변경 이력") {
        loadHistory();
      }
    });
    /*
      스냅샷 복원은 바뀌는 칸이 너무 많다. `restore` 표에 새 행이 하나 생기면
      (신호용 — 실제 데이터는 없다) 통째로 다시 받는 편이 확실하다.
    */
    channel.on("broadcast", { event: "reload" }, function () {
      loadState().then(function (loaded) {
        applyingRemote = true;
        fieldList().forEach(function (el) { el.value = el.dataset.orig; });
        restore(loaded);
        applyingRemote = false;
        cloudLoaded = true;
      }).catch(function (err) { noteFailure(err, "다시 불러오지 못했습니다"); });
    });
    channel.on("presence", { event: "sync" }, function () {
      try {
        var presenceState = channel.presenceState() || {};
        // 같은 이름은 한 번만 — 한 사람이 탭을 여럿 열어도 한 명으로 보인다.
        var seen = {};
        var people = [];
        Object.keys(presenceState).forEach(function (id) {
          var entry = presenceState[id] && presenceState[id][0];
          if (!entry || !entry.who || seen[entry.who]) return;
          seen[entry.who] = true;
          people.push(entry);
        });
        setLive(!saveBroken, people);
      } catch (e) {
        try { console.error("[porcelain] presence", e); } catch (e2) {}
      }
    });
    channel.subscribe(function (status) {
      if (status === "SUBSCRIBED") {
        var tab = document.querySelector("#tabBar .chip.on");
        channel.track({ who: me, where: tab ? tab.textContent : "" });
      } else if (status === "CHANNEL_ERROR" || status === "TIMED_OUT" || status === "CLOSED") {
        setLive(false);
      }
    });

    // 이름은 언제든 바꿀 수 있다. 바꾸면 그때부터의 이력에 새 이름이 남는다.
    document.getElementById("live").addEventListener("click", function (event) {
      // 저장이 깨졌을 때 눌러 보는 "다시 시도" — 상태를 다시 받아 오고 표시를 되돌린다.
      if (event.target.id === "retryLive") {
        event.preventDefault();
        loadState().then(function (loaded) {
          applyingRemote = true;
          restore(loaded);
          applyingRemote = false;
          cloudLoaded = true;
          setLive(true);
        }).catch(function (err) { noteFailure(err, "다시 시도했지만 안 됐습니다"); });
        return;
      }
      if (event.target.id !== "rename") return;
      event.preventDefault();
      var next = (prompt("이름", me) || "").trim();
      if (!next) return;
      me = next;
      localStorage.setItem("porcelain.who", me);
      if (channel) {
        var tab = document.querySelector("#tabBar .chip.on");
        channel.track({ who: me, where: tab ? tab.textContent : "" });
      }
    });
  }

  /*
    `defer`로 받는 Supabase JS가 도착하면(성공이든 실패든) 이 함수가 불린다.
    없으면(막혔거나 실패) 조용히 로컬 전용으로 남는다 — 아래 `try` 블록이 그
    경우를 이미 다룬다.
  */
  function tryConnectCloud() {
    if (!window.supabase || sb) return;
    sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    LIVE = true;
    startCloud();
  }
  window.__porcelainSupabaseReady = tryConnectCloud;
  // 스크립트가 이 줄이 실행되기 전에 이미 받아져 있었을 수도 있다(캐시 등).
  if (window.supabase) tryConnectCloud();

  try {
    /*
      클라우드를 쓸 때는 위에서 받아 온 값이 진짜다 — 여기서 이 컴퓨터에 남은
      값으로 덮으면 남이 고친 것이 되살아난다. 클라우드가 실패했을 때만 백업을
      쓰는데, 그건 위 `loadState().catch`가 한다.
    */
    var saved = LIVE ? null : localStorage.getItem(STORE);
    if (saved) restore(JSON.parse(saved));
  } catch (e) {}
  refresh();
})();
</script></body></html>]]

local out = process.args[1]
if out == nil or out == "" then
	out = "config_editor.html"
end
fs.writeFile(out, html)
print(string.format("[config_editor] %s — 카드 %d장 · 직업 %d종", out, totalCards, #classPanels))
