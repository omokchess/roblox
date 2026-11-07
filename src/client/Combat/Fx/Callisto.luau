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

--[[
	2026-11-07 사용자: "매 칸마다 뭐가 나오는 이펙트는 … 공격을 하는 스킬이면 다른 형식의 이펙트로."
	공격 연출은 칸 개수만큼 복제하지 않고, 칸 목록을 "모양"(가운데 · 앞뒤 u · 옆 v 범위 · 반지름)으로만 읽어 하나의 연출로 낸다.
	(예고 칸은 판이 이미 보여 준다 — 바닥에는 외곽선 Beam 과 낮은 빛만, 칸을 덮는 두꺼운 것은 두지 않는다)
]]
-- 범위 도구는 Fx/Common 에 있다(다른 직업의 광역기도 같이 쓴다)
local areaOf = function(ctx: any, cells: { Vector3 }): any
	return Common.AreaOf(ctx, cells)
end
local areaAt = Common.AreaAt
local outline = Common.Outline
local curtain = Common.Curtain
local fillArea = Common.AreaFill

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
	Shoot = "rbxassetid://16477162837", -- Anime/Shoot-01
	Shatter = "rbxassetid://17086390547", -- Anime/Shield-Break-01
	Wave = "rbxassetid://13634052022", -- Anime/ForceField-Break-01
	Boom = "http://www.roblox.com/asset/?id=11395089850", -- Big/Explosion-01
	Flame = "rbxassetid://16951304645", -- Anime/Fire-Slash-01
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
end

-- 내던짐: 대상이 떨어진 자리에 먼지와 충격파
function Fx.Throw(ctx: any)
	local ground = Vector3.new(ctx.Target.X, ctx.Ground + 0.3, ctx.Target.Z)
	ctx.Vfx.Pack("Anime/Shoot-01", CFrame.new(ground), { Color = STAR, Size = 0.9 })
	waveFb(ctx, ground + Vector3.new(0, 0.4, 0), 9, STAR)
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
	local a = areaOf(ctx, cells)
	Vfx.Flash(from, { Color = FLASH, Size = 6, Life = 0.12, Brightness = 7 }) -- 렌즈 섬광은 짧게
	Vfx.Pack("Loose/Shockwave", CFrame.new(from), { Color = STAR_CORE, Size = 0.3 })
	waveFb(ctx, from, 8, STAR_CORE)
	-- 초점 빛줄기가 범위 한쪽 끝에서 반대쪽 끝까지 옆으로 훑는다(칸마다 찍지 않는다)
	local steps = 10
	for k = 0, steps do
		task.delay(0.04 * k, function()
			local p = areaAt(a, 0, a.V0 + (a.V1 - a.V0) * k / steps, 0.3)
			Vfx.Beam(from, p, { Color = if k % 3 == 0 then BURN else STAR, Width = 1.6, Life = 0.16 })
			Vfx.Sparks(p, { Color = STAR_CORE, Count = 3, Speed = 10 })
		end)
	end
	task.delay(0.5, function()
		outline(ctx, a, STAR, 0.5)
		-- 범위 크기에 맞춰 키운다: 기둥 굵기 · 번개 시트 · 번개 팩 모두 범위 반지름에 비례 + 범위 전체 면을 덮는 묶음
		Vfx.Pillar(mid, { Color = STAR, Life = 0.5, Height = 9, Width = math.clamp(a.Radius * 0.35, 2.4, 6) })
		boltFb(ctx, mid + Vector3.new(0, 4, 0), math.max(12, a.Radius * 1.6), STAR_CORE)
		Vfx.Pack("Big/Lighting-01", CFrame.new(mid), { Color = STAR, Size = math.max(0.4, a.Radius / 18) })
		fillArea(ctx, a, STAR, { Core = STAR_CORE })
	end)
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
		end)
	end
	-- 맞는 범위(대상 둘레 3×3)에는 칸마다 찍지 않고 하나의 칼바람 고리가 범위 끝까지 퍼진다
	local ar = areaOf(ctx, reach(ctx, "Astro"))
	task.delay(0.4, function()
		Vfx.Ring(CFrame.new(Vector3.new(ar.Mid.X, ctx.Ground + 0.2, ar.Mid.Z)), { R0 = 1, R1 = ar.Radius + 2, Color = STAR, Life = 0.4, Width = 0.35, Height = 0.07 })
		Vfx.Pack("Anime/Slashes-01", CFrame.new(ar.Mid + Vector3.new(0, 1.4, 0)), { Color = STAR, Size = math.max(1.1, ar.Radius / 6) })
		impactFb(ctx, ar.Mid + Vector3.new(0, 1.2, 0), math.max(6, ar.Radius * 1.2), STAR)
		fillArea(ctx, ar, STAR, { Core = STAR_CORE, Quick = true })
		outline(ctx, ar, STAR, 0.45)
	end)
end

