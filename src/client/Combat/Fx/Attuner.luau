--!strict
--[[
	Fx/Attuner — 조율자 이펙트. 별빛(금빛·흰빛)·융해(분홍)·핵융합(눈부신 흰 청). (2026-10-25)
	별 대형 바꾸기는 무기(CombatWeapons:SetOrbMode — Orbit·Sky·Gather·Shield·Crown)가 하고, 여기는 빛만 그린다.
	ctx.Star(i) = 떠 있는 별 i 의 자리(1 메그레즈 · 2 메라크 · 3 알리오스 · 4 알카이드 · 5 미자르 · 6 페크다 · 7 두베),
	ctx.EnemyCenter = 적 진영 가운데.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local GOLD = c(255, 226, 140)
local WHITE = c(255, 250, 235)
local PALE = c(190, 214, 255)
local MELT = c(255, 90, 170)
local FUSION = c(220, 245, 255)

local Fx = {}

-- 별자리 선(두 별 사이 빛줄)
local function line(ctx: any, a: Vector3, b: Vector3, color: Color3, width: number, life: number)
	ctx.Vfx.Beam(a, b, { Color = color, Width = width, Life = life })
end

function Fx.StarTwinkle(ctx: any)
	local p = ctx.Star(1)
	ctx.Vfx.Flash(p, { Color = GOLD, Size = 3, Life = 0.4, Brightness = 3 })
	ctx.Vfx.Sparks(p, { Color = WHITE, Count = 6, Speed = 4, Accel = Vector3.new(0, 2, 0) })
end

function Fx.Touchdown(ctx: any)
	local feet = Common.Feet(ctx)
	ctx.Vfx.Ring(CFrame.new(feet + Vector3.new(0, 0.12, 0)), { R0 = 0.5, R1 = 4, Color = GOLD, Life = 0.5, Width = 0.18, Height = 0.05 })
	ctx.Vfx.Sparks(feet + Vector3.new(0, 0.3, 0), { Color = WHITE, Count = 10, Accel = Vector3.new(0, 4, 0) })
end

function Fx.StarShield(ctx: any)
	local front = ctx.Root.Position + ctx.Forward * 2.4 + Vector3.new(0, 0.6, 0)
	local cf = CFrame.lookAt(front, front + ctx.Forward)
	ctx.Vfx.Ring(cf, { R0 = 0.5, R1 = 2.6, Color = GOLD, Life = 0.5, Width = 0.22, Facing = true })
	ctx.Vfx.Ring(cf, { R0 = 0.3, R1 = 1.6, Color = WHITE, Life = 0.35, Width = 0.12, Facing = true })
end

function Fx.StarBlink(ctx: any)
	local at = ctx.Root.Position
	ctx.Vfx.Flash(at, { Color = GOLD, Size = 6, Life = 0.25, Brightness = 4 })
	ctx.Vfx.Burst(at, { Count = 10, Color = WHITE, Size = 0.18, Speed = 8, Gravity = 0, Life = 0.4 })
end

-- 메그레즈: 별이 빛을 모았다가 대상에게 빛줄기 — 맞은 자리에서 그 열(세로)을 위아래로 훑는다
function Fx.MegrezCharge(ctx: any)
	ctx.Vfx.Implode(ctx.Star(1), { Color = GOLD, Radius = 2.4, Count = 12, Life = 0.25 })
end

function Fx.MegrezBeam(ctx: any)
	local from = ctx.Star(1)
	local to = ctx.Target
	line(ctx, from, to, GOLD, 0.9, 0.35)
	line(ctx, from, to, WHITE, 0.35, 0.3)
	ctx.Vfx.Flash(from, { Color = WHITE, Size = 4, Life = 0.25, Brightness = 5 })
	-- 열 전체: 대상 둘레 앞뒤(화면 세로) 줄을 빛 기둥이 쓸고 간다
	local side = ctx.Forward:Cross(Vector3.new(0, 1, 0)).Unit
	for i = -1, 1 do
		task.delay(0.05 * (i + 1), function()
			ctx.Vfx.Pillar(Vector3.new(to.X, ctx.Ground, to.Z) + side * (i * 4.2), { Height = 8, Width = 1.2, Color = GOLD, Life = 0.4 })
		end)
	end
end

function Fx.StarHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = GOLD, Size = 6, Life = 0.25 })
	ctx.Vfx.Sparks(p, { Color = WHITE, Count = 14, Speed = 18 })
	ctx.Vfx.Burst(p, { Count = 6, Color = MELT, Size = 0.22, Speed = 10, Gravity = 10, Life = 0.5 })
end

-- 메라크: 별을 집어 들고(번쩍) 적의 줄 끝까지 던진다 — 줄을 따라 빛 꼬리가 달린다
function Fx.MerakSpark(ctx: any)
	local p = ctx.Star(2)
	ctx.Vfx.Flash(p, { Color = PALE, Size = 4, Life = 0.3, Brightness = 4 })
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.2, R1 = 1.4, Color = PALE, Life = 0.25, Width = 0.1, Facing = true })
end

