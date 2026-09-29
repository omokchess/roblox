--[[
	polite_card_text.luau — 능력 카드 설명을 존댓말로 바꾼다.

	요청: "설명을 다 존댓말로 바꾸고".

	카드가 340개라 손으로 고치면 오타와 누락이 난다. 한국어 종결어미는 규칙적이라
	**한글 유니코드 조합**으로 정확히 변환할 수 있어 기계로 처리한다.

	한글 음절 = 0xAC00 + (초성*21 + 중성)*28 + 종성
	  종성 ㄴ = 4, ㅂ = 17

	변환 규칙 (문장 끝의 `다`에만 적용)
	  1) `는다`            → `습니다`     얻는다 → 얻습니다
	  2) 종성이 ㄴ인 음절+`다` → 종성을 ㅂ으로 + `니다`
	                                    된다 → 됩니다, 한다 → 합니다, 진다 → 집니다
	  3) 그 외 음절+`다`   → 종성 있으면 `습니다`, 없으면 종성 ㅂ + `니다`
	                                    있다 → 있습니다, 크다 → 큽니다

	**Description 문자열 줄만** 건드린다. 파일 위쪽 설계 주석은 내가 남긴 메모라
	그대로 둔다.

	  lune run tools/polite_card_text.luau
]]

local fs = require("@lune/fs")

local BASE = 0xAC00
local JONG_COUNT = 28
local JONG_N = 4 -- ㄴ
local JONG_B = 17 -- ㅂ

-- UTF-8 한 글자를 코드포인트로. 한글은 3바이트다.
local function decode(text: string, index: number): (number?, number)
	local byte = string.byte(text, index)
	if not byte then
		return nil, index
	end
	if byte < 0x80 then
		return byte, index + 1
	end
	if byte >= 0xE0 then
		local b2, b3 = string.byte(text, index + 1), string.byte(text, index + 2)
		if not b2 or not b3 then
			return nil, index + 1
		end
		return ((byte - 0xE0) * 4096) + ((b2 - 0x80) * 64) + (b3 - 0x80), index + 3
	end
	--[[
		2바이트 문자(0xC0~0xDF 선두).

		처음엔 이 갈래를 빼먹고 선두 바이트를 그대로 돌려줬다. 그러면 `·`(U+00B7 =
		0xC2 0xB7)가 `Â` + `·` 두 글자로 쪼개져 **글자가 깨진다**(실제로 3곳이 깨졌다).
	]]
	if byte >= 0xC0 then
		local b2 = string.byte(text, index + 1)
		if not b2 then
			return nil, index + 1
		end
		return ((byte - 0xC0) * 64) + (b2 - 0x80), index + 2
	end
	return byte, index + 1
end

local function encode(codepoint: number): string
	return utf8.char(codepoint)
end

local function isHangul(codepoint: number?): boolean
	return codepoint ~= nil and codepoint >= BASE and codepoint <= 0xD7A3
end

local function jongseong(codepoint: number): number
	return (codepoint - BASE) % JONG_COUNT
end

local function withJongseong(codepoint: number, jong: number): number
	return codepoint - jongseong(codepoint) + jong
end

--[[
	문장 끝의 `다`를 존댓말로 바꾼다.
	`다` 바로 뒤가 문장 부호이거나 문자열 끝일 때만 종결어미로 본다
	(그래야 "그런다면" 같은 어중 `다`를 건드리지 않는다).
]]
local function politeSentence(text: string): string
	local out = {}
	local index = 1
	-- 직전 두 음절을 들고 다닌다. `는다` 판정에 필요하다.
	local prev: number? = nil
	local prevPrev: number? = nil

	while index <= #text do
		local codepoint, nextIndex = decode(text, index)
		if not codepoint then
			break
		end

		if codepoint == 0xB2E4 and isHangul(prev) then -- '다'
			local after = string.sub(text, nextIndex, nextIndex)
			local terminal = after == "" or after == "." or after == "!" or after == "?"
			if terminal then
				local stem = prev :: number
				if stem == 0xB294 and isHangul(prevPrev) then -- '는'
					-- `는다` → `습니다` : 앞 음절은 그대로 두고 '는'을 '습니'로 바꾼다.
					table.remove(out) -- '는' 제거
					table.insert(out, "습니다")
				elseif jongseong(stem) == JONG_N then
					table.remove(out)
					table.insert(out, encode(withJongseong(stem, JONG_B)))
					table.insert(out, "니다")
				elseif jongseong(stem) == 0 then
					table.remove(out)
					table.insert(out, encode(withJongseong(stem, JONG_B)))
					table.insert(out, "니다")
				else
					table.insert(out, "습니다")
				end
				prevPrev, prev = nil, nil
				index = nextIndex
				continue
			end
		end

		table.insert(out, encode(codepoint))
		prevPrev = prev
		prev = codepoint
		index = nextIndex
	end

	return table.concat(out)
end

--=== 파일 처리 ===--

local DIRECTORY = "src/shared/AbilityCards/"
local changedFiles = 0
local changedLines = 0

for _, entry in fs.readDir(DIRECTORY) do
	if entry:match("%.luau$") and entry ~= "init.luau" then
		local path = DIRECTORY .. entry
		local source = fs.readFile(path)
		local lines = {}
		local touched = false
		local inDescription = false

		for line in (source .. "\n"):gmatch("(.-)\n") do
			local isStart = line:match("^%s*Description = ")
			-- 이어지는 줄은 `.. "…"` 형태다.
			local isContinuation = inDescription and line:match('^%s*%.%.%s*"')

			if isStart or isContinuation then
				local converted = line:gsub('"([^"]*)"', function(inner)
					return '"' .. politeSentence(inner) .. '"'
				end)
				if converted ~= line then
					touched = true
					changedLines += 1
				end
				table.insert(lines, converted)
				-- 줄 끝이 쉼표면 Description 항목이 끝난 것이다.
				inDescription = not line:match(",%s*$")
			else
				inDescription = false
				table.insert(lines, line)
			end
		end

		if touched then
			fs.writeFile(path, table.concat(lines, "\n"):gsub("\n$", ""))
			changedFiles += 1
			print(string.format("  %s", entry))
		end
	end
end

print(string.format("[polite] 파일 %d개 / 줄 %d개 변환", changedFiles, changedLines))
