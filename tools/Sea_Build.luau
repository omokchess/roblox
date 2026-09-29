--!nocheck
--[[
	Sea_Build.luau — 섬들 둘레에 바다(지형 물)를 깐다. (2026-09-29 요청: "바다를 놔줘")
	편집 모드 로더: bash tools/job.sh tools/Sea_Build.luau  → /sea 보고

	잰 값(2026-09-29 높이 지도 recv/hmap*.txt): 섬 밑바닥(Gb 바위)은 모두 y -27, 가장자리 윗면은
	늪 -3~-2 · 숲/평원 -2~1 · 오염지대 -1~0 · 사막 3~4 · 성역 4~5 · 광산 8~11 · 설원 18~19 · 화산 39~42.
	그래서 수면을 -3.5 에 둔다(가장 낮은 늪 물가가 0.5 위). 높은 섬은 벼랑으로 바다에서 솟는다.
	섬 안에 수면보다 낮은 바닥은 늪 흙 판·수상가옥 다리뿐(늪 블록 물 -0.4 밑이라 안 보인다).

	물: y -28 ~ -3.5, 바닥: 모래 y -36 ~ -28(물속에서 허공이 안 보이게). 1024 칸씩 나눠 채운다.
	나중에 섬을 잇는 대륙이 되면 그 자리 물은 지형 도구로 비우면 된다(물은 부품을 밀어내지 않는다).
]]
local HS = game:GetService("HttpService")
local T = workspace.Terrain

local X0, X1, Z0, Z1 = -9600, 7808, -8000, 5824
local TOP, BOTTOM, FLOOR = -3.5, -28, -36
local TILE = 1024

T.WaterColor = Color3.fromRGB(16, 84, 104)
T.WaterTransparency = 0.35
T.WaterReflectance = 0.55
T.WaterWaveSize = 0.18
T.WaterWaveSpeed = 9

local n = 0
local t0 = os.clock()
for x = X0, X1 - 1, TILE do
	for z = Z0, Z1 - 1, TILE do
		local w = math.min(TILE, X1 - x)
		local d = math.min(TILE, Z1 - z)
		local cx, cz = x + w / 2, z + d / 2
		T:FillBlock(CFrame.new(cx, (TOP + BOTTOM) / 2, cz), Vector3.new(w, TOP - BOTTOM, d), Enum.Material.Water)
		T:FillBlock(CFrame.new(cx, (BOTTOM + FLOOR) / 2, cz), Vector3.new(w, BOTTOM - FLOOR, d), Enum.Material.Sand)
		n += 1
		if n % 8 == 0 then
			task.wait()
		end
	end
end

-- 확인: 바다 몇 곳의 수면
local out = {}
for _, p in { { 5000, 0 }, { -1000, 4000 }, { 0, -5000 }, { -6000, -1000 } } do
	local r = workspace:Raycast(Vector3.new(p[1], 200, p[2]), Vector3.new(0, -400, 0))
	table.insert(out, string.format("(%d,%d) %s", p[1], p[2], r and string.format("%s y=%.2f", r.Material.Name, r.Position.Y) or "없음"))
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/sea", string.format("타일 %d, %.1f초\n%s", n, os.clock() - t0, table.concat(out, "\n")))
end)