function Fx.MerakStreak(ctx: any)
	local from = ctx.Hand("R")
	local to = ctx.Target + ctx.Forward * 14
	ctx.Vfx.Projectile(from, to, {
		Time = 0.32,
		Arc = 0.4,
		TrailColor = PALE,
		Build = function()
			return ctx.Vfx.Part(Vector3.new(0.6, 0.6, 0.6), CFrame.new(from), WHITE, Enum.Material.Neon, Enum.PartType.Ball)
		end,
	})
	task.delay(0.12, function()
		line(ctx, ctx.Target - ctx.Forward * 2, to, PALE, 0.5, 0.35)
	end)
end

-- 알리오스: 별이 번쩍 커지고 — 진형 전체 위로 별빛 비가 쏟아진다
function Fx.AliothCall(ctx: any)
	local p = ctx.Star(3)
	ctx.Vfx.Flash(p, { Color = GOLD, Size = 9, Life = 0.5, Brightness = 6 })
	ctx.Vfx.Ring(CFrame.new(p), { R0 = 0.4, R1 = 3, Color = GOLD, Life = 0.5, Width = 0.14, Facing = true })
end

function Fx.AliothRain(ctx: any)
	local center = ctx.EnemyCenter
	local side = ctx.Forward:Cross(Vector3.new(0, 1, 0)).Unit
	local rng = Random.new()
	for i = 1, 22 do
		task.delay(i * 0.018, function()
			local spot = center + ctx.Forward * rng:NextNumber(-8, 8) + side * rng:NextNumber(-6, 6)
			local ground = Vector3.new(spot.X, ctx.Ground, spot.Z)
			ctx.Vfx.Beam(ground + Vector3.new(0, 16, 0), ground, { Color = if i % 3 == 0 then WHITE else GOLD, Width = 0.32, Life = 0.25 })
		end)
	end
end

function Fx.RainHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = GOLD, Size = 7, Life = 0.3 })
	ctx.Vfx.Burst(p, { Count = 8, Color = MELT, Size = 0.25, Speed = 12, Gravity = 20, Life = 0.6 })
end

-- 셉텐트리오네스: 별이 적 위로 날아오르고(Orbs Sky) → 별끼리 빛줄로 이어져 북두칠성이 된다 → 한 점으로 무너져 핵융합
function Fx.SeptRise(ctx: any)
	for i = 1, 7 do
		ctx.Vfx.Flash(ctx.Star(i), { Color = GOLD, Size = 3, Life = 0.35, Brightness = 3 })
	end
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), GOLD)
end

-- 북두칠성 잇는 차례: 손잡이 알카이드(4)·미자르(5)·알리오스(3)·메그레즈(1) → 국자 페크다(6)·메라크(2)·두베(7)·메그레즈(1)
local DIPPER = { 4, 5, 3, 1, 6, 2, 7, 1 }

function Fx.SeptLines(ctx: any)
	for k = 1, #DIPPER - 1 do
		task.delay(k * 0.05, function()
			line(ctx, ctx.Star(DIPPER[k]), ctx.Star(DIPPER[k + 1]), GOLD, 0.28, 0.65 - k * 0.04)
		end)
	end
end

function Fx.SeptCollapse(ctx: any)
	local center = ctx.EnemyCenter + Vector3.new(0, 4, 0)
	ctx.Vfx.Implode(center, { Color = WHITE, Radius = 9, Count = 26, Life = 0.28 })
	for i = 1, 7 do
		line(ctx, ctx.Star(i), center, GOLD, 0.22, 0.3)
	end
end

function Fx.Fusion(ctx: any, _ev: any, at: Vector3?)
	-- 큰 폭발은 한 번(맞은 적마다 이 함수가 불린다 — 같은 타격의 ctx 를 나눠 쓴다)
	if not ctx.FusionShown then
		ctx.FusionShown = true
		local center = ctx.EnemyCenter
		ctx.Vfx.Flash(center + Vector3.new(0, 3, 0), { Color = FUSION, Size = 34, Life = 0.6, Brightness = 12 })
		ctx.Vfx.Shockwave(Vector3.new(center.X, ctx.Ground + 0.1, center.Z), { Color = FUSION, Radius = 16, Life = 0.6 })
		ctx.Vfx.Ring(CFrame.new(Vector3.new(center.X, ctx.Ground + 0.2, center.Z)), { R0 = 2, R1 = 14, Color = MELT, Life = 0.7, Width = 0.5, Height = 0.12 })
	end
	if at then
		ctx.Vfx.Sparks(at, { Color = WHITE, Count = 18, Speed = 26 })
	end
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), GOLD)
end

return Fx
