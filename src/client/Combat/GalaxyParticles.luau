--!strict
--[[
	GalaxyParticles — 칼리스토 3페이즈 "필드 아래 우리은하"를 파티클로 짠다(2026-11-06 사용자:
	  "은하수 전체를 이루는 파티클이 여러개 필요해. sol's rng를 참고해서 만들면 퀄리티 좋게 만들 수 있을거야")
	Plan(radius)        순수 수치 배치표(인스턴스 없음 — tools/combat/galaxy_plan.luau 가 읽어 예산 계산·평면도를 그린다)
	Build(g, cf, radius) 배치표대로 부품·이미터를 g(은하 모형) 아래에 만들고 이미터 목록을 돌려준다(처음엔 모두 꺼 둔다)

	조사 요약(Sol's RNG 오라 — 정확한 제작 방식은 공개 자료가 없다. 확인된 것만):
	  · 작품 설명·모음 글에서 Galaxy 오라(1/500,000, 별 떨어지는 바이옴) = "우주 같은 웅웅 소리 + 눈에 띄는 외형" 정도만 공개
	    (itemlevel.net/sols-rng-all-aura-showcase, ginx.tv 오라 목록). 파티클 구성 해설은 DevForum 에도 없음(검색 확인).
	  · 일반 오라 제작법: 블렌더 메시를 층층이 겹치고 색·크기·회전·투명도를 스크립트로 흔든다(devforum.roblox.com/t/how-do-yall-make-auras/1383893),
	    ZOffset 으로 층 겹침 순서, 오라는 LockedToPart=false 로 입자가 흩날리게(CodePal 오라 가이드), Beam = 두 Attachment 사이 텍스처 띠.
	  → 이 모듈이 따온 요령: ① 같은 자리에 크기·밝기가 다른 이미터를 여러 겹(작은 반짝 알갱이 + 큰 옅은 글로우)
	    ② 발광(LightEmission 1) 알갱이와 비발광(0) 어두운 먼지를 섞어 깊이감 ③ Size·Transparency NumberSequence 로 서서히 켜졌다 꺼지게(+ Envelope 로 크기 무작위)
	    ④ 소용돌이 = 나선 팔을 따라 놓은 여러 Part 위 이미터, 회전은 은하 모형이 도는 것에 LockedToPart 로 실려서 ⑤ 길게 늘인(Squash) 입자로 유성.
	  (LockedToPart=true 로 한 건 은하 전체가 함께 돌아야 해서 — 오라처럼 흩날리게 하려면 false.)

	쓴 ParticleEmitter 속성(전부 create.roblox.com/docs/reference/engine/classes/ParticleEmitter 확인):
	  Enabled · LockedToPart · LightInfluence · LightEmission · Texture · Rate · Color · Size · Transparency · Lifetime · Speed · SpreadAngle
	  · Rotation · RotSpeed · Shape · ShapeStyle · EmissionDirection(Enum.NormalId) · Orientation(Enum.ParticleOrientation) · Squash(NumberSequence)
	쓴 Enum 항목(문서 확인): ParticleEmitterShape Box/Sphere · ParticleEmitterShapeStyle Volume · ParticleOrientation FacingCamera/VelocityParallel · NormalId Front.
	미확인(스튜디오에서 볼 것): Squash 부호(+가 늘이는지)·VelocityParallel 에서 어느 축이 길어지는지 — 문서에 설명 없음 → 아래 METEOR_SQUASH 한 곳만 고치면 된다.
]]

local GalaxyParticles = {}

local K, R0 = 0.21, 14 -- 로그 나선 r = 14·e^(0.21t) (build_callisto_space.py 와 같다), 팔 사이 90°
local ARMS = 4
local SEGMENTS = 7 -- 팔 하나를 이어 붙인 Part 수(곧은 상자로 곡선을 근사 — 겹쳐 놓는다)
local METEOR_SQUASH = 0.8 -- 유성 입자를 길게 늘이는 Squash 값(부호 스튜디오 확인)

type Spec = { [string]: any }

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX: { [string]: string } = { Sparkle = SPARKLE, Smoke = SMOKE }

local GOLD = { 255, 207, 138 }
local PALEGOLD = { 255, 238, 200 }
local WHITE = { 255, 255, 255 }
local BLUE = { 168, 200, 255 }
local NEBULA = { { 150, 100, 240 }, { 255, 120, 190 }, { 90, 220, 230 }, { 120, 130, 255 } } -- 팔마다 보라·분홍·청록·남색
local DUST = { 62, 42, 34 }

-- 두 색 사이를 흘러가는 Color 표
local function grad(...: { number }): { any }
	local list = { ... }
	local out = {}
	for i, c in list do
		table.insert(out, { (i - 1) / math.max(#list - 1, 1), c })
	end
	return out
end

-- 서서히 켜졌다 꺼지는 크기 곡선(peak = 최대, spread = 무작위 폭 Envelope)
local function bell(peak: number, spread: number): { any }
	return { { 0, 0, 0 }, { 0.2, peak, spread }, { 0.8, peak * 0.75, spread }, { 1, 0, 0 } }
end
local function fadeAlpha(mid: number): { any } -- 투명도: 1 → mid → 1
	return { { 0, 1 }, { 0.2, mid }, { 0.8, mid + (1 - mid) * 0.3 }, { 1, 1 } }
end

function GalaxyParticles.Plan(radius: number): { Spec }
	local list: { Spec } = {}
	local rmax = math.min(radius * 0.95, 130)
	local T0, T1 = 2.2, math.log(rmax / R0) / K
	local function pt(arm: number, t: number): (number, number, number, number, number, number)
		local r = R0 * math.exp(K * t)
		local a = arm * math.pi / 2 + t
		local x, z = math.cos(a) * r, -math.sin(a) * r
		local dx, dz = K * math.cos(a) - math.sin(a), -(K * math.sin(a) + math.cos(a)) -- 접선(바깥 방향)
		local n = math.sqrt(dx * dx + dz * dz)
		return x, z, dx / n, dz / n, math.cos(a), -math.sin(a) -- 위치, 접선, 반지름 방향 단위
	end
	local function add(s: Spec)
		table.insert(list, s)
	end

	for arm = 0, ARMS - 1 do
		-- ① 밝은 별 띠: 팔을 따라 7 토막, 안쪽은 금빛 → 바깥은 청백
		for k = 1, SEGMENTS do
			local t0 = T0 + (T1 - T0) * (k - 1) / SEGMENTS
			local t1 = T0 + (T1 - T0) * k / SEGMENTS
			local tc = (t0 + t1) / 2
			local x, z, dx, dz = pt(arm, tc)
			local r0, r1 = R0 * math.exp(K * t0), R0 * math.exp(K * t1)
			local len = 1.022 * (r1 - r0) / K * 1.2 -- 곡선 호 길이 + 겹침
			local r = R0 * math.exp(K * tc)
			local width = 3 + r * 0.07
			add({
				Name = ("ArmStars_%d_%d"):format(arm, k), Layer = "ArmStars", Arm = arm,
				Pos = { x, 0, z }, Look = { dx, dz }, Size = { width, 2 + (1 - r / 135) * 3, len },
				Shape = "Box", Dir = "Front", Rate = 2.5 + 0.06 * len, Life = { 5, 7 }, Speed = { 2, 5 }, Spread = 4,
				Tex = "Sparkle", Glow = 1, RotSpeed = { -40, 40 },
				Color = if r < 45 then grad(GOLD, WHITE) else grad(WHITE, BLUE), Scale = bell(3, 1.4), Alpha = fadeAlpha(0.1),
			})
		end
		-- ② 팔 바깥 성운(크고 옅음, 낮은 LightEmission)과 ③ 안쪽 경계 먼지(어둡고 반투명, 발광 0)
		for i, tc in { 5.2, 8.4 } do
			local x, z, dx, dz, rx, rz = pt(arm, tc)
			local r = R0 * math.exp(K * tc)
			local off = 6 + r * 0.14
			add({
				Name = ("Nebula_%d_%d"):format(arm, i), Layer = "Nebula", Arm = arm,
				Pos = { x + rx * off, 0, z + rz * off }, Look = { dx, dz }, Size = { 12 + r * 0.2, 5, 22 + r * 0.35 },
				Shape = "Box", Dir = "Front", Rate = 1.4, Life = { 10, 13 }, Speed = { 0.5, 1.5 }, Spread = 20,
				Tex = "Smoke", Glow = 0.35, RotSpeed = { -6, 6 },
				Color = grad(NEBULA[arm + 1], BLUE), Scale = { { 0, 28 + r * 0.15, 6 }, { 1, 40 + r * 0.2, 8 } }, Alpha = { { 0, 1 }, { 0.3, 0.9 }, { 0.7, 0.92 }, { 1, 1 } },
			})
		end
		for i, tc in { 3.9, 7.0 } do
			local x, z, dx, dz, rx, rz = pt(arm, tc)
			local r = R0 * math.exp(K * tc)
			local off = 5 + r * 0.11
			add({
				Name = ("Dust_%d_%d"):format(arm, i), Layer = "Dust", Arm = arm,
				Pos = { x - rx * off, 0, z - rz * off }, Look = { dx, dz }, Size = { 8 + r * 0.12, 4, 18 + r * 0.3 },
				Shape = "Box", Dir = "Front", Rate = 1.1, Life = { 10, 12 }, Speed = { 0.5, 1.5 }, Spread = 15,
				Tex = "Smoke", Glow = 0, RotSpeed = { -5, 5 },
				Color = grad(DUST, { 90, 62, 48 }), Scale = { { 0, 18 + r * 0.1, 4 }, { 1, 28 + r * 0.14, 6 } }, Alpha = { { 0, 1 }, { 0.3, 0.8 }, { 0.7, 0.86 }, { 1, 1 } },
			})
		end
	end

	-- ④ 팽대부(중심): 금백색 알갱이 · 큰 글로우 · 중간 글로우 · 가운데 반짝
	local function bulge(name: string, size: number, s: Spec)
		s.Name, s.Layer, s.Pos, s.Size, s.Shape = name, "Bulge", { 0, 0, 0 }, { size, size * 0.5, size }, "Sphere"
		add(s)
	end
	bulge("BulgeGrain", 26, { Rate = 18, Life = { 3, 4.5 }, Speed = { 0, 2 }, Tex = "Sparkle", Glow = 1, RotSpeed = { -60, 60 },
		Color = grad(GOLD, PALEGOLD), Scale = bell(2.6, 1.2), Alpha = fadeAlpha(0.1) })
	bulge("BulgeGlowBig", 14, { Rate = 2.2, Life = { 8, 10 }, Speed = { 0, 1 }, Tex = "Smoke", Glow = 1, RotSpeed = { -8, 8 },
		Color = grad(GOLD, { 255, 170, 90 }), Scale = { { 0, 36, 6 }, { 1, 56, 8 } }, Alpha = { { 0, 1 }, { 0.3, 0.86 }, { 0.7, 0.9 }, { 1, 1 } } })
	bulge("BulgeGlowMid", 8, { Rate = 3, Life = { 5, 6 }, Speed = { 0, 1 }, Tex = "Smoke", Glow = 1, RotSpeed = { -12, 12 },
		Color = grad(PALEGOLD, GOLD), Scale = { { 0, 14, 3 }, { 1, 24, 4 } }, Alpha = { { 0, 1 }, { 0.3, 0.72 }, { 0.7, 0.8 }, { 1, 1 } } })
	bulge("BulgeFlare", 4, { Rate = 1.2, Life = { 2.2, 3 }, Speed = { 0, 0 }, Tex = "Sparkle", Glow = 1, RotSpeed = { 20, 60 },
		Color = grad(WHITE, GOLD), Scale = { { 0, 0, 0 }, { 0.5, 16, 4 }, { 1, 0, 0 } }, Alpha = { { 0, 0.2 }, { 1, 0.2 } } })

	-- ⑤ 원반 전체의 잔별(납작한 타원체 안에 흩뿌림 — 가운데가 더 촘촘) · 안개 · 가끔 크게 반짝이는 별
	local disc = { radius * 2, 6, radius * 2 }
	local function discLayer(name: string, s: Spec)
		s.Name, s.Layer, s.Pos, s.Size, s.Shape = name, "Disc", { 0, 0, 0 }, disc, "Sphere"
		s.Speed = s.Speed or { 0, 0 }
		add(s)
	end
	discLayer("DiscStarsWhite", { Rate = 12, Life = { 8, 10 }, Tex = "Sparkle", Glow = 1, RotSpeed = { -20, 20 },
		Color = grad(WHITE, BLUE), Scale = { { 0, 0, 0 }, { 0.25, 1.4, 0.6 }, { 0.5, 0.6, 0.3 }, { 0.75, 1.4, 0.6 }, { 1, 0, 0 } }, Alpha = fadeAlpha(0.1) })
	discLayer("DiscStarsColor", { Rate = 6, Life = { 8, 10 }, Tex = "Sparkle", Glow = 1, RotSpeed = { -30, 30 },
		Color = grad({ 190, 210, 255 }, { 255, 190, 220 }, GOLD), Scale = bell(2.4, 1), Alpha = fadeAlpha(0.15) })
	discLayer("DiscHaze", { Rate = 2.4, Life = { 12, 15 }, Tex = "Smoke", Glow = 0.3, RotSpeed = { -4, 4 },
		Color = grad({ 120, 90, 220 }, { 90, 140, 230 }), Scale = { { 0, 45, 8 }, { 1, 70, 10 } }, Alpha = { { 0, 1 }, { 0.3, 0.93 }, { 0.7, 0.95 }, { 1, 1 } } })
	discLayer("DiscFlare", { Rate = 1.5, Life = { 1.8, 2.6 }, Tex = "Sparkle", Glow = 1, RotSpeed = { 20, 60 },
		Color = grad(WHITE, GOLD), Scale = { { 0, 0, 0 }, { 0.5, 14, 4 }, { 1, 0, 0 } }, Alpha = { { 0, 0 }, { 1, 0 } } })
	discLayer("DiscFlareBig", { Rate = 0.35, Life = { 3, 4 }, Tex = "Sparkle", Glow = 1, RotSpeed = { 10, 30 },
		Color = grad(WHITE, BLUE), Scale = { { 0, 0, 0 }, { 0.5, 24, 5 }, { 1, 0, 0 } }, Alpha = { { 0, 0 }, { 1, 0 } } })

	-- ⑥ 유성(길게 늘인 입자가 은하 위를 가로지른다): 원반 가장자리 양쪽 막대에서 서로 반대로
	for i, side in { 1, -1 } do
		add({
			Name = "Meteor" .. i, Layer = "Meteor", Pos = { -side * radius * 0.8, 8, side * radius * 0.3 }, Look = { side * 0.9, -side * 0.4 },
			Size = { 40, 2, 4 }, Shape = "Box", Dir = "Front", Rate = 0.35, Life = { 1.1, 1.6 }, Speed = { 80, 110 }, Spread = 0,
			Tex = "Sparkle", Glow = 1, Orient = "VelocityParallel", Squash = METEOR_SQUASH, RotSpeed = { 0, 0 },
			Color = if i == 1 then grad(WHITE, BLUE) else grad(PALEGOLD, GOLD), Scale = { { 0, 0, 0 }, { 0.15, 7, 1 }, { 1, 2, 0 } },
			Alpha = { { 0, 1 }, { 0.15, 0 }, { 0.7, 0.2 }, { 1, 1 } },
		})
	end
	return list
end

local function nseq(t: { any }): NumberSequence
	local keys = {}
	for _, k in t do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2], k[3] or 0))
	end
	return NumberSequence.new(keys)
end
local function cseq(t: { any }): ColorSequence
	local keys = {}
	for _, k in t do
		local c = k[2]
		table.insert(keys, ColorSequenceKeypoint.new(k[1], Color3.fromRGB(c[1], c[2], c[3])))
	end
	return ColorSequence.new(keys)
end

function GalaxyParticles.Build(g: Model, cf: CFrame, radius: number): { ParticleEmitter }
	local anchor = Instance.new("Folder")
	anchor.Name = "GalaxyFx"
	anchor.Parent = g
	local out: { ParticleEmitter } = {}
	for _, s in GalaxyParticles.Plan(radius) do
		local p = Instance.new("Part")
		p.Name = s.Name
		p.Transparency = 1
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size = Vector3.new(s.Size[1], s.Size[2], s.Size[3])
		local at = cf * Vector3.new(s.Pos[1], s.Pos[2], s.Pos[3])
		local look = s.Look
		p.CFrame = if look then CFrame.lookAt(at, at + cf:VectorToWorldSpace(Vector3.new(look[1], 0, look[2]))) else CFrame.new(at) * cf.Rotation
		p.Parent = anchor
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.LockedToPart = true
		e.LightInfluence = 0
		e.LightEmission = s.Glow
		e.Texture = TEX[s.Tex]
		e.Rate = s.Rate
		e.Lifetime = NumberRange.new(s.Life[1], s.Life[2])
		e.Speed = NumberRange.new(s.Speed[1], s.Speed[2])
		e.SpreadAngle = Vector2.new(s.Spread or 0, s.Spread or 0)
		e.Color = cseq(s.Color)
		e.Size = nseq(s.Scale)
		e.Transparency = nseq(s.Alpha)
		e.Rotation = NumberRange.new(0, if s.Orient then 0 else 360)
		e.RotSpeed = NumberRange.new(s.RotSpeed[1], s.RotSpeed[2])
		e.Shape = (Enum.ParticleEmitterShape :: any)[s.Shape]
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		if s.Dir then
			e.EmissionDirection = (Enum.NormalId :: any)[s.Dir]
		end
		if s.Orient then
			e.Orientation = (Enum.ParticleOrientation :: any)[s.Orient]
			e.Squash = NumberSequence.new(s.Squash)
		end
		e.Parent = p
		table.insert(out, e)
	end
	return out
end

return GalaxyParticles
