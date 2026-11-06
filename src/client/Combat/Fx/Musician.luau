--!strict
--[[
	Fx/Musician — 음악가 이펙트. 금빛 음표와 오선(다섯 줄)이 주인공이다. (2026-09-28)
	때리는 것은 칼날이 아니라 **소리** — 음표가 날아가 터지고, 강할수록 고리(음파)가 겹친다.
	2026-11-06 고급화: 예비(활끝에 모이는 빛 플립북) → 타격(음파 고리 + 번쩍 플립북 + 별·파동 팩) → 여운(떠오르는 반짝임).
	흰 섬광은 짧게, 큰 면은 반투명으로.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local GOLD = c(255, 214, 110)
local WARM = c(255, 244, 214)
local ROSE = c(255, 150, 190)

-- 플립북 그림(tools/combat/out/vfx_textures.tsv 의 flip=Grid* 만)
local TEX = {
	Charge = { "rbxassetid://15041986621", "Grid4x4" },
	Charge2 = { "rbxassetid://15041986460", "Grid4x4" },
	Punch = { "rbxassetid://16937107174", "Grid4x4" },
	Impact = { "rbxassetid://16923007448", "Grid4x4" },
	Bolt = { "rbxassetid://16951505034", "Grid2x2" },
	Flash = { "rbxassetid://11372587580", "Grid4x4" },
	Wave = { "rbxassetid://16477162837", "Grid4x4" },
	Break = { "rbxassetid://12239789629", "Grid4x4" },
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

local function bow(ctx: any): Vector3
	return ctx.Tip("W") or Common.Head(ctx)
end

function Fx.Tiptoe(ctx: any)
	ctx.Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 0.4, R1 = 2.2, Color = GOLD, Life = 0.35, Width = 0.12, Height = 0.05 })
	ctx.Vfx.Pack("Loose/Wave-2", CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.3, 0)), { Color = GOLD, Size = 0.5, Count = 0.5 })
end

function Fx.Flourish(ctx: any)
	local at = bow(ctx)
	ctx.Vfx.Notes(at, { Count = 5, Color = GOLD, Spread = 1.2 })
	fb(ctx, at, "Charge", { Size = 2.6, Color = GOLD, Life = 0.4, LightEmission = 0.5 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(at), { Color = GOLD, Size = 0.35 })
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
	-- 오선 방패 층: 방패 팩(반투명) + 번쩍 플립북
	Vfx.Pack("Anime/Shield-01", cf, { Color = GOLD, Size = 0.55, Count = 0.8 })
	fb(ctx, center, "Break", { Size = 4, Color = GOLD, Life = 0.4, LightEmission = 0.5, Transparency = 0.35 })
end

function Fx.Pirouette(ctx: any)
	ctx.Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 1, R1 = 3, Color = ROSE, Life = 0.45, Width = 0.15, Height = 0.05 })
	ctx.Vfx.Notes(ctx.Root.Position, { Count = 4, Color = ROSE, Spread = 1.4 })
	ctx.Vfx.Pack("Loose/Twirl", CFrame.new(ctx.Root.Position), { Color = ROSE, Size = 0.18, Count = 0.4 })
	fb(ctx, ctx.Root.Position, "Charge2", { Size = 4, Color = ROSE, Life = 0.45, LightEmission = 0.4, Transparency = 0.3 })
end

-- 벨로체: 활이 튈 때마다 작은 음표
function Fx.Spiccato(ctx: any)
	local at = bow(ctx)
	ctx.Vfx.Notes(at, { Count = 2, Color = GOLD, Spread = 0.6, Life = 0.5 })
	fb(ctx, at, "Punch", { Size = 1.4, Color = GOLD, Life = 0.2, LightEmission = 0.6 })
end

-- 벨로체: 음표 셋이 줄지어 날아간다(도착 ≈ 0.28초 뒤 Hit)
function Fx.NoteStream(ctx: any)
	local from = bow(ctx)
	-- 예비: 활끝에서 음파가 먼저 퍼진다
	fb(ctx, from, "Wave", { Size = 3.4, Color = GOLD, Life = 0.3, LightEmission = 0.5, Transparency = 0.3 })
	for i = 0, 2 do
		task.delay(i * 0.04, function()
			local to = ctx.Target + Vector3.new(0, (i - 1) * 0.5, 0)
			Common.NoteBolt(ctx.Vfx, from, to, 0.24, GOLD, 0.6 + i * 0.4)
		end)
	end
end

function Fx.NoteHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = GOLD, Size = 5, Life = 0.2 })
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.3, R1 = 2.4, Color = GOLD, Life = 0.3, Width = 0.18, Facing = true })
	ctx.Vfx.Notes(p, { Count = 4, Color = WARM, Spread = 1 })
	ctx.Vfx.Sparks(p, { Color = GOLD, Count = 12 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = GOLD, Size = 0.7 })
	-- 타격 층: 음표가 터지는 번쩍 + 임팩트, 여운으로 떠오르는 반짝임
	fb(ctx, p, "Punch", { Size = 4, Color = GOLD, Life = 0.28, LightEmission = 0.6 })
	fb(ctx, p, "Wave", { Size = 5.5, Color = WARM, Life = 0.32, LightEmission = 0.5, Transparency = 0.35 })
	ctx.Vfx.Pack("Loose/Dots1", CFrame.new(p), { Color = GOLD, Size = 0.8, Count = 0.4 })
