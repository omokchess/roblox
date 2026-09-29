--!strict
--[[
	Fx/Musician — 음악가 이펙트. 금빛 음표와 오선(다섯 줄)이 주인공이다. (2026-09-28)
	때리는 것은 칼날이 아니라 **소리** — 음표가 날아가 터지고, 강할수록 고리(음파)가 겹친다.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local GOLD = c(255, 214, 110)
local WARM = c(255, 244, 214)
local ROSE = c(255, 150, 190)

local Fx = {}

local function bow(ctx: any): Vector3
	return ctx.Tip("W") or Common.Head(ctx)
end

function Fx.Tiptoe(ctx: any)
	ctx.Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 0.4, R1 = 2.2, Color = GOLD, Life = 0.35, Width = 0.12, Height = 0.05 })
end

function Fx.Flourish(ctx: any)
	ctx.Vfx.Notes(bow(ctx), { Count = 5, Color = GOLD, Spread = 1.2 })
end

function Fx.StaveShield(ctx: any)
	local Vfx = ctx.Vfx
	local center = ctx.Root.Position + ctx.Forward * 1.8 + Vector3.new(0, 0.5, 0)
	local cf = CFrame.lookAt(center, center + ctx.Forward)
	for i = -2, 2 do
		local line = Vfx.Part(Vector3.new(3.2, 0.07, 0.07), cf * CFrame.new(0, i * 0.42, 0), GOLD)
		task.delay(0.45, function()
			line:Destroy()
		end)
	end
	Vfx.Ring(cf, { R0 = 0.4, R1 = 2.2, Color = GOLD, Life = 0.35, Width = 0.15, Facing = true })
	Vfx.Notes(center, { Count = 3, Color = GOLD, Spread = 1 })
end

function Fx.Pirouette(ctx: any)
	ctx.Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 1, R1 = 3, Color = ROSE, Life = 0.45, Width = 0.15, Height = 0.05 })
	ctx.Vfx.Notes(ctx.Root.Position, { Count = 4, Color = ROSE, Spread = 1.4 })
end

-- 벨로체: 활이 튈 때마다 작은 음표
function Fx.Spiccato(ctx: any)
	ctx.Vfx.Notes(bow(ctx), { Count = 2, Color = GOLD, Spread = 0.6, Life = 0.5 })
end

-- 벨로체: 음표 셋이 줄지어 날아간다(도착 ≈ 0.28초 뒤 Hit)
function Fx.NoteStream(ctx: any)
	local from = bow(ctx)
	for i = 0, 2 do
		task.delay(i * 0.04, function()
			local to = ctx.Target + Vector3.new(0, (i - 1) * 0.5, 0)
			Common.NoteBolt(ctx.Vfx, from, to, 0.24, GOLD, 0.6 + i * 0.4)
		end)
	end
end

function Fx.NoteHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = GOLD, Size = 6, Life = 0.25 })
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.3, R1 = 2.4, Color = GOLD, Life = 0.3, Width = 0.18, Facing = true })
	ctx.Vfx.Notes(p, { Count = 4, Color = WARM, Spread = 1 })
	ctx.Vfx.Sparks(p, { Color = GOLD, Count = 12 })
end

function Fx.Raise(ctx: any)
	ctx.Vfx.Flash(bow(ctx), { Color = WARM, Size = 4, Life = 0.4 })
end

-- 브릴란테: 금빛 음표가 둘레에 소나기처럼 흩날리고, 발밑에 큰 고리
function Fx.Brillante(ctx: any)
	local Vfx = ctx.Vfx
	local feet = Common.Feet(ctx)
	Vfx.Ring(CFrame.new(feet + Vector3.new(0, 0.15, 0)), { R0 = 1, R1 = 6, Color = GOLD, Life = 0.6, Width = 0.3, Height = 0.08 })
	Vfx.Pillar(feet, { Color = GOLD, Height = 9, Width = 3, Life = 0.6 })
	Vfx.Notes(ctx.Root.Position + Vector3.new(0, 1, 0), { Count = 10, Color = GOLD, Spread = 3, Rise = 1.4, Stagger = 0.03 })
	Vfx.Sparks(ctx.Root.Position + Vector3.new(0, 2, 0), { Color = GOLD, Count = 30, Accel = Vector3.new(0, -8, 0) })
