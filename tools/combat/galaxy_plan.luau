--!nolint
-- GalaxyParticles.Plan 을 읽어 이미터 수·살아 있는 입자 수(Rate × 평균 Lifetime)를 세고 평면도용 JSON 을 쓴다.
--   lune run tools/combat/galaxy_plan.luau  → tools/combat/out/galaxy_plan.json (python tools/combat/galaxy_layout.py 가 그림으로)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local G = require("../../src/client/Combat/GalaxyParticles")

local plan, beams = G.Plan(135)
local live, byLayer, emittersBy = 0, {}, {}
for _, s in plan do
	local n = s.Rate * (s.Life[1] + s.Life[2]) / 2
	live += n
	byLayer[s.Layer] = (byLayer[s.Layer] or 0) + n
	emittersBy[s.Layer] = (emittersBy[s.Layer] or 0) + 1
end
print(("이미터 %d (한도 70) · 살아 있는 입자 약 %d (한도 2000)"):format(#plan, live))
for layer, n in byLayer do
	print(("  %-9s 이미터 %2d · 입자 %4d"):format(layer, emittersBy[layer], n))
end
print(("Beam %d (한도 110)"):format(#beams))
fs.writeFile("tools/combat/out/galaxy_plan.json", serde.encode("json", { emitters = plan, beams = beams }, true))
