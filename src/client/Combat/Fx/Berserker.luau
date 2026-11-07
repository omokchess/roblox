--!strict
--[[
	Fx/Berserker — 광전사 이펙트. 피·검붉은 기운·돌. (2026-09-28)
	모든 것이 크다: 긴 타격 정지, 깊은 구덩이, 핏빛 초승달.
	2026-11-06 고급화: 예비(끓는 피·불씨 플립북) → 타격(원호 + 혈흔·불꽃·임팩트 플립북 + 땅 균열·피 팩) → 여운(연기·재).
	붉은 섬광은 짧게, 큰 면은 반투명으로 — 판과 캐릭터를 오래 덮지 않는다.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local BLOOD = c(200, 20, 24)
local DARK = c(60, 6, 10)
local EMBER = c(255, 90, 60)
local BLOODC = c(190, 28, 34)
local ASH = c(70, 55, 55)

-- 플립북 그림(tools/combat/out/vfx_textures.tsv 의 flip=Grid* 만)
local TEX = {
	Blood = { "rbxassetid://16664856199", "Grid4x4" },
	BloodPunch = { "rbxassetid://16668936898", "Grid4x4" },
	BloodPunch2 = { "rbxassetid://16669046762", "Grid4x4" },
	Fire = { "rbxassetid://13818306392", "Grid4x4" },
	Fire2 = { "rbxassetid://16676544947", "Grid4x4" },
	FireSlash = { "rbxassetid://16951304645", "Grid4x4" },
	Ash = { "rbxassetid://16955854038", "Grid4x4" },
	Punch = { "rbxassetid://16937107174", "Grid4x4" },
	Impact = { "rbxassetid://16923007448", "Grid4x4" },
	Slash = { "rbxassetid://16939611858", "Grid4x4" },
	Wave = { "rbxassetid://16477162837", "Grid4x4" },
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

function Fx.Crater(ctx: any)
	local Vfx = ctx.Vfx
	local feet = Common.Feet(ctx)
	Vfx.Shockwave(feet + Vector3.new(0, 0.1, 0), { Color = BLOOD, Radius = 6, Life = 0.45 })
	Common.Rubble(Vfx, feet + Vector3.new(0, 0.5, 0), 14)
	for k = 0, 5 do
		Common.Crack(Vfx, feet, CFrame.fromAxisAngle(Vector3.new(0, 1, 0), k / 6 * math.pi * 2) * ctx.Forward, 3.5, DARK)
	end
	fb(ctx, feet + Vector3.new(0, 0.8, 0), "Ash", { Size = 5.5, Color = ASH, Transparency = 0.35, Life = 0.7, LightEmission = 0 })
	fb(ctx, feet + Vector3.new(0, 0.6, 0), "Wave", { Size = 6, Color = BLOODC, Life = 0.4, LightEmission = 0.3, Transparency = 0.45 })
	Vfx.Pack("Anime/Crack-01", CFrame.new(feet + Vector3.new(0, 0.2, 0)), { Color = BLOOD, Size = 0.9, Count = 0.6 })
end

function Fx.Roar(ctx: any)
	local Vfx = ctx.Vfx
	local head = Common.Head(ctx)
	for i = 0, 2 do
		task.delay(i * 0.07, function()
			Vfx.Ring(CFrame.lookAt(head, head + ctx.Forward), { R0 = 0.5, R1 = 3 + i * 1.5, Color = if i == 1 then EMBER else BLOOD, Life = 0.35, Width = 0.2, Facing = true })
		end)
	end
	Vfx.Shake(0.35, 0.4)
	-- 포효 층: 입에서 퍼지는 충격 + 몸에서 이는 불길과 불씨
	local mouth = head + ctx.Forward * 0.8
	fb(ctx, mouth, "Wave", { Size = 6, Color = EMBER, Life = 0.4, LightEmission = 0.4, Transparency = 0.4 })
	fb(ctx, ctx.Root.Position, "Fire", { Size = 4.5, Color = EMBER, Life = 0.6, LightEmission = 0.4, Transparency = 0.35, Accel = Vector3.new(0, 4, 0) })
	Vfx.Pack("Anime/Fire-01", CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.5, 0)), { Color = EMBER, Size = 1.3, Count = 0.3 })
end

function Fx.HaftBlock(ctx: any)
	local p = ctx.Root.Position + ctx.Forward * 1.6 + Vector3.new(0, 0.6, 0)
	ctx.Vfx.Sparks(p, { Color = EMBER, Count = 20 })
	ctx.Vfx.Flash(p, { Color = EMBER, Size = 4.5, Life = 0.15 })
	ctx.Vfx.Shake(0.2, 0.15)
	fb(ctx, p, "Punch", { Size = 3.6, Color = EMBER, Life = 0.24, LightEmission = 0.5 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = EMBER, Size = 0.4 })
end

function Fx.ShoulderCheck(ctx: any)
	local p = ctx.Root.Position + ctx.Forward * 1.4
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.4, R1 = 2.6, Color = BLOOD, Life = 0.25, Width = 0.2, Facing = true })
	ctx.Vfx.Shake(0.25, 0.2)
	fb(ctx, p, "Punch", { Size = 4, Color = BLOODC, Life = 0.26, LightEmission = 0.3 })