-- 도약: 발밑에서 바람과 눈가루
function Fx.LeapDust(ctx: any)
	local feet = Common.Feet(ctx)
	ctx.Vfx.Ring(CFrame.new(feet + Vector3.new(0, 0.1, 0)), { R0 = 0.6, R1 = 5, Color = STAR, Life = 0.35, Width = 0.18, Height = 0.05 })
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
			local land = ctx.Target + Vector3.new(math.random(-45, 45) / 10, -1.5, math.random(-45, 45) / 10)
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
	local area = areaOf(ctx, cells)
	for i = 1, 8 do -- 하늘의 별 여덟(칸 수와 무관)
		task.delay(0.6 + 0.05 * i, function()
			local at = areaAt(area, area.U0 + math.random() * (area.U1 - area.U0), area.V0 + math.random() * (area.V1 - area.V0), 6 + math.random() * 5)
			star(ctx, at, 1.6, 1.2, if i % 3 == 0 then STAR_CORE else STAR)
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
		-- 내려앉는 하늘: 범위 전체를 한 장으로 덮는 어두운 장막이 가장자리부터 솟고, 가운데로 큰 파문 하나
		waveFb(ctx, mid + Vector3.new(0, 0.3, 0), area.Radius * 2, STAR, 0.7)
		Common.FullBoard(ctx, area, DEEP, { Core = STAR, Height = 12, Shake = 1.4 }) -- 판 전체(아군 + 적)가 가장자리까지 한꺼번에
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
	Vfx.Pack("Anime/Stars-01", CFrame.new(p + Vector3.new(0, 1.5, 0)), { Color = STAR_CORE, Size = 0.9, Count = 0.6 })
	for i = 0, 2 do
		task.delay(0.12 * i, function()
			Vfx.Ring(CFrame.new(Vector3.new(p.X, ctx.Ground + 0.15, p.Z)), { R0 = 1, R1 = 9 + i * 3, Color = if i == 1 then GOLDEN_STAR else STAR, Life = 0.7, Width = 0.3, Height = 0.06 })
		end)
	end
	Vfx.Burst(p + Vector3.new(0, 1.5, 0), { Count = 24, Colors = { STAR, STAR_CORE }, Size = 0.35, Speed = 20, Life = 0.9, Gravity = -6, Material = Enum.Material.Neon })
end

--=== 2페이즈 성위 품은 자 — 북두칠성 망치 ===--

-- 망치 머리가 닿은 자리: 금빛 충격 고리 + 별 파편 + 땅 균열(팩 — 큰 균열 · 바닥 금)
local function smash(ctx: any, at: Vector3, size: number)
	local ground = Vector3.new(at.X, ctx.Ground + 0.15, at.Z)
	ctx.Vfx.Ring(CFrame.new(ground), { R0 = 0.6, R1 = 4 * size, Color = GOLDEN, Life = 0.4, Width = 0.3, Height = 0.08 })
	ctx.Vfx.Flash(at, { Color = STAR_CORE, Size = math.min(5 * size, 8), Life = 0.12, Brightness = 5 })
	-- 플립북 층: 금빛 폭발 · 충격 · 바닥 파문 · 먼지(순간 입자 수를 지키려 크기로 키운다)
	boomFb(ctx, ground + Vector3.new(0, 0.8, 0), 6 * size, GOLDEN)
	impactFb(ctx, at, 5 * size, STAR_CORE)
	waveFb(ctx, ground + Vector3.new(0, 0.3, 0), 9 * size, GOLDEN)
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
	ctx.Vfx.Pack("Loose/MiniSparks", CFrame.new(at), { Color = GOLDEN, Size = 0.5, Count = 0.5 })
end

--[[
	칠성군 강화(2026-11-07 사용자: "다른 칼리스토의 스킬들도 조율자 스킬의 강화버전으로"): 조율자 별 기술의 문법을 금빛 · 크게 · 무겁게.
	알리오스 ↔ 조율자 AliothStrike(별이 진형을 곧게 가로질러 빨라지는 내리긋기) · 메그레즈 ↔ MegrezFling(별이 줄을 훑음) ·
	메라크 ↔ MerakDash/Burst(남는 선이 부분부분 터지다 통째로 터짐) · 페크다 ↔ SeptLaser(하늘 별에서 레이저, 선 자국) · 알코르 소환 ↔ 별이 떨어짐
]]
local STAR_PAL = {
	Layers = { { GOLDEN, 2.0, 0.45 }, { STAR_CORE, 0.8, 0.1 } },
	Ring = STAR_CORE,
	Flash = FLASH,
	Shock = GOLDEN,
	Burst = { GOLDEN, STAR_CORE },
	Core = STAR_CORE,
	Glow = GOLDEN,
}

-- 알리오스: 내려찍은 자리에서 장판 칸(2열 6칸)으로 금빛 물결이 달려가 장판으로 번진다(남는 장판은 전투 화면이 snapshot.Callisto.Aliot 로 그린다)
function Fx.AliothField(ctx: any)
	local Vfx = ctx.Vfx
	local hit = ctx.Tip("W") or (ctx.Root.Position + ctx.Forward * 3)
	smash(ctx, hit, 1.2)
	local cells = allyCells(ctx) -- 판 전체(18칸 — 2026-11-07 전체 광역기)
	local mid = center(cells)
	local from = Vector3.new(hit.X, ctx.Ground + 0.2, hit.Z)
	for k = 1, 6 do
		task.delay(0.05 * k, function()
			local at = from:Lerp(Vector3.new(mid.X, ctx.Ground + 0.2, mid.Z), k / 6)
			Vfx.Ring(CFrame.new(at), { R0 = 0.5, R1 = 3 + k * 0.8, Color = GOLDEN, Life = 0.35, Width = 0.2, Height = 0.05 })
		end)
	end
	-- 판 전체가 가장자리까지 한꺼번에 맞고(FullBoard), 이어서 별이 판 전체를 X 자로 가로지르며 장판을 새긴다
	local a = areaOf(ctx, cells)
	task.delay(0.05, function()
		Common.FullBoard(ctx, a, GOLDEN, { Core = STAR_CORE, Shake = 1.3 })
		Vfx.Pack("Anime/Shiny-01", CFrame.new(a.Mid + Vector3.new(0, 0.6, 0)), { Color = GOLDEN, Size = math.max(0.8, a.Radius / 10), Count = 0.6 })
	end)
	-- 조율자 알리오스처럼: 망치에서 튄 별이 장판을 X 자로 가로질러 긋는다(간격이 갈수록 짧아짐), 마지막 모서리에서 큰 금빛 폭발
	local pts = { hit + Vector3.new(0, 2, 0) }
	for _, uv in { { a.U0, a.V0 }, { a.U1, a.V1 }, { a.U0, a.V1 }, { a.U1, a.V0 }, { a.U0, a.V0 } } do
		table.insert(pts, areaAt(a, uv[1] * 0.9, uv[2] * 0.9, 1.6))
	end
	Common.StarZig(ctx, pts, { 0.12, 0.14, 0.1, 0.08, 0.06 }, STAR_PAL, function(k, at)
		fb(ctx, at, TEX.Slash, { Size = 6, Color = GOLDEN, Life = 0.22, LightEmission = 1, Rotation = math.random(-60, 60) })
		if k == 5 then
			boomFb(ctx, a.Mid + Vector3.new(0, 1, 0), a.Radius * 1.2, GOLDEN)
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
	-- 조율자 메그레즈처럼: 금빛 별이 대상 둘레 옆줄을 훑고 지나간다
	local r = ctx.Forward:Cross(Vector3.yAxis)
	local y = Vector3.new(0, 1.6, 0)
	Common.StarZig(ctx, { ctx.Target - r * 9 + y, ctx.Target + r * 9 + y }, { 0.14 }, STAR_PAL, function(_, at)
		fb(ctx, at, TEX.Bolt, { Size = 5, Color = GOLDEN, Life = 0.3, LightEmission = 1 })
	end)
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
		Common.SeptLaser(ctx, function()
			return apex
		end, land - Vector3.new(0, 2.2, 0), 0.5, 0.3, 0.25, STAR_PAL) -- 떨어지는 별이 가는 빛줄을 끌며 내려앉는다
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

-- 페크다(유도기): 하늘의 별 셋이 대상을 겨눠 레이저를 내리꽂는다 — 가운데 줄기는 굵게, 양옆 둘은 가늘게 대상 한 점으로 모인다(조율자 셉텐트리오네스 레이저 문법)
function Fx.PhecdaColumn(ctx: any)
	local Vfx = ctx.Vfx
	local at = ctx.Target
	local ground = Vector3.new(at.X, ctx.Ground + 0.3, at.Z)
	local r = ctx.Forward:Cross(Vector3.yAxis)
	smash(ctx, ctx.Tip("W") or at, 1)
	for k, off in { 0, -7, 7 } do
		task.delay((k - 1) * 0.05, function()
			local top = at + r * off + Vector3.new(0, 24, 0)
			Vfx.Flash(top, { Color = FLASH, Size = 3, Life = 0.14, Brightness = 4 })
			Common.SeptLaser(ctx, function()
				return top
			end, ground, if k == 1 then 1.5 else 0.8, 0.14, 0.25, STAR_PAL)
		end)
	end
	task.delay(0.14, function()
		Vfx.Pillar(ground, { Color = STAR, Life = 0.5, Height = 10, Width = 2.4 })
		impactFb(ctx, at, 6, STAR)
		waveFb(ctx, ground, 10, STAR_CORE, 0.5)
		Vfx.Pack("Loose/Shockwave", CFrame.new(ground), { Color = STAR_CORE, Size = 0.4 })
		Vfx.Shake(0.5, 0.25)
	end)
end

-- 메라크(유도기): 휘두른 망치 끝에서 금빛 선이 대상까지 이어지고, 선이 세 번 부분부분 터진 뒤 대상 쪽에서 통째로 터진다(조율자 메라크 문법)
function Fx.MerakRow(ctx: any)
	local Vfx = ctx.Vfx
	local from = ctx.Tip("W") or ctx.Root.Position
	local at = ctx.Target
	slashFb(ctx, from, 8, GOLDEN, 0.25)
	local line = Common.GlowLine(from, at, 0.2, 0.06, STAR_PAL)
	impactFb(ctx, at, 5, STAR_CORE)
	for k, t in { 0.08, 0.14, 0.2 } do
		task.delay(t, function()
			line.Flare(from:Lerp(at, (k - 0.5) / 3))
		end)
	end
	task.delay(0.3, function()
		line.Burst()
		Vfx.Flash(at, { Color = FLASH, Size = 7, Life = 0.2, Brightness = 5 })
		boomFb(ctx, at, 9, GOLDEN)
		waveFb(ctx, Vector3.new(at.X, ctx.Ground + 0.3, at.Z), 9, STAR_CORE, 0.5)
		for k = 0, 3 do
			Vfx.Burst(from:Lerp(at, k / 3), { Count = 4, Colors = { GOLDEN, STAR_CORE }, Size = 0.25, Speed = 10, Gravity = 6, Life = 0.5 })
		end
		Vfx.Shake(0.5, 0.25)
	end)
end

--[[
	북두칠성 — 조율자 셉텐트리오네스(Fx/Attuner)의 강화형 (2026-11-07 사용자: "조율자 셉텐트리오네스의 강화형으로 이펙트를 재구성").
	같은 문법: 하늘의 별 일곱(크고 금빛 · 청백) → 별이 차례로 레이저(굵게 · 두 겹, 강중약 간격, 카메라가 별을 올려다보다 레이저를 쫓아 내려가며 꺾임) →
	모으기(별이 조여 들고 0.5초 멈춤) → 망치로 국자 7칸에 내리꽂는 일격, 별자리 선이 판 위에 잠시 남는다. 제목 카드는 쓰지 않는다(컷인이 이펙트를 가려서).
	공용(Common)에서 쓴 것: SeptLaser(레이저) · SeptScar(선 자국) · sine · expoOut · quadIn(카메라 easing). 레이저 자리는 국자 7칸(ctx.ThreatTiles)의 모양을 따라 별마다 한 점,
	칸마다 같은 것을 찍지 않고 한 별자리의 선(레이저 착점끼리 이은 선)으로 읽힌다.
	모션: 사건 DipperLaser × 7(ev.star · nth · gap · hold) → DipperGather → DipperCrash(+Hit).
]]
-- 별 일곱의 색·크기 (2026-11-07 사용자: 실제 별 색깔·크기 비율 참고). 순서 = 알카이드 · 미자르 · 알리오스 · 메그레즈 · 페크다 · 메라크 · 두베.
-- 색: 분광형(Yale Bright Star Catalogue 분류, 사용자 제시 값: 알카이드 B3V · 미자르 A2V · 알리오스 A1III · 메그레즈 A3V · 페크다 A0V · 메라크 A1V · 두베 K0III)을
--     흑체색 표(Mitchell Charity "What color are the stars?": B 계열 청백 ≈ 170,191,255 · A 계열 흰빛 ≈ 202,215,255 · K0 주황 ≈ 255,210,161)에 맞춰 옮긴 값.
--     (표·분류는 기억에 의한 것 — 웹으로 다시 확인하지 않았다)
-- 크기: 밤하늘에서 보이는 밝기(겉보기 등급 V: 알리오스 1.77 · 두베 1.79 · 알카이드 1.86 · 미자르 2.04 · 메라크 2.37 · 페크다 2.44 · 메그레즈 3.31) 기준,
--     지름 ∝ 10^(-0.2·(V-1.77)) (밝기 ∝ 면적). 실제 반지름 비율(두베는 거성이라 10배 넘게 큼)은 화면이 이상해져 쓰지 않는다.
local DIPPER_MAG = { 1.86, 2.04, 1.77, 3.31, 2.44, 2.37, 1.79 }
local DIPPER_COL = { c(172, 194, 255), c(212, 222, 255), c(200, 214, 255), c(222, 230, 255), c(205, 217, 255), c(202, 215, 255), c(255, 210, 161) }
local DIPPER_STAR = {}
for i = 1, 7 do
	DIPPER_STAR[i] = {
		Col = DIPPER_COL[i],
		Core = DIPPER_COL[i]:Lerp(Color3.new(1, 1, 1), 0.6),
		Size = 10 ^ (-0.2 * (DIPPER_MAG[i] - 1.77)),
	}
end
local DIPPER_MIX = c(222, 228, 255) -- 강타(일곱 별이 한꺼번에 터짐)의 바탕색: 별빛 평균
local function dipperPal(info: any): { [string]: any }
	return {
		Layers = { { info.Col, 1.6, 0.45 }, { info.Core, 0.64, 0.1 } }, -- 별 색 겉 + 밝은 속 두 겹
		Ring = info.Core,
		Flash = FLASH,
		Shock = info.Col,
		Burst = { info.Col, info.Core },
		Core = FLASH,
		Glow = info.Col,
	}
end
local DIPPER_LINKS = { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 5 }, { 5, 6 }, { 6, 7 }, { 7, 4 } } -- 손잡이 → 국자 테두리
-- 리듬(2026-11-07 사용자: "띵 - 띵-띵ㅡ 띠디디디딩- 쿠구구구구... 콰앙!!!"): 카메라 이동·입자 모임 0.15~1.05 → 별 탄생(0.09초씩 순차) 1.05~1.59 → 떨림 1.95 → 레이저 가속 2.3~3.44 → 회전 이동·우르릉 3.25~4.7 → 강타 4.7. 모션 표(Skills.CallistoDipper)와 같아야 한다
local DIPPER_END = 4.7 -- 강타(DipperCrash) 시각 — 별자리 선이 여기까지 남는다
local DIPPER_T0 = 0.15 -- Dipper 사건 시각
local DIPPER_BIRTH_T = 1.05 -- 첫 별(알카이드) 탄생 시각, 이후 DIPPER_BIRTH_STEP 간격
local DIPPER_BIRTH_STEP = 0.09
local DIPPER_TREMBLE_T = 1.95 -- 별 떨림 시작(레이저 직전까지 진폭 증가)
local DIPPER_LASER_T = { 2.3, 2.75, 3.05, 3.25, 3.33, 3.39, 3.44 } -- 간격 0.45 · 0.30 · 0.20 · 0.08 · 0.06 · 0.05
local DIPPER_PUNCH_N = 3 -- 첫 세 발만 줌 펀치
local DIPPER_GATHER_T = 3.25 -- DipperGather 사건 시각(카메라 회전 이동 시작)
local DIPPER_ORBIT = 0.7 -- 회전 이동 시간
local DIPPER_ORBIT_HOLD = 0.3 -- 레이저가 끝난 뒤(3.44) 회전 이동을 시작하기까지 더 머무는 시간: 회전은 3.55 부터

local dipperStates: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local function dstate(ctx: any): any
	local s = dipperStates[ctx.Actor]
	if not s then
		s = {}
		dipperStates[ctx.Actor] = s
	end
	return s
end

-- 북두칠성: 아군 진영 하늘의 일곱 별 자리(국자 넷 + 손잡이 셋 — 알카이드가 칼리스토 쪽 끝). 조율자보다 크게 펼친다
local function dipperStars(ctx: any): { Vector3 }
	local cells = allyCells(ctx)
	local mid = center(cells) + Vector3.new(0, 9, 0) -- 낮춰서 올려다보지 않고 판과 한 화면에 들어오게
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local shape = { { 6, 1 }, { 3, 2 }, { 0.5, 1.5 }, { -1.5, 0 }, { -1.5, -3.5 }, { -6, -3 }, { -5.5, 0.5 } }
	local out = {}
	for i, s in shape do
		out[i] = mid + f * (-s[1] * 1.44) + r * (s[2] * 1.44) -- 2026-11-07 전체 20% 축소(1.8 → 1.44)
	end
	return out
end

-- 별마다 레이저가 닿을 바닥 한 점: 국자 7칸(ThreatTiles)의 자리를 별자리와 같은 순서(앞 → 뒤, 옆)로 짝지었다. 7칸이 아니면 별자리를 바닥에 그대로 내린다
local function dipperGround(ctx: any, stars: { Vector3 }): { Vector3 }
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local function rank(p: Vector3): number
		return p:Dot(f) * 1000 + p:Dot(r)
	end
	local cells = reach(ctx, "Dipper")
	local out = {}
	if #cells == 7 then
		table.sort(cells, function(a, b)
			return rank(a) < rank(b)
		end)
		local order = {}
		for i = 1, 7 do
			order[i] = i
		end
		table.sort(order, function(a, b)
			return rank(stars[a]) < rank(stars[b])
		end)
		for k, i in order do
			out[i] = Vector3.new(cells[k].X, ctx.Ground + 0.2, cells[k].Z)
		end
	else
		for i, p in stars do
			out[i] = Vector3.new(p.X, ctx.Ground + 0.2, p.Z)
		end
	end
	return out
end

-- 별자리(별 일곱 + 착점 일곱)가 한 화면에 들어오는 카메라 자리: 25° 내려다보는 방향으로 물러나며 세로 FOV 70 의 80%·가로(1.5:1) 안에 전부 들어올 때까지 거리를 늘린다.
-- 별자리는 화면 위쪽, 판(착점)은 아래쪽에 놓인다
local function dipperFrame(ctx: any, stars: { Vector3 }, ground: { Vector3 }): (Vector3, Vector3)
	local pts = {}
	for _, p in stars do
		table.insert(pts, p + Vector3.new(0, 2, 0)) -- 별 반지름 몫
		table.insert(pts, p - Vector3.new(0, 1.5, 0))
	end
	for _, p in ground do
		table.insert(pts, p)
	end
	local lo, hi = pts[1], pts[1]
	for _, p in pts do
		lo, hi = lo:Min(p), hi:Max(p)
	end
	local aim = (lo + hi) / 2
	local pitch = math.rad(25)
	local dir = ctx.Forward * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	local ty = math.tan(math.rad(35)) * 0.8
	local tx = ty * 1.5
	local eye = aim + dir * 120
	for dist = 20, 120 do
		local e = aim + dir * dist
		local cf = CFrame.lookAt(e, aim)
		local ok = true
		for _, p in pts do
			local lp = cf:PointToObjectSpace(p)
			local depth = -lp.Z
			if depth < 1 or math.abs(lp.X) / depth > tx or math.abs(lp.Y) / depth > ty then
				ok = false
				break
			end
		end
		if ok then
			eye = e
			break
		end
	end
	return eye, aim
end

-- 북두칠성 1: 카메라가 먼저 별자리와 판이 함께 보이는 하늘 자리로 옮겨 가고 → 별가루 입자가 별자리 모양으로 모였다가 → 별이 차례로 터지듯 커지고 → 떨린다
function Fx.Dipper(ctx: any)
	local Vfx = ctx.Vfx
	local s = dstate(ctx)
	local stars = dipperStars(ctx)
	s.Stars, s.Ground, s.Fired, s.Slammed, s.Gather = stars, dipperGround(ctx, stars), {}, false, false
	local t0 = os.clock()
	local function birthOf(i: number): number -- Dipper 사건 기준 상대 시각
		return DIPPER_BIRTH_T + DIPPER_BIRTH_STEP * (i - 1) - DIPPER_T0
	end
	-- 별가루: 별 자리마다 4알 + 이을 선마다 5알이 흩어진 자리에서 별자리 모양으로 모여든다(별이 태어나면 그 별 알은 사라진다) — 총 63알
	local motes = {}
	local rng = Random.new(7)
	local function addMote(target: Vector3, dieAt: number, i: number, col: Color3)
		local part = Vfx.Part(Vector3.one * 0.28, CFrame.new(target), col)
		part.Shape = Enum.PartType.Ball
		part.Transparency = 1
		local off = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(6, 13)
		table.insert(motes, { Part = part, To = target, Off = off, Die = dieAt, Delay = rng:NextNumber(0, 0.25), Ph = i + rng:NextNumber(0, 6) })
	end
	for i, p in stars do
		for _ = 1, 4 do
			addMote(p + Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3)), birthOf(i), i, DIPPER_STAR[i].Core)
		end
	end
	for li, link in DIPPER_LINKS do
		for k = 1, 5 do
			addMote(stars[link[1]]:Lerp(stars[link[2]], k / 6), birthOf(math.max(link[1], link[2])), li, DIPPER_STAR[link[1]].Col:Lerp(DIPPER_STAR[link[2]].Col, 0.5))
		end
	end
	Vfx.Timed(birthOf(7) + 0.3, function(_, _dt)
		local el = os.clock() - t0
		for _, m in motes do
			local u = math.clamp((el - 0.05 - m.Delay) / 0.7, 0, 1)
			m.Part.Position = m.To + m.Off * (1 - Common.expoOut(u)) + Vector3.new(0, math.sin(el * 6 + m.Ph) * 0.12, 0)
			local twinkle = 0.25 + 0.2 * math.sin(el * 14 + m.Ph)
			m.Part.Transparency = if el >= m.Die then 1 else math.max(0, 1 - u * 1.2) * 0.6 + twinkle * 0.4
		end
	end, function()
		for _, m in motes do
			m.Part:Destroy()
		end
	end)
	-- 별 탄생: 알카이드 → 두베 순서로 빠르게 연달아 터지며 커진다 (색 = 분광형, 크기 = 겉보기 밝기)
	for i, p in stars do
		local info = DIPPER_STAR[i]
		task.delay(birthOf(i), function()
			local glow = Vfx.Part(Vector3.one * 0.25, CFrame.new(p), info.Col)
			glow.Shape = Enum.PartType.Ball
			local core = Vfx.Part(Vector3.one * 0.16, CFrame.new(p), info.Core)
			core.Shape = Enum.PartType.Ball
			glow.Transparency, core.Transparency = 0.4, 0.05
			local gone, t = 0, 0
			Vfx.Timed(DIPPER_END - DIPPER_BIRTH_T + 0.6, function(_, dt)
				t += dt
				if s.Slammed then
					gone = math.min(1, gone + dt / 0.3)
				end
				local k = Common.expoOut(t / 0.4) * (1 - gone)
				local el = os.clock() - t0 + DIPPER_T0
				-- 떨림: 모두 커진 뒤(DIPPER_TREMBLE_T) 레이저 직전까지 진폭이 커지고, 이후엔 잔떨림 + 깜빡
				local tr = math.clamp((el - DIPPER_TREMBLE_T) / (DIPPER_LASER_T[1] - DIPPER_TREMBLE_T), 0, 1)
				local amp = if el < DIPPER_TREMBLE_T then 0 else 0.06 + 0.4 * tr
				local n = el * 40 + i * 7
				local at = p + Vector3.new(math.noise(n, 1.1), math.noise(2.2, n), math.noise(n, 3.3)) * amp
				glow.Position, core.Position = at, at
				local pulse = if s.Gather then 1.35 else 1 + 0.1 * math.sin(t * 9 + i)
				glow.Size = Vector3.one * (2.72 * info.Size * k * pulse + 0.01)
				core.Size = Vector3.one * (1.2 * info.Size * k * pulse + 0.01)
				if amp > 0 and not s.Gather then
					glow.Transparency = 0.4 + 0.25 * (math.noise(n, 8.8) * 0.5 + 0.5) * tr -- 깜빡
				end
			end, function()
				glow:Destroy()
				core:Destroy()
			end)
			-- 한번에 터져 나오는 별빛
			Vfx.Flash(p, { Color = FLASH, Size = 4 * info.Size, Life = 0.18, Brightness = 6 })
			Vfx.Pack("Loose/Sparkles", CFrame.new(p), { Color = info.Core, Size = 0.96 * info.Size })
			Vfx.Pack("Loose/Flare", CFrame.new(p), { Color = info.Core, Size = 0.8 * info.Size })
			Vfx.Pack("Anime/Stars-01", CFrame.new(p), { Color = info.Col, Size = 0.48 * info.Size })
			chargeFb(ctx, p, 4 * info.Size, info.Col)
			if i > 1 then
				Vfx.Beam(stars[i - 1], p, { Color = DIPPER_STAR[i - 1].Col:Lerp(info.Col, 0.5), Width = 0.24, Life = math.max(0.5, DIPPER_END - DIPPER_T0 - birthOf(i)) })
			end
		end)
	end
	-- 카메라 (a): 먼저 별자리와 판이 한 화면에 들어오는 자리(dipperFrame — 별자리 위쪽, 착점 아래쪽, 25° 내려다봄)로 옮겨 가 잡고(0.75초) 레이저가 끝날 때까지 머문다.
	-- 레이저 첫 세 발만 작게 앞으로 쿵(줌 펀치), 나머지 연사는 펀치 없이 쏟아진다
	local eyeTo, lookTo = dipperFrame(ctx, stars, s.Ground)
	s.frameEye, s.frameLook = eyeTo, lookTo
	local from = s.cam or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame) or CFrame.new()
	local look0 = from.Position + from.LookVector * 30
	ctx.Shot(DIPPER_GATHER_T - DIPPER_T0, function(_, tt)
		local u = Common.sine(tt / 0.75)
		local base = CFrame.lookAt(from.Position:Lerp(eyeTo, u), look0:Lerp(lookTo, u))
		local cf = base
		for i = DIPPER_PUNCH_N, 1, -1 do
			local since = tt - (DIPPER_LASER_T[i] - DIPPER_T0)
			if since >= 0 then
				cf += cf.LookVector * (0.4 * math.exp(-since * 14))
				break
			end
		end
		s.cam = base
		return cf
	end)
