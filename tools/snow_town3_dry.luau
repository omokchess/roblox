-- snow_town3_dry.luau — Studio 없이 3판 자료를 읽어 표 길이·좌표 범위·없는 필드를 검사하고 부품 수를 센다.
-- 돌리기: $LUNE run tools/snow_town3_dry.luau   (프로젝트 루트에서)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local D = luau.load(fs.readFile("tools/Snow_Town3_data.luau"))()
local inside = luau.load(fs.readFile("tools/Snow_Inside3_data.luau") .. "\nreturn INSIDE")()

local problems = {}
local function bad(fmt, ...)
	problems[#problems + 1] = string.format(fmt, ...)
end
local function isnum(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e7
end
local function checkRows(label, rows, nfields, numFrom, extra)
	for i, r in ipairs(rows) do
		if #r < nfields then
			bad("%s[%d] 필드 %d 개 (필요 %d)", label, i, #r, nfields)
		end
		for j = numFrom, nfields do
			if not isnum(r[j]) then
				bad("%s[%d] 필드 %d 가 숫자가 아님: %s", label, i, j, tostring(r[j]))
			end
		end
		if extra then
			extra(i, r)
		end
	end
end

local X0, X1, Z0, Z1, YMIN, YMAX = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
local function range(x0, x1, z0, z1, y)
	X0, X1 = math.min(X0, x0, x1), math.max(X1, x0, x1)
	Z0, Z1 = math.min(Z0, z0, z1), math.max(Z1, z0, z1)
	YMIN, YMAX = math.min(YMIN, y), math.max(YMAX, y)
end
local function box(label, i, r, ix)
	if r[ix[1]] >= r[ix[2]] then
		bad("%s[%d] x0>=x1", label, i)
	end
	if r[ix[3]] >= r[ix[4]] then
		bad("%s[%d] z0>=z1", label, i)
	end
	range(r[ix[1]], r[ix[2]], r[ix[3]], r[ix[4]], r[ix[5]])
end

-- 표 형식
checkRows("PADS", D.PADS, 9, 2)
for i, r in ipairs(D.PADS) do
	if type(r[1]) ~= "string" or type(r[10]) ~= "string" then
		bad("PADS[%d] 모델·이름 문자열 아님", i)
	end
	if not isnum(r[9]) then
		bad("PADS[%d] 번호", i)
	end
	range(r[2], r[2], r[3], r[3], r[5])
end
checkRows("KEEP", D.KEEP, 4, 2)
checkRows("TERRACES", D.TERRACES, 6, 2, function(i, r)
	box("TERRACES", i, r, { 2, 3, 4, 5, 6 })
	if r[7] ~= "눈" and r[7] ~= "돌바닥" then
		bad("TERRACES[%d] 재질 %s", i, tostring(r[7]))
	end
end)
checkRows("STEPS", D.STEPS, 6, 2, function(i, r)
	box("STEPS", i, r, { 2, 3, 4, 5, 6 })
end)
checkRows("ROCKS", D.ROCKS, 5, 1, function(i, r)
	box("ROCKS", i, r, { 1, 2, 3, 4, 5 })
end)
checkRows("SLABS", D.SLABS, 5, 1, function(i, r)
	box("SLABS", i, r, { 1, 2, 3, 4, 5 })
end)
checkRows("PATH_PIECES", D.PATH_PIECES, 7, 2, function(i, r)
	range(r[3], r[5], r[4], r[6], r[7])
end)
checkRows("PROPS", D.PROPS, 6, 2, function(i, r)
	if r[6] <= 0 then
		bad("PROPS[%d] 배율 %s", i, r[6])
	end
	range(r[2], r[2], r[3], r[3], r[4])
end)
for i, p in ipairs(D.PATHS) do
	if type(p[3]) ~= "table" or #p[3] < 2 then
		bad("PATHS[%d] 점 부족", i)
	end
end
if not (D.AIRSHIP and #D.AIRSHIP == 4) then
	bad("AIRSHIP 형식")
end
for _, k in ipairs({ "KEEP_FOLDERS", "REMOVE_FOLDERS", "BACKUP" }) do
	if D[k] == nil then
		bad("%s 없음", k)
	end
end

-- 높이 제한: 바위·단 윗면이 바닥 59.2 보다 낮은가
local low, h1 = 0, 0
local tall = 0
for _, r in ipairs(D.ROCKS) do
	local h = r[5] - 59.2
	if h <= 0 then
		low += 1
	end
	if h <= 1 then
		h1 += 1
	end
	tall = math.max(tall, h)
end
-- 안살림: 건물 이름이 PADS 모델에 있는가
local padNames = {}
for _, r in ipairs(D.PADS) do
	padNames[r[1]] = true
end
local insideKinds = 0
for k, spec in pairs(inside) do
	insideKinds += 1
	if not padNames[k] then
		bad("INSIDE.%s 는 PADS 에 없는 모델", k)
	end
	for _, f in ipairs({ "coll", "lamps" }) do
		if type(spec[f]) ~= "table" then
			bad("INSIDE.%s.%s 없음", k, f)
		end
	end
	for i, b in ipairs(spec.coll or {}) do
		if #b < 7 then
			bad("INSIDE.%s.coll[%d] 필드 %d", k, i, #b)
		end
	end
	for i, f in ipairs(spec.fires or {}) do
		if #f < 4 then
			bad("INSIDE.%s.fires[%d] 필드 %d", k, i, #f)
		end
	end
end

-- 부품 수(스크립트 규칙: 높이 1 넘는 바위·단 = 2, 아니면 1)
local function two(rows, ti, mat)
	local n = 0
	for _, r in ipairs(rows) do
		if mat and r[mat] == "돌바닥" then
			n += 1
		elseif r[ti] - 59.2 > 1 then
			n += 2
		else
			n += 1
		end
	end
	return n
end
local terP = two(D.TERRACES, 6, 7)
local rockP = two(D.ROCKS, 5)
local pathP = 0
for _, r in ipairs(D.PATH_PIECES) do
	if math.sqrt((r[5] - r[3]) ^ 2 + (r[6] - r[4]) ^ 2) > 0.01 then
		pathP += 1
	end
end
local coll = 0
for _, spec in pairs(inside) do
	coll += #spec.coll + #spec.lamps + #(spec.npc or {}) + #(spec.fires or {})
end
local total = terP + #D.STEPS + rockP + #D.SLABS + pathP + coll + #D.PADS
print(string.format("표 길이: PADS %d · KEEP %d · 단 %d · 넓은 단 %d · 바위 %d · 판 %d · 길 조각 %d · 길 중심선 %d · 소품 %d · 비행선 %s",
	#D.PADS, #D.KEEP, #D.TERRACES, #D.STEPS, #D.ROCKS, #D.SLABS, #D.PATH_PIECES, #D.PATHS, #D.PROPS, D.AIRSHIP and "있음" or "없음"))
print(string.format("좌표 범위: x %.0f ~ %.0f · z %.0f ~ %.0f · y %.2f ~ %.2f", X0, X1, Z0, Z1, YMIN, YMAX))
print(string.format("바위 높이 ≤1(눈 상자 하나) %d · 윗면이 바닥 이하 %d · 가장 높은 바위 %.1f", h1, low, tall))
print(string.format("안살림 건물 %d 종 (충돌 등 부품 %d)", insideKinds, coll))
print(string.format("예상 부품: 단 %d · 넓은단 %d · 바위 %d · 판 %d · 길 %d · 안살림 상자 %d · 자리표시/건물 %d → 합계 약 %d (키트 메시 제외)",
	terP, #D.STEPS, rockP, #D.SLABS, pathP, coll, #D.PADS, total))
print(string.format("500개마다 task.wait → 약 %d 번 쉼, 한 번에 수 초", math.floor(total / 500)))
print(string.format("백업 대상 폴더 %d 개, 남길 규칙 %d", #D.REMOVE_FOLDERS, #D.KEEP_FOLDERS))
if #problems == 0 then
	print("문제 없음")
else
	for _, p in ipairs(problems) do
		print("문제:", p)
	end
end