end

function Fx.Raise(ctx: any)
	local at = bow(ctx)
	ctx.Vfx.Flash(at, { Color = WARM, Size = 3.2, Life = 0.3 })
	fb(ctx, at, "Charge", { Size = 3, Color = GOLD, Life = 0.4, LightEmission = 0.5 })
	ctx.Vfx.Pack("Anime/Charge-01", CFrame.new(at), { Color = GOLD, Size = 0.5, Count = 0.4 })
end

-- 브릴란테: 금빛 음표가 둘레에 소나기처럼 흩날리고, 발밑에 큰 고리
function Fx.Brillante(ctx: any)
	local Vfx = ctx.Vfx
	local feet = Common.Feet(ctx)
	Vfx.Ring(CFrame.new(feet + Vector3.new(0, 0.15, 0)), { R0 = 1, R1 = 6, Color = GOLD, Life = 0.6, Width = 0.3, Height = 0.08 })
	Vfx.Pillar(feet, { Color = GOLD, Height = 9, Width = 3, Life = 0.6 })
	Vfx.Notes(ctx.Root.Position + Vector3.new(0, 1, 0), { Count = 10, Color = GOLD, Spread = 3, Rise = 1.4, Stagger = 0.03 })
	Vfx.Sparks(ctx.Root.Position + Vector3.new(0, 2, 0), { Color = GOLD, Count = 30, Accel = Vector3.new(0, -8, 0) })
	-- 무대 조명 층: 빛줄기 + 파동 + 번쩍 플립북
	Vfx.Pack("Loose/Rays", CFrame.new(feet + Vector3.new(0, 1.5, 0)), { Color = GOLD, Size = 0.5, Count = 0.5 })
	Vfx.Pack("Loose/Wave", CFrame.new(feet + Vector3.new(0, 0.4, 0)), { Color = GOLD, Size = 1.4, Count = 0.5 })
	fb(ctx, feet + Vector3.new(0, 1.5, 0), "Flash", { Size = 6, Color = WARM, Life = 0.25, LightEmission = 0.6, Transparency = 0.3 })
	fb(ctx, feet + Vector3.new(0, 2, 0), "Charge", { Size = 5, Color = GOLD, Life = 0.5, LightEmission = 0.5, Transparency = 0.3 })
	Vfx.Pack("Anime/Stars-01", CFrame.new(feet + Vector3.new(0, 3, 0)), { Color = GOLD, Size = 0.7 })
end

function Fx.SoftNotes(ctx: any)
	ctx.Vfx.Notes(bow(ctx), { Count = 2, Color = WARM, Spread = 0.8 })
	ctx.Vfx.Pack("Loose/Sparkles_Beam", CFrame.new(bow(ctx)), { Color = WARM, Size = 1, Count = 0.4 })
end

-- 포르테: 활 끝에서 음파가 앞으로 퍼지고 큰 음표 둘이 날아간다
function Fx.Forte(ctx: any)
	local Vfx = ctx.Vfx
	local from = bow(ctx)
	Vfx.Ring(CFrame.lookAt(from, from + ctx.Forward), { R0 = 0.5, R1 = 3.5, Color = GOLD, Life = 0.35, Width = 0.25, Facing = true })
	Common.NoteBolt(Vfx, from, ctx.Target, 0.22, GOLD, 0.4)
	Common.NoteBolt(Vfx, from, ctx.Target + Vector3.new(0, 1, 0), 0.24, ROSE, 1.2)
	fb(ctx, from, "Wave", { Size = 5, Color = GOLD, Life = 0.35, LightEmission = 0.5, Transparency = 0.3 })
	fb(ctx, from, "Charge", { Size = 2.6, Color = WARM, Life = 0.3, LightEmission = 0.6 })
	Vfx.Pack("Anime/Shoot-01", CFrame.lookAt(from, from + ctx.Forward), { Color = GOLD, Size = 0.5 })
end

