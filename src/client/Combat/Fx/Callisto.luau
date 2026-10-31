--!strict
--[[
	Fx/Callisto — 히든 보스 칼리스토 이펙트(2026-10-31). 색은 별빛 둘: 차가운 푸른 별빛(칼날·별) + 카메라 플래시 흰빛.
	자리: ctx.Root = 칼리스토, ctx.Target = 맞는 아군, ctx.Tip("W") = 칼날 끝, ctx.Tip("O") = 카메라 렌즈.
	아군 칸 전부를 덮는 기술(렌즈·칼춤·장판)은 ctx.AllyTiles(전투 화면이 넘겨준다 — 없으면 대상 둘레를 어림).
]]
local Common = require(script.Parent.Common)
local c = Common.c

local STAR = c(150, 200, 255)
local STAR_CORE = c(225, 240, 255)
local DEEP = c(60, 80, 190)
local FLASH = c(255, 252, 240)
local BURN = c(255, 170, 90)

local Fx = {}

-- 아군 칸 가운데들(없으면 대상 둘레 3×3 어림)
local function allyCells(ctx: any): { Vector3 }
	local out = {}
	for _, tile in ctx.AllyTiles or {} do
		table.insert(out, tile.Position)
	end
	if #out == 0 then
		local r = ctx.Forward:Cross(Vector3.yAxis)
		for dx = -1, 1 do
			for dy = -1, 1 do
				table.insert(out, ctx.Target + ctx.Forward * (dx * 6) + r * (dy * 6) - Vector3.new(0, 2.5, 0))
			end
		end
	end
	return out
end