end

-- 별 하나가 레이저를 쏜다(ev.star = 별 번호 · nth = 몇 번째 · hold = 강타까지 남은 초): 별로 빛이 빨려 들고(AIM) → 두 겹 레이저가 바닥 한 점으로(GROW) →
-- 떨어진 자리에 충격 · 앞서 쏜 점과 선으로 이어진다. 첫 세 발은 레이저가 하늘에서 판으로 내려꽂히는 게 눈에 보이게 천천히 뻗고 오래 남고, 마지막 연사는 빠르게 쏟아진다.
-- 카메라는 레이저가 끝날 때까지 별자리와 판이 함께 보이는 자리에 머문다
local D_AIM = 0.03
local D_GROW = { 0.2, 0.15, 0.1, 0.05, 0.05, 0.05, 0.05 } -- 레이저가 별에서 바닥까지 뻗는 시간
local D_LIFE = { 0.5, 0.4, 0.3, 0.2, 0.2, 0.2, 0.2 } -- 다 뻗은 뒤 남는 시간
function Fx.DipperLaser(ctx: any, ev: any)
	local Vfx = ctx.Vfx
	local s = dstate(ctx)
	if not s.Stars then
		Fx.Dipper(ctx)
	end
	local i = (ev and ev.star) or 1
	local nth = (ev and ev.nth) or i
	local hold = (ev and ev.hold) or 1
	local top, g = s.Stars[i], s.Ground[i]
	local info = DIPPER_STAR[i]
	local grow = D_GROW[math.clamp(nth, 1, 7)]
	Vfx.Implode(top, { Color = info.Core, Radius = 3.2 * info.Size, Count = 4, Life = 0.08 })
	task.delay(D_AIM, function()
		Common.SeptLaser(ctx, function()
			return top
		end, g, 1.36, grow, D_LIFE[math.clamp(nth, 1, 7)], dipperPal(info))
		Vfx.Flash(top, { Color = FLASH, Size = 3.2 * info.Size, Life = 0.14, Brightness = 6 })
	end)
	task.delay(D_AIM + grow, function()
		impactFb(ctx, g + Vector3.new(0, 0.64, 0), 4, info.Col)
		Vfx.Pack("Loose/Sparkles", CFrame.new(g + Vector3.new(0, 0.8, 0)), { Color = info.Core, Size = 0.56 })
		for _, link in DIPPER_LINKS do
			local other = if link[2] == i then link[1] elseif link[1] == i then link[2] else nil
			if other and s.Fired[other] then
				local lift = Vector3.new(0, 0.1, 0)
				Vfx.Beam(s.Ground[other] + lift, g + lift, { Color = DIPPER_STAR[other].Col:Lerp(info.Col, 0.5), Width = 0.32, Life = math.max(0.4, hold - D_AIM - grow) })
			end
		end
		s.Fired[i] = true
	end)
