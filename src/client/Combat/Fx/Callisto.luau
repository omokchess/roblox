--!strict
--[[
	Fx/Callisto — 히든 보스 칼리스토 이펙트(2026-10-31). 색은 별빛 둘: 차가운 푸른 별빛(칼날·별) + 카메라 플래시 흰빛.
	2026-11-01 3판: 블록 이펙트(모양·판정이 읽히는 것) 위에 마켓 VFX 팩 질감(ctx.Vfx.Pack — 빛번짐·불꽃·별가루·균열)을 겹치고,
	신호(칼날 번뜩 = 말레니아의 큰 기술 신호 · 포착 원 = 영(Fatal Frame) 카메라 옵스큐라)를 더했다. 레퍼런스 표는 `보스 칼리스토.md`.
	자리: ctx.Root = 칼리스토, ctx.Target = 맞는 아군, ctx.Tip("W") = 칼날 끝, ctx.Tip("O") = 카메라 렌즈.
	아군 칸 전부를 덮는 기술은 ctx.AllyTiles(전투 화면이 넘겨준다 — 없으면 대상 둘레를 어림).
	2026-11-06: 범위가 줄어든 4종(렌즈 9 · 아스트로 세시 3×3 · 알리오스 2열 · 북두칠성 7칸)은 ctx.ThreatTiles(그 기술이 실제로 덮는 칸 BasePart 목록 — 프로그래밍이 예고 Cells 로 넘김)를 쓰고,
	없으면 ctx.AllyTiles 의 순서(행 우선 · 6열 × 3행)와 ctx.Target 에서 설계서 모양대로 어림한다(reach). 케노스 아스테리스모스는 ctx.SafeTiles(빛 칸 6칸 BasePart 목록 — 없으면 앞 두 열).
]]
local Common = require(script.Parent.Common)
local CallistoBody = require(script.Parent.Parent.Callisto)
local CallistoSpace = require(script.Parent.Parent.CallistoSpace)
local c = Common.c

local STAR = c(150, 200, 255)
local STAR_CORE = c(225, 240, 255)
local DEEP = c(60, 80, 190)
local FLASH = c(255, 252, 240)
local BURN = c(255, 170, 90)
local GOLDEN_STAR = c(255, 222, 150)
local GOLDEN = c(255, 214, 130)
local NEBULA = c(140, 100, 225) -- 3페이즈 성운 보라
local CORONA = c(255, 190, 120) -- 3페이즈 일식 코로나
local ASH = c(190, 196, 214) -- 연기 · 먼지 회청

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

-- 아군 칸 배열은 행 우선(y 1..H, x 1..W — BattleClient)이라 순서에서 열·행을 읽는다(행 3 고정). 열 1 = 앞(중앙선 쪽)
local GRID_ROWS = 3
local function gridOf(ctx: any): number?
	local tiles = ctx.AllyTiles
	if not tiles or #tiles == 0 or #tiles % GRID_ROWS ~= 0 then
		return nil
	end
	return #tiles // GRID_ROWS
end

local function targetIndex(ctx: any): number
	local best, bestD = 1, math.huge
	for i, tile in ctx.AllyTiles do
		local d = tile.Position - ctx.Target
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude < bestD then
			best, bestD = i, d.Magnitude
		end
	end
	return best
end

-- 북두칠성 7칸(행 · 열): 설계서 2절 그림 — 위 행에서 뒤 한 칸, 가운데 행 열 3~5, 아래 행 열 1~3
local DIPPER_CELLS = { { 1, 6 }, { 2, 3 }, { 2, 4 }, { 2, 5 }, { 3, 1 }, { 3, 2 }, { 3, 3 } }

-- 줄어든 범위의 칸 가운데들. shape = "Lens"(대상 열 + 양옆 3열) · "Astro"(대상 둘레 3×3) · "Alioth"(대상 열 + 앞 열) · "Dipper"(국자 7칸)
local function reach(ctx: any, shape: string): { Vector3 }
	if ctx.ThreatTiles and #ctx.ThreatTiles > 0 then
		local out = {}
		for _, tile in ctx.ThreatTiles do
			table.insert(out, tile.Position)
		end
		return out
	end
	local w = gridOf(ctx)
	if not w or (shape == "Dipper" and w ~= 6) then
		return allyCells(ctx)
	end
	local ti = targetIndex(ctx)
	local tc, tr = (ti - 1) % w + 1, (ti - 1) // w + 1
	local out = {}
	for i, tile in ctx.AllyTiles do
		local col, row = (i - 1) % w + 1, (i - 1) // w + 1
		local ok = false
		if shape == "Lens" then
			local lo = math.clamp(tc - 1, 1, w - 2)
			ok = col >= lo and col <= lo + 2
		elseif shape == "Astro" then
			ok = math.abs(col - tc) <= 1 and math.abs(row - tr) <= 1
		elseif shape == "Alioth" then
			local lo = math.max(1, math.min(tc - 1, w - 1))
			ok = col == lo or col == lo + 1
		else
			for _, cell in DIPPER_CELLS do
				if cell[1] == row and cell[2] == col then
					ok = true
				end
			end
		end
		if ok then
			table.insert(out, tile.Position)
		end
	end
	return out
end

local function lens(ctx: any): Vector3
	return ctx.Tip("O") or ctx.Hand("L")
end

-- 작은 별 하나(빛나는 공) — 반짝였다 사라진다
local function star(ctx: any, at: Vector3, size: number, life: number, color: Color3?)
	ctx.Vfx.Flash(at, { Color = color or STAR, Size = size, Life = life, Brightness = 3 })
end

--=== 플립북 · 팩 묶음 도구(2026-11-06 4판 고급화) ===--
-- 공용 CombatVfx.Flipbook(at, opts) 로 VFX 팩의 스프라이트 시트를 그대로 쓴다(시트 목록: tools/combat/out/vfx_textures.tsv). 아직 없으면 조용히 건너뛴다.
-- 밝기 절제: 화면을 덮는 흰 섬광은 snap(0.1초)뿐이고, 나머지 번쩍임은 0.2초 안쪽 · 작은 크기. 연기 · 파문은 어두운 색조로 오래 남긴다.
local TEX = {
	Slash = "rbxassetid://16939611858", -- Anime/Slash-01
	Impact = "rbxassetid://16923007448", -- Anime/Slash-Impact-01
	Charge = "rbxassetid://15041986460", -- Anime/Charge-01
	Bolt = "rbxassetid://16664675233", -- Anime/Lighting-01
	Punch = "rbxassetid://16678929169", -- Anime/Punch-02
	Smoke = "rbxassetid://16669188960", -- Anime/Smoke-01
	Shoot = "rbxassetid://16477162837", -- Anime/Shoot-01
	Shatter = "rbxassetid://17086390547", -- Anime/Shield-Break-01
	Wave = "rbxassetid://13634052022", -- Anime/ForceField-Break-01
	Boom = "http://www.roblox.com/asset/?id=11395089850", -- Big/Explosion-01
	Flame = "rbxassetid://16951304645", -- Anime/Fire-Slash-01
	Wind = "rbxassetid://14595543880", -- Anime/Wind-02
	Flash = "rbxassetid://11372772717", -- Loose/Flash
}

local function fb(ctx: any, at: any, tex: string, o: { [string]: any })
	local make = ctx.Vfx.Flipbook
	if make then
		o.Texture, o.Layout = tex, o.Layout or "Grid4x4"
		make(at, o)
	end
end

-- 베기 번쩍(시트 한 장이 0.2초에 흘러간다)
local function slashFb(ctx: any, at: Vector3, size: number, color: Color3, life: number?)
	fb(ctx, at, TEX.Slash, { Size = size, Color = color, Life = life or 0.22, LightEmission = 1, Rotation = math.random(0, 360) })
end

-- 타격 충격: 베기 충격 시트 + 주먹 시트
local function impactFb(ctx: any, at: Vector3, size: number, color: Color3)
	fb(ctx, at, TEX.Impact, { Size = size, Color = color, Life = 0.4, LightEmission = 1, Rotation = math.random(0, 360) })
	fb(ctx, at, TEX.Punch, { Size = size * 0.7, Color = color, Life = 0.4, LightEmission = 1 })
end

-- 연기 · 먼지 덩어리(위로 번지며 흩어짐)
local function smokeFb(ctx: any, at: Vector3, size: number, color: Color3, n: number?)
	fb(ctx, at, TEX.Smoke, { Size = size, Color = color, Count = n or 3, Life = 1.2, Speed = 3, Spread = 180, Accel = Vector3.new(0, 1.5, 0), LightEmission = 0.1 })
end

-- 기 모으기(예비 동작)
local function chargeFb(ctx: any, at: Vector3, size: number, color: Color3)
	fb(ctx, at, TEX.Charge, { Size = size, Color = color, Count = 2, Life = 0.5, LightEmission = 1 })
end

-- 둥근 충격 파문 · 폭발 · 번개 · 깨짐 조각
local function waveFb(ctx: any, at: Vector3, size: number, color: Color3, life: number?)
	fb(ctx, at, TEX.Wave, { Size = size, Color = color, Life = life or 0.5, LightEmission = 1 })
end

local function boomFb(ctx: any, at: Vector3, size: number, color: Color3)
	fb(ctx, at, TEX.Boom, { Size = size, Color = color, Life = 0.55, LightEmission = 0.6 })
end

local function boltFb(ctx: any, at: Vector3, size: number, color: Color3)
	fb(ctx, at, TEX.Bolt, { Size = size, Color = color, Life = 0.5, LightEmission = 1, Rotation = math.random(0, 360) })
end

local function shatterFb(ctx: any, at: Vector3, size: number, color: Color3)
	fb(ctx, at, TEX.Shatter, { Size = size, Color = color, Life = 0.5, LightEmission = 1 })
end

-- 카메라 찰칵: 0.1초짜리 작은 흰 섬광 + 플래시 시트(화면 전체를 덮지 않는다)
local function snap(ctx: any, at: Vector3, size: number)
	ctx.Vfx.Flash(at, { Color = FLASH, Size = size, Life = 0.1, Brightness = 4 })
	fb(ctx, at, TEX.Flash, { Size = size * 1.6, Color = FLASH, Life = 0.16, LightEmission = 1 })
end

-- 칼날 궤적: 대상 앞에서 비스듬한 원호 + 별가루(트로히아는 style = "Back" — 수평 등손 베기, 팩의 여러 줄 베기 자국)
-- 연타(트로히아 5연격 2026-11-06): ev.sz = 크기 배율(약 0.7 · 중 0.95 · 강 1.5), ev.flip = 베는 방향 뒤집기(좌↔우 번갈아)
function Fx.BladeArc(ctx: any, ev: any)
	local p = ctx.Target
	local back = ev and ev.style == "Back"
	local sz = (ev and ev.sz) or 1
	local sw = if ev and ev.flip then -1 else 1
	if back then
		Common.Arc(ctx, p - ctx.Forward * 1.2, 90 + math.random(-12, 12), -130 * sw, 130 * sw, { Radius = 3.4 * sz, Color = STAR, Core = STAR_CORE, Life = 0.2 + 0.04 * sz, Width = 0.6 * sz })
		ctx.Vfx.Pack("Anime/Slashes-01", CFrame.new(p), { Color = STAR, Size = 0.7 * sz })
	else
		Common.Arc(ctx, p - ctx.Forward * 1.2, 30 + math.random(-25, 25), 140, -60, { Radius = 3.6 * sz, Color = STAR, Core = STAR_CORE, Life = 0.3, Width = 0.7 * sz })
		ctx.Vfx.Pack("Anime/Slash-01", CFrame.new(p), { Color = STAR_CORE, Size = 0.8 * sz })
	end
	ctx.Vfx.Sparks(p, { Color = STAR_CORE, Count = math.floor(10 * sz), Speed = 22 })
	-- 플립북: 베기 번쩍 · 센 타격(sz ≥ 0.95)엔 충격 + 카메라 섬광 한 컷 + 별가루
	slashFb(ctx, p, (if back then 5 else 6.5) * sz, STAR_CORE)
	if sz >= 0.95 then
		impactFb(ctx, p, 4 * sz, STAR)
		snap(ctx, p, 3 * sz)
		ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = STAR_CORE, Size = 0.4 * sz, Count = 0.5 })
	end
