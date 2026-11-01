--!strict
--[[
	Fx/Callisto — 히든 보스 칼리스토 이펙트(2026-10-31). 색은 별빛 둘: 차가운 푸른 별빛(칼날·별) + 카메라 플래시 흰빛.
	자리: ctx.Root = 칼리스토, ctx.Target = 맞는 아군, ctx.Tip("W") = 칼날 끝, ctx.Tip("O") = 카메라 렌즈.
	아군 칸 전부를 덮는 기술(렌즈·칼춤·장판)은 ctx.AllyTiles(전투 화면이 넘겨준다 — 없으면 대상 둘레를 어림).
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
end

-- 의수 칼날: 손 속에서 미끄러져 나옴(날을 따라 별빛 한 줄기) · 다시 들어감
function Fx.BladeOut(ctx: any)
	local model = ctx.Actor and ctx.Actor.Model
	if model then
		CallistoBody.Blade(model, true, 0.28)
	end
	local tip, base = ctx.Tip("W"), ctx.Base and ctx.Base("W")
	if tip then
		ctx.Vfx.Flash(tip, { Color = STAR_CORE, Size = 1.6, Life = 0.25, Brightness = 5 })
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
		Vfx.Flash(at, { Color = STAR_CORE, Size = 6, Life = 0.35, Brightness = 7 })
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
	ctx.Vfx.Flash(ctx.Root.Position + Vector3.new(0, 1, 0), { Color = STAR_CORE, Size = 8, Life = 0.6, Brightness = 5 })
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
	Vfx.Flash(p + Vector3.new(0, 1, 0), { Color = STAR_CORE, Size = 10, Life = 0.5, Brightness = 8 })
	for i = 0, 2 do
		task.delay(0.12 * i, function()
			Vfx.Ring(CFrame.new(Vector3.new(p.X, ctx.Ground + 0.15, p.Z)), { R0 = 1, R1 = 9 + i * 3, Color = if i == 1 then GOLDEN_STAR else STAR, Life = 0.7, Width = 0.3, Height = 0.06 })
		end)
	end
	Vfx.Burst(p + Vector3.new(0, 1.5, 0), { Count = 24, Colors = { STAR, STAR_CORE }, Size = 0.35, Speed = 20, Life = 0.9, Gravity = -6, Material = Enum.Material.Neon })
end

--=== 2페이즈 성위 품은 자 — 북두칠성 망치 ===--

local GOLDEN = c(255, 214, 130)

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

-- 망치 머리가 닿은 자리: 금빛 충격 고리 + 별 파편
local function smash(ctx: any, at: Vector3, size: number)
	local ground = Vector3.new(at.X, ctx.Ground + 0.15, at.Z)
	ctx.Vfx.Ring(CFrame.new(ground), { R0 = 0.6, R1 = 4 * size, Color = GOLDEN, Life = 0.4, Width = 0.3, Height = 0.08 })
	ctx.Vfx.Flash(at, { Color = STAR_CORE, Size = 5 * size, Life = 0.2, Brightness = 6 })
	ctx.Vfx.Burst(ground + Vector3.new(0, 0.3, 0), { Count = math.floor(10 * size), Colors = { STAR, STAR_CORE, GOLDEN }, Size = 0.4, Speed = 18, Life = 0.55, Gravity = 40, Material = Enum.Material.Neon })
end

-- 평타: 대상 앞에 내려찍기
function Fx.HammerSmash(ctx: any)
	smash(ctx, ctx.Tip("W") or ctx.Target, 1)
end

-- 알리오스: 내려찍은 자리에서 아군 필드로 별빛 장판이 번진다(남는 장판은 전투 화면이 snapshot.Callisto.Aliot 로 그린다)
function Fx.AliothField(ctx: any)
	local Vfx = ctx.Vfx
	smash(ctx, ctx.Tip("W") or (ctx.Root.Position + ctx.Forward * 3), 1.2)
	local cells = allyCells(ctx)
	local mid = center(cells)
	Vfx.Ring(CFrame.new(mid + Vector3.new(0, 0.2, 0)), { R0 = 2, R1 = 20, Color = GOLDEN, Life = 0.8, Width = 0.35, Height = 0.06 })
	for i, p in cells do
		task.delay(0.03 * i, function()
			Vfx.Flash(p + Vector3.new(0, 0.4, 0), { Color = if i % 2 == 0 then GOLDEN else STAR, Size = 3, Life = 0.5, Brightness = 2 })
		end)
	end
end

-- 메그레즈: 가로 후려치기 원호 + 별 파편
function Fx.MegrezSwing(ctx: any)
	Common.Arc(ctx, ctx.Target - ctx.Forward * 1.5, 88, 120, -100, { Radius = 4.2, Color = GOLDEN, Core = STAR_CORE, Life = 0.32, Width = 0.9 })
	smash(ctx, ctx.Target, 0.8)
end

-- 소환: 하늘에서 작은 별 하나가 적 진영으로 떨어진다(그 자리에 알코르가 선다)
function Fx.SummonStar(ctx: any)
	local Vfx = ctx.Vfx
	local tiles = ctx.EnemyTiles or {}
	local land = if #tiles > 0 then tiles[math.random(1, #tiles)].Position + Vector3.new(0, 2.6, 0) else ctx.Root.Position + ctx.Forward * -4
	local from = land + Vector3.new(0, 22, 0)
	star(ctx, ctx.Tip("W") or ctx.Root.Position, 3, 0.4, STAR_CORE)
	Vfx.Projectile(from, land, { Time = 0.45, Color = STAR_CORE, TrailColor = STAR })
	task.delay(0.45, function()
		Vfx.Flash(land, { Color = STAR_CORE, Size = 6, Life = 0.4, Brightness = 6 })
		Vfx.Ring(CFrame.new(land - Vector3.new(0, 2.4, 0)), { R0 = 0.5, R1 = 4, Color = STAR, Life = 0.5, Width = 0.2, Height = 0.05 })
	end)
end

-- 페크다: 대상이 선 열을 따라 위에서 별빛 기둥이 차례로 내리꽂힌다
function Fx.PhecdaColumn(ctx: any)
	local Vfx = ctx.Vfx
	smash(ctx, ctx.Tip("W") or ctx.Target, 1.3)
	for i, p in lineCells(ctx, "Column") do
		task.delay(0.05 * i, function()
			Vfx.Projectile(p + Vector3.new(0, 16, 0), p + Vector3.new(0, 0.4, 0), { Time = 0.1, Color = STAR_CORE, TrailColor = STAR })
			Vfx.Pillar(p, { Color = STAR, Life = 0.5, Height = 8, Width = 2.2 })
		end)
	end
end

-- 메라크: 휘두른 자리에서 대상이 선 행을 따라 금빛 충격파가 끝까지 달린다
function Fx.MerakRow(ctx: any)
	local Vfx = ctx.Vfx
	local cells = lineCells(ctx, "Row")
	local mid = center(cells)
	local from = ctx.Tip("W") or ctx.Root.Position
	Vfx.Beam(from, mid + Vector3.new(0, 0.6, 0), { Color = GOLDEN, Width = 1.6, Life = 0.4 })
	for i, p in cells do
		task.delay(0.04 * i, function()
			Vfx.Shockwave(p + Vector3.new(0, 0.2, 0), { Color = GOLDEN, Radius = 3.5, Life = 0.35 })
			Vfx.Burst(p + Vector3.new(0, 0.4, 0), { Count = 5, Colors = { GOLDEN, STAR_CORE }, Size = 0.35, Speed = 14, Life = 0.45, Material = Enum.Material.Neon })
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

-- 북두칠성 1: 하늘에 별 일곱이 차례로 켜지고 선으로 이어진다
function Fx.Dipper(ctx: any)
	local Vfx = ctx.Vfx
	local stars = dipperStars(ctx)
	for i, p in stars do
		task.delay(0.12 * i, function()
			Vfx.Flash(p, { Color = STAR_CORE, Size = 4, Life = 1.4, Brightness = 5 })
			if i > 1 then
				Vfx.Beam(stars[i - 1], p, { Color = STAR, Width = 0.25, Life = 1.2 })
			end
		end)
	end
end

-- 북두칠성 2: 망치가 닿는 순간 별이 아군 칸 전부로 쏟아진다
function Fx.DipperCrash(ctx: any)
	local Vfx = ctx.Vfx
	local stars = dipperStars(ctx)
	smash(ctx, ctx.Tip("W") or ctx.Target, 1.6)
	for i, p in allyCells(ctx) do
		local from = stars[(i - 1) % #stars + 1]
		task.delay(0.02 * i, function()
			Vfx.Projectile(from, p + Vector3.new(0, 0.4, 0), { Time = 0.14, Color = STAR_CORE, TrailColor = STAR })
			task.delay(0.14, function()
				Vfx.Pillar(p, { Color = if i % 3 == 0 then GOLDEN else STAR, Life = 0.55, Height = 7, Width = 2.2 })
			end)
		end)
	end
	local mid = center(allyCells(ctx))
	task.delay(0.3, function()
		Vfx.Ring(CFrame.new(mid + Vector3.new(0, 0.2, 0)), { R0 = 2, R1 = 24, Color = STAR_CORE, Life = 0.7, Width = 0.5, Height = 0.08 })
	end)
end

return Fx
