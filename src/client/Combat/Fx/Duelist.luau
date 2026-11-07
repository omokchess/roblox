--!strict
--[[
	Fx/Duelist — 결투사 이펙트. 강철빛 흰-청 선과 핏빛 붉은색 두 가지만 쓴다(절제). (2026-09-28)
	찌르기는 "선 하나", 패링은 "불꽃 한 점" — 크게 번지지 않고 날카롭게.
	2026-11-06 고급화: 예비(칼끝 모음 플립북) → 타격(찌르기 선 + 임팩트·혈흔 플립북 + 팩 별) → 여운(연기).
	흰 섬광은 짧게(0.2초 안팎), 몸·판을 덮는 큰 면은 쓰지 않는다.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local STEEL = c(214, 234, 255)
local EDGE = c(150, 200, 255)
local RED = c(220, 30, 40)
local BLOODC = c(200, 40, 48)
local SPARK = c(255, 220, 150)

-- 플립북 그림(tools/combat/out/vfx_textures.tsv 의 flip=Grid* 만)
local TEX = {
	SlashImpact = { "rbxassetid://16923007448", "Grid4x4" },
	Slash = { "rbxassetid://16939611858", "Grid4x4" },
	BloodPunch = { "rbxassetid://16668936898", "Grid4x4" },
	Blood = { "rbxassetid://16664856199", "Grid4x4" },
	Charge = { "rbxassetid://15041986621", "Grid4x4" },
	Bolt = { "rbxassetid://16951505034", "Grid2x2" },
	Punch = { "rbxassetid://16937107174", "Grid4x4" },
}
local FRAMES = { Grid2x2 = 4, Grid4x4 = 16, Grid8x8 = 64 }

-- 플립북 한 장(공용 CombatVfx.Flipbook). 틀이 없으면 조용히 건너뛴다. Framerate 는 한 바퀴가 Life 에 끝나게
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

function Fx.Appel(ctx: any)
	local foot = ctx.Root.Position + ctx.Forward * 1.2
	local ground = Vector3.new(foot.X, ctx.Ground, foot.Z)
	Common.Land(ctx.Vfx, ground, 0.6)
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(ground + Vector3.new(0, 0.4, 0)), { Color = STEEL, Size = 0.35 })
end

-- 찌르기 타격: 칼끝에서 대상까지 선이 꽂히고, 뒤로 불꽃·피가 뚫고 나간다
local function pierce(ctx: any, at: Vector3, dir: Vector3, scale: number)
	local Vfx = ctx.Vfx
	Vfx.Thrust(at - dir * 3, dir, { Length = 6 * scale, Color = STEEL, Width = 0.3 * scale })
	Vfx.Flash(at, { Color = EDGE, Size = 5 * scale, Life = 0.16 })
	Vfx.Sparks(at + dir * 0.6, { Color = STEEL, Count = math.floor(12 * scale), Speed = 26 })
	Common.Blood(Vfx, at + dir * 0.8, dir, math.floor(8 * scale), 20 * scale)
	-- 타격 층: 은빛 임팩트 + 뒤로 뿜는 혈흔
	fb(ctx, at, "SlashImpact", { Size = 4.5 * scale, Color = STEEL, Life = 0.32, LightEmission = 0.5 })
	fb(ctx, at + dir * 0.9, "BloodPunch", { Size = 3.2 * scale, Color = BLOODC, Life = 0.45, LightEmission = 0, Speed = 3, Spread = 25 })
end

function Fx.Pierce(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	pierce(ctx, p, ctx.Forward, 1)
	ctx.Vfx.Pack("Anime/Slash-Impact-01", CFrame.new(p), { Color = EDGE, Size = 0.8, Count = 0.6 })
	-- 칼끝 별: 찌르는 순간 반짝 하나
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = STEEL, Size = 0.4 })
end

