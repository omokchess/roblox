--!strict
--[[
	Fx/WallPilgrim — 월 필그림 이펙트. 녹슨 쇠·핏빛 천·촛불빛 금색. (2026-09-28)
	경건하지만 섬뜩하게: 후광, 쏟아지는 못, 찍힌 자리에 새겨지는 붉은 십자.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local RUST = c(150, 40, 36)
local CANDLE = c(255, 200, 120)
local IRON = c(120, 112, 106)

local Fx = {}

-- 못 하나(떨어뜨리기용)
local function nail(Vfx: any, at: CFrame): Model
	local model = Instance.new("Model")
	local shaft = Vfx.Part(Vector3.new(0.26, 2.2, 0.26), at, IRON, Enum.Material.CorrodedMetal)
	local head = Vfx.Part(Vector3.new(0.7, 0.2, 0.7), at * CFrame.new(0, 1.15, 0), c(80, 74, 70), Enum.Material.CorrodedMetal)
	local wrap = Vfx.Part(Vector3.new(0.32, 0.4, 0.32), at * CFrame.new(0, 0.7, 0), RUST, Enum.Material.Fabric)
	shaft.Parent, head.Parent, wrap.Parent = model, model, model
	model.PrimaryPart = shaft
	model.Parent = Vfx.Folder()
	return model
end

-- 바닥에 붉은 십자가 새겨졌다 사라진다
local function crossMark(Vfx: any, ground: Vector3, forward: Vector3)
	local cf = CFrame.lookAt(ground + Vector3.new(0, 0.12, 0), ground + Vector3.new(0, 0.12, 0) + forward)
	local a = Vfx.Part(Vector3.new(0.35, 0.06, 3.2), cf, RUST)
	local b = Vfx.Part(Vector3.new(2.2, 0.06, 0.35), cf * CFrame.new(0, 0, -0.5), RUST)
	task.delay(1.2, function()
		a:Destroy()
		b:Destroy()
	end)
end

function Fx.Genuflect(ctx: any)
	local front = Common.Feet(ctx) + ctx.Forward * 1.6
	ctx.Vfx.Sparks(front, { Color = CANDLE, Count = 14 })
	ctx.Vfx.Dust(front, { Count = 8, Color = c(150, 140, 130) })
	crossMark(ctx.Vfx, front, ctx.Forward)
end

-- 고통을 반김: 머리 위에 희미한 후광이 번쩍
function Fx.Rapture(ctx: any)
	local head = Common.Head(ctx) + Vector3.new(0, 1, 0)
	ctx.Vfx.Ring(CFrame.new(head), { R0 = 0.6, R1 = 1.4, Color = CANDLE, Life = 0.6, Width = 0.12, Height = 0.08 })
	Common.Blood(ctx.Vfx, ctx.Root.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, 1, 0), 6, 10)
end

function Fx.CrossBlock(ctx: any)
	local p = ctx.Root.Position + ctx.Forward * 1.6 + Vector3.new(0, 1, 0)
	ctx.Vfx.Sparks(p, { Color = CANDLE, Count = 18, Speed = 20 })
	ctx.Vfx.Flash(p, { Color = CANDLE, Size = 5, Life = 0.2 })
	ctx.Vfx.Shake(0.15, 0.15)
end

function Fx.Scuttle(ctx: any)
	ctx.Vfx.Dust(Common.Feet(ctx), { Count = 6, Color = c(140, 130, 120), Size = 0.9 })
end

-- 못질: 두 못이 박히며 불꽃 + 핏빛 십자
function Fx.NailDown(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	Vfx.Flash(p, { Color = CANDLE, Size = 7, Life = 0.25 })
	Vfx.Sparks(p, { Color = CANDLE, Count = 22, Speed = 24 })
	Common.Blood(Vfx, p, Vector3.new(0, 1, 0) - ctx.Forward * 0.3, 12, 18)
	crossMark(Vfx, Vector3.new(p.X, ctx.Ground, p.Z), ctx.Forward)
end

-- 갈라진 신도: X 로 긋는 두 줄기
function Fx.CrossSlash(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	local center = ctx.Root.Position + ctx.Forward * 1.5 + Vector3.new(0, 0.8, 0)
	Common.Arc(ctx, center, 40, 120, -60, { Radius = 2.6, Color = RUST, Core = CANDLE, Width = 0.6, Sweep = 0.04 })
	Common.Arc(ctx, center, -40, 120, -60, { Radius = 2.6, Color = RUST, Core = CANDLE, Width = 0.6, Sweep = 0.04 })
	ctx.Vfx.Sparks(p, { Color = CANDLE, Count = 14 })
	Common.Blood(ctx.Vfx, p, ctx.Forward, 8, 16)
end

-- 갈라 벌리기: 양옆으로 핏빛 줄기가 뻗는다(두 칸)
function Fx.Split(ctx: any)
	local p = ctx.Root.Position + ctx.Forward * 2 + Vector3.new(0, 0.6, 0)
	local side = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	ctx.Vfx.Thrust(p, side, { Length = 5, Color = RUST, Width = 0.35 })
	ctx.Vfx.Thrust(p, -side, { Length = 5, Color = RUST, Width = 0.35 })
end

function Fx.Halo(ctx: any)
	local Vfx = ctx.Vfx
	local head = Common.Head(ctx) + Vector3.new(0, 1.4, 0)
	Vfx.Ring(CFrame.new(head), { R0 = 0.4, R1 = 1.8, Color = CANDLE, Life = 1.0, Width = 0.18, Height = 0.1 })
	Vfx.Pillar(Common.Feet(ctx), { Color = CANDLE, Height = 18, Width = 1.6, Life = 0.9 })
	Vfx.Sparks(head, { Color = CANDLE, Count = 16, Accel = Vector3.new(0, 6, 0), MinSpeed = 2, Speed = 6, Lifetime = 1 })
end

-- 합창: 대상 줄(아군이 보는 방향으로 뻗은 라인) 위 하늘에서 못이 줄지어 떨어진다(도착 ≈ 0.3초)
-- 2026-10-04 사용자: 범위는 겨눈 라인 전체인데 못이 옆으로(가로줄) 흩어졌다 → 앞쪽(Forward)을 따라 맞은 적들을 덮게
function Fx.NailRain(ctx: any)
	local Vfx = ctx.Vfx
	local side = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	local origin = ctx.Root.Position
	-- 맞은 적들의 앞쪽 거리 범위(없으면 앞 6~30)
	local near, far = math.huge, -math.huge
	for _, p in ctx.Targets do
		local d = (p - origin):Dot(ctx.Forward)
		near, far = math.min(near, d), math.max(far, d)
	end
	if near == math.huge then
		near, far = 6, 30
	end
	near, far = near - 3, far + 3
	local rng = Random.new()
	local count = math.clamp(math.floor((far - near) / 2.5), 9, 18)
	for i = 1, count do
		local along = near + (far - near) * (i - 0.5) / count + rng:NextNumber(-0.8, 0.8)
		local offset = ctx.Forward * along + side * rng:NextNumber(-1.4, 1.4)
		local ground = Vector3.new(origin.X, ctx.Ground, origin.Z) + offset
		local delay = rng:NextNumber(0, 0.18)
		task.delay(delay, function()
			local model = nail(Vfx, CFrame.new(ground + Vector3.new(0, 16, 0)) * CFrame.Angles(math.pi, 0, 0))
			local t0 = os.clock()
			while os.clock() - t0 < 0.22 do
				local k = ((os.clock() - t0) / 0.22) ^ 2
				model:PivotTo(CFrame.new(ground + Vector3.new(0, 16 - 15 * k, 0)) * CFrame.Angles(math.pi, 0, 0))
				task.wait()
			end
			model:PivotTo(CFrame.new(ground + Vector3.new(0, 0.8, 0)) * CFrame.Angles(math.pi, 0, 0))
			Vfx.Sparks(ground + Vector3.new(0, 0.2, 0), { Color = CANDLE, Count = 8 })
			Vfx.Dust(ground, { Count = 4, Color = c(140, 130, 120), Size = 0.8 })
			task.wait(0.8)
			model:Destroy()
		end)
	end
end

function Fx.NailRainHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	Common.Blood(ctx.Vfx, p, Vector3.new(0, 1, 0), 10, 14)
	ctx.Vfx.Flash(p, { Color = CANDLE, Size = 6, Life = 0.25 })
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), CANDLE)
end

return Fx