local function center(points: { Vector3 }): Vector3
	local sum = Vector3.zero
	for _, p in points do
		sum += p
	end
	return sum / math.max(1, #points)
end

local function lens(ctx: any): Vector3
	return ctx.Tip("O") or ctx.Hand("L")
end

-- 작은 별 하나(빛나는 공) — 반짝였다 사라진다
local function star(ctx: any, at: Vector3, size: number, life: number, color: Color3?)
	ctx.Vfx.Flash(at, { Color = color or STAR, Size = size, Life = life, Brightness = 3 })
end

-- 칼날 궤적: 대상 앞에서 비스듬한 원호 + 별가루
function Fx.BladeArc(ctx: any)
	local p = ctx.Target
	Common.Arc(ctx, p - ctx.Forward * 1.2, 30 + math.random(-25, 25), 140, -60, { Radius = 3.6, Color = STAR, Core = STAR_CORE, Life = 0.3, Width = 0.7 })
	ctx.Vfx.Sparks(p, { Color = STAR_CORE, Count = 10, Speed = 22 })
end

-- 찌르기: 칼날 끝에서 대상까지 한 줄 + 꿰뚫고 나가는 별가루
function Fx.Stab(ctx: any)
	local from = ctx.Tip("W") or ctx.Hand("R")
	local dir = ctx.Target - from
	dir = if dir.Magnitude > 1e-3 then dir.Unit else ctx.Forward
	ctx.Vfx.Thrust(ctx.Target - dir * 3, dir, { Length = 6, Color = STAR, Width = 0.26 })
	ctx.Vfx.Flash(ctx.Target, { Color = STAR_CORE, Size = 4.5, Life = 0.16 })
	ctx.Vfx.Sparks(ctx.Target + dir * 0.6, { Color = STAR, Count = 12, Speed = 26 })
end

-- 카메라 찰칵: 렌즈에서 흰 플래시, 대상 둘레에 사진 틀(네모 고리)
function Fx.Flash(ctx: any)
	local at = lens(ctx)
	ctx.Vfx.Flash(at, { Color = FLASH, Size = 7, Life = 0.22, Brightness = 9 })
	ctx.Vfx.Flash(ctx.Target, { Color = FLASH, Size = 5, Life = 0.3, Brightness = 4 })
	local p = ctx.Target
	ctx.Vfx.Ring(CFrame.lookAt(p, p - ctx.Forward), { R0 = 3.2, R1 = 2.2, Color = FLASH, Life = 0.35, Width = 0.12, Facing = true, Segments = 4 })
end

-- 렌즈 모으기: 렌즈 앞에 별빛 구가 0.6초 동안 커진다
function Fx.LensCharge(ctx: any)
	local Vfx = ctx.Vfx
	local ball = Vfx.Part(Vector3.new(0.2, 0.2, 0.2), CFrame.new(lens(ctx)), STAR_CORE)
	ball.Shape = Enum.PartType.Ball
	Vfx.Timed(0.62, function(alpha)
		local s = 0.2 + alpha * 1.6
		ball.Size = Vector3.new(s, s, s)
		ball.CFrame = CFrame.new(lens(ctx) - ctx.Forward * 0.2)
		ball.Transparency = 0.15 + 0.2 * math.sin(alpha * 30)
	end, function()
		ball:Destroy()
	end)
	for i = 0, 5 do
		task.delay(i * 0.09, function()
			local at = lens(ctx)
			local from = at + Vector3.new(math.random(-30, 30) / 10, math.random(-20, 30) / 10, math.random(-30, 30) / 10)
			Vfx.Projectile(from, at, { Time = 0.18, Color = STAR, TrailColor = STAR })
		end)
	end
end

-- 렌즈 광선: 렌즈에서 아군 진영 가운데로 굵은 빛, 칸마다 차례로 타오른다
function Fx.LensBurn(ctx: any)
	local Vfx = ctx.Vfx
	local cells = allyCells(ctx)
	local mid = center(cells) + Vector3.new(0, 0.5, 0)
	local from = lens(ctx)
	Vfx.Beam(from, mid, { Color = STAR, Width = 3.2, Life = 0.55 })
	Vfx.Flash(from, { Color = FLASH, Size = 8, Life = 0.25, Brightness = 10 })
	for i, p in cells do
		task.delay(0.02 * i, function()
			Vfx.Pillar(p, { Color = if i % 3 == 0 then BURN else STAR, Life = 0.5, Height = 6, Width = 1.8 })
			Vfx.Burst(p + Vector3.new(0, 0.3, 0), { Count = 5, Colors = { STAR, STAR_CORE, BURN }, Size = 0.35, Speed = 14, Life = 0.5, Material = Enum.Material.Neon })
		end)
	end
end

-- 칼춤(아스트로 세시): 0.8초 동안 몸 둘레로 가로베기 원호가 사방으로 퍼지고, 끝에 별빛 충격파
function Fx.BladeStorm(ctx: any)
	local Vfx = ctx.Vfx
	local a = ctx.Actor
	for i = 0, 9 do
		task.delay(i * 0.08, function()
			local p = a.Pos.Position
			local dir = (CFrame.Angles(0, math.rad(i * 72), 0) * ctx.Forward).Unit
			local up = (CFrame.fromAxisAngle(dir, math.rad(80 + math.random(-12, 12))) * Vector3.new(0, 1, 0)).Unit
			Vfx.Slash(CFrame.fromMatrix(p, dir, up), { Radius = 5.5, From = 150, To = -150, Color = STAR, Core = STAR_CORE, Life = 0.26, Width = 0.6 })
		end)
	end
	local cells = allyCells(ctx)
	task.delay(0.4, function()
		for i, p in cells do
			if i % 2 == 1 then
				Vfx.Sparks(p + Vector3.new(0, 1.2, 0), { Color = STAR_CORE, Count = 6, Speed = 18 })
			end
		end
	end)
	task.delay(0.82, function()
		local p = a.Pos.Position
		Vfx.Ring(CFrame.new(Vector3.new(p.X, ctx.Ground + 0.15, p.Z)), { R0 = 1, R1 = 16, Color = STAR, Life = 0.5, Width = 0.3, Height = 0.06 })
	end)
end

-- 공명적 성위(평타): 칼날 끝에 별을 모아 쏜다
function Fx.StarBolt(ctx: any)
	local from = ctx.Tip("W") or ctx.Hand("R")
	star(ctx, from, 2.5, 0.2, STAR_CORE)
	ctx.Vfx.Projectile(from, ctx.Target, { Time = 0.14, Color = STAR_CORE, TrailColor = STAR })
	task.delay(0.14, function()
		ctx.Vfx.Flash(ctx.Target, { Color = STAR, Size = 5, Life = 0.25, Brightness = 5 })
		ctx.Vfx.Sparks(ctx.Target, { Color = STAR_CORE, Count = 10, Speed = 20 })
	end)
end

-- 인위적 별자리: 대상 둘레 허공에 별 일곱이 차례로 켜지며 선으로 이어지고, 한꺼번에 내리꽂힌다
function Fx.Constellation(ctx: any)
	local Vfx = ctx.Vfx
	local r = ctx.Forward:Cross(Vector3.yAxis)
	-- 큰곰자리 꼴(국자 넷 + 손잡이 셋), 대상 위 9 높이에 눕힘
	local shape = { { -1.6, 0.6 }, { -0.6, 0.9 }, { -0.4, -0.2 }, { -1.5, -0.4 }, { 0.6, -0.5 }, { 1.4, -1.0 }, { 2.2, -1.7 } }
	local points = {}
	for i, s in shape do
		points[i] = ctx.Target + r * (s[1] * 2.4) + ctx.Forward * (s[2] * 2.4) + Vector3.new(0, 9, 0)
	end
	for i, p in points do
		task.delay(0.06 * i, function()
			star(ctx, p, 2.2, 0.75, STAR_CORE)
			if i > 1 then
				Vfx.Beam(points[i - 1], p, { Color = STAR, Width = 0.18, Life = 0.6 })
			end
		end)
	end
	task.delay(0.62, function()
		for i, p in points do
			local land = ctx.Target + (p - ctx.Target) * Vector3.new(0.35, 0, 0.35) - Vector3.new(0, 1.5, 0)
			Vfx.Projectile(p, land, { Time = 0.08 + 0.01 * i, Color = STAR_CORE, TrailColor = STAR })
			task.delay(0.1 + 0.01 * i, function()
				Vfx.Burst(land, { Count = 6, Colors = { STAR, STAR_CORE }, Size = 0.4, Speed = 16, Life = 0.45, Material = Enum.Material.Neon })
			end)
		end
	end)
end

-- 쏟아지는 뭇별(한 번): 하늘에서 별 다섯이 대상 둘레로 떨어진다
function Fx.StarShower(ctx: any)
	local Vfx = ctx.Vfx
	for i = 1, 5 do
		task.delay(0.04 * i, function()
			local land = ctx.Target + Vector3.new(math.random(-20, 20) / 10, -1.5, math.random(-20, 20) / 10)
			local from = land + Vector3.new(math.random(-40, 40) / 10, 18, math.random(-40, 40) / 10)
			Vfx.Projectile(from, land, { Time = 0.16, Color = STAR_CORE, TrailColor = STAR })
			task.delay(0.16, function()
				Vfx.Flash(land, { Color = STAR, Size = 3.5, Life = 0.22, Brightness = 4 })
			end)
		end)
	end
end

-- 뭇별 아래에 잠기리: 아군·적 진영 위로 밤하늘이 내려앉는다(남는 장판은 전투 화면이 snapshot.Callisto.Field 로 그린다)
function Fx.Submerge(ctx: any)
	local Vfx = ctx.Vfx
	local cells = allyCells(ctx)
	for _, tile in ctx.EnemyTiles or {} do
		table.insert(cells, tile.Position)
	end
	local mid = center(cells)
	for i = 0, 3 do
		task.delay(0.3 * i, function()
			Vfx.Ring(CFrame.new(mid + Vector3.new(0, 0.2, 0)), { R0 = 2, R1 = 26, Color = if i % 2 == 0 then STAR else DEEP, Life = 0.9, Width = 0.4, Height = 0.08 })
		end)
	end
	for i, p in cells do
		task.delay(0.6 + 0.025 * i, function()
			star(ctx, p + Vector3.new(0, 6 + math.random() * 4, 0), 1.6, 1.2, if i % 4 == 0 then STAR_CORE else STAR)
		end)
	end
	task.delay(1.4, function()
		for _, p in cells do
			Vfx.Pillar(p, { Color = DEEP, Life = 0.6, Height = 4, Width = 2.6 })
		end
	end)
end

return Fx