end

-- 칼날 번뜩(말레니아 — "의수가 반짝이면 큰 기술"): 칼끝에 네 갈래 별빛이 반짝 켜진다
function Fx.SlashGlint(ctx: any)
	local at = ctx.Tip("W") or ctx.Hand("R")
	ctx.Vfx.Flash(at, { Color = STAR_CORE, Size = 2.4, Life = 0.22, Brightness = 6 })
	ctx.Vfx.Pack("Loose/Flare", CFrame.new(at), { Color = STAR_CORE, Size = 0.45 })
	ctx.Vfx.Pack("Loose/Rays", CFrame.new(at), { Color = STAR_CORE, Size = 0.3, Count = 0.5 })
	chargeFb(ctx, at, 2.4, STAR_CORE)
	snap(ctx, at, 2)
end

-- 세시 파라티리시의 화상: 베인 자리에 불꽃 베기 자국 + 별빛 충격
function Fx.BurnSlash(ctx: any)
	local p = ctx.Target
	ctx.Vfx.Pack("Anime/Fire-Slash-01", CFrame.new(p), { Color = BURN, Size = 0.8 })
	ctx.Vfx.Pack("Anime/Slash-Impact-01", CFrame.new(p), { Color = STAR_CORE, Size = 0.9 })
	ctx.Vfx.Sparks(p, { Color = BURN, Count = 8, Speed = 16 })
	fb(ctx, p, TEX.Flame, { Size = 6, Color = BURN, Life = 0.3, LightEmission = 0.6, Rotation = math.random(0, 360) })
	impactFb(ctx, p, 4.5, STAR_CORE)
	smokeFb(ctx, p + Vector3.new(0, 0.5, 0), 2.5, ASH, 2)
end

-- 찌르기: 칼날 끝에서 대상까지 한 줄 + 꿰뚫고 나가는 별가루와 충격(팩)
function Fx.Stab(ctx: any, ev: any)
	local beat = (ev and ev.s) or 3 -- 신데시 3비트(2026-11-06): 1 약 · 2 중 · 3 강 — 별빛 크기·가루 수가 단계로 커진다
	local k = 0.6 + 0.2 * (beat - 1)
	local from = ctx.Tip("W") or ctx.Hand("R")
	local dir = ctx.Target - from
	dir = if dir.Magnitude > 1e-3 then dir.Unit else ctx.Forward
	ctx.Vfx.Thrust(ctx.Target - dir * 3, dir, { Length = 6 * k, Color = STAR, Width = 0.26 * k })
	ctx.Vfx.Flash(ctx.Target, { Color = STAR_CORE, Size = 4.5 * k, Life = 0.16 })
	ctx.Vfx.Sparks(ctx.Target + dir * 0.6, { Color = STAR, Count = math.floor(12 * k), Speed = 26 })
	ctx.Vfx.Pack("Anime/Slash-Impact-01", CFrame.new(ctx.Target), { Color = STAR, Size = 0.7 * k })
	ctx.Vfx.Pack("Loose/Flash-3", CFrame.new(ctx.Target + dir * 0.8), { Color = STAR_CORE, Size = 0.6 * k })
	-- 플립북: 칼끝 발사 시트 → 꿰뚫는 베기 + 충격, 셋째 비트엔 카메라 섬광과 별가루
	fb(ctx, from, TEX.Shoot, { Size = 3 * k, Color = STAR, Life = 0.3, LightEmission = 1 })
	slashFb(ctx, ctx.Target, 6 * k, STAR_CORE)
	impactFb(ctx, ctx.Target, 5 * k, STAR)
	if beat >= 3 then
		snap(ctx, ctx.Target, 3.4)
		ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(ctx.Target), { Color = STAR_CORE, Size = 0.5, Count = 0.5 })
		smokeFb(ctx, ctx.Target, 3, ASH, 2)
	end
end

-- 카메라 찰칵(페이탈 프레임): 렌즈에서 흰 섬광, 대상 둘레에 사진 틀(네모 고리) + 반짝이는 빛살
function Fx.Flash(ctx: any)
	local at = lens(ctx)
	-- 흰 섬광은 0.1 초 안팎으로 짧게(캐릭터를 가리지 않게), 여운은 시트가 맡는다
	ctx.Vfx.Flash(at, { Color = FLASH, Size = 6, Life = 0.12, Brightness = 7 })
	ctx.Vfx.Flash(ctx.Target, { Color = FLASH, Size = 4, Life = 0.14, Brightness = 3 })
	fb(ctx, at, TEX.Flash, { Size = 9, Color = FLASH, Life = 0.2, LightEmission = 1 })
	shatterFb(ctx, ctx.Target, 7, STAR_CORE) -- 정지한 사진 틀이 깨지는 조각
	ctx.Vfx.Pack("Loose/Flash", CFrame.new(at), { Color = FLASH, Size = 0.6 })
	ctx.Vfx.Pack("Anime/Shiny-01", CFrame.new(ctx.Target), { Color = FLASH, Size = 0.6 })
	local p = ctx.Target
	ctx.Vfx.Ring(CFrame.lookAt(p, p - ctx.Forward), { R0 = 3.2, R1 = 2.2, Color = FLASH, Life = 0.35, Width = 0.12, Facing = true, Segments = 4 })
end

-- 포착 원(영 — 카메라 옵스큐라의 필라멘트가 대상을 향해 좁혀진다): 셔터 직전 0.22초
function Fx.Focus(ctx: any)
	local p = ctx.Target
	local face = CFrame.lookAt(p, p - ctx.Forward)
	ctx.Vfx.Ring(face, { R0 = 5, R1 = 1.6, Color = STAR_CORE, Life = 0.24, Width = 0.08, Facing = true, Segments = 24 })
	ctx.Vfx.Ring(face * CFrame.Angles(0, 0, math.rad(45)), { R0 = 4.2, R1 = 1.3, Color = FLASH, Life = 0.24, Width = 0.06, Facing = true, Segments = 4 })
	ctx.Vfx.Pack("Loose/Circle", CFrame.new(p), { Color = STAR_CORE, Size = 0.35 })
	chargeFb(ctx, p, 6, STAR) -- 필라멘트가 좁혀드는 모으기
	fb(ctx, p, TEX.Wave, { Size = 5, Color = STAR_CORE, Life = 0.24, LightEmission = 1 })
end

-- 멱살 잡기(심베라즈마): 움켜쥔 자리에 별가루가 튄다
function Fx.Grab(ctx: any)
	local at = ctx.Target + Vector3.new(0, 0.8, 0)
	ctx.Vfx.Pack("Anime/Punch-03", CFrame.new(at), { Color = STAR_CORE, Size = 0.5 })
	ctx.Vfx.Sparks(at, { Color = STAR, Count = 8, Speed = 12 })
	impactFb(ctx, at, 3.2, STAR)
	smokeFb(ctx, at, 1.8, ASH, 2)
end

-- 내던짐: 대상이 떨어진 자리에 먼지와 충격파
function Fx.Throw(ctx: any)
	local ground = Vector3.new(ctx.Target.X, ctx.Ground + 0.3, ctx.Target.Z)
	ctx.Vfx.Pack("Anime/Smoke-01", CFrame.new(ground), { Color = c(180, 186, 205), Size = 0.8 })
	ctx.Vfx.Pack("Anime/Shoot-01", CFrame.new(ground), { Color = STAR, Size = 0.9 })
	ctx.Vfx.Dust(ground, { Color = c(190, 196, 214), Count = 12, Size = 1.4, Speed = 12 })
	smokeFb(ctx, ground, 5, ASH, 4)
	waveFb(ctx, ground + Vector3.new(0, 0.4, 0), 9, STAR)
	fb(ctx, ground + Vector3.new(0, 1, 0), TEX.Wind, { Size = 8, Color = ASH, Life = 0.5, LightEmission = 0.3 })
	impactFb(ctx, ground + Vector3.new(0, 1, 0), 5, STAR_CORE)
end

-- 렌즈 모으기: 렌즈 앞에 별빛 구가 0.7초 동안 커지고, 둘레에서 별빛이 빨려 든다(팩 — 기 모으기 · 소용돌이)
function Fx.LensCharge(ctx: any)
	local Vfx = ctx.Vfx
	local ball = Vfx.Part(Vector3.new(0.2, 0.2, 0.2), CFrame.new(lens(ctx)), STAR_CORE)
	ball.Shape = Enum.PartType.Ball
	Vfx.Timed(0.74, function(alpha)
		local s = 0.2 + alpha * 1.6
		ball.Size = Vector3.new(s, s, s)
		ball.CFrame = CFrame.new(lens(ctx) - ctx.Forward * 0.2)
		ball.Transparency = 0.15 + 0.2 * math.sin(alpha * 30)
	end, function()
		ball:Destroy()
	end)
	Vfx.Pack("Anime/Charge-01", CFrame.new(lens(ctx)), { Color = STAR, Size = 0.6 })
	Vfx.Pack("Loose/Swirling", CFrame.new(lens(ctx)), { Color = STAR, Size = 0.15 })
	-- 플립북 모으기: 0.24초마다 점점 큰 모으기 시트
	for i = 0, 2 do
		task.delay(i * 0.24, function()
			chargeFb(ctx, lens(ctx), 2.4 + i * 0.9, if i == 2 then STAR_CORE else STAR)
		end)
	end
	for i = 0, 7 do
		task.delay(i * 0.085, function()
			local at = lens(ctx)
			local from = at + Vector3.new(math.random(-30, 30) / 10, math.random(-20, 30) / 10, math.random(-30, 30) / 10)
			Vfx.Projectile(from, at, { Time = 0.18, Color = STAR, TrailColor = STAR })
		end)
	end
end

