--!nocheck
--[[
	Snow_WalkScan.luau — 2026-11-08. 슈네라이히 마을 걷는 자리 격자 재기(1 스터드 칸, 층 여럿).
	사용자: "플레이어 두 명이 앞만 보고 걸어갔을 때 약간 남을 수 있는 너비" → 칸마다 걸을 수 있는 바닥 높이를 재서
	tools/snow_walkwidth.py 가 너비 지도(폭 10 미만 좁은 길)를 그린다.
	칸마다: 위(y 135)에서 아래로 광선(CanCollide 만) → 맞은 윗면(법선 y > 0.7)마다 그 위 사람 기둥(1×4.2×1, 발 1.3 위부터 — 넘을 수 있는 턱은 빼고)이
	비었으면 걸을 수 있는 층. 광선은 맞은 자리 조금 밑에서 다시 쏴 아래층도 찾는다(맞음 14 · 층 6 까지).
	보고: /walk_info(범위), /walk_NNN(줄 묶음). 칸 하나 = 층 수 한 글자 + 층마다 높이 두 글자((h-40)/0.05, 64진).
	bash tools/job.sh tools/Snow_WalkScan.luau
]]
local HS = game:GetService("HttpService")
local town = workspace.Schneereich["마을"]
local A = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"

-- 범위: 마을 파트(큰 판 빼고)의 XZ 끝
local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
for _, p in town:GetDescendants() do
	if p:IsA("BasePart") and p.Size.Magnitude < 400 then
		local c = p.Position
		x0, x1 = math.min(x0, c.X), math.max(x1, c.X)
		z0, z1 = math.min(z0, c.Z), math.max(z1, c.Z)
	end
end
x0, x1, z0, z1 = math.floor(x0) - 4, math.ceil(x1) + 4, math.floor(z0) - 4, math.ceil(z1) + 4
local NX, NZ = x1 - x0, z1 - z0
HS:PostAsync("http://127.0.0.1:34999/walk_info", string.format("%d %d %d %d", x0, z0, NX, NZ))

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = {}
rp.RespectCanCollide = true
local op = OverlapParams.new()
op.RespectCanCollide = true
op.MaxParts = 1
local TOP, BOT = 135, 45
local BOX = Vector3.new(1, 4.2, 1) -- 발 1.3 위부터(계단 턱 0.73 이 칸 안에 들면 막힌 것으로 잘못 보던 것 — 2026-11-08)

local function enc(h)
	local v = math.clamp(math.floor((h - 40) / 0.05 + 0.5), 0, 4095)
	return A:sub(v // 64 + 1, v // 64 + 1) .. A:sub(v % 64 + 1, v % 64 + 1)
end

local rows, chunk, n = {}, 0, 0
local t0 = os.clock()
for iz = 0, NZ - 1 do
	local z = z0 + iz + 0.5
	local line = table.create(NX)
	for ix = 0, NX - 1 do
		local x = x0 + ix + 0.5
		local y = TOP
		local lv = {}
		for _ = 1, 14 do
			local r = workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, BOT - y, 0), rp)
			if not r then
				break
			end
			local h = r.Position.Y
			if r.Normal.Y > 0.7 then
				local hit = workspace:GetPartBoundsInBox(CFrame.new(x, h + 1.3 + 2.1, z), BOX, op)
				if #hit == 0 then
					table.insert(lv, enc(h))
					if #lv >= 6 then
						break
					end
				end
			end
			y = h - 0.05
		end
		line[ix + 1] = #lv .. table.concat(lv)
		n += 1
		if n % 2500 == 0 then
			task.wait()
		end
	end
	table.insert(rows, table.concat(line))
	if #rows >= 40 or iz == NZ - 1 then
		HS:PostAsync(string.format("http://127.0.0.1:34999/walk_%03d", chunk), table.concat(rows, "\n"))
		chunk += 1
		rows = {}
	end
end
HS:PostAsync("http://127.0.0.1:34999/walk_done", string.format("chunks %d cells %d sec %.1f", chunk, n, os.clock() - t0))
