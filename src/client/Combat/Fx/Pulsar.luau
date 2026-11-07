--!strict
--[[
	Fx/Pulsar — 펄서 이펙트. 청록 자기장·빔·섬광. (2026-09-28)
	오브 대형 바꾸기는 무기(CombatWeapons:SetOrbMode)가 하고, 여기는 빛만 그린다.
	2026-11-06 고급화: 예비(오브에 모이는 전하 플립북) → 타격(맥동 고리 + 번개·충격 플립북 + 전기 팩) → 여운(잔 전기·반짝임).
	"섬광"의 흰 번쩍은 0.2초 안쪽으로 짧게, 큰 면은 반투명으로.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local CYAN = c(110, 220, 255)
local WHITE = c(235, 250, 255)
local DEEP = c(40, 110, 200)

-- 플립북 그림(tools/combat/out/vfx_textures.tsv 의 flip=Grid* 만)
local TEX = {
	Charge = { "rbxassetid://15041986621", "Grid4x4" },
	Charge2 = { "rbxassetid://15041986460", "Grid4x4" },
	Lightning = { "rbxassetid://16664675233", "Grid4x4" },
	Lightning8 = { "rbxassetid://12390063093", "Grid8x8" },
	Bolt = { "rbxassetid://16951505034", "Grid2x2" },
	Wave = { "rbxassetid://16477162837", "Grid4x4" },
	Shield = { "rbxassetid://17086390547", "Grid4x4" },
	Impact = { "rbxassetid://16923007448", "Grid4x4" },
	Flash = { "rbxassetid://11372587580", "Grid4x4" },
	Punch = { "rbxassetid://16937107174", "Grid4x4" },
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

local function orbCenter(ctx: any): Vector3
	return ctx.Root.Position + ctx.Forward * 2.4 + Vector3.new(0, 0.6, 0)
end

function Fx.Touchdown(ctx: any)
	local feet = Common.Feet(ctx)
	ctx.Vfx.Ring(CFrame.new(feet + Vector3.new(0, 0.12, 0)), { R0 = 0.5, R1 = 4, Color = CYAN, Life = 0.5, Width = 0.2, Height = 0.05 })
	ctx.Vfx.Sparks(feet + Vector3.new(0, 0.3, 0), { Color = CYAN, Count = 12, Accel = Vector3.new(0, 4, 0) })
	fb(ctx, feet + Vector3.new(0, 0.6, 0), "Wave", { Size = 5, Color = CYAN, Life = 0.4, LightEmission = 0.5, Transparency = 0.4 })
	ctx.Vfx.Pack("Anime/Lighting-03", CFrame.new(feet + Vector3.new(0, 0.8, 0)), { Color = CYAN, Size = 0.5, Count = 0.5 })
end

function Fx.OrbShield(ctx: any)
	local front = ctx.Root.Position + ctx.Forward * 2.4 + Vector3.new(0, 0.6, 0)
	local cf = CFrame.lookAt(front, front + ctx.Forward)
	ctx.Vfx.Ring(cf, { R0 = 0.5, R1 = 2.4, Color = CYAN, Life = 0.5, Width = 0.25, Facing = true })
	local tri = ctx.Vfx.Part(Vector3.new(2.6, 2.6, 0.08), cf, CYAN)
	tri.Transparency = 0.6
	task.delay(0.4, function()
		tri:Destroy()
	end)
	-- 자기장 방패 층
	fb(ctx, front, "Shield", { Size = 5, Color = CYAN, Life = 0.45, LightEmission = 0.5, Transparency = 0.35 })
	ctx.Vfx.Pack("Anime/ForceField-01", cf, { Color = CYAN, Size = 0.7, Count = 0.5 })
end

-- 순간 이동 잔상: 원래 자리에 번쩍 + 빛가루
function Fx.Blink(ctx: any)
	local at = ctx.Root.Position
	ctx.Vfx.Flash(at, { Color = CYAN, Size = 5.5, Life = 0.18, Brightness = 4 })
	ctx.Vfx.Burst(at, { Count = 12, Color = CYAN, Size = 0.2, Speed = 8, Gravity = 0, Life = 0.4 })
	ctx.Vfx.Ring(CFrame.lookAt(at, at + ctx.Forward), { R0 = 1.5, R1 = 0.2, Color = WHITE, Life = 0.2, Width = 0.12, Facing = true })
	fb(ctx, at, "Bolt", { Size = 5, Color = CYAN, Life = 0.22, LightEmission = 0.7 })
	fb(ctx, at, "Charge2", { Size = 4, Color = CYAN, Life = 0.35, LightEmission = 0.5, Transparency = 0.3 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(at), { Color = WHITE, Size = 0.4 })
end

-- 자기권: 몸을 둘러 도는 고리 셋(높이 다르게) + 발밑 파동
function Fx.Magnetosphere(ctx: any)
	local Vfx = ctx.Vfx
	local base = ctx.Root.Position
	for i = 0, 2 do
		task.delay(i * 0.08, function()
			local cf = CFrame.new(base + Vector3.new(0, -0.8 + i * 0.9, 0)) * CFrame.Angles(math.rad(12 * (i - 1)), 0, math.rad(15 * (1 - i)))
			Vfx.Ring(cf, { R0 = 1.2, R1 = 4.2, Color = if i == 1 then WHITE else CYAN, Life = 0.7, Width = 0.18, Height = 0.1 })
			fb(ctx, base + Vector3.new(0, -0.8 + i * 0.9, 0), "Wave", { Size = 5 + i, Color = CYAN, Life = 0.45, LightEmission = 0.5, Transparency = 0.5 })
		end)
	end
	Vfx.Shockwave(Common.Feet(ctx) + Vector3.new(0, 0.1, 0), { Color = DEEP, Radius = 6, Life = 0.5 })
	Vfx.Sparks(base, { Color = CYAN, Count = 24, Speed = 16, Accel = Vector3.new(0, 0, 0) })
	-- 맥동하는 자기장: 전기 갈라짐 + 잔 번개
	fb(ctx, base, "Lightning", { Size = 6, Color = CYAN, Life = 0.4, LightEmission = 0.7, Transparency = 0.2 })
	Vfx.Pack("Anime/Lighting-03", CFrame.new(base), { Color = CYAN, Size = 0.8, Count = 0.6 })
	Vfx.Pack("Loose/Wave-2", CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.3, 0)), { Color = CYAN, Size = 1.5, Count = 0.5 })
end

function Fx.Charge(ctx: any)
	local at = orbCenter(ctx)
	ctx.Vfx.Implode(at, { Color = CYAN, Radius = 4, Count = 16, Life = 0.3 })
	fb(ctx, at, "Charge", { Size = 4, Color = CYAN, Life = 0.35, LightEmission = 0.6 })
	ctx.Vfx.Pack("Anime/Charge-01", CFrame.new(at), { Color = CYAN, Size = 0.7, Count = 0.4 })
end

function Fx.ConvergeBeam(ctx: any)
	local from = orbCenter(ctx)
	ctx.Vfx.Beam(from, ctx.Target + ctx.Forward * 2, { Color = CYAN, Width = 1.3, Life = 0.4 })
	ctx.Vfx.Flash(from, { Color = WHITE, Size = 4.5, Life = 0.16, Brightness = 5 })
	ctx.Vfx.Ring(CFrame.lookAt(from, from + ctx.Forward), { R0 = 0.3, R1 = 2, Color = CYAN, Life = 0.25, Width = 0.18, Facing = true })
	-- 발사 층: 입구에서 터지는 충격 + 빛줄기
	fb(ctx, from, "Wave", { Size = 5, Color = CYAN, Life = 0.3, LightEmission = 0.6, Transparency = 0.3 })
	fb(ctx, from, "Charge2", { Size = 3.4, Color = WHITE, Life = 0.3, LightEmission = 0.7 })
	ctx.Vfx.Pack("Anime/Shoot-01", CFrame.lookAt(from, from + ctx.Forward), { Color = CYAN, Size = 0.6 })
	ctx.Vfx.Pack("Loose/Sparkles_Beam", CFrame.lookAt(from, ctx.Target), { Color = CYAN, Size = 1, Count = 0.5 })
end

function Fx.BeamHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = CYAN, Size = 6, Life = 0.18 })
	ctx.Vfx.Sparks(p, { Color = WHITE, Count = 18, Speed = 24 })
	ctx.Vfx.Lightning(p + Vector3.new(0, 1.5, 0), p - Vector3.new(0, 1.2, 0), { Color = CYAN })
	ctx.Vfx.Pack("Anime/Lighting-03", CFrame.new(p), { Color = CYAN, Size = 0.9 })
	ctx.Vfx.Pack("Anime/Shoot-01", CFrame.new(p), { Color = CYAN })
	-- 타격 층: 번개 플립북 + 임팩트, 여운은 잔 전기
	fb(ctx, p, "Lightning8", { Size = 7, Color = CYAN, Life = 0.4, LightEmission = 0.7 })
	fb(ctx, p, "Impact", { Size = 5, Color = WHITE, Life = 0.28, LightEmission = 0.6 })
	ctx.Vfx.Pack("Anime/Lighting-01", CFrame.new(p), { Color = CYAN, Size = 0.9, Count = 0.5 })
	task.delay(0.2, function()
		ctx.Vfx.Pack("Loose/Dots1", CFrame.new(p), { Color = CYAN, Size = 1, Count = 0.4 })
	end)