-- 렌즈 광선: 렌즈에서 맞는 9칸 가운데로 굵은 빛(번개 질감), 칸마다 차례로 타오른다(불꽃)
function Fx.LensBurn(ctx: any)
	local Vfx = ctx.Vfx
	local cells = reach(ctx, "Lens") -- 대상 열 + 양옆 열 9칸(2026-11-06)
	local mid = center(cells) + Vector3.new(0, 0.5, 0)
	local from = lens(ctx)
	Vfx.Beam(from, mid, { Color = STAR, Width = 3.2, Life = 0.55 })
	Vfx.Flash(from, { Color = FLASH, Size = 6, Life = 0.12, Brightness = 7 }) -- 렌즈 섬광은 짧게
	Vfx.Pack("Loose/Shockwave", CFrame.new(from), { Color = STAR_CORE, Size = 0.3 })
	Vfx.Pack("Big/Lighting-01", CFrame.new(mid), { Color = STAR, Size = 0.4 })
	waveFb(ctx, from, 8, STAR_CORE)
	boltFb(ctx, from:Lerp(mid, 0.5), 12, STAR)
	for i, p in cells do
		task.delay(0.02 * i, function()
			Vfx.Pillar(p, { Color = if i % 3 == 0 then BURN else STAR, Life = 0.5, Height = 6, Width = 1.8 })
			Vfx.Burst(p + Vector3.new(0, 0.3, 0), { Count = 5, Colors = { STAR, STAR_CORE, BURN }, Size = 0.35, Speed = 14, Life = 0.5, Material = Enum.Material.Neon })
			Vfx.Pack("Anime/Fire-01", CFrame.new(p + Vector3.new(0, 0.4, 0)), { Color = BURN, Size = 0.7, Count = 0.4 })
			-- 칸마다(맞는 칸에만) 번개 시트 + 타오르는 불꽃 시트, 이어 연기
			boltFb(ctx, p + Vector3.new(0, 3, 0), 7, if i % 3 == 0 then BURN else STAR_CORE)
			if i % 3 == 0 then
				fb(ctx, p + Vector3.new(0, 1, 0), TEX.Flame, { Size = 4.5, Color = BURN, Life = 0.4, LightEmission = 0.6 })
			end
			task.delay(0.35, function()
				smokeFb(ctx, p + Vector3.new(0, 0.5, 0), 3, ASH, 2)
			end)
		end)
	end
end

-- 칼춤(아스트로 세시 — 블레이드 댄서 · 물새 춤): 회전 묶음 셋(0 · 0.36 · 0.68초)마다 몸 둘레로 가로베기 원호가 사방으로 퍼지고,
-- 몸을 감싼 칼바람(팩 회오리)
function Fx.BladeStorm(ctx: any)
	local Vfx = ctx.Vfx
	local a = ctx.Actor
	for burst = 0, 2 do
		for i = 0, 4 do
			task.delay(burst * 0.36 + i * 0.05, function()
				local p = a.Pos.Position
				local dir = (CFrame.Angles(0, math.rad(i * 72 + burst * 36), 0) * ctx.Forward).Unit
				local up = (CFrame.fromAxisAngle(dir, math.rad(80 + math.random(-12, 12))) * Vector3.new(0, 1, 0)).Unit
				Vfx.Slash(CFrame.fromMatrix(p, dir, up), { Radius = 5.5, From = 150, To = -150, Color = STAR, Core = STAR_CORE, Life = 0.24, Width = 0.6 })
				slashFb(ctx, p + dir * 3.5, 6, STAR_CORE, 0.2)
			end)
		end
		task.delay(burst * 0.36, function()
			Vfx.Pack("Big/Tornado-01", CFrame.new(a.Pos.Position - Vector3.new(0, 2, 0)), { Color = STAR, Size = 0.45, Count = 0.5 })
			fb(ctx, a.Pos.Position, TEX.Wind, { Size = 12, Color = STAR, Life = 0.5, LightEmission = 0.6 })
		end)
	end
	-- 베기 자국은 맞는 칸(대상 둘레 3×3 — 2026-11-06)에만 남긴다
	local cells = reach(ctx, "Astro")
	task.delay(0.4, function()
		for i, p in cells do
			if i % 2 == 1 then
				Vfx.Sparks(p + Vector3.new(0, 1.2, 0), { Color = STAR_CORE, Count = 6, Speed = 18 })
				Vfx.Pack("Anime/Slash-01", CFrame.new(p + Vector3.new(0, 1.2, 0)), { Color = STAR, Size = 0.6 })
				impactFb(ctx, p + Vector3.new(0, 1.2, 0), 3.6, STAR)
			end
		end
	end)
end

-- 도약: 발밑에서 바람과 눈가루
function Fx.LeapDust(ctx: any)
	local feet = Common.Feet(ctx)
	ctx.Vfx.Pack("Anime/Wind-02", CFrame.new(feet + Vector3.new(0, 0.3, 0)), { Color = c(220, 230, 245), Size = 0.6 })
	ctx.Vfx.Ring(CFrame.new(feet + Vector3.new(0, 0.1, 0)), { R0 = 0.6, R1 = 5, Color = STAR, Life = 0.35, Width = 0.18, Height = 0.05 })
	smokeFb(ctx, feet + Vector3.new(0, 0.4, 0), 4, ASH, 3)
	fb(ctx, feet + Vector3.new(0, 0.6, 0), TEX.Wind, { Size = 8, Color = STAR_CORE, Life = 0.4, LightEmission = 0.4 })
end

-- 칼춤 착지: 칼바람 고리가 퍼지고 땅에 베기 자국
function Fx.StormEnd(ctx: any)
	local Vfx = ctx.Vfx
	local p = ctx.Actor.Pos.Position
	local ground = Vector3.new(p.X, ctx.Ground + 0.15, p.Z)
	Vfx.Ring(CFrame.new(ground), { R0 = 1, R1 = 16, Color = STAR, Life = 0.5, Width = 0.3, Height = 0.06 })
	Vfx.Pack("Loose/Shockwave", CFrame.new(ground + Vector3.new(0, 0.5, 0)), { Color = STAR_CORE, Size = 0.45 })
	Vfx.Pack("Anime/Crack-01", CFrame.new(ground), { Color = STAR, Size = 1.6 })
	for i = 0, 2 do
		local dir = CFrame.Angles(0, math.rad(i * 120), 0) * ctx.Forward
		Vfx.Pack("Anime/Slashes-01", CFrame.new(ground + dir * 3 + Vector3.new(0, 1, 0)), { Color = STAR, Size = 0.6 })
		slashFb(ctx, ground + dir * 3 + Vector3.new(0, 1, 0), 5, STAR_CORE)
	end
	waveFb(ctx, ground + Vector3.new(0, 0.5, 0), 18, STAR)
	impactFb(ctx, ground + Vector3.new(0, 1, 0), 6, STAR_CORE)
	smokeFb(ctx, ground + Vector3.new(0, 0.4, 0), 7, ASH, 4)
end

-- 공명적 성위(평타): 망치 머리에서 별이 튕겨 나가(충격 고리) 대상에게 꽂힌다
function Fx.StarBolt(ctx: any)
	local from = ctx.Tip("W") or ctx.Hand("R")
	star(ctx, from, 2.5, 0.2, STAR_CORE)
	ctx.Vfx.Pack("Anime/Shoot-01", CFrame.new(from), { Color = STAR, Size = 0.8 })
	chargeFb(ctx, from, 3, GOLDEN) -- 망치 머리에 금빛 모으기
	fb(ctx, from, TEX.Shoot, { Size = 3.5, Color = STAR, Life = 0.3, LightEmission = 1 })
	ctx.Vfx.Projectile(from, ctx.Target, { Time = 0.15, Color = STAR_CORE, TrailColor = STAR, Arc = 1.2 })
	task.delay(0.15, function()
		impactFb(ctx, ctx.Target, 4.5, STAR)
		waveFb(ctx, ctx.Target, 6, GOLDEN, 0.35)
		ctx.Vfx.Flash(ctx.Target, { Color = STAR, Size = 4, Life = 0.15, Brightness = 4 })
		ctx.Vfx.Sparks(ctx.Target, { Color = STAR_CORE, Count = 10, Speed = 20 })
		ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(ctx.Target), { Color = STAR_CORE, Size = 0.7 })
	end)
end

-- 인위적 별자리: 왼손이 긋는 대로 대상 위 허공에 큰곰자리 일곱 별이 0.11초마다 하나씩 켜지며 선으로 이어지고(손이 별마다 멈추는 박자와 같다),
-- 0.8초에 한꺼번에 내리꽂힌다
function Fx.Constellation(ctx: any)
	local Vfx = ctx.Vfx
	local r = ctx.Forward:Cross(Vector3.yAxis)
	local shape = { { -1.6, 0.6 }, { -0.6, 0.9 }, { -0.4, -0.2 }, { -1.5, -0.4 }, { 0.6, -0.5 }, { 1.4, -1.0 }, { 2.2, -1.7 } }
	local points = {}
	for i, sp in shape do
		points[i] = ctx.Target + r * (sp[1] * 2.4) + ctx.Forward * (sp[2] * 2.4) + Vector3.new(0, 9, 0)
	end
	for i, p in points do
		task.delay(0.11 * (i - 1), function()
			star(ctx, p, 2.2, 0.85, STAR_CORE)
			Vfx.Pack("Loose/Flare", CFrame.new(p), { Color = STAR_CORE, Size = 0.4 })
			fb(ctx, p, TEX.Flash, { Size = 3.2, Color = STAR_CORE, Life = 0.3, LightEmission = 1 }) -- 별이 켜질 때 플래시 시트
			if i > 1 then
				Vfx.Beam(points[i - 1], p, { Color = STAR, Width = 0.18, Life = 0.75 - 0.11 * (i - 1) })
			end
		end)
	end
	task.delay(0.8, function()
		waveFb(ctx, Vector3.new(ctx.Target.X, ctx.Ground + 0.4, ctx.Target.Z), 14, GOLDEN, 0.6)
		for i, p in points do
			local land = ctx.Target + (p - ctx.Target) * Vector3.new(0.35, 0, 0.35) - Vector3.new(0, 1.5, 0)
			Vfx.Projectile(p, land, { Time = 0.08 + 0.01 * i, Color = STAR_CORE, TrailColor = STAR })
			task.delay(0.1 + 0.01 * i, function()
				Vfx.Burst(land, { Count = 6, Colors = { STAR, STAR_CORE }, Size = 0.4, Speed = 16, Life = 0.45, Material = Enum.Material.Neon })
				Vfx.Pack("Anime/Stars-01", CFrame.new(land + Vector3.new(0, 1, 0)), { Color = STAR, Size = 0.5, Count = 0.5 })
				impactFb(ctx, land + Vector3.new(0, 1, 0), 3.4, STAR_CORE)
			end)
		end
	end)
end

-- 쏟아지는 뭇별(3비트 중 하나, ev.s = 1 약 · 2 중 · 3 강): 망치가 하늘을 가리키면 별이 모이고, 내리그으면 대상 둘레로 별이 떨어진다(3·4·7개 — 셋째가 가장 많고 충격 고리)
function Fx.StarShower(ctx: any, ev: any)
	local Vfx = ctx.Vfx
	local beat = (ev and ev.s) or 3
	local count = ({ 3, 4, 7 })[math.clamp(beat, 1, 3)]
	local head = ctx.Tip("W") or ctx.Root.Position
	Vfx.Pack("Loose/Sparkles_Beam", CFrame.new(head), { Color = STAR_CORE, Size = 0.6 })
	chargeFb(ctx, head, 2.6 + beat * 0.6, if beat == 3 then GOLDEN else STAR_CORE) -- 별 모으기
	for i = 1, count do
		task.delay(0.12 + 0.04 * i, function()
			local land = ctx.Target + Vector3.new(math.random(-20, 20) / 10, -1.5, math.random(-20, 20) / 10)
			local from = land + Vector3.new(math.random(-40, 40) / 10, 18, math.random(-40, 40) / 10)
			Vfx.Projectile(from, land, { Time = 0.16, Color = STAR_CORE, TrailColor = STAR })
			task.delay(0.16, function()
				Vfx.Flash(land, { Color = STAR, Size = 3, Life = 0.14, Brightness = 4 })
				Vfx.Pack("Anime/Stars-01", CFrame.new(land + Vector3.new(0, 0.8, 0)), { Color = STAR_CORE, Size = 0.45, Count = 0.5 })
				impactFb(ctx, land + Vector3.new(0, 0.8, 0), 3, STAR)
			end)
		end)
	end
	if beat == 3 then
		task.delay(0.12 + 0.04 * count + 0.16, function()
			Vfx.Ring(CFrame.new(Vector3.new(ctx.Target.X, ctx.Ground + 0.15, ctx.Target.Z)), { R0 = 0.8, R1 = 6, Color = STAR, Life = 0.4, Width = 0.25, Height = 0.06 })
			local ground = Vector3.new(ctx.Target.X, ctx.Ground + 0.4, ctx.Target.Z)
			waveFb(ctx, ground, 12, GOLDEN)
			smokeFb(ctx, ground, 4, ASH, 3)
		end)
	end
