-- ZFight_Count.luau — 2026-10-24. ZFight_Scan 이 남긴 _G.ZFightPairs 에서 보이는 쌍(아래 보지 않음 · 색/재질 다름)을 정확히 센다 → recv/zcount.txt (묶음 목록은 넓이 큰 것만 보여 작은 쌍이 빠진다)
local HS = game:GetService("HttpService")
local ROOTS = { workspace:FindFirstChild("Surface"), workspace:FindFirstChild("Jeolhwa"), workspace:FindFirstChild("Schneereich") }
local function ok(p)
	for _, r in ipairs(ROOTS) do
		if p:IsDescendantOf(r) then
			return true
		end
	end
	return false
end
-- 같은 색·재질 쌍은 무늬 없는 재질일 때만 안 보인다(ZFight_Fix 와 같은 기준)
local FLAT = { [Enum.Material.SmoothPlastic] = true, [Enum.Material.Neon] = true, [Enum.Material.Glass] = true, [Enum.Material.ForceField] = true }
local mineN, otherN, ex = 0, 0, {}
for _, q in ipairs(_G.ZFightPairs or {}) do
	if q.n.Y > -0.5 and q.a.Parent and q.b.Parent and not (q.a.Color == q.b.Color and q.a.Material == q.b.Material and FLAT[q.a.Material]) then
		if ok(q.a) or ok(q.b) then
			mineN += 1
			if #ex < 12 then
				ex[#ex + 1] = string.format("%.2f %s ~ %s @ %.0f %.0f %.0f", q.area, q.a:GetFullName():sub(-50), q.b:GetFullName():sub(-50), q.a.Position.X, q.a.Position.Y, q.a.Position.Z)
			end
		else
			otherN += 1
		end
	end
end
HS:PostAsync("http://127.0.0.1:34999/zcount", string.format("보이는 쌍: 내 폴더 %d, 그 밖(사용자 모델) %d\n", mineN, otherN) .. table.concat(ex, "\n"))