end

-- 모으기: 별 일곱이 한꺼번에 조여 들며 커지고 망치에 빛이 모인다. 카메라는 레이저가 끝난 뒤(DIPPER_ORBIT_HOLD 만큼 더 머문 다음)에야 축을 놓고 돈다
function Fx.DipperGather(ctx: any)
	local Vfx = ctx.Vfx
	local s = dstate(ctx)
	local stars = s.Stars or dipperStars(ctx)
	s.Gather = true
	task.delay(DIPPER_ORBIT_HOLD, function() -- 별이 조여 드는 건 연사가 끝난 뒤
		for i, p in stars do
			Vfx.Implode(p, { Color = DIPPER_STAR[i].Col, Radius = 4.8 * DIPPER_STAR[i].Size, Count = 8, Life = 0.35 })
		end
	end)
	local head = ctx.Base and ctx.Base("W") or ctx.Hand("R")
	chargeFb(ctx, head, 4.8, DIPPER_MIX)
	-- 카메라 (b): 레이저가 끝난 뒤(DIPPER_ORBIT_HOLD 후) 축을 놓고 빙 돌며(orbit) 플레이어 기준 아군 칸 왼쪽 맨 위 끝으로 옮겨 간다(축 = 아군 칸 중심의 수직선, 0.7초). 그 뒤 우르릉 떨림이 점점 커진다.
	-- 플레이어 카메라는 -Forward 쪽(적)을 보므로 화면 왼쪽 = +R, 위(먼 쪽) = -Forward
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local cells = allyCells(ctx)
	local corner, best = cells[1], -math.huge
	for _, p in cells do
		local score = p:Dot(r) - p:Dot(f)
		if score > best then
			corner, best = p, score
		end
	end
	local mid = center(cells)
	local eye = corner + r * 5 - f * 3 + Vector3.new(0, 10, 0)
	local look = mid
	s.cornerEye, s.cornerLook = eye, look
	local from = s.cam or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame) or CFrame.new()
	local look0 = from.Position + from.LookVector * 30
	local d0, d1 = from.Position - mid, eye - mid
	local a0, a1 = math.atan2(d0.Z, d0.X), math.atan2(d1.Z, d1.X)
	local da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi -- 짧은 쪽 회전각
	local r0, r1 = Vector2.new(d0.X, d0.Z).Magnitude, Vector2.new(d1.X, d1.Z).Magnitude
	ctx.Shot(DIPPER_END - DIPPER_GATHER_T + 0.02, function(_, tt)
		local u = Common.sine(math.max(0, tt - DIPPER_ORBIT_HOLD) / DIPPER_ORBIT)
		local ang = a0 + da * u
		local rad = r0 + (r1 - r0) * u
		local pos = Vector3.new(mid.X + math.cos(ang) * rad, mid.Y + d0.Y + (d1.Y - d0.Y) * u, mid.Z + math.sin(ang) * rad)
		local base = CFrame.lookAt(pos, look0:Lerp(look, u))
		-- 쿠구구구구: 머무는 동안에도 이미 떨리고 강타 직전까지 진폭이 점점 커진다(진동수 높게)
		local k = math.clamp(tt / (DIPPER_END - DIPPER_GATHER_T), 0, 1)
		local amp = 0.03 + 0.65 * k * k
		local n = tt * 38
		local cf = base * CFrame.new(math.noise(n, 0.3) * amp, math.noise(0.7, n) * amp, 0) * CFrame.Angles(0, 0, math.noise(n, 9.1) * amp * 0.04)
		s.cam = base
		return cf
	end)