end

-- 뭇별 아래에 잠기리: 떠오르는 동안 몸 둘레로 밤하늘이 소용돌이치고, 허공을 내리치면 아군·적 진영 위로 하늘이 내려앉는다
-- (남는 장판은 전투 화면이 snapshot.Callisto.Field 로 그린다)
function Fx.Submerge(ctx: any)
	local Vfx = ctx.Vfx
	local cells = allyCells(ctx)
	for _, tile in ctx.EnemyTiles or {} do
		table.insert(cells, tile.Position)
	end
	local mid = center(cells)
	Vfx.Pack("Loose/Twirl", CFrame.new(ctx.Root.Position + Vector3.new(0, 1, 0)), { Color = DEEP, Size = 0.4 })
	chargeFb(ctx, ctx.Root.Position + Vector3.new(0, 1, 0), 6, STAR) -- 몸 둘레로 밤하늘이 모인다
	for i = 0, 3 do
		task.delay(0.3 * i, function()
			waveFb(ctx, mid + Vector3.new(0, 0.5, 0), 22 + i * 4, if i % 2 == 0 then STAR else NEBULA, 0.9)
			Vfx.Ring(CFrame.new(mid + Vector3.new(0, 0.2, 0)), { R0 = 2, R1 = 26, Color = if i % 2 == 0 then STAR else DEEP, Life = 0.9, Width = 0.4, Height = 0.08 })
		end)
	end
	for i, p in cells do
		task.delay(0.6 + 0.025 * i, function()
			star(ctx, p + Vector3.new(0, 6 + math.random() * 4, 0), 1.6, 1.2, if i % 4 == 0 then STAR_CORE else STAR)
		end)
	end
	task.delay(1.52, function()
		if ctx.Actor and ctx.Actor.Model then
			CallistoBody.Flare(ctx.Actor.Model) -- 일식 후광이 타오른다
		end
		Vfx.Pack("Loose/PurpleExpanding", CFrame.new(mid + Vector3.new(0, 2, 0)), { Color = STAR, Size = 1.6 })
		Vfx.Pack("Loose/Shockwave", CFrame.new(mid + Vector3.new(0, 0.5, 0)), { Color = STAR_CORE, Size = 0.9 })
		boomFb(ctx, mid + Vector3.new(0, 2, 0), 14, DEEP)
		shatterFb(ctx, mid + Vector3.new(0, 4, 0), 18, NEBULA)
		for _, p in cells do
			Vfx.Pillar(p, { Color = DEEP, Life = 0.6, Height = 4, Width = 2.6 })
			waveFb(ctx, p + Vector3.new(0, 0.3, 0), 4.5, STAR, 0.5) -- 내려앉는 하늘이 칸마다 닿는다
		end
	end)
end

--=== 표정 · 등장 · 페이즈 전환 ===--

-- 모션 도중 표정 바꾸기(사건 { n = "Mood", m = 표정, d = 초 }) — 그린 얼굴(Combat/Callisto)이 있을 때만
function Fx.Mood(ctx: any, ev: any)
	local face = ctx.Actor and ctx.Actor.Face
	if face and ev and ev.m then
		face:Set(ev.m, ev.d)
	end
end

-- 얼굴 클로즈업 컷신: 정면 약간 옆에서 9 → 5 스터드로 다가간다(돌진 중에도 머리를 따라간다)
local function faceShot(ctx: any, d: number, from: number, to: number, side: number)
	local head = ctx.Actor.Model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	ctx.Shot(d, function(alpha: number)
		local h = head.Position
		local f = ctx.Forward
		local r = f:Cross(Vector3.yAxis)
		local k = 1 - (1 - math.min(alpha * 1.4, 1)) ^ 2
		local dist = from + (to - from) * k
		local eye = h + f * dist + r * side + Vector3.new(0, 0.35, 0)
		return CFrame.lookAt(eye, h + Vector3.new(0, 0.05, 0))
	end)
end

-- 시작 컷신 카메라(2026-11-01): 마주 본 채 왼발 클로즈업(0 ~ 0.26) → 왼쪽 위(칼리스토의 오른쪽 = 의수 쪽)로 올라가며 의수 칼날 시험을 비춤
local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

function Fx.IntroShot(ctx: any, ev: any)
	local model = ctx.Actor and ctx.Actor.Model
	local leg = model and model:FindFirstChild("Left Leg") :: BasePart?
	local arm = model and model:FindFirstChild("Right Arm") :: BasePart?
	local head = model and model:FindFirstChild("Head") :: BasePart?
	if not leg or not arm or not head then
		return
	end
	ctx.Shot((ev and ev.d) or 4.6, function(alpha: number)
		local f = ctx.Forward
		local r = f:Cross(Vector3.yAxis)
		local foot = leg.Position - Vector3.new(0, 0.85, 0)
		local footEye = foot + f * 3.0 - r * 0.6 + Vector3.new(0, 0.45, 0)
		local hand = arm.CFrame * Vector3.new(0, -0.9, 0)
		local armEye = head.Position + f * 6.2 + r * 3.4 + Vector3.new(0, 1.4, 0)
		local armLook = hand:Lerp(head.Position, 0.35)
		if alpha < 0.26 then
			return CFrame.lookAt(footEye, foot)
		end
		local k = smooth((alpha - 0.26) / 0.34)
		local eye = footEye:Lerp(armEye, k) + Vector3.new(0, math.sin(k * math.pi) * 0.8, 0)
		local look = foot:Lerp(armLook, k)
		if alpha > 0.6 then
			eye = armEye + (armLook - armEye).Unit * ((alpha - 0.6) * 2.4)
		end
		return CFrame.lookAt(eye, look)
	end)
	ctx.Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 0.5, R1 = 6, Color = STAR, Life = 1.2, Width = 0.2, Height = 0.05 })
	local feet = Common.Feet(ctx) + Vector3.new(0, 0.3, 0)
	waveFb(ctx, feet, 12, STAR, 0.9)
	smokeFb(ctx, feet, 5, ASH, 3)
end

-- 의수 칼날: 손 속에서 미끄러져 나옴(날을 따라 별빛 한 줄기) · 다시 들어감
function Fx.BladeOut(ctx: any)
	local model = ctx.Actor and ctx.Actor.Model
	if model then
		CallistoBody.Blade(model, true, 0.28)
	end
	local tip, base = ctx.Tip("W"), ctx.Base and ctx.Base("W")
	if tip then
		ctx.Vfx.Flash(tip, { Color = STAR_CORE, Size = 1.6, Life = 0.2, Brightness = 5 })
		slashFb(ctx, tip, 3.4, STAR_CORE, 0.3)
		ctx.Vfx.Pack("Loose/MiniSparks", CFrame.new(tip), { Color = STAR_CORE, Size = 0.4, Count = 0.5 })
		if base then
			ctx.Vfx.Burst(base, { Count = 8, Colors = { STAR, STAR_CORE }, Size = 0.18, Speed = 6, Life = 0.4, Gravity = 4, Material = Enum.Material.Neon })
		end
	end
end

function Fx.BladeIn(ctx: any)
	local model = ctx.Actor and ctx.Actor.Model
	if model then
		CallistoBody.Blade(model, false, 0.3)
	end
end

function Fx.PageShot(ctx: any, ev: any)
	faceShot(ctx, (ev and ev.d) or 2.7, 8, 4.2, -1.4)
end

-- 2·3페이즈 컷신 카메라: 2 = 앞에서 휘두르는 팔을 보다가 물러서며 둘레를 돌아 우주를 크게 / 3 = 몸을 보다가 위로 물러나 내려다봄(필드 아래 우리은하)
function Fx.PhaseShot(ctx: any, ev: any)
	local phase = (ev and ev.p) or 2
	ctx.Shot((ev and ev.d) or 4.4, function(alpha: number)
		local f = ctx.Forward
		local r = f:Cross(Vector3.yAxis)
		local chest = ctx.Root.Position + Vector3.new(0, 1.2, 0)
		if phase == 2 then
			local k = smooth((alpha - 0.2) / 0.6)
			local ang = math.rad(-25 + 70 * k)
			local dist = 7 + 9 * k
			local dir = (f * math.cos(ang) + r * math.sin(ang)).Unit
			return CFrame.lookAt(chest + dir * dist + Vector3.new(0, 1.5 + 3 * k, 0), chest + Vector3.new(0, 1.5 * k, 0))
		end
		local k = smooth((alpha - 0.35) / 0.55)
		local eye = chest + f * (6 - 2 * k) + r * (2 + 4 * k) + Vector3.new(0, 1 + 16 * k, 0)
		local look = chest:Lerp(ctx.Root.Position - Vector3.new(0, 18, 0), k * 0.6)
		return CFrame.lookAt(eye, look)
	end)
end

-- 2페이즈 전환 순간: 팔 검과 오른 소매가 부서지고(강철·금·트위드 파편) 가면이 사라져 우주 팔 · 우주 머리, 배경이 우주로 — 빠르게 돌다 느려진다
function Fx.PhaseTwo(ctx: any)
	local model = ctx.Actor and ctx.Actor.Model
	local arm = model and model:FindFirstChild("Right Arm") :: BasePart?
	local Vfx = ctx.Vfx
	if arm then
		local at = arm.CFrame * Vector3.new(0, -0.6, 0)
		Vfx.Burst(at, { Count = 22, Colors = { c(208, 213, 222), c(228, 186, 100), c(110, 74, 48) }, Size = 0.3, Speed = 22, Life = 1.0, Gravity = 30, Material = Enum.Material.Metal })
		Vfx.Burst(at, { Count = 16, Colors = { STAR, STAR_CORE }, Size = 0.25, Speed = 14, Life = 0.9, Gravity = -4, Material = Enum.Material.Neon })
		Vfx.Flash(at, { Color = STAR_CORE, Size = 5, Life = 0.16, Brightness = 6 })
		-- 팔 검 · 소매가 부서지는 순간: 깨짐 시트 + 금빛 폭발 + 충격 + 강철 먼지
		shatterFb(ctx, at, 10, STAR_CORE)
		boomFb(ctx, at, 8, GOLDEN_STAR)
		impactFb(ctx, at, 6, GOLDEN)
		smokeFb(ctx, at, 5, ASH, 4)
		Vfx.Pack("Anime/ForceField-Break-01", CFrame.new(at), { Color = GOLDEN_STAR, Size = 0.7, Count = 0.5 })
		Vfx.Pack("Anime/Stars-01", CFrame.new(at), { Color = STAR_CORE, Size = 0.9, Count = 0.6 })
	end
	if model then
		CallistoBody.SetPage(model, 2)
		-- 의수에 끼운 검도 같이 부서진다(망치는 컷신이 끝나면 손에 — BattleClient)
		local weapon = model:FindFirstChild("CombatWeapon")
		for _, p in (if weapon then weapon:GetDescendants() else {}) do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
	end
	CallistoSpace.Show(0.6)
	CallistoSpace.Spin(4.5, 0.05)
	task.delay(0.35, function()
		CallistoSpace.Spin(0.12, 2.4)
	end)