end

function Fx.FlareGather(ctx: any)
	local chest = ctx.Root.Position + ctx.Forward * 0.8 + Vector3.new(0, 0.4, 0)
	ctx.Vfx.Implode(chest, { Color = WHITE, Radius = 3, Count = 12, Life = 0.2 })
	fb(ctx, chest, "Charge", { Size = 3, Color = CYAN, Life = 0.3, LightEmission = 0.6 })
	ctx.Vfx.Pack("Anime/Charge-01", CFrame.new(chest), { Color = CYAN, Size = 0.5, Count = 0.4 })
end

-- 섬광: 시전자 앞에서 눈부신 빛이 터지고, 대상 줄을 따라 번쩍임이 달린다
function Fx.Flare(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	-- 맞은 적이 여럿이면 범위 전체를 한 번 덮는다(단일 대상처럼 보이지 않게 — 2026-11-07)
	local area = Common.TargetsArea(ctx)
	if area and Common.Once(ctx, "Flare") then
		Common.AreaFill(ctx, area, CYAN, { Core = WHITE })
	end
	local chest = ctx.Root.Position + ctx.Forward * 0.8 + Vector3.new(0, 0.4, 0)
	Vfx.Flash(chest, { Color = WHITE, Size = 14, Life = 0.2, Brightness = 6 })
	Vfx.Ring(CFrame.lookAt(chest, chest + ctx.Forward), { R0 = 0.5, R1 = 6, Color = WHITE, Life = 0.4, Width = 0.3, Facing = true })
	fb(ctx, chest, "Flash", { Size = 9, Color = WHITE, Life = 0.22, LightEmission = 0.6, Transparency = 0.35 })
	fb(ctx, chest + ctx.Forward * 1.5, "Wave", { Size = 8, Color = CYAN, Life = 0.35, LightEmission = 0.5, Transparency = 0.4 })
	Vfx.Pack("Loose/Rays", CFrame.new(chest), { Color = CYAN, Size = 0.5, Count = 0.4 })
	local p = at or ctx.Target
	task.delay(0.08, function()
		Vfx.Flash(p, { Color = CYAN, Size = 8, Life = 0.2, Brightness = 5 })
		Vfx.Sparks(p, { Color = WHITE, Count = 20 })
		fb(ctx, p, "Bolt", { Size = 6, Color = CYAN, Life = 0.25, LightEmission = 0.7 })
		fb(ctx, p, "Impact", { Size = 6, Color = WHITE, Life = 0.3, LightEmission = 0.6 })
		Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = WHITE, Size = 0.6 })
	end)
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), CYAN)
	ctx.Vfx.Pack("Loose/Sparkles", CFrame.new(ctx.Root.Position), { Color = CYAN, Size = 0.6, Count = 0.3 })
end

return Fx
