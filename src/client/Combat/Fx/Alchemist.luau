--!strict
--[[
	Fx/Alchemist — 연금술사 이펙트. 유리·거품·색색의 약물. (2026-09-28)
	부산스럽게: 찰랑임·부글거림·퐁. 던진 병은 포물선을 그려 깨지고 약물이 튄다.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local GREEN = c(120, 230, 110)
local ORANGE = c(255, 140, 60)
local PURPLE = c(180, 110, 255)
local GLASS = c(220, 245, 240)
local HERB = c(150, 190, 90)

local Fx = {}

local function bubbles(Vfx: any, at: Vector3, color: Color3, count: number)
	Vfx.Burst(at, { Count = count, Color = color, Size = 0.22, Speed = 5, Gravity = -12, Life = 0.7, Material = Enum.Material.Neon })
end

function Fx.Stumble(ctx: any)
	ctx.Vfx.Dust(Common.Feet(ctx), { Count = 5, Size = 0.8 })
end

function Fx.Slosh(ctx: any)
	local p = ctx.Tip("W") or Common.Head(ctx)
	bubbles(ctx.Vfx, p, GREEN, 5)
end

function Fx.Huddle(ctx: any)
	ctx.Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 0.6, R1 = 2.4, Color = GLASS, Life = 0.35, Width = 0.12, Height = 0.05 })
end

-- 다지기: 절구(왼손 병) 위로 풀빛 가루가 폴폴
function Fx.GrindPuff(ctx: any)
	local p = ctx.Tip("O") or ctx.Root.Position
	ctx.Vfx.Dust(p, { Count = 5, Color = HERB, Size = 0.6, Speed = 4 })
	ctx.Vfx.Sparks(p, { Color = HERB, Count = 6, MinSpeed = 2, Speed = 6, Accel = Vector3.new(0, 3, 0) })
end

function Fx.GrindDone(ctx: any)
	local p = ctx.Tip("O") or ctx.Root.Position
	ctx.Vfx.Flash(p, { Color = GREEN, Size = 4, Life = 0.3 })
	bubbles(ctx.Vfx, p, GREEN, 8)
end

-- 섞기: 오른 병에서 왼 병으로 약물 줄기
function Fx.Pour(ctx: any)
	local from = ctx.Tip("W")
	local to = ctx.Tip("O")
	if from and to then
		ctx.Vfx.Beam(from, to, { Color = GREEN, Width = 0.2, Life = 0.5 })
	end
end

function Fx.Fizz(ctx: any)
	local Vfx = ctx.Vfx
	for i = 0, 3 do
		task.delay(i * 0.1, function()
			local p = ctx.Tip(if i % 2 == 0 then "W" else "O") or ctx.Root.Position
			bubbles(Vfx, p, if i % 2 == 0 then GREEN else ORANGE, 5)
		end)
	end
end

function Fx.MixDone(ctx: any)
	local Vfx = ctx.Vfx
	local p = ctx.Root.Position + Vector3.new(0, 1.5, 0)
	Vfx.Flash(p, { Color = PURPLE, Size = 5, Life = 0.3 })
	Vfx.Burst(p, { Count = 10, Colors = { GREEN, ORANGE, PURPLE }, Size = 0.25, Speed = 8, Gravity = -6, Life = 0.7, Material = Enum.Material.Neon })
end

-- 던지기: 손의 병 모양 그대로 포물선을 그려 날아간다(0.45초 뒤 Hit)
function Fx.Lob(ctx: any)
	local Vfx = ctx.Vfx
	local from = ctx.Tip("W") or ctx.Root.Position + Vector3.new(0, 2, 0)
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
	Vfx.Flash(p, { Color = GREEN, Size = 9, Life = 0.3 })
	Vfx.Ring(CFrame.new(Vector3.new(p.X, ctx.Ground + 0.12, p.Z)), { R0 = 0.5, R1 = 3.6, Color = GREEN, Life = 0.5, Width = 0.3, Height = 0.05 })
	Vfx.Dust(p - Vector3.new(0, 1, 0), { Count = 10, Color = c(170, 230, 150), Size = 1.2 })
end

function Fx.Pop(ctx: any)
	local p = ctx.Tip("W") or ctx.Root.Position
	ctx.Vfx.Flash(p, { Color = GLASS, Size = 3, Life = 0.2 })
	bubbles(ctx.Vfx, p, GREEN, 4)
end

function Fx.Gulp(ctx: any)
	local Vfx = ctx.Vfx
	for i = 0, 2 do
		task.delay(i * 0.15, function()
			bubbles(Vfx, Common.Head(ctx), GREEN, 3)
		end)
	end
end

function Fx.Shudder(ctx: any)
	ctx.Vfx.Burst(ctx.Root.Position, { Count = 8, Colors = { GREEN, PURPLE }, Size = 0.25, Speed = 10, Gravity = -4, Life = 0.5, Material = Enum.Material.Neon })
end

-- 중독: 초록 기운이 몸에서 터져 나오고 앞으로 독 안개
function Fx.ToxicAura(ctx: any)
	local Vfx = ctx.Vfx
	local feet = Common.Feet(ctx)
	Vfx.Pillar(feet, { Color = GREEN, Height = 10, Width = 3, Life = 0.6 })
	Vfx.Shockwave(feet + Vector3.new(0, 0.1, 0), { Color = GREEN, Radius = 5, Life = 0.5 })
	Vfx.Dust(ctx.Root.Position, { Count = 14, Color = c(140, 220, 120), Size = 1.4, Speed = 10 })
end

function Fx.ToxicHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Dust(p, { Count = 10, Color = c(140, 220, 120), Size = 1.3 })
	bubbles(ctx.Vfx, p, GREEN, 10)
	ctx.Vfx.Flash(p, { Color = GREEN, Size = 6, Life = 0.25 })
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), GREEN)
end

return Fx