end

-- 북두칠성 2: 망치가 닿는 순간 국자 모양 전체를 한 번에 강타 — 하늘의 별 일곱이 터지며 범위 가운데로 큰 기둥 하나가 떨어지고 바닥 균열이 범위 모양으로 번지며,
-- 별자리 선(레이저 착점끼리 이은 선)이 판 위에 타올라 잠시 남는다
function Fx.DipperCrash(ctx: any)
	local Vfx = ctx.Vfx
	local s = dstate(ctx)
	local stars = s.Stars or dipperStars(ctx)
	local points = s.Ground or dipperGround(ctx, stars)
	s.Slammed = true
	smash(ctx, ctx.Tip("W") or ctx.Target, 1.6)
	local a = areaOf(ctx, points)
	local mid = a.Mid
	for i, p in stars do
		Vfx.Flash(p, { Color = FLASH, Size = 4 * DIPPER_STAR[i].Size, Life = 0.2, Brightness = 6 })
	end
	for _, link in DIPPER_LINKS do
		Common.SeptScar(points[link[1]] + Vector3.new(0, 0.05, 0), points[link[2]] + Vector3.new(0, 0.05, 0), { Core = FLASH, Glow = DIPPER_MIX }, 3.2)
	end
	Vfx.Pillar(mid, { Color = DIPPER_MIX, Life = 0.7, Height = 21, Width = math.clamp(a.Radius * 0.6, 4.8, 9.6) })
	Vfx.Pack("vfx pack/Explosion", CFrame.new(mid + Vector3.new(0, 0.6, 0)), { Color = STAR, Size = 0.48, Count = 0.5 })
	Vfx.Pack("Big/Big-Crack-01", CFrame.new(Vector3.new(mid.X, ctx.Ground + 0.15, mid.Z)), { Color = DIPPER_MIX, Size = math.max(0.4, a.Radius / 8) })
	boomFb(ctx, mid + Vector3.new(0, 1.4, 0), math.max(11, a.Radius * 2), DIPPER_MIX)
	impactFb(ctx, mid + Vector3.new(0, 0.9, 0), 6.4, STAR_CORE)
	Common.FullBoard(ctx, areaOf(ctx, allyCells(ctx)), DIPPER_MIX, { Core = STAR_CORE, Shake = 1.6 }) -- 판 전체(별자리 모양 a 는 기둥 · 균열 크기용)
	Vfx.Ring(CFrame.new(mid + Vector3.new(0, 0.2, 0)), { R0 = 2, R1 = a.Radius + 5, Color = STAR_CORE, Life = 0.8, Width = 0.4, Height = 0.08 })
	task.delay(0.1, function()
		Vfx.Pack("Loose/Shockwave", CFrame.new(mid + Vector3.new(0, 0.6, 0)), { Color = DIPPER_MIX, Size = 0.9 })
		waveFb(ctx, mid + Vector3.new(0, 0.4, 0), 32, STAR_CORE, 0.7)
	end)
	-- 강타 카메라 (c): 한 번에 쾅 — 앞으로 쿵 밀리며 크게 흔들렸다가(짧고 묵직하게 가라앉음) 범위 쪽으로 천천히 다가가며 머문 뒤 전투 카메라로 돌아온다
	local eye = s.cornerEye or (s.cam and s.cam.Position) or mid
	local look = s.cornerLook or center(points)
	local base = CFrame.lookAt(eye, look)
	ctx.Shot(1.3, function(_, tt)
		local into = base.Position:Lerp(look, 0.12 * Common.sine(tt / 1.3))
		local amp = 1.6 * math.exp(-tt * 5.5)
		local n = tt * 45
		local cf = CFrame.lookAt(into, look)
			* CFrame.new(math.noise(n, 0.3) * amp, math.noise(0.7, n) * amp, 0)
			* CFrame.Angles(0, 0, math.noise(n, 9.1) * amp * 0.05)
		cf += cf.LookVector * (3 * math.exp(-tt * 14))
		s.cam = cf
		return cf
	end)
	s.Stars, s.Fired = nil, nil -- 다음 시전을 위해 비운다
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
	Vfx.Ring(CFrame.new(at), { R0 = 0.4, R1 = 3.2 * k, Color = STAR, Life = 0.45, Width = 0.18, Height = 0.05 })
	Vfx.Pack("Loose/Flare", CFrame.new(at), { Color = STAR_CORE, Size = 0.45 * k })
	Vfx.Sparks(at, { Color = STAR_CORE, Count = 8, Speed = 10 })