function Fx.PierceBack(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	pierce(ctx, p, -ctx.Forward, 1.1)
	fb(ctx, p, "Blood", { Size = 3, Color = BLOODC, Life = 0.5, LightEmission = 0 })
end

-- 앞뒤관통 둘째(뒤에서 강하게): 등 뒤에서 앞으로 꿰뚫는 큰 찌르기
function Fx.PierceBackBig(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	pierce(ctx, p, -ctx.Forward, 1.6)
	ctx.Vfx.Ring(CFrame.lookAt(p, p - ctx.Forward), { R0 = 0.4, R1 = 3.6, Color = STEEL, Life = 0.32, Width = 0.24, Facing = true })
	ctx.Vfx.Pack("Anime/Slash-Impact-01", CFrame.new(p), { Color = EDGE, Size = 1.2, Count = 0.7 })
	ctx.Vfx.Pack("Loose/Flash-3", CFrame.new(p), { Color = STEEL, Size = 0.6, Count = 0.4 })
	fb(ctx, p, "Bolt", { Size = 6, Color = STEEL, Life = 0.24, LightEmission = 0.7 })
	fb(ctx, p - ctx.Forward * 1.2, "BloodPunch", { Size = 4.4, Color = BLOODC, Life = 0.5, LightEmission = 0 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = STEEL, Size = 0.6 })
end

function Fx.PierceBig(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	pierce(ctx, p, ctx.Forward, 1.5)
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.4, R1 = 3.2, Color = STEEL, Life = 0.3, Width = 0.22, Facing = true })
	fb(ctx, p, "Slash", { Size = 7, Color = EDGE, Life = 0.26, LightEmission = 0.6 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = STEEL, Size = 0.5 })
end

-- 뽑아내며 칼끝 튕김: 작은 핏방울이 위로 흩어진다
function Fx.Flick(ctx: any)
	local tip = ctx.Tip()
	if tip then
		Common.Blood(ctx.Vfx, tip, Vector3.new(0, 1, 0) + ctx.Forward * -0.3, 5, 12)
		fb(ctx, tip, "Blood", { Size = 1.6, Color = BLOODC, Life = 0.4, LightEmission = 0 })
	end
end

function Fx.ParrySpark(ctx: any)
	local p = ctx.Tip() or (ctx.Root.Position + ctx.Forward * 2)
	local mid = p:Lerp(ctx.Root.Position + Vector3.new(0, 0.8, 0), 0.4)
	ctx.Vfx.Flash(mid, { Color = c(255, 240, 200), Size = 7, Life = 0.16, Brightness = 4 })
	ctx.Vfx.Sparks(mid, { Color = SPARK, Count = 26, Speed = 30 })
	ctx.Vfx.Ring(CFrame.lookAt(mid, mid + ctx.Forward), { R0 = 0.3, R1 = 2.6, Color = c(255, 236, 190), Life = 0.25, Width = 0.18, Facing = true })
	ctx.Vfx.Shake(0.25, 0.18)
	-- 쇳소리 불꽃: 임팩트 + 별
	fb(ctx, mid, "SlashImpact", { Size = 4, Color = SPARK, Life = 0.26, LightEmission = 0.6 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(mid), { Color = SPARK, Size = 0.4 })
end

function Fx.Riposte(ctx: any)
	local from = ctx.Root.Position + Vector3.new(0, 0.6, 0) + ctx.Forward * 2
	ctx.Vfx.Thrust(from, ctx.Forward, { Length = 5, Color = STEEL, Width = 0.22 })
	fb(ctx, from + ctx.Forward * 1.5, "Slash", { Size = 5, Color = STEEL, Life = 0.2, LightEmission = 0.6 })
end

function Fx.BlockSpark(ctx: any)
	local p = ctx.Tip() or (ctx.Root.Position + ctx.Forward * 1.5)
	local mid = p:Lerp(ctx.Root.Position + Vector3.new(0, 1, 0), 0.5)
	ctx.Vfx.Sparks(mid, { Color = c(255, 190, 110), Count = 18, Speed = 22 })
	ctx.Vfx.Flash(mid, { Color = c(255, 200, 140), Size = 4.5, Life = 0.14 })
	ctx.Vfx.Shake(0.18, 0.15)
	fb(ctx, mid, "Punch", { Size = 3.2, Color = SPARK, Life = 0.22, LightEmission = 0.5 })
end

function Fx.Salute(ctx: any)
	local tip = ctx.Tip()
	if tip then
		ctx.Vfx.Flash(tip, { Color = STEEL, Size = 2.6, Life = 0.3, Brightness = 3 })
		ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(tip), { Color = STEEL, Size = 0.45 })
		fb(ctx, tip, "Charge", { Size = 2.4, Color = STEEL, Life = 0.35, LightEmission = 0.5 })
	end
end

function Fx.Focus(ctx: any)
	local ground = Vector3.new(ctx.Root.Position.X, ctx.Ground, ctx.Root.Position.Z)
	ctx.Vfx.Ring(CFrame.new(ground + Vector3.new(0, 0.12, 0)), { R0 = 4.5, R1 = 1.4, Color = EDGE, Life = 0.6, Width = 0.16, Height = 0.05 })
	ctx.Vfx.Implode(ctx.Root.Position + Vector3.new(0, 1.2, 0), { Color = EDGE, Radius = 5, Count = 12, Life = 0.5 })
	-- 예비: 몸 둘레로 모이는 푸른 기운
	fb(ctx, ctx.Root.Position + Vector3.new(0, 1.2, 0), "Charge", { Size = 4, Color = EDGE, Life = 0.55, LightEmission = 0.4, Transparency = 0.3 })
end

function Fx.FocusSnap(ctx: any)
	local head = ctx.Root.Position + Vector3.new(0, 1.6, 0)
	ctx.Vfx.Flash(head, { Color = EDGE, Size = 3.5, Life = 0.18, Brightness = 4 })
	ctx.Vfx.Ring(CFrame.new(Vector3.new(ctx.Root.Position.X, ctx.Ground + 0.12, ctx.Root.Position.Z)), { R0 = 1, R1 = 4, Color = EDGE, Life = 0.35, Width = 0.2, Height = 0.06 })
	fb(ctx, head, "Bolt", { Size = 3, Color = EDGE, Life = 0.2, LightEmission = 0.7 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(head), { Color = STEEL, Size = 0.3 })
end

-- 검 끝을 쏘아라 — 모으기: 칼끝에 별빛이 맺히고 빛가루가 빨려든다
function Fx.Glint(ctx: any)
	local tip = ctx.Tip() or ctx.Root.Position
	ctx.Vfx.Implode(tip, { Color = STEEL, Radius = 4, Count = 16, Life = 0.4 })
	ctx.Vfx.Flash(tip, { Color = c(255, 255, 255), Size = 2.8, Life = 0.3, Brightness = 4 })
	fb(ctx, tip, "Charge", { Size = 3.4, Color = STEEL, Life = 0.4, LightEmission = 0.6 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(tip), { Color = c(255, 255, 255), Size = 0.55 })
	ctx.Vfx.Pack("Anime/Charge-01", CFrame.new(tip), { Color = EDGE, Size = 0.5, Count = 0.4 })
end

-- 검 끝을 쏘아라 — 타격: 대상을 가르는 긴 흰 선, 뒤따라 붉은 선이 터진다
function Fx.PointBlank(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	local dir = ctx.Forward
	Vfx.Thrust(p - dir * 8, dir, { Length = 16, Color = STEEL, Width = 0.5, Life = 0.4 })
	Vfx.Flash(p, { Color = c(255, 255, 255), Size = 8, Life = 0.2, Brightness = 5 })
	Vfx.Ring(CFrame.lookAt(p, p + dir), { R0 = 0.5, R1 = 5, Color = STEEL, Life = 0.35, Width = 0.3, Facing = true })
	Vfx.Sparks(p, { Color = STEEL, Count = 30, Speed = 36 })
	-- 타격 층: 큰 임팩트 + 번개 모양 갈라짐 + 별
	fb(ctx, p, "SlashImpact", { Size = 9, Color = STEEL, Life = 0.34, LightEmission = 0.6 })
	fb(ctx, p, "Bolt", { Size = 7, Color = EDGE, Life = 0.26, LightEmission = 0.7 })
	Vfx.Pack("Anime/Slash-01", CFrame.new(p), { Color = STEEL, Size = 1.1, Count = 0.2 })
	Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = c(255, 255, 255), Size = 0.8 })
	task.delay(0.12, function()
		Vfx.Beam(p - dir * 6, p + dir * 6, { Color = RED, Width = 0.35, Life = 0.6 })
		Common.Blood(Vfx, p, dir + Vector3.new(0, 0.4, 0), 22, 26)
		Common.Blood(Vfx, p, -dir + Vector3.new(0, 0.6, 0), 10, 14)
		fb(ctx, p + dir * 1.5, "BloodPunch", { Size = 5.5, Color = BLOODC, Life = 0.5, LightEmission = 0, Speed = 4, Spread = 30 })
		fb(ctx, p - dir * 1.5, "Blood", { Size = 4, Color = BLOODC, Life = 0.5, LightEmission = 0 })
	end)
	-- 여운: 꿰뚫린 자리의 연기
end

-- 피 털기: 칼 옆으로 핏방울이 흩뿌려진다
function Fx.Chiburi(ctx: any)
	local tip = ctx.Tip() or ctx.Root.Position
	local side = ctx.Root.RightVector
	Common.Blood(ctx.Vfx, tip, side + Vector3.new(0, -0.3, 0), 9, 16)
	fb(ctx, tip + side * 1.2, "Blood", { Size = 2.2, Color = BLOODC, Life = 0.4, LightEmission = 0, Speed = 5, Spread = 20 })
end

-- 결투 신청 — 도전: 대상 머리 위에 붉은 표식(도발)이 내려앉고 발밑에 붉은 고리, 칼끝에서 대상까지 가는 붉은 선 하나
function Fx.Challenge(ctx: any)
	local Vfx = ctx.Vfx
	local p = ctx.Target
	local mark = p + Vector3.new(0, 4.2, 0)
	local ground = Vector3.new(p.X, ctx.Ground, p.Z)
	local tip = ctx.Tip() or (ctx.Root.Position + ctx.Forward * 2)
	Vfx.Beam(tip, p + Vector3.new(0, 1, 0), { Color = RED, Width = 0.18, Life = 0.35 })
	Vfx.Ring(CFrame.new(ground + Vector3.new(0, 0.15, 0)), { R0 = 3.2, R1 = 1.2, Color = RED, Life = 0.5, Width = 0.2, Height = 0.06 })
	-- 표식: 머리 위 붉은 번쩍(짧게) + 별 + 아래로 꽂히는 번개 플립북
	Vfx.Flash(mark, { Color = RED, Size = 2.6, Life = 0.18, Brightness = 3 })
	fb(ctx, mark, "Bolt", { Size = 3, Color = RED, Life = 0.22, LightEmission = 0.7 })
	Vfx.Pack("Anime/Stars-01", CFrame.new(mark), { Color = RED, Size = 0.5 })
	Common.Land(Vfx, ground, 0.5, BLOODC)
end

-- 결투 신청 — 보호막: 몸에서 은청 방패 파문이 퍼지고 아군 칸마다 방패가 맺힌다
function Fx.ShieldWave(ctx: any)
	local Vfx = ctx.Vfx
	local mid = ctx.Root.Position + Vector3.new(0, 1, 0)
	Vfx.Ring(CFrame.new(Vector3.new(mid.X, ctx.Ground + 0.15, mid.Z)), { R0 = 1, R1 = 9, Color = EDGE, Life = 0.6, Width = 0.25, Height = 0.08 })
	Vfx.Pack("Anime/Shield-01", CFrame.lookAt(mid, mid + ctx.Forward), { Size = 0.8, Tint = EDGE })
	Vfx.Flash(mid, { Color = EDGE, Size = 3, Life = 0.16, Brightness = 3 })
	for i, tile in ctx.AllyTiles or {} do
		task.delay(0.05 + 0.04 * (i - 1), function()
			local at = tile.Position + Vector3.new(0, 2, 0)
			Vfx.Pack("Anime/Shield-01", CFrame.lookAt(at, at + ctx.Forward), { Size = 0.7, Tint = EDGE })
			Vfx.Ring(CFrame.new(Vector3.new(at.X, ctx.Ground + 0.15, at.Z)), { R0 = 0.8, R1 = 3, Color = STEEL, Life = 0.4, Width = 0.15, Height = 0.05 })
			fb(ctx, at, "Charge", { Size = 3, Color = EDGE, Life = 0.35, LightEmission = 0.6 })
		end)
	end
end

-- 강제 결투 응수 — 도발: 낮아지며 몸 둘레에 붉은 고리 둘(안으로 모임), 앞으로 붉은 번쩍
function Fx.TauntMark(ctx: any)
	local Vfx = ctx.Vfx
	local ground = Vector3.new(ctx.Root.Position.X, ctx.Ground, ctx.Root.Position.Z)
	Vfx.Ring(CFrame.new(ground + Vector3.new(0, 0.15, 0)), { R0 = 6, R1 = 1.5, Color = RED, Life = 0.55, Width = 0.22, Height = 0.06 })
	Vfx.Ring(CFrame.new(ground + Vector3.new(0, 0.2, 0)), { R0 = 4, R1 = 1.2, Color = BLOODC, Life = 0.45, Width = 0.14, Height = 0.05 })
	local head = ctx.Root.Position + Vector3.new(0, 2.4, 0)
	Vfx.Flash(head, { Color = RED, Size = 2.8, Life = 0.16, Brightness = 3 })
	Vfx.Pack("Anime/Stars-01", CFrame.new(head), { Color = RED, Size = 0.4 })
end

-- 강제 결투 응수 — 크게 쳐내는 마지막 패리: 쇳소리 불꽃에 은청 고리와 임팩트 플립북
function Fx.ParryBig(ctx: any)
	local p = ctx.Tip() or (ctx.Root.Position + ctx.Forward * 2)
	local mid = p:Lerp(ctx.Root.Position + Vector3.new(0, 0.8, 0), 0.3)
	ctx.Vfx.Flash(mid, { Color = c(255, 240, 200), Size = 8.5, Life = 0.16, Brightness = 4 })
	ctx.Vfx.Sparks(mid, { Color = SPARK, Count = 40, Speed = 36 })
	ctx.Vfx.Ring(CFrame.lookAt(mid, mid + ctx.Forward), { R0 = 0.3, R1 = 3.6, Color = EDGE, Life = 0.3, Width = 0.22, Facing = true })
	ctx.Vfx.Shake(0.3, 0.2)
	fb(ctx, mid, "SlashImpact", { Size = 6, Color = SPARK, Life = 0.28, LightEmission = 0.6 })
	fb(ctx, mid, "Bolt", { Size = 4.5, Color = STEEL, Life = 0.22, LightEmission = 0.7 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(mid), { Color = SPARK, Size = 0.6 })
end

function Fx.GuardRing(ctx: any)
	Common.GuardRing(ctx.Vfx, ctx, EDGE)
	local front = ctx.Root.Position + ctx.Forward * 1.6
	fb(ctx, front, "Punch", { Size = 3, Color = EDGE, Life = 0.28, LightEmission = 0.5 })
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Vector3.new(ctx.Root.Position.X, ctx.Ground, ctx.Root.Position.Z), EDGE)
	ctx.Vfx.Pack("Loose/Sparkles", CFrame.new(ctx.Root.Position), { Color = STEEL, Size = 0.6, Count = 0.3 })
end

return Fx
