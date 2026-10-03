--!strict
--[[
	Fx/Quasar — 퀘이사 이펙트. 보랏빛 중력과 별가루. (2026-09-28)
	무게가 느껴지게: 모여드는 빛(빨려듦) → 크게 터지는 충격파 → 땅의 금·돌 조각.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local VIOLET = c(150, 120, 255)
local DEEP = c(60, 30, 120)
local STAR = c(230, 225, 255)

local Fx = {}

function Fx.HeavyLand(ctx: any)
	local feet = Common.Feet(ctx)
	Common.Land(ctx.Vfx, feet, 1.4, c(180, 170, 200))
	ctx.Vfx.Shockwave(feet + Vector3.new(0, 0.1, 0), { Color = VIOLET, Radius = 5, Life = 0.4 })
	Common.Crack(ctx.Vfx, feet + ctx.Forward * 1.5, ctx.Forward, 4, DEEP)
end

function Fx.MassAbsorb(ctx: any)
	ctx.Vfx.Implode(ctx.Root.Position, { Color = VIOLET, Radius = 3.5, Count = 10, Life = 0.35 })
	ctx.Vfx.Ring(CFrame.new(ctx.Root.Position), { R0 = 2.5, R1 = 1, Color = VIOLET, Life = 0.3, Width = 0.2, Height = 0.1 })
end

function Fx.GravityWall(ctx: any)
	local front = ctx.Root.Position + ctx.Forward * 2
	ctx.Vfx.Ring(CFrame.lookAt(front, front + ctx.Forward), { R0 = 0.5, R1 = 3, Color = VIOLET, Life = 0.45, Width = 0.3, Facing = true })
	ctx.Vfx.Dust(Common.Feet(ctx) + ctx.Forward * 2, { Color = c(160, 150, 180), Count = 8 })
end

function Fx.Deflect(ctx: any)
	local p = ctx.Tip() or ctx.Root.Position + ctx.Forward * 2
	ctx.Vfx.Sparks(p, { Color = STAR, Count = 20, Speed = 26 })
	ctx.Vfx.Flash(p, { Color = VIOLET, Size = 6, Life = 0.2 })
	ctx.Vfx.Shake(0.2, 0.15)
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
		end)
	end
end

-- 붕괴 타격: 보랏빛 충격파 + 땅이 갈라지고 돌이 튄다
function Fx.CollapseSlam(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local ground = Common.Feet(ctx) + ctx.Forward * 3
	local p = at or ctx.Target
	Vfx.Flash(p, { Color = VIOLET, Size = 14, Life = 0.35, Brightness = 7 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.1, 0), { Color = VIOLET, Radius = 9, Life = 0.5 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.2, 0), { Color = DEEP, Radius = 6, Life = 0.35 })
	Common.Rubble(Vfx, ground, 16, c(120, 110, 140))
	Vfx.Dust(ground, { Color = c(150, 140, 170), Count = 18, Size = 1.8, Speed = 16 })
	for k = -1, 1 do
		local dir = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), k * 0.5) * ctx.Forward)
		Common.Crack(Vfx, ground, dir, 6, DEEP, 1.2)
	end
	Common.Arc(ctx, ctx.Root.Position + ctx.Forward * 2 + Vector3.new(0, 1, 0), 0, 150, -40, { Radius = 4.5, Color = VIOLET, Core = STAR, Width = 1.4, Sweep = 0.05 })
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
end

function Fx.PointSky(ctx: any)
	local tip = ctx.Tip() or Common.Head(ctx)
	ctx.Vfx.Pillar(tip, { Color = VIOLET, Height = 30, Width = 0.8, Life = 0.6 })
	ctx.Vfx.Flash(tip, { Color = STAR, Size = 5, Life = 0.4 })
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

function Fx.SummonSword(ctx: any)
	local Vfx = ctx.Vfx
	local top = ctx.Target + Vector3.new(0, 14, 0)
	local model = if ctx.Weapons then ctx.Weapons:ClonePiece("W") else nil
	if model then
		model.Name = "SingularitySword"
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Grip" then
				p.CastShadow = false
				p.Transparency = math.max(p.Transparency, 0.08)
			end
		end
		scaleModel(model, GIANT)
		-- 손잡이(원점)를 위에, 날끝(6.9 × 배율)이 아래로
		model:PivotTo(CFrame.new(top + Vector3.new(0, 6, 0)) * CFrame.Angles(math.pi, 0, 0))
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
	model.Parent = Vfx.Folder()
	summoned[ctx.Actor] = model
	Vfx.Flash(top, { Color = VIOLET, Size = 18, Life = 0.5 })
	Vfx.Implode(top, { Color = STAR, Radius = 9, Count = 20, Life = 0.5 })
end

-- 내려 긋는 손짓: 빛의 검이 떨어져 꽂힌다(0.25초)
function Fx.DropSword(ctx: any)
	local model = summoned[ctx.Actor]
	summoned[ctx.Actor] = nil
	if not model then
		return
	end
	local start = model:GetPivot()
	local goal = start - Vector3.new(0, 12.5, 0)
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 0.25 do
			local k = ((os.clock() - t0) / 0.25) ^ 2
			model:PivotTo(start:Lerp(goal, k))
			task.wait()
		end
		model:PivotTo(goal)
		task.wait(0.5)
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
		model:Destroy()
	end)
end

function Fx.SingularityHit(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	local ground = Vector3.new(p.X, ctx.Ground, p.Z)
	Vfx.Flash(p, { Color = STAR, Size = 16, Life = 0.4, Brightness = 9 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.1, 0), { Color = VIOLET, Radius = 10, Life = 0.55 })
	Vfx.Pillar(ground, { Color = VIOLET, Height = 16, Width = 3.5, Life = 0.5 })
	Common.Rubble(Vfx, ground, 14, c(120, 110, 140))
	for k = 0, 5 do
		Common.Crack(Vfx, ground, CFrame.fromAxisAngle(Vector3.new(0, 1, 0), k / 6 * math.pi * 2) * ctx.Forward, 5, DEEP, 1.2)
	end
end

function Fx.InfallCut(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	Common.Arc(ctx, ctx.Root.Position + Vector3.new(0, 0.6, 0), 85, 160, -30, { Radius = 5, Color = VIOLET, Core = STAR, Width = 1.1, Sweep = 0.05 })
	ctx.Vfx.Flash(p, { Color = VIOLET, Size = 8, Life = 0.25 })
	ctx.Vfx.Sparks(p, { Color = STAR, Count = 16 })
	ctx.Vfx.Implode(p, { Color = STAR, Radius = 3, Count = 8, Life = 0.3 })
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), VIOLET)
end

return Fx
