--!strict
--[[
	Fx/Alchemist — 연금술사 이펙트. 유리·거품·색색의 약물. (2026-09-28)
	부산스럽게: 찰랑임·부글거림·퐁. 던진 병은 포물선을 그려 깨지고 약물이 튄다.
	2026-11-06 고급화: 예비(부글 거품·김 플립북) → 타격(깨짐 + 약물 튐·화염·독 플립북 + 유리 파편·스플래시 팩) → 여운(독 연기·불씨).
	번쩍은 짧게, 안개 층은 반투명으로.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local GREEN = c(120, 230, 110)
local ORANGE = c(255, 140, 60)
local PURPLE = c(180, 110, 255)
local GLASS = c(220, 245, 240)
local HERB = c(150, 190, 90)

-- 플립북 그림(tools/combat/out/vfx_textures.tsv 의 flip=Grid* 만)
local TEX = {
	Splash = { "rbxassetid://17063077953", "Grid4x4" },
	Water = { "rbxassetid://16664715772", "Grid4x4" },
	Water2 = { "rbxassetid://16664772965", "Grid4x4" },
	Fire = { "rbxassetid://13818306392", "Grid4x4" },
	Fire3 = { "rbxassetid://11395089850", "Grid4x4" },
	Shatter = { "rbxassetid://17086390547", "Grid4x4" },
	Punch = { "rbxassetid://16937107174", "Grid4x4" },
	Impact = { "rbxassetid://16923007448", "Grid4x4" },
	Charge = { "rbxassetid://15041986621", "Grid4x4" },
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

local function bubbles(Vfx: any, at: Vector3, color: Color3, count: number)
	Vfx.Burst(at, { Count = count, Color = color, Size = 0.22, Speed = 5, Gravity = -12, Life = 0.7, Material = Enum.Material.Neon })
end

function Fx.Stumble(_ctx: any)
end

function Fx.Slosh(ctx: any)
	local p = ctx.Tip("W") or Common.Head(ctx)
	bubbles(ctx.Vfx, p, GREEN, 5)
	fb(ctx, p, "Splash", { Size = 1.8, Color = GREEN, Life = 0.4, LightEmission = 0.3, Speed = 2, Spread = 40 })
end

function Fx.Huddle(ctx: any)
	ctx.Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 0.6, R1 = 2.4, Color = GLASS, Life = 0.35, Width = 0.12, Height = 0.05 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.6, 0)), { Color = GLASS, Size = 0.3 })
end

-- 다지기: 절구(왼손 병) 위로 풀빛 가루가 폴폴
function Fx.GrindPuff(ctx: any)
	local p = ctx.Tip("O") or ctx.Root.Position
	ctx.Vfx.Sparks(p, { Color = HERB, Count = 6, MinSpeed = 2, Speed = 6, Accel = Vector3.new(0, 3, 0) })
end

function Fx.GrindDone(ctx: any)
	local p = ctx.Tip("O") or ctx.Root.Position
	ctx.Vfx.Flash(p, { Color = GREEN, Size = 3.2, Life = 0.2 })
	bubbles(ctx.Vfx, p, GREEN, 8)
	fb(ctx, p, "Splash", { Size = 2.6, Color = GREEN, Life = 0.4, LightEmission = 0.3 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = GREEN, Size = 0.3 })
end

-- 섞기: 오른 병에서 왼 병으로 약물 줄기
function Fx.Pour(ctx: any)
	local from = ctx.Tip("W")
	local to = ctx.Tip("O")
	if from and to then
		ctx.Vfx.Beam(from, to, { Color = GREEN, Width = 0.2, Life = 0.5 })
		fb(ctx, to, "Splash", { Size = 1.6, Color = GREEN, Life = 0.35, LightEmission = 0.3 })
	end
end

function Fx.Fizz(ctx: any)
	local Vfx = ctx.Vfx
	for i = 0, 3 do
		task.delay(i * 0.1, function()
			local p = ctx.Tip(if i % 2 == 0 then "W" else "O") or ctx.Root.Position
			local col = if i % 2 == 0 then GREEN else ORANGE
			bubbles(Vfx, p, col, 5)
			if i % 2 == 1 then
				fb(ctx, p, "Fire", { Size = 1.6, Color = ORANGE, Transparency = 0.4, Life = 0.4, Accel = Vector3.new(0, 3, 0), LightEmission = 0.4 })
			end
		end)
	end
end

function Fx.MixDone(ctx: any)
	local Vfx = ctx.Vfx
	local p = ctx.Root.Position + Vector3.new(0, 1.5, 0)
	Vfx.Flash(p, { Color = PURPLE, Size = 4, Life = 0.2 })
	Vfx.Burst(p, { Count = 10, Colors = { GREEN, ORANGE, PURPLE }, Size = 0.25, Speed = 8, Gravity = -6, Life = 0.7, Material = Enum.Material.Neon })
	fb(ctx, p, "Charge", { Size = 3.6, Color = PURPLE, Life = 0.4, LightEmission = 0.5 })
	fb(ctx, p, "Splash", { Size = 3.4, Color = GREEN, Life = 0.4, LightEmission = 0.3 })
	Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = PURPLE, Size = 0.5 })
end