end

-- 3페이즈 전환 순간: 옷이 1.1 초에 걸쳐 사라지고 우주 몸
function Fx.PhaseThree(ctx: any)
	local model = ctx.Actor and ctx.Actor.Model
	if model then
		CallistoBody.SetPage(model, 3, 1.1)
	end
	CallistoSpace.Show(0)
	local chest = ctx.Root.Position + Vector3.new(0, 1, 0)
	ctx.Vfx.Flash(chest, { Color = STAR_CORE, Size = 5, Life = 0.18, Brightness = 4 }) -- 섬광은 짧게, 우주 몸이 보이게
	-- 일식 코로나 + 성운이 번지는 파문 넷(어두운 색조 · 0.25초 간격), 번개 시트가 둘레를 가른다
	ctx.Vfx.Pack("Loose/PurpleExpanding", CFrame.new(chest), { Color = NEBULA, Size = 1.2, Count = 0.6 })
	ctx.Vfx.Pack("Loose/BlackSwirl", CFrame.new(chest), { Size = 0.8, Count = 0.5 })
	for i = 0, 3 do
		task.delay(0.25 * i, function()
			waveFb(ctx, chest, 16 + 8 * i, if i % 2 == 0 then CORONA else NEBULA, 0.9)
			boltFb(ctx, chest + Vector3.new(math.random(-5, 5), math.random(0, 4), math.random(-5, 5)), 7, NEBULA)
		end)
	end
	smokeFb(ctx, Vector3.new(ctx.Root.Position.X, ctx.Ground + 0.4, ctx.Root.Position.Z), 8, ASH, 4)
end

-- 우주 회전이 서서히 빨라진다(옷이 다 바뀐 뒤)
function Fx.SpinUp(_ctx: any)
	CallistoSpace.Spin(1.6, 3.5)
end

-- 우리은하가 전투 필드 아래에서 떠오른다
function Fx.GalaxyRise(_ctx: any)
	CallistoSpace.Galaxy(true, 2.2)
end

-- 일어서며 별빛이 터진다(무기가 바뀌는 순간과 함께)
function Fx.PageBurst(ctx: any)
	local Vfx = ctx.Vfx
	local p = ctx.Root.Position
	Vfx.Flash(p + Vector3.new(0, 1, 0), { Color = STAR_CORE, Size = 6, Life = 0.14, Brightness = 6 })
	local ground = Vector3.new(p.X, ctx.Ground + 0.4, p.Z)
	waveFb(ctx, ground, 22, STAR)
	boomFb(ctx, p + Vector3.new(0, 1.5, 0), 9, STAR)
	shatterFb(ctx, p + Vector3.new(0, 1.5, 0), 10, GOLDEN_STAR)
	smokeFb(ctx, ground, 8, ASH, 4)
	Vfx.Pack("Anime/Stars-01", CFrame.new(p + Vector3.new(0, 1.5, 0)), { Color = STAR_CORE, Size = 0.9, Count = 0.6 })
	for i = 0, 2 do
		task.delay(0.12 * i, function()
			Vfx.Ring(CFrame.new(Vector3.new(p.X, ctx.Ground + 0.15, p.Z)), { R0 = 1, R1 = 9 + i * 3, Color = if i == 1 then GOLDEN_STAR else STAR, Life = 0.7, Width = 0.3, Height = 0.06 })
		end)
	end
	Vfx.Burst(p + Vector3.new(0, 1.5, 0), { Count = 24, Colors = { STAR, STAR_CORE }, Size = 0.35, Speed = 20, Life = 0.9, Gravity = -6, Material = Enum.Material.Neon })
end

--=== 2페이즈 성위 품은 자 — 북두칠성 망치 ===--

-- 대상과 같은 열(앞뒤 같은 칸 = 칼리스토가 보는 방향 성분이 같다) · 같은 행(옆 성분이 같다)의 아군 칸
local function lineCells(ctx: any, along: "Column" | "Row"): { Vector3 }
	local axis = if along == "Column" then ctx.Forward else ctx.Forward:Cross(Vector3.yAxis)
	local out = {}
	for _, p in allyCells(ctx) do
		local d = p - ctx.Target
		if math.abs(Vector3.new(d.X, 0, d.Z):Dot(axis)) < 2.6 then
			table.insert(out, p)
		end
	end
	return out
end

-- 망치 머리가 닿은 자리: 금빛 충격 고리 + 별 파편 + 땅 균열(팩 — 큰 균열 · 바닥 금)
local function smash(ctx: any, at: Vector3, size: number)
	local ground = Vector3.new(at.X, ctx.Ground + 0.15, at.Z)
	ctx.Vfx.Ring(CFrame.new(ground), { R0 = 0.6, R1 = 4 * size, Color = GOLDEN, Life = 0.4, Width = 0.3, Height = 0.08 })
	ctx.Vfx.Flash(at, { Color = STAR_CORE, Size = math.min(5 * size, 8), Life = 0.12, Brightness = 5 })
	-- 플립북 층: 금빛 폭발 · 충격 · 바닥 파문 · 먼지(순간 입자 수를 지키려 크기로 키운다)
	boomFb(ctx, ground + Vector3.new(0, 0.8, 0), 6 * size, GOLDEN)
	impactFb(ctx, at, 5 * size, STAR_CORE)
	waveFb(ctx, ground + Vector3.new(0, 0.3, 0), 9 * size, GOLDEN)
	smokeFb(ctx, ground + Vector3.new(0, 0.3, 0), 4 * size, ASH, 3)
	ctx.Vfx.Burst(ground + Vector3.new(0, 0.3, 0), { Count = math.floor(10 * size), Colors = { STAR, STAR_CORE, GOLDEN }, Size = 0.4, Speed = 18, Life = 0.55, Gravity = 40, Material = Enum.Material.Neon })
	ctx.Vfx.Pack("Big/Big-Crack-01", CFrame.new(ground + Vector3.new(0, 0.2, 0)), { Color = GOLDEN, Size = 0.3 * size })
	ctx.Vfx.Pack("Anime/Crack-01", CFrame.new(ground + Vector3.new(0, 0.1, 0)), { Color = STAR, Size = 1.4 * size })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(ground + Vector3.new(0, 0.8, 0)), { Color = GOLDEN, Size = 0.5 * size, Count = 0.5 })
end

-- 망치의 국자 별이 밝아진다(치켜들 때 — 큰 한 방의 신호)
function Fx.HammerGlow(ctx: any)
	local head = ctx.Base and ctx.Base("W") or ctx.Hand("R")
	ctx.Vfx.Flash(head, { Color = STAR_CORE, Size = 3.5, Life = 0.25, Brightness = 5 })
	ctx.Vfx.Pack("Anime/Stars-01", CFrame.new(head), { Color = STAR, Size = 0.55, Count = 0.6 })
	chargeFb(ctx, head, 4.5, GOLDEN) -- 치켜든 망치에 금빛이 모인다
	task.delay(0.15, function()
		chargeFb(ctx, head, 3, STAR_CORE)
	end)
end

-- 평타: 대상 앞에 내려찍기
function Fx.HammerSmash(ctx: any)
	local at = ctx.Tip("W") or ctx.Target
	smash(ctx, at, 1)
	fb(ctx, at + Vector3.new(0, 1, 0), TEX.Wind, { Size = 6, Color = GOLDEN, Life = 0.35, LightEmission = 0.5 })
	ctx.Vfx.Pack("Loose/MiniSparks", CFrame.new(at), { Color = GOLDEN, Size = 0.5, Count = 0.5 })
end

-- 알리오스: 내려찍은 자리에서 장판 칸(2열 6칸)으로 금빛 물결이 달려가 장판으로 번진다(남는 장판은 전투 화면이 snapshot.Callisto.Aliot 로 그린다)
function Fx.AliothField(ctx: any)
	local Vfx = ctx.Vfx
	local hit = ctx.Tip("W") or (ctx.Root.Position + ctx.Forward * 3)
	smash(ctx, hit, 1.2)
	local cells = reach(ctx, "Alioth") -- 아군이 선 열 + 앞 열 6칸(2026-11-06)
	local mid = center(cells)
	local from = Vector3.new(hit.X, ctx.Ground + 0.2, hit.Z)
	for k = 1, 6 do
		task.delay(0.05 * k, function()
			local at = from:Lerp(Vector3.new(mid.X, ctx.Ground + 0.2, mid.Z), k / 6)
			Vfx.Ring(CFrame.new(at), { R0 = 0.5, R1 = 3 + k * 0.6, Color = GOLDEN, Life = 0.35, Width = 0.2, Height = 0.05 })
			fb(ctx, at + Vector3.new(0, 0.8, 0), TEX.Wind, { Size = 4 + k * 0.4, Color = GOLDEN, Life = 0.3, LightEmission = 0.5 })
		end)
	end
	task.delay(0.32, function()
		-- 판 전체를 덮는 큰 고리 대신 칸마다 작은 고리(장판 범위가 칸 모양으로 읽히게)
		for i, p in cells do
			task.delay(0.03 * i, function()
				Vfx.Ring(CFrame.new(p + Vector3.new(0, 0.2, 0)), { R0 = 1, R1 = 4.5, Color = GOLDEN, Life = 0.6, Width = 0.25, Height = 0.06 })
				Vfx.Flash(p + Vector3.new(0, 0.4, 0), { Color = if i % 2 == 0 then GOLDEN else STAR, Size = 3, Life = 0.5, Brightness = 2 })
				Vfx.Pack("Anime/Shiny-01", CFrame.new(p + Vector3.new(0, 0.6, 0)), { Color = GOLDEN, Size = 0.4, Count = 0.4 })
				waveFb(ctx, p + Vector3.new(0, 0.4, 0), 5.5, GOLDEN, 0.6) -- 장판 칸 모양대로(ThreatTiles)
				chargeFb(ctx, p + Vector3.new(0, 0.8, 0), 2.6, STAR_CORE)
			end)
		end
	end)
end

-- 메그레즈: 가로 후려치기 원호 + 맞은 자리에 금빛 초승달 충격(팩)
function Fx.MegrezSwing(ctx: any)
	Common.Arc(ctx, ctx.Target - ctx.Forward * 1.5, 88, 120, -100, { Radius = 4.2, Color = GOLDEN, Core = STAR_CORE, Life = 0.32, Width = 0.9 })
	smash(ctx, ctx.Target, 0.7)
	ctx.Vfx.Pack("vfx pack/f", CFrame.new(ctx.Target), { Color = GOLDEN, Size = 0.4 })
	ctx.Vfx.Pack("Anime/Punch-02", CFrame.new(ctx.Target), { Color = STAR_CORE, Size = 0.8 })
	slashFb(ctx, ctx.Target, 8.5, GOLDEN, 0.25)
	impactFb(ctx, ctx.Target, 5, STAR_CORE)