end

-- 핏빛 분쇄 준비: 몸에서 피가 끓어오른다
function Fx.BloodBoil(ctx: any)
	local Vfx = ctx.Vfx
	Vfx.Burst(ctx.Root.Position, { Count = 12, Colors = Common.BLOOD, Size = 0.3, Speed = 8, Gravity = -10, Life = 0.6 })
	Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 3.5, R1 = 1, Color = BLOOD, Life = 0.35, Width = 0.2, Height = 0.06 })
	-- 예비: 몸에서 솟는 피안개와 불씨
	fb(ctx, ctx.Root.Position, "Blood", { Size = 4.5, Color = BLOODC, Transparency = 0.3, Life = 0.6, LightEmission = 0, Accel = Vector3.new(0, 5, 0) })
	fb(ctx, ctx.Root.Position + Vector3.new(0, -0.5, 0), "Fire2", { Size = 3.5, Color = EMBER, Transparency = 0.4, Life = 0.55, LightEmission = 0.3, Accel = Vector3.new(0, 4, 0) })
	Vfx.Pack("Anime/Blood-02", CFrame.new(ctx.Root.Position), { Color = BLOOD, Size = 0.9, Count = 0.5 })
end

-- 핏빛 분쇄: 핏빛 초승달이 내려꽂히고 구덩이에서 피가 솟구친다
function Fx.BloodCrash(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	local ground = Vector3.new(p.X, ctx.Ground, p.Z)
	Common.Arc(ctx, ctx.Root.Position + ctx.Forward * 2 + Vector3.new(0, 1, 0), 0, 160, -50, { Radius = 4.2, Color = BLOOD, Core = EMBER, Width = 1.3, Sweep = 0.04 })
	Vfx.Flash(p, { Color = BLOOD, Size = 10, Life = 0.22, Brightness = 5 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.1, 0), { Color = BLOOD, Radius = 8, Life = 0.5 })
	Vfx.Pillar(ground, { Color = BLOOD, Height = 8, Width = 3, Life = 0.4 })
	Common.Blood(Vfx, p, Vector3.new(0, 1, 0), 26, 26)
	Common.Rubble(Vfx, ground + Vector3.new(0, 0.5, 0), 16)
	for k = 0, 6 do
		Common.Crack(Vfx, ground, CFrame.fromAxisAngle(Vector3.new(0, 1, 0), k / 7 * math.pi * 2) * ctx.Forward, 5, DARK, 1.3)
	end
	-- 마켓 팩 질감: 초승달·돌·땅 충격(검은 층은 그대로) + 피 튐
	Vfx.Pack("vfx pack/f", CFrame.new(ground + Vector3.new(0, 0.3, 0)), { Color = BLOOD, Size = 0.45 })
	Vfx.Pack("Anime/Blood-Punch-01", CFrame.new(p), { Color = BLOOD, Size = 1.4 })
	-- 타격·여운 층: 혈흔·임팩트·불꽃 플립북, 균열 팩, 이어서 연기와 재
	fb(ctx, p, "BloodPunch2", { Size = 8, Color = BLOODC, Life = 0.5, LightEmission = 0 })
	fb(ctx, p, "Impact", { Size = 8, Color = EMBER, Life = 0.34, LightEmission = 0.5 })
	fb(ctx, ground + Vector3.new(0, 1, 0), "Fire", { Size = 6, Color = EMBER, Life = 0.6, LightEmission = 0.4, Transparency = 0.35, Accel = Vector3.new(0, 4, 0) })
	Vfx.Pack("Anime/Crack-01", CFrame.new(ground + Vector3.new(0, 0.2, 0)), { Color = BLOOD, Size = 1.6, Count = 0.6 })
	Vfx.Pack("Anime/Blood-01", CFrame.new(p), { Color = BLOOD, Size = 1.2 })
	task.delay(0.3, function()
		fb(ctx, ground + Vector3.new(0, 1.5, 0), "Ash", { Size = 7, Color = ASH, Transparency = 0.4, Life = 0.9, LightEmission = 0, Accel = Vector3.new(0, 2, 0) })
	end)
end

function Fx.AxeSlashA(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	Common.Arc(ctx, ctx.Root.Position + ctx.Forward * 1.5 + Vector3.new(0, 1, 0), -45, 140, -60, { Radius = 4, Color = BLOOD, Core = EMBER, Width = 1.1, Sweep = 0.04 })
	Common.Blood(ctx.Vfx, p, ctx.Forward + Vector3.new(0, 0.4, 0), 12, 20)
	ctx.Vfx.Flash(p, { Color = BLOOD, Size = 6, Life = 0.16 })
	fb(ctx, p, "BloodPunch", { Size = 4, Color = BLOODC, Life = 0.42, LightEmission = 0, Speed = 3, Spread = 25 })
	fb(ctx, p, "Slash", { Size = 5.5, Color = EMBER, Life = 0.22, LightEmission = 0.5 })
	ctx.Vfx.Pack("Anime/Slash-Impact-01", CFrame.new(p), { Color = BLOOD, Size = 0.9, Count = 0.5 })
end

function Fx.AxeSlashB(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	Common.Arc(ctx, ctx.Root.Position + ctx.Forward * 1.5 + Vector3.new(0, 1, 0), 45, 140, -60, { Radius = 4.4, Color = BLOOD, Core = EMBER, Width = 1.3, Sweep = 0.04 })
	Common.Blood(ctx.Vfx, p, ctx.Forward + Vector3.new(0, 0.6, 0), 16, 24)
	ctx.Vfx.Flash(p, { Color = BLOOD, Size = 7.5, Life = 0.2 })
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.4, R1 = 3, Color = BLOOD, Life = 0.3, Width = 0.22, Facing = true })
	fb(ctx, p, "BloodPunch2", { Size = 5, Color = BLOODC, Life = 0.45, LightEmission = 0, Speed = 3, Spread = 25 })
	fb(ctx, p, "FireSlash", { Size = 6, Color = EMBER, Life = 0.28, LightEmission = 0.5 })
	ctx.Vfx.Pack("Anime/Slash-Impact-01", CFrame.new(p), { Color = BLOOD, Size = 1.1, Count = 0.6 })
end

-- 회오리: 몸 둘레 핏빛 원호 + 흙먼지. 원호는 몸이 도는 쪽(모션 Root 돌림이 음수 = 위에서 보아 시계 방향)으로 돈다
-- (2026-10-03 사용자: 회전 모션과 회전 이펙트 방향이 반대 — -180 → 180 으로 뒤집음)
function Fx.Whirl(ctx: any)
	Common.Arc(ctx, ctx.Root.Position + Vector3.new(0, 0.3, 0), 90, -180, 180, { Radius = 4.6, Color = BLOOD, Core = EMBER, Width = 1, Sweep = 0.22, Life = 0.25, Segments = 26 })
	local feet = Common.Feet(ctx)
	fb(ctx, feet + Vector3.new(0, 1, 0), "Wave", { Size = 9, Color = BLOODC, Life = 0.3, LightEmission = 0.3, Transparency = 0.5 })
	ctx.Vfx.Pack("Anime/Fire-01", CFrame.new(feet + Vector3.new(0, 0.6, 0)), { Color = EMBER, Size = 1.2, Count = 0.25 })
end

function Fx.BurstBlast(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	-- 맞은 적이 여럿이면 범위 전체를 한 번 덮는다(단일 대상처럼 보이지 않게 — 2026-11-07)
	local area = Common.TargetsArea(ctx)
	if area and Common.Once(ctx, "BurstBlast") then
		Common.AreaFill(ctx, area, EMBER, { Core = BLOOD })
	end
	local ground = Common.Feet(ctx) + ctx.Forward * 3
	Vfx.Flash(ground + Vector3.new(0, 1, 0), { Color = EMBER, Size = 11, Life = 0.22, Brightness = 6 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.1, 0), { Color = BLOOD, Radius = 9, Life = 0.55 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.2, 0), { Color = EMBER, Radius = 5, Life = 0.35 })
	Common.Rubble(Vfx, ground + Vector3.new(0, 0.5, 0), 20)
	if at then
		Common.Blood(Vfx, at, Vector3.new(0, 1, 0), 10, 18)
		fb(ctx, at, "BloodPunch", { Size = 5, Color = BLOODC, Life = 0.45, LightEmission = 0 })
	end
	-- 폭발 층: 불길·임팩트 플립북 + 균열·불꽃 팩, 뒤이어 연기와 재
	local mid = ground + Vector3.new(0, 1.2, 0)
	fb(ctx, mid, "Fire", { Size = 9, Color = EMBER, Life = 0.55, LightEmission = 0.45, Transparency = 0.3, Accel = Vector3.new(0, 4, 0) })
	fb(ctx, mid, "Impact", { Size = 9, Color = EMBER, Life = 0.32, LightEmission = 0.5 })
	fb(ctx, mid, "Wave", { Size = 13, Color = BLOODC, Life = 0.4, LightEmission = 0.3, Transparency = 0.5 })
	Vfx.Pack("Anime/Crack-01", CFrame.new(ground + Vector3.new(0, 0.2, 0)), { Color = BLOOD, Size = 1.5, Count = 0.6 })
	Vfx.Pack("Anime/Fire-02", CFrame.new(mid), { Color = EMBER, Size = 1.2, Count = 0.6 })
	task.delay(0.3, function()
		fb(ctx, mid + Vector3.new(0, 0.5, 0), "Ash", { Size = 7, Color = ASH, Transparency = 0.4, Life = 0.9, LightEmission = 0, Accel = Vector3.new(0, 2, 0) })
	end)
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), BLOOD)
	ctx.Vfx.Pack("Loose/Sparkles", CFrame.new(ctx.Root.Position), { Color = EMBER, Size = 0.6, Count = 0.3 })
end

return Fx
