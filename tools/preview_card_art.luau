--[[
	preview_card_art.luau — 카드 그림을 HTML로 뽑아 본다.

	`CardArt`는 Roblox 인스턴스가 아니라 **도형 목록**을 돌려주므로, Studio를 켜지
	않고도 그대로 그려 볼 수 있다. 문양을 손볼 때마다 게임을 켜는 대신 이걸 열면 된다.

	  lune run tools/preview_card_art.luau [출력경로.html] [모드] [크기]
	    모드  sample(기본: 직업·등급마다 2장) | all(306장 전부) | art(손그림 있는 카드만)
	          | 직업 Id(그 직업 전부) | ids=카드Id,카드Id
	    크기  그림 한 변 픽셀(기본 150)

	Roblox와 CSS의 대응
	  AnchorPoint(0.5, 0.5)  → transform: translate(-50%, -50%)
	  Rotation(도)            → rotate(...deg)
	  UICorner(Scale)         → border-radius = Scale * min(폭, 높이)
	                            (로블록스의 Scale은 짧은 변 기준이다)

	**주의 — 잘림은 이 미리보기로 검증되지 않는다.**
	CSS `overflow:hidden`은 회전한 요소도 자르지만, 로블록스의 `ClipsDescendants`는
	**회전한 자손을 자르지 않는다.** 그래서 여기서 멀쩡해 보여도 게임에서는 문양이
	카드 밖으로 새어 나갈 수 있다(실제로 한 번 그랬다). 게임 쪽은 CanvasGroup으로
	해결했으니, 경계를 넘는 도형을 새로 넣을 때는 Studio에서 눈으로 확인할 것.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local SHARED = "src/shared/"
local CARD_PIXELS = tonumber(process.args[3]) or 150
local MODE = process.args[2] or "sample"

--=== Roblox 전역 최소 구현 (run_system_tests와 같은 방식) ===--

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

readTree(SHARED, "")

local cache: { [string]: any } = {}
local loadShared
local makeProxy

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
	env.math = math
	env.table = table
	env.string = string
	env.warn = function() end
	env.Color3 = Color3

	local dir = name:match("^(.*)/[^/]+$")
	local leaf = name:match("([^/]+)$")
	if leaf == "init" and dir then
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

	local chunk = luau.load(source, { debugName = name, environment = env })
	local result = chunk()
	cache[name] = result
	return result
end

--=== 그리기 ===--

local CardArt = loadShared("CardArt")
local AbilityCardDefinitions = loadShared("AbilityCardDefinitions")
-- 카드 풀은 등록해야 찬다(예전엔 이걸 빼먹어 빈 화면이었다)
loadShared("AbilityCards/init").Register()

local function css(color: any): string
	return string.format(
		"rgb(%d,%d,%d)",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function renderCard(card: any): string
	local art = CardArt.For(card)
	local parts = {
		string.format('<div class="card"><div class="art" style="background:%s">', css(art.Background)),
	}

	for _, item in art.Shapes do
		local w = item.W * CARD_PIXELS
		local h = item.H * CARD_PIXELS
		local radius = item.Corner * math.min(w, h)
		local style = string.format(
			"left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;"
				.. "transform:translate(-50%%,-50%%) rotate(%.2fdeg);border-radius:%.2fpx;"
				.. "opacity:%.3f;z-index:%d;",
			item.X * CARD_PIXELS,
			item.Y * CARD_PIXELS,
			w,
			h,
			item.Rotation,
			radius,
			1 - item.Transparency,
			item.ZIndex
		)
		if item.Stroke > 0 then
			style ..= string.format("border:%.2fpx solid %s;", math.max(item.Stroke * CARD_PIXELS, 1), css(item.Color))
		else
			style ..= string.format("background:%s;", css(item.Color))
		end
		table.insert(parts, string.format('<i style="%s"></i>', style))
	end

	table.insert(
		parts,
		string.format(
			'<b class="name">%s</b></div><div class="meta">%s · %s%s<br>%s</div></div>',
			card.Name,
			card.Grade,
			table.concat(card.Tags, " / "),
			if card.Art then " · 그림 " .. card.Art else "",
			card.Id
		)
	)
	return table.concat(parts)
end

local CLASSES = {
	"Musician",
	"Duelist",
	"Pulsar",
	"Quasar",
	"WallPilgrim",
	"WallMason",
	"WallBreaker",
	"Alchemist",
	"Berserker",
}

local sections = {}
for _, classId in CLASSES do
	local cells = {}
	for _, grade in { "Essential", "Rare", "Common" } do
		local pool = AbilityCardDefinitions.GetPool(classId, grade)
		local wanted: { [string]: boolean }? = nil
		if MODE:sub(1, 4) == "ids=" then
			wanted = {}
			for id in MODE:sub(5):gmatch("[^,]+") do
				(wanted :: any)[id] = true
			end
		end
		for index, card in pool do
			local take = if MODE == "sample" then index <= 2
				elseif MODE == "all" then true
				elseif MODE == "art" then card.Art ~= nil
				elseif wanted then wanted[card.Id] == true
				else MODE == classId
			if take then
				table.insert(cells, renderCard(card))
			end
		end
	end
	if #cells > 0 then
		table.insert(sections, string.format('<h2>%s</h2><div class="row">%s</div>', classId, table.concat(cells)))
	end
end

local html = string.format(
	[[<!doctype html><meta charset="utf-8"><title>카드 그림 미리보기</title>
<style>
 body{background:#14141a;color:#e6e6ef;font-family:system-ui,sans-serif;margin:24px}
 h1{font-size:20px} h2{font-size:14px;color:#9aa;margin:22px 0 8px;letter-spacing:.08em}
 .row{display:flex;flex-wrap:wrap;gap:14px}
 .card{width:%dpx}
 .art{position:relative;width:%dpx;height:%dpx;overflow:hidden;border:1px solid #333}
 .art i{position:absolute;display:block}
 .name{position:absolute;left:0;right:0;bottom:0;z-index:50;background:rgba(12,12,16,.75);
       font-size:12px;padding:4px 6px;font-weight:700}
 .meta{font-size:10px;color:#889;margin-top:4px;line-height:1.4}
</style>
<h1>카드 그림 미리보기</h1>
<p style="color:#889;font-size:12px">필수 · 희귀 · 일반 순. 문양은 태그, 테두리 장식과 광채는 등급이 정한다.</p>
%s]],
	CARD_PIXELS,
	CARD_PIXELS,
	CARD_PIXELS,
	table.concat(sections)
)

local output = process.args[1] or "card_art_preview.html"
fs.writeFile(output, html)
print("[preview_card_art] " .. output)