-- 던지기: 손의 병 모양 그대로 포물선을 그려 날아간다(0.45초 뒤 Hit)
function Fx.Lob(ctx: any)
	local Vfx = ctx.Vfx
	local from = ctx.Tip("W") or ctx.Root.Position + Vector3.new(0, 2, 0)
	-- 예비: 던지는 손끝에 약물이 튄다
	fb(ctx, from, "Splash", { Size = 2.4, Color = GREEN, Life = 0.35, LightEmission = 0.3 })
	Vfx.Projectile(from, ctx.Target, {
		Time = 0.45,
		Arc = 4,
		Spin = 3,
		TrailColor = GREEN,
		Build = function()
			local model = ctx.Weapons and ctx.Weapons:ClonePiece("W")
			if model then
				model.Parent = Vfx.Folder()
				return model
			end
			return Vfx.Part(Vector3.new(0.6, 0.8, 0.6), CFrame.new(from), GREEN)
		end,
	})
end

-- 깨짐: 유리 조각 + 약물 튐 + 김
function Fx.Shatter(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	Vfx.Burst(p, { Count = 14, Color = GLASS, Size = 0.22, Speed = 22, Life = 0.6, Material = Enum.Material.Glass })
	Vfx.Burst(p, { Count = 12, Colors = { GREEN, c(80, 200, 80) }, Size = 0.4, Speed = 14, Gravity = 50, Life = 0.7, Material = Enum.Material.Neon })
	Vfx.Flash(p, { Color = GREEN, Size = 7, Life = 0.2 })
	Vfx.Ring(CFrame.new(Vector3.new(p.X, ctx.Ground + 0.12, p.Z)), { R0 = 0.5, R1 = 3.6, Color = GREEN, Life = 0.5, Width = 0.3, Height = 0.05 })
	Vfx.Pack("Anime/Splash-01", CFrame.new(p), { Color = GREEN, Size = 1.2 })
	-- 타격 층: 병 깨짐(유리 파편 모양) + 약물 튐 + 임팩트
	fb(ctx, p, "Shatter", { Size = 6, Color = GLASS, Life = 0.4, LightEmission = 0.4, Transparency = 0.3 })
	fb(ctx, p, "Splash", { Size = 6, Color = GREEN, Life = 0.5, LightEmission = 0.3 })
	fb(ctx, p, "Punch", { Size = 4, Color = c(200, 255, 190), Life = 0.26, LightEmission = 0.5 })
	Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = GLASS, Size = 0.5 })
	-- 여운: 바닥에 번지는 약물 웅덩이 김
end

function Fx.Pop(ctx: any)
	local p = ctx.Tip("W") or ctx.Root.Position
	ctx.Vfx.Flash(p, { Color = GLASS, Size = 2.6, Life = 0.16 })
	bubbles(ctx.Vfx, p, GREEN, 4)
	fb(ctx, p, "Punch", { Size = 2, Color = GLASS, Life = 0.22, LightEmission = 0.5 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = GREEN, Size = 0.3 })
end

function Fx.Gulp(ctx: any)
	local Vfx = ctx.Vfx
	for i = 0, 2 do
		task.delay(i * 0.15, function()
			local head = Common.Head(ctx)
			bubbles(Vfx, head, GREEN, 3)
			fb(ctx, head, "Splash", { Size = 1.8, Color = GREEN, Life = 0.35, LightEmission = 0.3 })
		end)
	end
end

function Fx.Shudder(ctx: any)
	ctx.Vfx.Burst(ctx.Root.Position, { Count = 8, Colors = { GREEN, PURPLE }, Size = 0.25, Speed = 10, Gravity = -4, Life = 0.5, Material = Enum.Material.Neon })
	fb(ctx, ctx.Root.Position, "Charge", { Size = 3, Color = GREEN, Life = 0.4, LightEmission = 0.5, Transparency = 0.3 })
end

-- 중독: 초록 기운이 몸에서 터져 나오고 앞으로 독 안개
function Fx.ToxicAura(ctx: any)
	local Vfx = ctx.Vfx
	local feet = Common.Feet(ctx)
	Vfx.Pillar(feet, { Color = GREEN, Height = 10, Width = 3, Life = 0.6 })
	Vfx.Shockwave(feet + Vector3.new(0, 0.1, 0), { Color = GREEN, Radius = 5, Life = 0.5 })
	-- 예비·여운: 독 기운이 피어오르고 안개가 앞으로 번진다
	fb(ctx, ctx.Root.Position, "Charge", { Size = 5, Color = GREEN, Life = 0.5, LightEmission = 0.5, Transparency = 0.3 })
	Vfx.Pack("Anime/Stars-01", CFrame.new(ctx.Root.Position), { Color = GREEN, Size = 0.5 })
end

function Fx.ToxicHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	bubbles(ctx.Vfx, p, GREEN, 10)
	ctx.Vfx.Flash(p, { Color = GREEN, Size = 5, Life = 0.18 })
	fb(ctx, p, "Splash", { Size = 4.5, Color = GREEN, Life = 0.45, LightEmission = 0.3 })
	fb(ctx, p, "Punch", { Size = 3.4, Color = c(190, 255, 170), Life = 0.26, LightEmission = 0.5 })
	ctx.Vfx.Pack("Anime/Splash-01", CFrame.new(p), { Color = GREEN, Size = 0.8, Count = 0.6 })
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), GREEN)
	ctx.Vfx.Pack("Loose/Sparkles", CFrame.new(ctx.Root.Position), { Color = GREEN, Size = 0.6, Count = 0.3 })
end

return Fx