end

-- 빛 칸에 가는 빛기둥(대기 동안 낮게 맥동) · 붉은 칸에 금 간 균열 — 턴 B 위험 표시를 월드에도 건다
function Fx.KenosCast(ctx: any)
	local Vfx = ctx.Vfx
	local safe, dark = kenosSplit(ctx)
	if #safe > 0 then -- 빛 칸 묶음 전체에 낮은 빛의 장막 하나, 대기 동안 맥동
		local a = areaOf(ctx, safe)
		curtain(ctx, areaAt(a, a.U0, a.V0), areaAt(a, a.U0, a.V1), STAR_CORE, 3, 6)
		curtain(ctx, areaAt(a, a.U1, a.V0), areaAt(a, a.U1, a.V1), STAR_CORE, 3, 6)
		outline(ctx, a, STAR_CORE, 6)
		chargeFb(ctx, a.Mid + Vector3.new(0, 1, 0), 4, STAR_CORE)
		for k = 1, 4 do
			task.delay(0.6 * k, function()
				Vfx.Flash(a.Mid + Vector3.new(0, 0.5, 0), { Color = STAR_CORE, Size = 4, Life = 0.3, Brightness = 3 })
			end)
		end
	end
	if #dark > 0 then -- 붉은 칸 묶음 위로 금 간 균열이 한 번에 번진다
		local a = areaOf(ctx, dark)
		local ground = Vector3.new(a.Mid.X, ctx.Ground + 0.12, a.Mid.Z)
		Vfx.Pack("Anime/Crack-01", CFrame.new(ground), { Color = CRACK, Size = math.max(1.5, a.Radius / 6) })
		Vfx.Ring(CFrame.new(ground), { R0 = 0.4, R1 = a.Radius, Color = CRACK, Life = 0.7, Width = 0.2, Height = 0.05 })
		outline(ctx, a, CRACK, 0.9)
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
	chargeFb(ctx, from, 5, STAR_CORE)
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
	boltFb(ctx, gnd + Vector3.new(0, 3, 0), 10 * k, NEBULA)
	Vfx.Pack("Big/Explosion-01", CFrame.new(gnd + Vector3.new(0, 1, 0)), { Color = GOLDEN_STAR, Size = 0.45 * k, Count = 0.35 })
	-- 붉은 칸 묶음: 착지점에서 범위 끝까지 퍼지는 큰 균열 고리 하나와 외곽선(칸마다 찍지 않는다)
	if #dark > 0 then
		local a = areaOf(ctx, dark)
		local ground = Vector3.new(a.Mid.X, ctx.Ground + 0.15, a.Mid.Z)
		Vfx.Ring(CFrame.new(ground), { R0 = 0.6, R1 = a.Radius + 3, Color = CRACK, Life = 0.5, Width = 0.35, Height = 0.07 })
		boomFb(ctx, a.Mid + Vector3.new(0, 0.8, 0), 8 * k, CRACK)
		Vfx.Pack("Anime/Crack-01", CFrame.new(ground), { Color = CRACK, Size = math.max(1.4, a.Radius / 6) * k })
		Common.FullBoard(ctx, a, CRACK, { Core = STAR_CORE, Shake = 1.2 * k }) -- 붉은 칸 전체가 가장자리까지 한꺼번에
	end
	if #safe > 0 then -- 빛 칸 묶음은 장막 하나
		local a = areaOf(ctx, safe)
		curtain(ctx, areaAt(a, a.U0, a.V0), areaAt(a, a.U0, a.V1), STAR_CORE, 9, 0.45)
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
	Vfx.Pack("Anime/Crack-01", CFrame.new(ground), { Color = STAR, Size = 1.8 })
	Vfx.Pack("Loose/Shockwave", CFrame.new(ground + Vector3.new(0, 0.5, 0)), { Color = STAR_CORE, Size = 0.7 })
	impactFb(ctx, ground + Vector3.new(0, 1, 0), 7, STAR_CORE)
	waveFb(ctx, ground + Vector3.new(0, 0.3, 0), 18, STAR, 0.6)
	shatterFb(ctx, ground + Vector3.new(0, 1.5, 0), 10, DEEP)
end

return Fx