end

function Fx.SoftNotes(ctx: any)
	ctx.Vfx.Notes(bow(ctx), { Count = 2, Color = WARM, Spread = 0.8 })
end

-- 포르테: 활 끝에서 음파가 앞으로 퍼지고 큰 음표 둘이 날아간다
function Fx.Forte(ctx: any)
	local Vfx = ctx.Vfx
	local from = bow(ctx)
	Vfx.Ring(CFrame.lookAt(from, from + ctx.Forward), { R0 = 0.5, R1 = 3.5, Color = GOLD, Life = 0.35, Width = 0.25, Facing = true })
	Common.NoteBolt(Vfx, from, ctx.Target, 0.22, GOLD, 0.4)
	Common.NoteBolt(Vfx, from, ctx.Target + Vector3.new(0, 1, 0), 0.24, ROSE, 1.2)
end

-- 크레셴도 타격: 십자 모양으로 음파가 터진다
function Fx.CrescendoHit(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	Vfx.Flash(p, { Color = GOLD, Size = 9, Life = 0.3, Brightness = 6 })
	for i = 0, 2 do
		task.delay(i * 0.06, function()
			Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.4, R1 = 2.4 + i * 1.3, Color = if i == 1 then ROSE else GOLD, Life = 0.35, Width = 0.2, Facing = true })
		end)
	end
	local side = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	for _, d in { side, -side, Vector3.new(0, 1, 0) } do
		Vfx.Thrust(p, d, { Length = 3.5, Color = GOLD, Width = 0.25, Life = 0.3 })
	end
	Vfx.Notes(p, { Count = 6, Color = WARM, Spread = 1.6 })
end

function Fx.Tremolo(ctx: any)
	local Vfx = ctx.Vfx
	for i = 0, 5 do
		task.delay(i * 0.1, function()
			Vfx.Notes(bow(ctx), { Count = 1, Color = if i % 2 == 0 then GOLD else ROSE, Spread = 0.8, Life = 0.6 })
		end)
	end
	Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 4, R1 = 1.5, Color = GOLD, Life = 0.7, Width = 0.15, Height = 0.05 })
end

function Fx.Gather(ctx: any)
	ctx.Vfx.Implode(bow(ctx), { Color = GOLD, Radius = 5, Count = 18, Life = 0.35 })
end

-- 크레셴도 알 포르테: 별처럼 사방으로 빛줄기가 뻗고 음표가 폭죽처럼 터진다
function Fx.AlForteStar(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	Vfx.Flash(p, { Color = WARM, Size = 16, Life = 0.4, Brightness = 9 })
	Vfx.Shockwave(p - Vector3.new(0, 1.2, 0), { Color = GOLD, Radius = 8, Life = 0.5 })
	local fwd = ctx.Forward
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local dir = (CFrame.fromAxisAngle(fwd, a) * Vector3.new(0, 1, 0))
		Vfx.Thrust(p, dir, { Length = if k % 2 == 0 then 6 else 3.5, Color = if k % 2 == 0 then GOLD else ROSE, Width = 0.3, Life = 0.45 })
	end
	Vfx.Notes(p, { Count = 12, Color = GOLD, Spread = 2.5, Rise = 1.5, Stagger = 0.02 })
	Vfx.Sparks(p, { Color = GOLD, Count = 40, Speed = 34 })
end

function Fx.Pizz(ctx: any)
	local at = ctx.Tip("O") or Common.Head(ctx)
	ctx.Vfx.Notes(at, { Count = 1, Color = WARM, Spread = 0.3, Life = 0.8 })
	ctx.Vfx.Ring(CFrame.lookAt(at, at + ctx.Forward), { R0 = 0.2, R1 = 1, Color = GOLD, Life = 0.25, Width = 0.08, Facing = true })
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), GOLD)
end

return Fx
