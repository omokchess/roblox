--!nocheck
--[[
	Player_SpawnFix.luau — 허공에서 시작하는 것을 고친다.

	원인은 프로젝트의 PlazaService 29줄이다.
		local SPAWN_CENTER = Vector3.new(-990, 36, -990)
	이 자리는 바다 한가운데다. 광장이 거기 떠 있고 플레이어는 그 위에서
	시작해 떨어진다. 맵을 1/3 로 줄인 뒤에는 더 멀어졌다.

	**좌표를 손으로 새로 적지 않는다.** 평원 섬을 격자로 훑어
	  땅이 있고, 절화 궁과 멀고, 주위 60 스터드가 평평한
	자리를 골라 그 값을 써 넣는다. 맵 배율이 또 바뀌어도 다시 돌리면 된다.

	바꾸는 것
	  ServerScriptService/Server/PlazaService 의 SPAWN_CENTER 한 줄
	  Workspace/PlayerSpawn 발판 자리
	  이미 세워져 있던 PorcelainPlaza 는 지운다. 다음 실행에서 새 자리에 다시 선다
]]

local SSS = game:GetService("ServerScriptService")
local World = workspace.Surface.World
local G = World:FindFirstChild("G_평원")
assert(G, "G_평원 이 없다")

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { G }

local function ground(x, z)
	local h = workspace:Raycast(Vector3.new(x, 4000, z), Vector3.new(0, -8000, 0), rp)
	return h and h.Position.Y or nil
end

-- 절화 궁을 피해야 한다. 궁 모델의 범위를 잰다
local palace = workspace:FindFirstChild("Jeolhwa_FIXED_ALL_VISIBLE")
local pmnx, pmxx, pmnz, pmxz = 1e9, -1e9, 1e9, -1e9
if palace then
	for _, p in ipairs(palace:GetDescendants()) do
		if p:IsA("BasePart") then
			pmnx = math.min(pmnx, p.Position.X - p.Size.X / 2)
			pmxx = math.max(pmxx, p.Position.X + p.Size.X / 2)
			pmnz = math.min(pmnz, p.Position.Z - p.Size.Z / 2)
			pmxz = math.max(pmxz, p.Position.Z + p.Size.Z / 2)
		end
	end
end

local PLAZA = 130 -- 광장이 차지할 한 변. 이만큼은 비어 있어야 한다
local KEEP = 90 -- 궁에서 떨어뜨릴 거리

-- 섬 범위
local mnx, mxx, mnz, mxz = 1e9, -1e9, 1e9, -1e9
for _, p in ipairs(G:GetChildren()) do
	if p:IsA("BasePart") then
		mnx, mxx = math.min(mnx, p.Position.X), math.max(mxx, p.Position.X)
		mnz, mxz = math.min(mnz, p.Position.Z), math.max(mxz, p.Position.Z)
	end
end

-- 후보를 훑어 가장 평평하고 궁에서 먼 자리를 고른다
local best, bestScore = nil, -1e9
local STEP = 20
for x = mnx + PLAZA, mxx - PLAZA, STEP do
	for z = mnz + PLAZA, mxz - PLAZA, STEP do
		-- 궁과 겹치지 않는지
		local nearPalace = palace
			and (x + PLAZA / 2 > pmnx - KEEP and x - PLAZA / 2 < pmxx + KEEP)
			and (z + PLAZA / 2 > pmnz - KEEP and z - PLAZA / 2 < pmxz + KEEP)
		if not nearPalace then
			local lo, hi, n = 1e9, -1e9, 0
			for ix = -1, 1 do
				for iz = -1, 1 do
					local g = ground(x + ix * PLAZA * 0.45, z + iz * PLAZA * 0.45)
					if g then
						lo, hi, n = math.min(lo, g), math.max(hi, g), n + 1
					end
				end
			end
			if n == 9 then
				-- 평평한 쪽이 좋고, 섬 가운데보다 가장자리가 아닌 쪽이 좋다
				local flat = -(hi - lo)
				local mid = -(math.abs(x - (mnx + mxx) / 2) + math.abs(z - (mnz + mxz) / 2)) * 0.02
				local score = flat + mid
				if score > bestScore then
					bestScore, best = score, Vector3.new(x, hi, z)
				end
			end
		end
	end
end

assert(best, "평원에서 광장을 놓을 자리를 못 찾았다")

--=== PlazaService 의 한 줄을 바꾼다 ===--
local svc = SSS:FindFirstChild("Server")
assert(svc, "Server 스크립트가 없다")
local mod = svc:FindFirstChild("PlazaService")
assert(mod, "PlazaService 가 없다")

local src = mod.Source
local before = src:match("local SPAWN_CENTER = Vector3%.new%([^\n]*%)")
assert(before, "SPAWN_CENTER 줄을 못 찾았다")

local after = string.format("local SPAWN_CENTER = Vector3.new(%d, %d, %d)",
	math.floor(best.X + 0.5), math.floor(best.Y + 0.5), math.floor(best.Z + 0.5))
mod.Source = src:gsub("local SPAWN_CENTER = Vector3%.new%([^\n]*%)", after, 1)

--=== 세워져 있던 광장은 지운다. 새 자리에 다시 선다 ===--
local oldPlaza = workspace:FindFirstChild("PorcelainPlaza")
if oldPlaza then
	oldPlaza:Destroy()
end

--=== 스폰 발판도 같은 자리로 ===--
local pad = workspace:FindFirstChild("PlayerSpawn")
if pad then
	pad.Position = Vector3.new(best.X, best.Y + 2.5, best.Z + 62)
end

--=== 자기검사 ===--
assert(mod.Source:find(after, 1, true), "SPAWN_CENTER 가 안 바뀌었다")
local g9 = 0
for ix = -1, 1 do
	for iz = -1, 1 do
		if ground(best.X + ix * PLAZA * 0.45, best.Z + iz * PLAZA * 0.45) then
			g9 = g9 + 1
		end
	end
end
assert(g9 == 9, "고른 자리 " .. g9 .. "/9 만 땅이다")

print("[Spawn] 전: " .. before)
print("[Spawn] 후: " .. after)
print(string.format("[Spawn] 평원 범위 x %d..%d z %d..%d / 궁 x %d..%d z %d..%d",
	mnx, mxx, mnz, mxz, pmnx, pmxx, pmnz, pmxz))
print("[Spawn] 광장 자리 아홉 점 모두 땅이다. 발판도 같이 옮겼다")
