-- Snow_Town3_MoveKeep.luau 의 순수 함수(상자 빼기·칸 묶기) 시험. lune run tools/movekeep_test.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local src = fs.readFile("tools/Snow_Town3_MoveKeep.luau")
local body = src:match("%-%-@@PURE_BEGIN\n(.-)\n%-%-@@PURE_END")
assert(body, "PURE 구간을 못 찾음")
local f = luau.load(body .. "\nreturn { newBox = newBox, intersects = intersects, subtract = subtract, mergeCells = mergeCells }")
local M = f()
local vol = function(b)
	return (b.x1 - b.x0) * (b.y1 - b.y0) * (b.z1 - b.z0)
end
math.randomseed(7)
local function rnd(lo, hi)
	return lo + math.random() * (hi - lo)
end
local function rbox()
	local x, y, z = rnd(-10, 10), rnd(-10, 10), rnd(-10, 10)
	return M.newBox(x, x + rnd(1, 12), y, y + rnd(1, 12), z, z + rnd(1, 12))
end
local fails, maxPieces = 0, 0
for _ = 1, 3000 do
	local a, b = rbox(), rbox()
	local pieces = M.subtract(a, b)
	maxPieces = math.max(maxPieces, #pieces)
	local ov = 0
	if M.intersects(a, b) then
		ov = (math.min(a.x1, b.x1) - math.max(a.x0, b.x0)) * (math.min(a.y1, b.y1) - math.max(a.y0, b.y0)) * (math.min(a.z1, b.z1) - math.max(a.z0, b.z0))
	end
	local sum = 0
	for i, p in ipairs(pieces) do
		sum += vol(p)
		if M.intersects(p, b) and #pieces > 0 and M.intersects(a, b) then
			fails += 1
		end
		for j = i + 1, #pieces do
			if M.intersects(p, pieces[j]) then
				fails += 1
			end
		end
	end
	if math.abs(sum - (vol(a) - ov)) > 1e-6 then
		fails += 1
	end
end
assert(fails == 0, "상자 빼기 실패 " .. fails)
assert(maxPieces <= 6, "조각 6 초과")
-- 완전히 덮이면 0 조각, 안 겹치면 원래 하나
assert(#M.subtract(M.newBox(0, 1, 0, 1, 0, 1), M.newBox(-1, 2, -1, 2, -1, 2)) == 0, "덮임")
assert(#M.subtract(M.newBox(0, 1, 0, 1, 0, 1), M.newBox(5, 6, 5, 6, 5, 6)) == 1, "안겹침")

-- 칸 묶기: 합 = 칸 수, 겹침 없음, 칸 밖 없음
for _ = 1, 300 do
	local set, cells = {}, {}
	for j = 0, 14 do
		for i = 0, 14 do
			if math.random() < 0.6 then
				set[i .. "," .. j] = true
				cells[#cells + 1] = { i, j }
			end
		end
	end
	local rects = M.mergeCells(cells)
	local seen, total = {}, 0
	for _, r in ipairs(rects) do
		for j = r.j0, r.j1 do
			for i = r.i0, r.i1 do
				local k = i .. "," .. j
				assert(set[k], "칸 밖")
				assert(not seen[k], "겹침")
				seen[k] = true
				total += 1
			end
		end
	end
	assert(total == #cells, "합 불일치")
end
print("movekeep_test OK")