-- 크레셴도 타격: 십자 모양으로 음파가 터진다
function Fx.CrescendoHit(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	Vfx.Flash(p, { Color = GOLD, Size = 7, Life = 0.22, Brightness = 4 })
	for i = 0, 2 do
		task.delay(i * 0.06, function()
			Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.4, R1 = 2.4 + i * 1.3, Color = if i == 1 then ROSE else GOLD, Life = 0.35, Width = 0.2, Facing = true })
			fb(ctx, p, "Wave", { Size = 3 + i * 1.6, Color = if i == 1 then ROSE else GOLD, Life = 0.3, LightEmission = 0.5, Transparency = 0.4 })
		end)
	end
	local side = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	for _, d in { side, -side, Vector3.new(0, 1, 0) } do
		Vfx.Thrust(p, d, { Length = 3.5, Color = GOLD, Width = 0.25, Life = 0.3 })
	end
	Vfx.Notes(p, { Count = 6, Color = WARM, Spread = 1.6 })
	fb(ctx, p, "Punch", { Size = 5.5, Color = GOLD, Life = 0.3, LightEmission = 0.6 })
	fb(ctx, p, "Bolt", { Size = 5, Color = WARM, Life = 0.22, LightEmission = 0.7 })
	Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = GOLD, Size = 0.8 })
	Vfx.Pack("Loose/Dots1", CFrame.new(p), { Color = GOLD, Size = 1, Count = 0.4 })
end

function Fx.Tremolo(ctx: any)
	local Vfx = ctx.Vfx
	for i = 0, 5 do
		task.delay(i * 0.1, function()
			local at = bow(ctx)
			Vfx.Notes(at, { Count = 1, Color = if i % 2 == 0 then GOLD else ROSE, Spread = 0.8, Life = 0.6 })
			fb(ctx, at, "Punch", { Size = 1.8, Color = if i % 2 == 0 then GOLD else ROSE, Life = 0.2, LightEmission = 0.6 })
		end)
	end
	Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 4, R1 = 1.5, Color = GOLD, Life = 0.7, Width = 0.15, Height = 0.05 })
end

function Fx.Gather(ctx: any)
	local at = bow(ctx)
	ctx.Vfx.Implode(at, { Color = GOLD, Radius = 5, Count = 18, Life = 0.35 })
	fb(ctx, at, "Charge", { Size = 3.6, Color = GOLD, Life = 0.4, LightEmission = 0.6 })
	ctx.Vfx.Pack("Anime/Charge-01", CFrame.new(at), { Color = GOLD, Size = 0.6, Count = 0.4 })
end

-- 크레셴도 알 포르테: 별처럼 사방으로 빛줄기가 뻗고 음표가 폭죽처럼 터진다
function Fx.AlForteStar(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	Vfx.Flash(p, { Color = WARM, Size = 10, Life = 0.25, Brightness = 5 })
	Vfx.Shockwave(p - Vector3.new(0, 1.2, 0), { Color = GOLD, Radius = 8, Life = 0.5 })
	local fwd = ctx.Forward
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local dir = (CFrame.fromAxisAngle(fwd, a) * Vector3.new(0, 1, 0))
		Vfx.Thrust(p, dir, { Length = if k % 2 == 0 then 6 else 3.5, Color = if k % 2 == 0 then GOLD else ROSE, Width = 0.3, Life = 0.45 })
	end
	Vfx.Notes(p, { Count = 12, Color = GOLD, Spread = 2.5, Rise = 1.5, Stagger = 0.02 })
	Vfx.Sparks(p, { Color = GOLD, Count = 40, Speed = 34 })
	-- 폭죽 층: 큰 번쩍·임팩트·파동 플립북 + 별·빛줄기·반짝임 팩
	fb(ctx, p, "Flash", { Size = 11, Color = WARM, Life = 0.28, LightEmission = 0.6, Transparency = 0.3 })
	fb(ctx, p, "Punch", { Size = 9, Color = GOLD, Life = 0.34, LightEmission = 0.6 })
	fb(ctx, p, "Wave", { Size = 12, Color = ROSE, Life = 0.4, LightEmission = 0.5, Transparency = 0.45 })
	fb(ctx, p, "Break", { Size = 8, Color = GOLD, Life = 0.4, LightEmission = 0.5, Transparency = 0.4 })
	Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = GOLD, Size = 1.4 })
	Vfx.Pack("Loose/Rays", CFrame.new(p), { Color = GOLD, Size = 0.8, Count = 0.5 })
	Vfx.Pack("Loose/Wave", CFrame.new(p), { Color = ROSE, Size = 1.6, Count = 0.5 })
	task.delay(0.25, function()
		Vfx.Pack("Loose/Dots1", CFrame.new(p), { Color = GOLD, Size = 1.4, Count = 0.5 })
	end)
end

function Fx.Pizz(ctx: any)
	local at = ctx.Tip("O") or Common.Head(ctx)
	ctx.Vfx.Notes(at, { Count = 1, Color = WARM, Spread = 0.3, Life = 0.8 })
	ctx.Vfx.Ring(CFrame.lookAt(at, at + ctx.Forward), { R0 = 0.2, R1 = 1, Color = GOLD, Life = 0.25, Width = 0.08, Facing = true })
	fb(ctx, at, "Punch", { Size = 1.5, Color = GOLD, Life = 0.2, LightEmission = 0.6 })
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), GOLD)
	ctx.Vfx.Pack("Loose/Sparkles", CFrame.new(ctx.Root.Position), { Color = GOLD, Size = 0.6, Count = 0.3 })
end

return Fx
