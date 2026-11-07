--!strict
--[[
	Fx/Quasar — 퀘이사 이펙트. 보랏빛 중력과 별가루. (2026-09-28)
	무게가 느껴지게: 모여드는 빛(빨려듦) → 크게 터지는 충격파 → 땅의 금·돌 조각.
	2026-11-06 고급화: 예비(어둠 소용돌이·모으기 플립북) → 타격(충격파 + 임팩트·잿빛 플립북 + 균열·별 팩) → 여운(어둠 연기·별가루).
	암흑기사풍 검은 층은 Pack 이 다시 칠하지 않는다. 흰 섬광은 짧게.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local VIOLET = c(150, 120, 255)
local DEEP = c(60, 30, 120)
local STAR = c(230, 225, 255)

-- 플립북 그림(tools/combat/out/vfx_textures.tsv 의 flip=Grid* 만)
local TEX = {
	Charge = { "rbxassetid://15041986621", "Grid4x4" },
	Impact = { "rbxassetid://16923007448", "Grid4x4" },
	Ash = { "rbxassetid://16955854038", "Grid4x4" },
	Wave = { "rbxassetid://16477162837", "Grid4x4" },
	Shield = { "rbxassetid://17086390547", "Grid4x4" },
	Bolt = { "rbxassetid://16951505034", "Grid2x2" },
	Slash = { "rbxassetid://16939611858", "Grid4x4" },
}
local FRAMES = { Grid2x2 = 4, Grid4x4 = 16, Grid8x8 = 64 }

-- 플립북 한 장(공용 CombatVfx.Flipbook). 틀이 없으면 조용히 건너뛴다
local function fb(ctx: any, at: Vector3, key: string, o: { [string]: any })
	local flip = ctx.Vfx.Flipbook
	if not flip then
		return
	end
	local t = TEX[key]
	local opt = table.clone(o)
	opt.Texture, opt.Layout = t[1], t[2]
	opt.Framerate = opt.Framerate or FRAMES[t[2]] / (opt.Life or 0.5)
	flip(at, opt)
end

local Fx = {}

function Fx.HeavyLand(ctx: any)
	local feet = Common.Feet(ctx)
	Common.Land(ctx.Vfx, feet, 1.4, c(180, 170, 200))
	ctx.Vfx.Shockwave(feet + Vector3.new(0, 0.1, 0), { Color = VIOLET, Radius = 5, Life = 0.4 })
	Common.Crack(ctx.Vfx, feet + ctx.Forward * 1.5, ctx.Forward, 4, DEEP)
	fb(ctx, feet + Vector3.new(0, 0.6, 0), "Wave", { Size = 6, Color = VIOLET, Life = 0.4, LightEmission = 0.4, Transparency = 0.4 })
	ctx.Vfx.Pack("Anime/Crack-01", CFrame.new(feet + Vector3.new(0, 0.2, 0)), { Color = VIOLET, Size = 0.9, Count = 0.6 })
end

function Fx.MassAbsorb(ctx: any)
	ctx.Vfx.Implode(ctx.Root.Position, { Color = VIOLET, Radius = 3.5, Count = 10, Life = 0.35 })
	ctx.Vfx.Ring(CFrame.new(ctx.Root.Position), { R0 = 2.5, R1 = 1, Color = VIOLET, Life = 0.3, Width = 0.2, Height = 0.1 })
	-- 예비: 몸으로 빨려드는 보랏빛 + 어둠 소용돌이
	fb(ctx, ctx.Root.Position, "Charge", { Size = 4, Color = VIOLET, Life = 0.35, LightEmission = 0.5 })
	ctx.Vfx.Pack("Loose/BlackSwirl", CFrame.new(ctx.Root.Position), { Size = 0.3, Count = 0.5 })
end

function Fx.GravityWall(ctx: any)
	local front = ctx.Root.Position + ctx.Forward * 2
	ctx.Vfx.Ring(CFrame.lookAt(front, front + ctx.Forward), { R0 = 0.5, R1 = 3, Color = VIOLET, Life = 0.45, Width = 0.3, Facing = true })
	fb(ctx, front, "Shield", { Size = 5.5, Color = VIOLET, Life = 0.45, LightEmission = 0.4, Transparency = 0.35 })
	ctx.Vfx.Pack("Anime/Shield-01", CFrame.lookAt(front, front + ctx.Forward), { Color = VIOLET, Size = 0.7, Count = 0.8 })
end

function Fx.Deflect(ctx: any)
	local p = ctx.Tip() or ctx.Root.Position + ctx.Forward * 2
	ctx.Vfx.Sparks(p, { Color = STAR, Count = 20, Speed = 26 })
	ctx.Vfx.Flash(p, { Color = VIOLET, Size = 5, Life = 0.16 })
	ctx.Vfx.Shake(0.2, 0.15)
	fb(ctx, p, "Impact", { Size = 4.5, Color = STAR, Life = 0.28, LightEmission = 0.6 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = STAR, Size = 0.5 })
end

-- 붕괴 모으기: 칼 위에 검은 구가 생겨 주위 빛가루를 빨아들인다
function Fx.Implode(ctx: any)
	local Vfx = ctx.Vfx
	local above = ctx.Root.Position + Vector3.new(0, 4.5, 0.5)
	local core = Vfx.Part(Vector3.new(1, 1, 1), CFrame.new(above), c(20, 10, 40), Enum.Material.Neon, Enum.PartType.Ball)
	local halo = Vfx.Part(Vector3.new(1.6, 1.6, 1.6), CFrame.new(above), VIOLET, Enum.Material.Neon, Enum.PartType.Ball)
	halo.Transparency = 0.6
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 0.85 do
			local k = (os.clock() - t0) / 0.85
			core.Size = Vector3.one * (1 + k * 1.8)
			halo.Size = Vector3.one * (1.6 + k * 2.6 + math.sin(k * 40) * 0.2)
			task.wait()
		end
		core:Destroy()
		halo:Destroy()
	end)
	for i = 0, 3 do
		task.delay(i * 0.18, function()
			Vfx.Implode(above, { Color = if i % 2 == 0 then VIOLET else STAR, Radius = 7, Count = 14, Life = 0.4 })
			fb(ctx, above, "Charge", { Size = 3 + i * 0.8, Color = if i % 2 == 0 then VIOLET else STAR, Life = 0.4, LightEmission = 0.5, Transparency = 0.3 })
		end)
	end
	-- 예비: 검은 구 둘레의 어둠 소용돌이와 별빛
	Vfx.Pack("Loose/BlackSwirl", CFrame.new(above), { Size = 0.5, Count = 0.6 })
	Vfx.Pack("Loose/PurpleExpanding", CFrame.new(above), { Size = 0.4, Count = 0.6 })
	Vfx.Pack("Anime/Stars-01", CFrame.new(above), { Color = STAR, Size = 0.6 })
end

-- 붕괴 타격: 보랏빛 충격파 + 땅이 갈라지고 돌이 튄다
function Fx.CollapseSlam(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	-- 맞은 적이 여럿이면 범위 전체를 한 번 덮는다(단일 대상처럼 보이지 않게 — 2026-11-07)
	local area = Common.TargetsArea(ctx)
	if area and Common.Once(ctx, "CollapseSlam") then
		Common.AreaFill(ctx, area, VIOLET, { Core = STAR })
	end
	local ground = Common.Feet(ctx) + ctx.Forward * 3
	local p = at or ctx.Target
	Vfx.Flash(p, { Color = VIOLET, Size = 10, Life = 0.22, Brightness = 5 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.1, 0), { Color = VIOLET, Radius = 9, Life = 0.5 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.2, 0), { Color = DEEP, Radius = 6, Life = 0.35 })
	Common.Rubble(Vfx, ground, 16, c(120, 110, 140))
	for k = -1, 1 do
		local dir = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), k * 0.5) * ctx.Forward)
		Common.Crack(Vfx, ground, dir, 6, DEEP, 1.2)
	end
	Common.Arc(ctx, ctx.Root.Position + ctx.Forward * 2 + Vector3.new(0, 1, 0), 0, 150, -40, { Radius = 4.5, Color = VIOLET, Core = STAR, Width = 1.4, Sweep = 0.05 })
	-- 마켓 팩 질감: 땅 갈라짐 + 중력 소용돌이
	Vfx.Pack("Anime/Crack-01", CFrame.new(ground + Vector3.new(0, 0.2, 0)), { Color = VIOLET, Size = 1.5 })
	Vfx.Pack("Loose/Swirling", CFrame.new(p), { Color = VIOLET, Size = 0.5 })
	-- 타격·여운 층: 임팩트·충격 플립북, 별 폭발, 잿빛·어둠 연기
	fb(ctx, p, "Impact", { Size = 9, Color = VIOLET, Life = 0.36, LightEmission = 0.6 })
	fb(ctx, p, "Wave", { Size = 12, Color = STAR, Life = 0.4, LightEmission = 0.5, Transparency = 0.5 })
	fb(ctx, ground + Vector3.new(0, 1, 0), "Ash", { Size = 7, Color = c(110, 100, 135), Life = 0.7, LightEmission = 0, Transparency = 0.3, Accel = Vector3.new(0, 3, 0) })
	Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = STAR, Size = 1 })
	Vfx.Pack("Loose/Black", CFrame.new(ground + Vector3.new(0, 1, 0)), { Size = 0.4, Count = 0.5 })