end

-- 소환: 망치 머리(미자르 곁)에서 작은 별(알코르)이 떨어져 나와 높이 솟았다가 적 진영으로 떨어지고, 내려앉는 자리에 별 문이 열린다
function Fx.SummonStar(ctx: any)
	local Vfx = ctx.Vfx
	local tiles = ctx.EnemyTiles or {}
	local land = if #tiles > 0 then tiles[math.random(1, #tiles)].Position + Vector3.new(0, 2.6, 0) else ctx.Root.Position + ctx.Forward * -4
	local from = ctx.Tip("W") or ctx.Root.Position
	local apex = from:Lerp(land, 0.5) + Vector3.new(0, 14, 0)
	star(ctx, from, 3, 0.4, STAR_CORE)
	Vfx.Pack("Loose/Flare", CFrame.new(from), { Color = STAR_CORE, Size = 0.5 })
	chargeFb(ctx, from, 3.2, GOLDEN)
	Vfx.Projectile(from, apex, { Time = 0.3, Color = STAR_CORE, TrailColor = STAR })
	task.delay(0.3, function()
		Vfx.Projectile(apex, land, { Time = 0.3, Color = STAR_CORE, TrailColor = STAR })
		Vfx.Pack("Anime/Portal-01", CFrame.new(land - Vector3.new(0, 2.2, 0)), { Color = STAR, Size = 0.6 })
		waveFb(ctx, land - Vector3.new(0, 2.2, 0), 9, STAR, 0.6) -- 별 문이 열리는 파문
	end)
	task.delay(0.6, function()
		impactFb(ctx, land, 5, STAR_CORE)
		Vfx.Flash(land, { Color = STAR_CORE, Size = 5, Life = 0.18, Brightness = 5 })
		Vfx.Ring(CFrame.new(land - Vector3.new(0, 2.4, 0)), { R0 = 0.5, R1 = 4, Color = STAR, Life = 0.5, Width = 0.2, Height = 0.05 })
		Vfx.Pack("Anime/Stars-01", CFrame.new(land), { Color = STAR_CORE, Size = 0.6 })
	end)
end

-- 페크다: 대상이 선 열을 따라 위에서 별빛 기둥이 차례로 내리꽂힌다(칸마다 충격파)
function Fx.PhecdaColumn(ctx: any)
	local Vfx = ctx.Vfx
	smash(ctx, ctx.Tip("W") or ctx.Target, 1.3)
	for i, p in lineCells(ctx, "Column") do
		task.delay(0.06 * i, function()
			Vfx.Projectile(p + Vector3.new(0, 16, 0), p + Vector3.new(0, 0.4, 0), { Time = 0.1, Color = STAR_CORE, TrailColor = STAR })
			Vfx.Pillar(p, { Color = STAR, Life = 0.5, Height = 8, Width = 2.2 })
			boltFb(ctx, p + Vector3.new(0, 4, 0), 9, STAR_CORE) -- 내리꽂히는 번개 기둥 시트
			task.delay(0.1, function()
				Vfx.Pack("Loose/Shockwave", CFrame.new(p + Vector3.new(0, 0.4, 0)), { Color = STAR_CORE, Size = 0.22 })
				impactFb(ctx, p + Vector3.new(0, 0.7, 0), 4.5, STAR)
				waveFb(ctx, p + Vector3.new(0, 0.3, 0), 7, STAR_CORE, 0.45)
			end)
		end)
	end
end

-- 메라크: 휘두른 자리에서 금빛 초승달 충격파가 대상의 행을 따라 끝까지 달린다
function Fx.MerakRow(ctx: any)
	local Vfx = ctx.Vfx
	local cells = lineCells(ctx, "Row")
	local mid = center(cells)
	local from = ctx.Tip("W") or ctx.Root.Position
	Vfx.Beam(from, mid + Vector3.new(0, 0.6, 0), { Color = GOLDEN, Width = 1.6, Life = 0.4 })
	slashFb(ctx, from, 8, GOLDEN, 0.25)
	table.sort(cells, function(a, b)
		return (a - from).Magnitude < (b - from).Magnitude
	end)
	for i, p in cells do
		task.delay(0.05 * i, function()
			Vfx.Shockwave(p + Vector3.new(0, 0.2, 0), { Color = GOLDEN, Radius = 3.5, Life = 0.35 })
			Vfx.Burst(p + Vector3.new(0, 0.4, 0), { Count = 5, Colors = { GOLDEN, STAR_CORE }, Size = 0.35, Speed = 14, Life = 0.45, Material = Enum.Material.Neon })
			Vfx.Pack("vfx pack/f", CFrame.new(p + Vector3.new(0, 0.4, 0)), { Color = GOLDEN, Size = 0.3, Count = 0.5 })
			slashFb(ctx, p + Vector3.new(0, 0.9, 0), 6, GOLDEN, 0.25)
			smokeFb(ctx, p + Vector3.new(0, 0.3, 0), 3, ASH, 2)
		end)
	end
end

-- 북두칠성: 아군 진영 하늘의 일곱 별 자리(국자 넷 + 손잡이 셋 — 알카이드가 칼리스토 쪽 끝)
local function dipperStars(ctx: any): { Vector3 }
	local cells = allyCells(ctx)
	local mid = center(cells) + Vector3.new(0, 15, 0)
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local shape = { { 6, 1 }, { 3, 2 }, { 0.5, 1.5 }, { -1.5, 0 }, { -1.5, -3.5 }, { -6, -3 }, { -5.5, 0.5 } }
	local out = {}
	for i, s in shape do
		out[i] = mid + f * (-s[1]) + r * s[2]
	end
	return out
end

-- 북두칠성 1: 하늘에 별 일곱이 차례로 켜지고(별마다 반짝) 선으로 이어진다
function Fx.Dipper(ctx: any)
	local Vfx = ctx.Vfx
	local stars = dipperStars(ctx)
	for i, p in stars do
		task.delay(0.12 * i, function()
			Vfx.Flash(p, { Color = STAR_CORE, Size = 4, Life = 1.4, Brightness = 5 })
			Vfx.Pack("Loose/Flare", CFrame.new(p), { Color = STAR_CORE, Size = 0.8 })
			chargeFb(ctx, p, 4, STAR_CORE)
			if i > 1 then
				Vfx.Beam(stars[i - 1], p, { Color = STAR, Width = 0.25, Life = 1.2 })
			end
		end)
	end
	-- 일곱 별이 다 켜지면 하늘에 은은한 파문(어두운 푸른빛 — 아래 칸 예고를 가리지 않는다)
	task.delay(0.12 * #stars + 0.1, function()
		waveFb(ctx, center(stars), 34, DEEP, 1.0)
	end)
end

