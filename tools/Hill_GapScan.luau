--!nocheck
--[[
	Hill_GapScan.luau — 2026-09-27. 숲 거목(보스) 언덕의 빈 공간 찾기 → recv/hillgap.txt

	구역(REGION)을 STEP 격자로 위에서 쏴 땅 높이 지도를 만들고(World, Mountains, Ramps 만 땅으로 본다)
	  구멍   아무것도 안 맞는 칸 (이웃 넷은 맞는데)
	  틈     양옆(동서 또는 남북) 둘 다보다 3 넘게 꺼진 좁은 골. 블록 사이가 벌어진 곳
	  웅덩이 이웃 여덟 모두보다 3 넘게 낮은 점
	을 모아 이웃끼리 묶어 덩어리로 보고한다. 거목 오르는 길(남북 축 x -1600) 위 턱도 잰다.
	_G.HillGaps 에 덩어리 목록을 남긴다.
]]
local REGION = { -1900, 60, -1300, 1040 } -- x0, z0, x1, z1
local STEP = 3
local S = workspace.Surface
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
local ground = { S.World }
for _, n in ipairs({ "Mountains", "Ramps" }) do
	if S:FindFirstChild(n) then
		ground[#ground + 1] = S[n]
	end
end
rp.FilterDescendantsInstances = ground

local H, INST = {}, {}
local x0, z0, x1, z1 = REGION[1], REGION[2], REGION[3], REGION[4]
local nx, nz = math.floor((x1 - x0) / STEP), math.floor((z1 - z0) / STEP)
for i = 0, nx do
	H[i], INST[i] = {}, {}
	for j = 0, nz do
		local h = workspace:Raycast(Vector3.new(x0 + i * STEP, 600, z0 + j * STEP), Vector3.new(0, -900, 0), rp)
		H[i][j] = h and h.Position.Y or false
		INST[i][j] = h and h.Instance or nil
	end
	if i % 20 == 0 then
		task.wait()
	end
end

local bad = {}
for i = 1, nx - 1 do
	for j = 1, nz - 1 do
		local v = H[i][j]
		local W, E, N, Sx = H[i - 1][j], H[i + 1][j], H[i][j + 1], H[i][j - 1]
		local kind
		if not v then
			if W and E and N and Sx then
				kind = "구멍"
			end
		else
			if (W and E and W - v > 3 and E - v > 3) or (N and Sx and N - v > 3 and Sx - v > 3) then
				kind = "틈"
			end
		end
		if kind then
			bad[#bad + 1] = { i = i, j = j, kind = kind, v = v, nb = math.max(W or -1e9, E or -1e9, N or -1e9, Sx or -1e9) }
		end
	end
end
-- 이웃끼리 묶기
local key = {}
for k, b in ipairs(bad) do
	key[b.i .. "," .. b.j] = k
end
local seen, blobs = {}, {}
for k, b in ipairs(bad) do
	if not seen[k] then
		local stack, cells = { k }, {}
		seen[k] = true
		while #stack > 0 do
			local c = table.remove(stack)
			cells[#cells + 1] = bad[c]
			for di = -1, 1 do
				for dj = -1, 1 do
					local q = key[(bad[c].i + di) .. "," .. (bad[c].j + dj)]
					if q and not seen[q] then
						seen[q] = true
						stack[#stack + 1] = q
					end
				end
			end
		end
		local sx, sz, lo, hi = 0, 0, 1e9, -1e9
		local kinds = {}
		for _, c in ipairs(cells) do
			sx += x0 + c.i * STEP
			sz += z0 + c.j * STEP
			kinds[c.kind] = true
			if c.v then
				lo = math.min(lo, c.v)
			end
			hi = math.max(hi, c.nb)
		end
		local kl = {}
		for kk in pairs(kinds) do
			kl[#kl + 1] = kk
		end
		blobs[#blobs + 1] = { n = #cells, x = sx / #cells, z = sz / #cells, lo = lo, hi = hi, kind = table.concat(kl, "+"), cells = cells }
	end
end
table.sort(blobs, function(a, b)
	return a.n > b.n
end)
_G.HillGaps = blobs
local out = { string.format("구역 %d..%d, %d..%d 격자 %d: 덩어리 %d (칸 %d)", x0, x1, z0, z1, STEP, #blobs, #bad) }
for k = 1, math.min(60, #blobs) do
	local b = blobs[k]
	local inst = INST[b.cells[1].i][b.cells[1].j]
	out[#out + 1] = string.format("  %-6s 칸 %3d @ (%.0f, %.0f) 바닥 %s 둘레 %.1f  %s", b.kind, b.n, b.x, b.z,
		b.lo < 1e8 and string.format("%.1f", b.lo) or "없음", b.hi, inst and inst:GetFullName():gsub("^Workspace%.Surface%.", "") or "")
end
-- 오르는 길 두 줄(x -1600 ± 20) 위 턱
out[#out + 1] = "== 오르는 길 위 턱 (한 칸 3 에 2.5 넘게 오르는 곳)"
for _, lane in ipairs({ -1620, -1600, -1580 }) do
	local i = math.floor((lane - x0) / STEP)
	for j = 1, nz do
		local a, b = H[i][j - 1], H[i][j]
		if a and b and math.abs(b - a) > 2.5 then
			out[#out + 1] = string.format("  x %d z %.0f: %.1f → %.1f", lane, z0 + j * STEP, a, b)
		end
	end
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/hillgap", table.concat(out, "\n"))
print("hillgap", #blobs)