end

-- 붕괴 차징: 앞쪽 적 칸들에서 보랏빛이 시전자 쪽으로 끌려온다
function Fx.Pull(ctx: any)
	local Vfx = ctx.Vfx
	local hand = ctx.Hand("L")
	for i = 1, 5 do
		local from = ctx.Root.Position + ctx.Forward * (4 + i * 2) + Vector3.new(0, 0.5, 0)
		Vfx.Beam(from, hand, { Color = if i % 2 == 0 then VIOLET else DEEP, Width = 0.25, Life = 0.35 })
	end
	Vfx.Implode(hand, { Color = STAR, Radius = 4, Count = 10, Life = 0.3 })
	-- 예비: 손에 맺히는 보랏빛 응집 + 끌려오는 어둠
	fb(ctx, hand, "Charge", { Size = 3.2, Color = VIOLET, Life = 0.35, LightEmission = 0.5 })
	Vfx.Pack("Anime/Charge-01", CFrame.new(hand), { Color = VIOLET, Size = 0.6, Count = 0.4 })
	Vfx.Pack("Loose/BlackSwirl", CFrame.new(hand), { Size = 0.25, Count = 0.5 })
end

function Fx.PointSky(ctx: any)
	local tip = ctx.Tip() or Common.Head(ctx)
	ctx.Vfx.Pillar(tip, { Color = VIOLET, Height = 30, Width = 0.8, Life = 0.6 })
	ctx.Vfx.Flash(tip, { Color = STAR, Size = 4, Life = 0.25 })
	fb(ctx, tip, "Charge", { Size = 3.6, Color = VIOLET, Life = 0.4, LightEmission = 0.6 })
	fb(ctx, tip, "Bolt", { Size = 4, Color = STAR, Life = 0.25, LightEmission = 0.7 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(tip), { Color = STAR, Size = 0.6 })
end

-- 특이점: 대상 위 하늘에 거대한 빛의 검이 거꾸로 나타난다
local summoned: { [any]: Model } = {}

-- 2026-10-03 사용자: 떨어지는 검을 퀘이사 무기(블렌더 대검)로 — 손에 든 대검 조각을 복제해 2.2배로 키우고 거꾸로(끝이 아래) 세운다.
-- 무기가 없으면(구경 등) 예전 빛의 검 조각으로
local GIANT = 2.2
-- 모델을 피벗 기준으로 k 배(부품 크기·자리 모두)
local function scaleModel(model: Model, k: number)
	local pivot = model:GetPivot()
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(p.CFrame)
			p.Size *= k
			p.CFrame = pivot * (CFrame.new(rel.Position * k) * rel.Rotation)
		end
	end
end

--[[
	2026-10-03 단계 연출(사양: 특이점은 소모한 질량에 따라 3단계로 연출과 범위가 바뀜). ctx.Stage = 범위 단계 + 1
	  1단계  검을 상대 위에 소환해 내려찍음
	  2단계  큰 검 — 빔을 쏜 뒤 내려찍음(SingularityBeam)
	  3단계  아주 큰 검 — 빔 뒤 파동이 퍼지도록 내려찍음(SingularityHit 의 파동)
	ctx.Vfx 는 단계만큼 이미 커져 있다(CombatDirector). 검 모델 크기만 여기서 단계로 키운다
]]
local SWORD_STAGE = { 1, 1.4, 1.9 }

function Fx.SummonSword(ctx: any)
	local Vfx = ctx.Vfx
	local S = SWORD_STAGE[ctx.Stage or 1] or SWORD_STAGE[#SWORD_STAGE]
	local top = ctx.Target + Vector3.new(0, 14 * S, 0)
	local model = if ctx.Weapons then ctx.Weapons:ClonePiece("W") else nil
	if model then
		model.Name = "SingularitySword"
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Grip" then
				p.CastShadow = false
				p.Transparency = math.max(p.Transparency, 0.08)
			end
		end
		scaleModel(model, GIANT * S)
		-- 손잡이(원점)를 위에, 날끝(6.9 × 배율)이 아래로
		model:PivotTo(CFrame.new(top + Vector3.new(0, 6 * S, 0)) * CFrame.Angles(math.pi, 0, 0))
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = VIOLET, 18, 3
		light.Parent = model.PrimaryPart
	else
		model = Instance.new("Model")
		model.Name = "SingularitySword"
		local function piece(size: Vector3, off: Vector3, color: Color3, alpha: number)
			local p = Vfx.Part(size, CFrame.new(top + off), color)
			p.Transparency = alpha
			p.Parent = model
			return p
		end
		piece(Vector3.new(2.2, 11, 0.5), Vector3.new(0, -1, 0), VIOLET, 0.25)
		piece(Vector3.new(0.7, 11.5, 0.7), Vector3.new(0, -1, 0), STAR, 0.05)
		piece(Vector3.new(5, 0.8, 1.2), Vector3.new(0, 4.6, 0), DEEP, 0.1)
		piece(Vector3.new(0.9, 3, 0.9), Vector3.new(0, 6.4, 0), DEEP, 0.1)
	end
	if not ctx.Weapons then
		scaleModel(model, S)
	end
	-- 떨어질 거리(날끝이 땅에 박히게) — DropSword
	model:SetAttribute("Drop", 12.5 * S)
	model.Parent = Vfx.Folder()
	summoned[ctx.Actor] = model
	Vfx.Flash(top, { Color = VIOLET, Size = 14, Life = 0.3 })
	Vfx.Implode(top, { Color = STAR, Radius = 9, Count = 20, Life = 0.5 })
	-- 예비: 하늘의 포털에서 검이 나타난다(어둠 소용돌이 + 모으기 + 별)
	fb(ctx, top, "Charge", { Size = 9 * S, Color = VIOLET, Life = 0.55, LightEmission = 0.5, Transparency = 0.3 })
	Vfx.Pack("Anime/Portal-01", CFrame.lookAt(top, top - Vector3.yAxis), { Color = VIOLET, Size = 1.4 * S, Count = 0.6 })
	Vfx.Pack("Loose/BlackSwirl", CFrame.new(top), { Size = 0.6 * S, Count = 0.5 })
	Vfx.Pack("Anime/Stars-01", CFrame.new(top), { Color = STAR, Size = 1.2 * S })
end

-- 내려 긋는 손짓: 빛의 검이 떨어져 꽂힌다(0.25초)
function Fx.DropSword(ctx: any)
	local model = summoned[ctx.Actor]
	summoned[ctx.Actor] = nil
	if not model then
		return
	end
	local start = model:GetPivot()
	local goal = start - Vector3.new(0, model:GetAttribute("Drop") or 12.5, 0)
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 0.25 do
			local k = ((os.clock() - t0) / 0.25) ^ 2
			model:PivotTo(start:Lerp(goal, k))
			task.wait()
		end
		model:PivotTo(goal)
		fb(ctx, goal.Position + Vector3.new(0, 6, 0), "Slash", { Size = 10, Color = STAR, Life = 0.2, LightEmission = 0.6, Transparency = 0.3 })
		task.wait(0.5)
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
		model:Destroy()
	end)
end

-- 2단계부터: 떠 있는 검에서 대상으로 빔(내려찍기 전)
function Fx.SingularityBeam(ctx: any)
	if (ctx.Stage or 1) < 2 then
		return
	end
	local Vfx = ctx.Vfx
	local S = SWORD_STAGE[ctx.Stage] or SWORD_STAGE[#SWORD_STAGE]
	local from = ctx.Target + Vector3.new(0, 14 * S - 4, 0)
	Vfx.Beam(from, ctx.Target, { Color = VIOLET, Width = 1.4, Life = 0.4 })
	Vfx.Flash(ctx.Target, { Color = STAR, Size = 8, Life = 0.3 })
	Vfx.Shockwave(Vector3.new(ctx.Target.X, ctx.Ground + 0.1, ctx.Target.Z), { Color = VIOLET, Radius = 4, Life = 0.3 })
	fb(ctx, from, "Charge", { Size = 6 * S, Color = VIOLET, Life = 0.4, LightEmission = 0.6 })
	fb(ctx, ctx.Target, "Impact", { Size = 6 * S, Color = STAR, Life = 0.3, LightEmission = 0.6 })
	Vfx.Pack("Anime/Charge-01", CFrame.new(from), { Color = VIOLET, Size = 1.2 * S, Count = 0.5 })
end

function Fx.SingularityHit(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	local ground = Vector3.new(p.X, ctx.Ground, p.Z)
	-- 3단계: 내려찍은 자리에서 파동 셋이 차례로 퍼진다
	if (ctx.Stage or 1) >= 3 then
		for i, r in { 14, 20, 26 } do
			task.delay(0.1 * i, function()
				Vfx.Shockwave(ground + Vector3.new(0, 0.15, 0), { Color = if i == 2 then STAR else VIOLET, Radius = r, Life = 0.6 })
			end)
		end
	end
	Vfx.Flash(p, { Color = STAR, Size = 12, Life = 0.22, Brightness = 6 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.1, 0), { Color = VIOLET, Radius = 10, Life = 0.55 })
	Vfx.Pillar(ground, { Color = VIOLET, Height = 16, Width = 3.5, Life = 0.5 })
	Common.Rubble(Vfx, ground, 14, c(120, 110, 140))
	for k = 0, 5 do
		Common.Crack(Vfx, ground, CFrame.fromAxisAngle(Vector3.new(0, 1, 0), k / 6 * math.pi * 2) * ctx.Forward, 5, DEEP, 1.2)
	end
	-- 타격·여운 층: 별빛 폭발 + 충격 플립북 + 땅 균열·어둠 소용돌이 팩, 그 뒤 연기
	local st = ctx.Stage or 1
	fb(ctx, p, "Impact", { Size = 10 + st * 2, Color = VIOLET, Life = 0.4, LightEmission = 0.6 })
	fb(ctx, p, "Wave", { Size = 14 + st * 3, Color = STAR, Life = 0.45, LightEmission = 0.5, Transparency = 0.5 })
	fb(ctx, ground + Vector3.new(0, 1.5, 0), "Ash", { Size = 8 + st * 2, Color = c(110, 100, 135), Life = 0.8, LightEmission = 0, Transparency = 0.3, Accel = Vector3.new(0, 3, 0) })
	Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = STAR, Size = 1.3 })
	Vfx.Pack("Anime/Crack-01", CFrame.new(ground + Vector3.new(0, 0.2, 0)), { Color = VIOLET, Size = 1.6, Count = 0.6 })
	Vfx.Pack("Loose/BlackSwirl", CFrame.new(ground + Vector3.new(0, 1, 0)), { Size = 0.6, Count = 0.5 })
end

function Fx.InfallCut(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	Common.Arc(ctx, ctx.Root.Position + Vector3.new(0, 0.6, 0), 85, 160, -30, { Radius = 5, Color = VIOLET, Core = STAR, Width = 1.1, Sweep = 0.05 })
	ctx.Vfx.Flash(p, { Color = VIOLET, Size = 6, Life = 0.18 })
	ctx.Vfx.Sparks(p, { Color = STAR, Count = 16 })
	ctx.Vfx.Implode(p, { Color = STAR, Radius = 3, Count = 8, Life = 0.3 })
	fb(ctx, p, "Slash", { Size = 7, Color = VIOLET, Life = 0.26, LightEmission = 0.6 })
	fb(ctx, p, "Impact", { Size = 5, Color = STAR, Life = 0.3, LightEmission = 0.6 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = STAR, Size = 0.7 })
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), VIOLET)
	ctx.Vfx.Pack("Loose/Sparkles", CFrame.new(ctx.Root.Position), { Color = STAR, Size = 0.6, Count = 0.3 })
end

return Fx