-- 북두칠성 2: 망치가 닿는 순간 별이 아군 칸 전부로 쏟아지고(칸마다 별빛 폭발), 진영 가운데로 큰 충격파
function Fx.DipperCrash(ctx: any)
	local Vfx = ctx.Vfx
	local stars = dipperStars(ctx)
	smash(ctx, ctx.Tip("W") or ctx.Target, 1.6)
	-- 별 일곱이 국자 7칸에 하나씩(앞쪽 별 ↔ 앞쪽 칸 순) 떨어진다(2026-11-06)
	local cells = reach(ctx, "Dipper")
	local f = ctx.Forward
	table.sort(cells, function(a, b)
		return a:Dot(f) < b:Dot(f)
	end)
	local order = table.clone(stars)
	table.sort(order, function(a, b)
		return a:Dot(f) < b:Dot(f)
	end)
	for i, p in cells do
		local from = order[(i - 1) % #order + 1]
		task.delay(0.02 * i, function()
			Vfx.Projectile(from, p + Vector3.new(0, 0.4, 0), { Time = 0.14, Color = STAR_CORE, TrailColor = STAR })
			task.delay(0.14, function()
				Vfx.Pillar(p, { Color = if i % 3 == 0 then GOLDEN else STAR, Life = 0.55, Height = 7, Width = 2.2 })
				Vfx.Pack("vfx pack/Explosion", CFrame.new(p + Vector3.new(0, 0.6, 0)), { Color = STAR, Size = 0.35, Count = 0.35 })
				impactFb(ctx, p + Vector3.new(0, 0.7, 0), 4.5, STAR_CORE)
				boomFb(ctx, p + Vector3.new(0, 0.9, 0), 4.5, if i % 3 == 0 then GOLDEN else STAR)
			end)
		end)
	end
	local mid = center(cells)
	task.delay(0.3, function()
		Vfx.Ring(CFrame.new(mid + Vector3.new(0, 0.2, 0)), { R0 = 2, R1 = 12, Color = STAR_CORE, Life = 0.7, Width = 0.5, Height = 0.08 })
		Vfx.Pack("Loose/Shockwave", CFrame.new(mid + Vector3.new(0, 0.6, 0)), { Color = STAR_CORE, Size = 0.9 })
		waveFb(ctx, mid + Vector3.new(0, 0.4, 0), 30, STAR_CORE, 0.7)
		smokeFb(ctx, mid + Vector3.new(0, 0.4, 0), 8, ASH, 4)
	end)
end

--=== 3페이즈 케노스 아스테리스모스 — WWE 피니셔(2026-11-06 밤, 설계서 B절) ===--
-- 도발(Call · Snuff · Murmur) → 탑로프(Step · Cast · Ropes) → 상공 대기(Orbit) → 다이브(DiveShot · Tail · Landing) → 파워밤(Grab · Lift · Slam) / 끌어내림(Sever · Crash · Orbit 스턴).
-- 칸 정보: ctx.SafeTiles = 빛 칸(BasePart 목록 — 없으면 앞 두 열 6칸) · ctx.RopeTiles = 열 1·6 칸(없으면 AllyTiles 에서 어림) · ctx.Strong = 강화판(30% — 충격이 1.25배).
-- 컷인(FINISHER · PIN!) · 핀 게이지 · 로프 칸 표시는 HUD 가 그린다. 여기는 월드 연출만.
-- 파워밤: 대상 모델을 들어 올리지 않는다(캐릭터는 다른 시스템이 움직여 위험) — 왼손의 별빛 덩어리를 대상 삼아 들어 올렸다 내리찍는다.

local CRACK = c(176, 48, 64) -- 붉은 금 균열
local ROPE = c(170, 215, 255) -- 청백 로프

-- 빛 칸 · 붉은 칸 가운데들
local function kenosSplit(ctx: any): ({ Vector3 }, { Vector3 })
	local safe, dark = {}, {}
	local w = gridOf(ctx)
	for i, tile in ctx.AllyTiles or {} do
		local isSafe
		if ctx.SafeTiles and #ctx.SafeTiles > 0 then
			isSafe = table.find(ctx.SafeTiles, tile) ~= nil
		else
			isSafe = w ~= nil and (i - 1) % w + 1 <= 2
		end
		table.insert(if isSafe then safe else dark, tile.Position)
	end
	return safe, dark
end

-- 머리 자리(별 도는 곳) · 하늘 위 아무 곳(별 술렁)
local function headAt(ctx: any): Vector3
	local head = ctx.Actor and ctx.Actor.Model and ctx.Actor.Model:FindFirstChild("Head") :: BasePart?
	return if head then head.Position else ctx.Root.Position + Vector3.new(0, 3, 0)
end

local function skyPoint(ctx: any): Vector3
	local a, r = math.random() * math.pi * 2, 6 + math.random() * 24
	return Vector3.new(ctx.Root.Position.X + math.cos(a) * r, ctx.Ground + 14 + math.random() * 16, ctx.Root.Position.Z + math.sin(a) * r)
end

local function targetPoint(ctx: any): Vector3
	return if typeof(ctx.Target) == "Vector3" then ctx.Target else ctx.Root.Position + ctx.Forward * 4
end

-- 도발 1: 오른팔 + 망치가 하늘을 가리키자 하늘 구의 별들이 하나둘 밝아진다
function Fx.KenosCall(ctx: any)
	local at = ctx.Tip("W") or ctx.Hand("R")
	ctx.Vfx.Pack("Loose/Sparkles_Beam", CFrame.new(at), { Color = STAR_CORE, Size = 0.7 })
	ctx.Vfx.Pack("Loose/Rays", CFrame.new(at), { Color = STAR_CORE, Size = 0.4, Count = 0.5 })
	chargeFb(ctx, at, 4.5, GOLDEN)
	for i = 1, 12 do
		task.delay(0.05 * i, function()
			local sp = skyPoint(ctx)
			star(ctx, sp, 2.6, 0.9, if i % 3 == 0 then STAR_CORE else STAR)
			if i % 3 == 0 then
				fb(ctx, sp, TEX.Flash, { Size = 4, Color = STAR_CORE, Life = 0.3, LightEmission = 1 })
			end
		end)
	end
end

-- 도발 2: 주먹을 쥐면 별 하나가 꺼진다(밝게 번쩍 → 어두운 푸른 고리와 가루만 남음)
function Fx.KenosSnuff(ctx: any)
	local Vfx = ctx.Vfx
	local fist = ctx.Hand("L")
	Vfx.Pack("Anime/Punch-03", CFrame.new(fist), { Color = STAR_CORE, Size = 0.4 })
	local p = fist + ctx.Forward * 4 + Vector3.new(0, 10, 0)
	star(ctx, p, 4, 0.15, FLASH)
	fb(ctx, p, TEX.Flash, { Size = 6, Color = FLASH, Life = 0.2, LightEmission = 1 })
	task.delay(0.3, function()
		shatterFb(ctx, p, 8, DEEP)
		smokeFb(ctx, p, 5, c(60, 70, 130), 3)
		Vfx.Ring(CFrame.lookAt(p, p + Vector3.yAxis), { R0 = 0.5, R1 = 4, Color = DEEP, Life = 0.6, Width = 0.12, Facing = true })
		Vfx.Burst(p, { Count = 10, Colors = { DEEP, c(30, 40, 90) }, Size = 0.3, Speed = 8, Life = 0.7, Gravity = 6, Material = Enum.Material.Neon })
	end)
end

-- 도발 3: 나머지 별들이 술렁인다(빠른 깜빡임이 하늘 가득 + 둥근 파문)
function Fx.KenosMurmur(ctx: any)
	local Vfx = ctx.Vfx
	for _ = 1, 30 do
		task.delay(math.random() * 0.6, function()
			star(ctx, skyPoint(ctx), 1.4 + math.random() * 1.4, 0.14, if math.random() < 0.3 then FLASH else STAR)
		end)
	end
	local mid = Vector3.new(ctx.Root.Position.X, ctx.Ground + 20, ctx.Root.Position.Z)
	for i = 0, 2 do
		task.delay(0.15 * i, function()
			waveFb(ctx, mid, 36, if i == 1 then NEBULA else STAR, 0.8)
			Vfx.Ring(CFrame.new(mid), { R0 = 2, R1 = 34, Color = STAR, Life = 0.8, Width = 0.25, Height = 0.05 })
		end)
	end
end

-- 탑로프: 별빛 발판이 발밑에 하나 켜진다(ev.h = 발판 높이, ev.s = 단계 — 단계마다 조금씩 크게)
function Fx.KenosStep(ctx: any, ev: any)
	local Vfx = ctx.Vfx
	local k = 0.8 + 0.2 * ((ev and ev.s) or 1)
	local at = Vector3.new(ctx.Root.Position.X, ctx.Ground + ((ev and ev.h) or 2), ctx.Root.Position.Z)
	Vfx.Flash(at, { Color = STAR_CORE, Size = 3.5 * k, Life = 0.35, Brightness = 4 })
	waveFb(ctx, at, 6 * k, STAR, 0.4)
	chargeFb(ctx, at, 3 * k, STAR_CORE)
	smokeFb(ctx, at - Vector3.new(0, 0.3, 0), 3 * k, ASH, 2)
	Vfx.Ring(CFrame.new(at), { R0 = 0.4, R1 = 3.2 * k, Color = STAR, Life = 0.45, Width = 0.18, Height = 0.05 })
	Vfx.Pack("Loose/Flare", CFrame.new(at), { Color = STAR_CORE, Size = 0.45 * k })
	Vfx.Sparks(at, { Color = STAR_CORE, Count = 8, Speed = 10 })
end

-- 빛 칸에 가는 빛기둥(대기 동안 낮게 맥동) · 붉은 칸에 금 간 균열 — 턴 B 위험 표시를 월드에도 건다
function Fx.KenosCast(ctx: any)
	local Vfx = ctx.Vfx
	local safe, dark = kenosSplit(ctx)
	for i, p in safe do
		task.delay(0.05 * i, function()
			chargeFb(ctx, p + Vector3.new(0, 1, 0), 3, STAR_CORE) -- 빛 칸에 모이는 빛(칸 표시는 기둥이 그대로 맡는다)
			Vfx.Pillar(p, { Color = STAR_CORE, Life = 6, Height = 14, Width = 0.5 })
			Vfx.Flash(p + Vector3.new(0, 0.5, 0), { Color = STAR, Size = 3, Life = 1.0, Brightness = 2 })
		end)
		for k = 1, 4 do
			task.delay(0.6 * k, function()
				Vfx.Flash(p + Vector3.new(0, 0.5, 0), { Color = STAR_CORE, Size = 3.4, Life = 0.3, Brightness = 3 })
			end)
		end
	end
	for i, p in dark do
		task.delay(0.04 * i, function()
			local ground = Vector3.new(p.X, ctx.Ground + 0.12, p.Z)
			Vfx.Pack("Anime/Crack-01", CFrame.new(ground), { Color = CRACK, Size = 1.5 })
			Vfx.Ring(CFrame.new(ground), { R0 = 0.4, R1 = 3, Color = CRACK, Life = 0.6, Width = 0.15, Height = 0.05 })
			smokeFb(ctx, ground + Vector3.new(0, 0.3, 0), 2.4, c(70, 40, 60), 2) -- 붉은 칸에 금 간 틈의 검은 김
		end)
	end
end

-- 로프: 판 양 끝 열(1 · 6) 바깥에 청백 줄 3개와 기둥(링의 로프) — 다이브 때까지 서 있는다
local function ropeLines(ctx: any): { { Vector3 } }
	local positions = {}
	if ctx.RopeTiles and #ctx.RopeTiles > 0 then
		for _, tile in ctx.RopeTiles do
			table.insert(positions, tile.Position)
		end
	else
		local w = gridOf(ctx)
		for i, tile in ctx.AllyTiles or {} do
			local col = if w then (i - 1) % w + 1 else 0
			if w and (col == 1 or col == w) then
				table.insert(positions, tile.Position)
			end
		end
	end
	if #positions == 0 then
		return {}
	end
	local mid = center(allyCells(ctx))
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local groups = { [1] = {}, [-1] = {} }
	for _, p in positions do
		table.insert(groups[if (p - mid):Dot(f) >= 0 then 1 else -1], p)
	end
	local out = {}
	for sign, list in groups do
		if #list > 0 then
			local g = center(list) + f * (sign * 4)
			local lo, hi = math.huge, -math.huge
			for _, p in list do
				local v = (p - g):Dot(r)
				lo, hi = math.min(lo, v), math.max(hi, v)
			end
			table.insert(out, { g + r * (lo - 3), g + r * (hi + 3) })
		end
	end
	return out
end

function Fx.KenosRopes(ctx: any)
	local Vfx = ctx.Vfx
	for _, line in ropeLines(ctx) do
		for h = 1, 3 do
			local lift = Vector3.new(0, ctx.Ground + 0.2 + 1.4 * h, 0)
			Vfx.Beam(Vector3.new(line[1].X, 0, line[1].Z) + lift, Vector3.new(line[2].X, 0, line[2].Z) + lift, { Color = ROPE, Width = 0.22, Life = 7 })
		end
		for _, e in line do
			Vfx.Pillar(Vector3.new(e.X, ctx.Ground, e.Z), { Color = ROPE, Life = 7, Height = 5, Width = 0.4 })
			Vfx.Flash(Vector3.new(e.X, ctx.Ground + 4.4, e.Z), { Color = STAR_CORE, Size = 2.4, Life = 0.8, Brightness = 4 })
			chargeFb(ctx, Vector3.new(e.X, ctx.Ground + 4.4, e.Z), 3, ROPE)
		end
	end
end

-- 로프가 충격을 받아 번쩍인다(다이브 착지 때 — 대비선만 켜고 끈다)
local function ropeFlash(ctx: any)
	for _, line in ropeLines(ctx) do
		for t = 0, 1, 0.25 do
			local p = line[1]:Lerp(line[2], t)
			ctx.Vfx.Flash(Vector3.new(p.X, ctx.Ground + 3, p.Z), { Color = FLASH, Size = 3, Life = 0.12, Brightness = 5 })
			boltFb(ctx, Vector3.new(p.X, ctx.Ground + 3, p.Z), 6, ROPE)
		end
	end
end

-- 상공 대기 · 스턴: 머리 위로 별이 돈다(ev.c = 별 수, ev.stun = 스턴 — 느리고 낮은 원). 모션이 도는 동안(상한 6초) 계속 그린다
function Fx.KenosOrbit(ctx: any, ev: any)
	local Vfx = ctx.Vfx
	local count = (ev and ev.c) or 7
	local stun = ev and ev.stun
	local model = ctx.Actor and ctx.Actor.Model
	task.spawn(function()
		local t0 = os.clock()
		local pulse = 0
		while os.clock() - t0 < 6 and model and model.Parent do
			pulse += 1
			if pulse % 5 == 1 then
				chargeFb(ctx, headAt(ctx) + Vector3.new(0, if stun then 1.9 else 2.8, 0), if stun then 3 else 4, if stun then DEEP else STAR) -- 별 궤도 가운데 맥동
			end
			local t = os.clock() - t0
			local head = headAt(ctx)
			for i = 1, count do
				local a = t * (if stun then 3 else 1.6) + i * math.pi * 2 / count
				local r = if stun then 1.7 else 2.6
				local at = head + Vector3.new(math.cos(a) * r, (if stun then 1.9 else 2.8) + 0.25 * math.sin(a * 2), math.sin(a) * r)
				Vfx.Flash(at, { Color = if i == 1 then STAR_CORE else STAR, Size = if stun then 1.1 else 1.3, Life = 0.2, Brightness = 4 })
			end
			task.wait(0.16)
		end
	end)
end

-- 다이브 조준 컷: 0.4초 — 아군 뒤에서 상공의 칼리스토를 올려다본다
function Fx.KenosDiveShot(ctx: any, ev: any)
	local mid = center(allyCells(ctx))
	ctx.Shot((ev and ev.d) or 0.4, function(alpha: number)
		local f = ctx.Forward
		local eye = mid + f * (14 - 3 * alpha) + Vector3.new(0, 5, 0)
		return CFrame.lookAt(eye, ctx.Root.Position + Vector3.new(0, 8.5 - 2 * alpha, 0))
	end)
end

-- 다이브 낙하: 별 꼬리 세 줄이 칼리스토가 떠 있던 자리에서 대상 쪽으로 곧장 꽂힌다
function Fx.KenosTail(ctx: any)
	local r = ctx.Forward:Cross(Vector3.yAxis)
	local from = ctx.Root.Position + Vector3.new(0, 7.5, 0)
	local to = targetPoint(ctx)
	for i = -1, 1 do
		ctx.Vfx.Projectile(from + r * (i * 1.4), to + r * (i * 1.1), { Time = 0.5, Color = STAR_CORE, TrailColor = STAR })
	end
	ctx.Vfx.Pack("Anime/Wind-02", CFrame.new(from), { Color = STAR, Size = 0.6 })
	chargeFb(ctx, from, 5, STAR_CORE)
	fb(ctx, from, TEX.Wind, { Size = 10, Color = STAR, Life = 0.4, LightEmission = 0.6 })
	-- 낙하 중 잔상: 경로를 따라 별빛 시트가 차례로 남는다
	for k = 1, 4 do
		task.delay(0.1 * k, function()
			local at = from:Lerp(to, k / 5)
			fb(ctx, at, TEX.Shoot, { Size = 4, Color = STAR, Life = 0.25, LightEmission = 1 })
		end)
	end
end

-- 다이브 착지: 충격 링과 균열이 붉은 칸에 번지고(착지점에서 가까운 칸부터), 빛 칸엔 기둥만 선다. 로프가 번쩍인다
function Fx.KenosLanding(ctx: any)
	local Vfx = ctx.Vfx
	local k = if ctx.Strong then 1.25 else 1
	local safe, dark = kenosSplit(ctx)
	local hit = targetPoint(ctx)
	smash(ctx, hit, 1.5 * k)
	Vfx.Ring(CFrame.new(Vector3.new(hit.X, ctx.Ground + 0.2, hit.Z)), { R0 = 1, R1 = 14 * k, Color = STAR_CORE, Life = 0.6, Width = 0.4, Height = 0.07 })
	-- WWE 다이브 착지: 큰 폭발 + 깨짐 + 파문 + 먼지, 우주 붕괴처럼 성운 보라 한 겹
	local gnd = Vector3.new(hit.X, ctx.Ground + 0.4, hit.Z)
	boomFb(ctx, gnd + Vector3.new(0, 1.5, 0), 12 * k, GOLDEN_STAR)
	shatterFb(ctx, gnd + Vector3.new(0, 1, 0), 15 * k, STAR_CORE)
	waveFb(ctx, gnd, 24 * k, NEBULA, 0.7)
	smokeFb(ctx, gnd, 8 * k, ASH, 5)
	boltFb(ctx, gnd + Vector3.new(0, 3, 0), 10 * k, NEBULA)
	Vfx.Pack("Big/Explosion-01", CFrame.new(gnd + Vector3.new(0, 1, 0)), { Color = GOLDEN_STAR, Size = 0.45 * k, Count = 0.35 })
	table.sort(dark, function(a, b)
		return (a - hit).Magnitude < (b - hit).Magnitude
	end)
	for i, p in dark do
		task.delay(0.025 * i, function()
			local ground = Vector3.new(p.X, ctx.Ground + 0.15, p.Z)
			Vfx.Ring(CFrame.new(ground), { R0 = 0.6, R1 = 4.5 * k, Color = CRACK, Life = 0.4, Width = 0.28, Height = 0.07 })
			Vfx.Flash(p + Vector3.new(0, 0.5, 0), { Color = STAR_CORE, Size = 3.5 * k, Life = 0.12, Brightness = 4 })
			boomFb(ctx, p + Vector3.new(0, 0.8, 0), 4 * k, CRACK)
			Vfx.Burst(ground + Vector3.new(0, 0.3, 0), { Count = 5, Colors = { CRACK, STAR_CORE }, Size = 0.35, Speed = 14, Life = 0.5, Gravity = 36, Material = Enum.Material.Neon })
			Vfx.Pack("Anime/Crack-01", CFrame.new(ground), { Color = CRACK, Size = 1.4 * k })
		end)
	end
	for _, p in safe do
		Vfx.Pillar(p, { Color = STAR_CORE, Life = 0.45, Height = 14, Width = 0.8 })
	end
	ropeFlash(ctx)
end

-- 파워밤 1: 움켜쥔 손에 별빛 덩어리(대상을 대신한다)가 잡혀, 내리찍을 때까지 손을 따라다닌다
function Fx.KenosGrab(ctx: any)
	local Vfx = ctx.Vfx
	local ball = Vfx.Part(Vector3.new(0.3, 0.3, 0.3), CFrame.new(ctx.Hand("L")), STAR_CORE)
	ball.Shape = Enum.PartType.Ball
	Vfx.Timed(0.78, function(alpha)
		local s = 1.1 + 0.25 * math.sin(alpha * 40)
		ball.Size = Vector3.new(s, s, s)
		ball.CFrame = CFrame.new(ctx.Hand("L") + Vector3.new(0, 1.2, 0))
		ball.Transparency = 0.3
	end, function()
		ball:Destroy()
	end)
	Vfx.Pack("Anime/Punch-03", CFrame.new(ctx.Hand("L")), { Color = STAR_CORE, Size = 0.5 })
	Vfx.Sparks(ctx.Hand("L"), { Color = STAR, Count = 8, Speed = 12 })
	impactFb(ctx, ctx.Hand("L"), 3.4, STAR_CORE)
	chargeFb(ctx, ctx.Hand("L") + Vector3.new(0, 1.2, 0), 3.2, STAR)
end

-- 파워밤 2: 들어 올리는 동안 별가루가 올라가고, 버티는 동안 떨리며 빛이 모인다
function Fx.KenosLift(ctx: any)
	local at = ctx.Hand("L") + Vector3.new(0, 2, 0)
	ctx.Vfx.Pack("Anime/Charge-01", CFrame.new(at), { Color = STAR, Size = 0.5 })
	for i = 0, 3 do
		task.delay(0.1 * i, function()
			ctx.Vfx.Flash(ctx.Hand("L") + Vector3.new(0, 2 + 0.2 * i, 0), { Color = STAR_CORE, Size = 3 + i * 0.5, Life = 0.18, Brightness = 4 })
			chargeFb(ctx, ctx.Hand("L") + Vector3.new(0, 2 + 0.3 * i, 0), 3 + i * 0.7, if i == 3 then GOLDEN_STAR else STAR) -- 올라갈수록 커지는 모으기
		end)
	end
end

-- 파워밤 3: 내리찍은 자리에 큰 균열 + 별 파편 폭발(슬로 느낌 — 파편이 천천히 흩어짐)
function Fx.KenosSlam(ctx: any)
	local Vfx = ctx.Vfx
	local at = targetPoint(ctx)
	smash(ctx, at, 2)
	local ground = Vector3.new(at.X, ctx.Ground + 0.3, at.Z)
	Vfx.Burst(ground, { Count = 30, Colors = { STAR, STAR_CORE, GOLDEN_STAR, CRACK }, Size = 0.45, Speed = 22, Life = 1.0, Gravity = 18, Material = Enum.Material.Neon })
	Vfx.Ring(CFrame.new(ground), { R0 = 1, R1 = 12, Color = STAR_CORE, Life = 0.6, Width = 0.4, Height = 0.07 })
	Vfx.Pack("Loose/Shockwave", CFrame.new(ground + Vector3.new(0, 0.5, 0)), { Color = STAR_CORE, Size = 0.9 })
	-- 파워밤 피니시: 큰 폭발 · 깨짐 · 성운 파문 · 번개 셋 · 두꺼운 먼지 · 별가루
	boomFb(ctx, ground + Vector3.new(0, 1.8, 0), 16, GOLDEN_STAR)
	shatterFb(ctx, ground + Vector3.new(0, 1.2, 0), 18, STAR_CORE)
	waveFb(ctx, ground + Vector3.new(0, 0.3, 0), 28, NEBULA, 0.8)
	smokeFb(ctx, ground, 12, ASH, 6)
	for i = 0, 2 do
		boltFb(ctx, ground + CFrame.Angles(0, math.rad(i * 120 + 30), 0) * Vector3.new(5, 3, 0), 9, if i == 1 then CORONA else NEBULA)
	end
	Vfx.Pack("Big/Explosion-01", CFrame.new(ground + Vector3.new(0, 1.2, 0)), { Color = GOLDEN_STAR, Size = 0.6, Count = 0.4 })
	Vfx.Pack("Anime/Stars-01", CFrame.new(ground + Vector3.new(0, 1.5, 0)), { Color = STAR_CORE, Size = 1.1, Count = 0.7 })
end

-- 끌어내림 1: 다이브 도중 한쪽 별빛이 끊긴다(몸 둘레 별 조각이 사방으로 튄다)
function Fx.KenosSever(ctx: any)
	local at = ctx.Root.Position + Vector3.new(0, 6.5, 0)
	ctx.Vfx.Flash(at, { Color = FLASH, Size = 5, Life = 0.12, Brightness = 6 })
	shatterFb(ctx, at, 10, STAR_CORE)
	boltFb(ctx, at, 8, DEEP)
	ctx.Vfx.Burst(at, { Count = 18, Colors = { STAR, STAR_CORE, DEEP }, Size = 0.35, Speed = 18, Life = 0.9, Gravity = 22, Material = Enum.Material.Neon })
	ctx.Vfx.Pack("Loose/Flash-3", CFrame.new(at), { Color = STAR_CORE, Size = 0.7 })
end

-- 끌어내림 2: 바닥에 쿵 — 충격 링 · 먼지 · 균열
function Fx.KenosCrash(ctx: any)
	local Vfx = ctx.Vfx
	local ground = Vector3.new(ctx.Root.Position.X, ctx.Ground + 0.2, ctx.Root.Position.Z)
	Vfx.Ring(CFrame.new(ground), { R0 = 1, R1 = 12, Color = STAR_CORE, Life = 0.6, Width = 0.4, Height = 0.07 })
	Vfx.Dust(ground, { Color = c(190, 196, 214), Count = 14, Size = 1.6, Speed = 14 })
	Vfx.Pack("Anime/Crack-01", CFrame.new(ground), { Color = STAR, Size = 1.8 })
	Vfx.Pack("Loose/Shockwave", CFrame.new(ground + Vector3.new(0, 0.5, 0)), { Color = STAR_CORE, Size = 0.7 })
	impactFb(ctx, ground + Vector3.new(0, 1, 0), 7, STAR_CORE)
	waveFb(ctx, ground + Vector3.new(0, 0.3, 0), 18, STAR, 0.6)
	shatterFb(ctx, ground + Vector3.new(0, 1.5, 0), 10, DEEP)
	smokeFb(ctx, ground, 8, ASH, 4)
end

return Fx
