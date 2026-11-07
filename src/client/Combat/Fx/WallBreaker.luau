--!strict
--[[
	Fx/WallBreaker — 월 브레이커 이펙트. 주황 수정빛과 부서지는 돌. (2026-09-28)
	다 부순다: 크게 패는 구덩이, 사방으로 튀는 돌, 한 바퀴 휩쓰는 큰 호.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local EMBER = c(255, 160, 80)
local HOT = c(255, 220, 160)
local ROCK = c(120, 100, 80)

-- 팩 플립북 그림(모두 Grid4x4 — tools/combat/out/vfx_textures.tsv). 2026-11-06 100배 고급화: 플립북 + 팩 묶음을 블록 이펙트 위에 겹친다
local TEX = {
	Slash = "rbxassetid://16939611858",
	Impact = "rbxassetid://16923007448",
	Hit = "rbxassetid://16678929169",
	Fire = "rbxassetid://13818306392",
	Break = "rbxassetid://15514662196",
	Energy = "rbxassetid://15041986621",
	Light = "rbxassetid://16664675233",
	Flash = "rbxassetid://11372772717",
	Explosion = "rbxassetid://11395089850",
	Shock = "rbxassetid://16477162837",
}
-- 플립북 한 장(Vfx.Flipbook 이 아직 없으면 조용히 건너뛴다)
local function fb(Vfx: any, at: any, o: { [string]: any })
	if Vfx.Flipbook then
		o.Layout = o.Layout or "Grid4x4"
		o.Mode = o.Mode or "OneShot"
		Vfx.Flipbook(at, o)
	end
end

local Fx = {}

function Fx.ButtSlam(ctx: any)
	local p = Common.Feet(ctx) + ctx.Forward * 1.2
	Common.Land(ctx.Vfx, p, 0.9, c(170, 150, 120))
	Common.Crack(ctx.Vfx, p, ctx.Forward, 3, ROCK)
	Common.Crack(ctx.Vfx, p, -ctx.Forward, 2.5, ROCK)
	fb(ctx.Vfx, p + Vector3.new(0, 0.4, 0), { Texture = TEX.Shock, Size = 6, Color = EMBER, Life = 0.35, LightEmission = 0.7, Transparency = 0.4 })
	ctx.Vfx.Pack("Anime/Crack-01", CFrame.new(p + Vector3.new(0, 0.2, 0)), { Color = ROCK, Size = 0.4 })
end

function Fx.Riled(ctx: any)
	ctx.Vfx.Burst(Common.Head(ctx), { Count = 6, Color = EMBER, Size = 0.2, Speed = 10, Gravity = 20, Life = 0.4 })
	fb(ctx.Vfx, Common.Head(ctx), { Texture = TEX.Fire, Size = 3, Color = EMBER, Life = 0.4, LightEmission = 0.6, Transparency = 0.4 })
end

function Fx.StaffBlock(ctx: any)
	local p = ctx.Root.Position + Vector3.new(0, 2.2, 0) + ctx.Forward * 0.6
	ctx.Vfx.Sparks(p, { Color = HOT, Count = 18 })
	ctx.Vfx.Flash(p, { Color = EMBER, Size = 5, Life = 0.2 })
	ctx.Vfx.Shake(0.18, 0.15)
	fb(ctx.Vfx, p, { Texture = TEX.Hit, Size = 4.5, Color = HOT, Life = 0.25, LightEmission = 1 })
	fb(ctx.Vfx, p, { Texture = TEX.Break, Size = 5, Color = EMBER, Life = 0.35, LightEmission = 0.8, Transparency = 0.35 })
	ctx.Vfx.Pack("Loose/MiniSparks", CFrame.new(p), { Color = HOT, Size = 0.5 })
end

function Fx.VaultLand(ctx: any)
	Common.Land(ctx.Vfx, Common.Feet(ctx), 0.8, c(170, 150, 120))
end

-- 쪼개기: 곡괭이가 박힌 자리 — 구덩이, 돌 조각, 주황 불꽃
function Fx.PickSlam(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	local ground = Vector3.new(p.X, ctx.Ground, p.Z)
	Vfx.Flash(p, { Color = EMBER, Size = 10, Life = 0.3, Brightness = 6 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.1, 0), { Color = EMBER, Radius = 4.5, Life = 0.4 })
	Common.Rubble(Vfx, ground + Vector3.new(0, 0.5, 0), 16, ROCK)
	Vfx.Sparks(p, { Color = HOT, Count = 24, Speed = 28 })
	for k = 0, 4 do
		Common.Crack(Vfx, ground, CFrame.fromAxisAngle(Vector3.new(0, 1, 0), k / 5 * math.pi * 2) * ctx.Forward, 3.5, ROCK)
	end
	Common.Arc(ctx, ctx.Root.Position + ctx.Forward * 1.5 + Vector3.new(0, 1, 0), 0, 150, -50, { Radius = 3.6, Color = EMBER, Core = HOT, Width = 0.9, Sweep = 0.05 })
	Vfx.Pack("Big/Big-Crack-01", CFrame.new(ground + Vector3.new(0, 0.3, 0)), { Color = EMBER, Size = 0.35 })
	-- 바위 파편 층: 임팩트 플립북 · 먼지 폭발 구름 · 충격 · 곡괭이 슬래시
	fb(Vfx, p, { Texture = TEX.Impact, Size = 9, Color = HOT, Life = 0.35, LightEmission = 1, Transparency = 0.2 })
	fb(Vfx, ground + Vector3.new(0, 0.5, 0), { Texture = TEX.Shock, Size = 10, Color = EMBER, Life = 0.4, LightEmission = 0.8, Transparency = 0.4 })
	fb(Vfx, ctx.Root.Position + ctx.Forward * 1.5 + Vector3.new(0, 1.5, 0), { Texture = TEX.Slash, Size = 8, Color = EMBER, Life = 0.22, LightEmission = 0.7, Transparency = 0.2 })
	Vfx.Pack("Anime/Punch-02", CFrame.new(p), { Color = EMBER, Size = 0.8 })
end

function Fx.Yank(ctx: any)
	local p = Common.Feet(ctx) + ctx.Forward * 3
	Common.Rubble(ctx.Vfx, p + Vector3.new(0, 0.4, 0), 6, ROCK)
end

-- 무너뜨리기: 한 바퀴 휩쓰는 큰 가로 호
function Fx.Sweep(ctx: any)
	Common.Arc(ctx, ctx.Root.Position + Vector3.new(0, 0.2, 0), 90, 200, -160, { Radius = 5.5, Color = EMBER, Core = HOT, Width = 1.2, Sweep = 0.16, Life = 0.3, Segments = 24 })
	-- 휩쓰는 호 따라 바위 가루가 바닥에서 인다
	fb(ctx.Vfx, ctx.Root.Position + Vector3.new(0, 0.4, 0), { Texture = TEX.Slash, Size = 12, Color = EMBER, Life = 0.25, LightEmission = 0.7, Transparency = 0.25 })
end

function Fx.SweepHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	-- 맞은 적이 여럿이면 범위 전체를 한 번 덮는다(단일 대상처럼 보이지 않게 — 2026-11-07)
	local area = Common.TargetsArea(ctx)
	if area and Common.Once(ctx, "SweepHit") then
		Common.AreaFill(ctx, area, EMBER, { Core = HOT })
	end
	ctx.Vfx.Flash(p, { Color = EMBER, Size = 7, Life = 0.25 })
	fb(ctx.Vfx, p, { Texture = TEX.Impact, Size = 6, Color = HOT, Life = 0.3, LightEmission = 1 })
	Common.Rubble(ctx.Vfx, p, 8, ROCK)
end

-- 허물다 모으기: 머리 위 풍차 둘레로 불씨가 빨려든다
function Fx.Windmill(ctx: any)
	local Vfx = ctx.Vfx
	local above = ctx.Root.Position + Vector3.new(0, 3, 0)
	for i = 0, 3 do
		task.delay(i * 0.16, function()
			Vfx.Implode(above, { Color = if i % 2 == 0 then EMBER else HOT, Radius = 6, Count = 12, Life = 0.35 })
			Vfx.Ring(CFrame.new(above), { R0 = 3, R1 = 1.5, Color = EMBER, Life = 0.25, Width = 0.15, Height = 0.08 })
			-- 예비: 풍차가 돌 때마다 불씨 플립북이 빨려들고 바닥 먼지가 말려 오른다
			fb(Vfx, above, { Texture = TEX.Energy, Size = 5 - i * 0.6, Color = if i % 2 == 0 then EMBER else HOT, Life = 0.3, LightEmission = 0.9, Transparency = 0.4 + i * 0.05 })
		end)
	end
end

-- 허물다 타격: 큰 폭발 + 깊은 구덩이 + 불기둥
function Fx.TearDownBlast(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	-- 맞은 적이 여럿이면 범위 전체를 한 번 덮는다(단일 대상처럼 보이지 않게 — 2026-11-07)
	local area = Common.TargetsArea(ctx)
	if area and Common.Once(ctx, "TearDownBlast") then
		Common.AreaFill(ctx, area, EMBER, { Core = HOT })
	end
	local p = at or ctx.Target
	local ground = Vector3.new(p.X, ctx.Ground, p.Z)
	Vfx.Flash(p, { Color = HOT, Size = 18, Life = 0.4, Brightness = 10 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.1, 0), { Color = EMBER, Radius = 10, Life = 0.55 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.2, 0), { Color = HOT, Radius = 6, Life = 0.35 })
	Vfx.Pillar(ground, { Color = EMBER, Height = 12, Width = 4, Life = 0.5 })
	Common.Rubble(Vfx, ground + Vector3.new(0, 0.5, 0), 26, ROCK)
	for k = 0, 7 do
		Common.Crack(Vfx, ground, CFrame.fromAxisAngle(Vector3.new(0, 1, 0), k / 8 * math.pi * 2) * ctx.Forward, 6, ROCK, 1.4)
	end
	-- 큰 폭발 층(흰 섬광은 위 Flash 하나로 충분 — 플립북은 불·먼지·바위 색): 폭발 → 충격 → 먼지 버섯 → 남는 재
	fb(Vfx, ground + Vector3.new(0, 2, 0), { Texture = TEX.Explosion, Size = 16, Color = EMBER, Life = 0.55, LightEmission = 0.6, Transparency = 0.2 })
	fb(Vfx, ground + Vector3.new(0, 1, 0), { Texture = TEX.Impact, Size = 14, Color = HOT, Life = 0.4, LightEmission = 1, Transparency = 0.3 })
	fb(Vfx, ground + Vector3.new(0, 0.5, 0), { Texture = TEX.Shock, Size = 22, Color = EMBER, Life = 0.55, LightEmission = 0.8, Transparency = 0.45 })
	Vfx.Pack("Big/Explosion-01", CFrame.new(ground + Vector3.new(0, 1, 0)), { Color = EMBER, Size = 0.35 })
	Vfx.Pack("Big/Big-Crack-01", CFrame.new(ground + Vector3.new(0, 0.3, 0)), { Color = EMBER, Size = 0.6 })
end

-- 제 살 깎기: 자기 가슴에서 금이 번지며 주황 빛이 샌다
function Fx.SelfStrike(ctx: any)
	local chest = ctx.Root.Position + ctx.Forward * 0.5 + Vector3.new(0, 0.4, 0)
	ctx.Vfx.Flash(chest, { Color = EMBER, Size = 6, Life = 0.25 })
	ctx.Vfx.Burst(chest, { Count = 10, Colors = { EMBER, HOT, ROCK }, Size = 0.3, Speed = 14, Life = 0.5 })
	Common.Blood(ctx.Vfx, chest, ctx.Forward, 6, 10)
	fb(ctx.Vfx, chest, { Texture = TEX.Break, Size = 4.5, Color = EMBER, Life = 0.4, LightEmission = 0.8, Transparency = 0.35 })
	fb(ctx.Vfx, chest, { Texture = TEX.Fire, Size = 3.5, Color = EMBER, Life = 0.5, LightEmission = 0.6, Transparency = 0.4 })
	ctx.Vfx.Pack("Anime/Crack-01", CFrame.new(chest), { Color = EMBER, Size = 0.25 })
end

function Fx.Roar(ctx: any)
	local head = Common.Head(ctx)
	ctx.Vfx.Ring(CFrame.lookAt(head, head + ctx.Forward), { R0 = 0.6, R1 = 4, Color = EMBER, Life = 0.4, Width = 0.2, Facing = true })
	ctx.Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 1, R1 = 5, Color = EMBER, Life = 0.5, Width = 0.25, Height = 0.06 })
	ctx.Vfx.Shake(0.3, 0.35)
	-- 포효: 입 앞 충격파 + 발치로 퍼지는 먼지 고리
	fb(ctx.Vfx, head + ctx.Forward * 1.2, { Texture = TEX.Shock, Size = 9, Color = EMBER, Life = 0.4, LightEmission = 0.8, Transparency = 0.4 })
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), EMBER)
	ctx.Vfx.Pack("Loose/MiniSparks", CFrame.new(Common.Feet(ctx) + Vector3.new(0, 1, 0)), { Color = EMBER, Size = 0.5 })
end

return Fx
