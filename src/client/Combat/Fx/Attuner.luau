--!strict
--[[
	Fx/Attuner — 조율자 이펙트. 별빛(푸른빛·흰빛)·융해(분홍)·핵융합(눈부신 흰 청). (2026-10-25, 2026-10-31 사용자 말로 스킬 넷 다시)
	별 대형 바꾸기는 무기(CombatWeapons:SetOrbMode — Orbit·Pick·Sky·Gather·Shield·Crown)가 하고, 별 하나를 이펙트가 직접 날릴 땐
	ctx.Weapons:Drive(i, fn) — fn(dt) 이 돌려주는 월드 자리로 별이 간다(nil 을 돌려주면 대형 자리로 돌아간다).
	ctx.Star(i) = 떠 있는 별 i 의 자리(1 메그레즈 · 2 메라크 · 3 알리오스 · 4 알카이드 · 5 미자르 · 6 페크다 · 7 두베),
	ctx.EnemyCenter = 적 진영 가운데.

	2026-10-31 사용자: "전체적인 느낌은 염동력으로 움직인다는 느낌. 별을 하나 꺼낸 후에 다른 별들은 비활성화 되면서 오른쪽 아래(허리춤 쯤)로
	빠지도록" — 스킬마다 Orbs Pick(star = i)로 그 별을 손끝에 꺼내고(나머지는 흐려져 허리춤으로), 손짓에 맞춰 별을 날린다.
	  메그레즈       팔을 왼쪽으로 가져갔다 오른쪽으로 확 — 별이 대상 열 끝으로 날아가 열을 가로질러 훑고 돌아온다(MegrezFling) · 맞은 적 StarHit
	  메라크         별을 왼쪽 아래로 옮겼다가 팔을 오른쪽 위로 휘두르면 별이 내 행을 꿰뚫고 달리며 흰 선을 남기고(MerakDash · 1타 MerakPass),
	                 그 선이 네 번 부분부분 터지고 다섯 번째에 통째로 터진다(MerakBurst — 비율 10 · 2 · 2 · 2 · 2 · 4)
	  알리오스       별을 적 진영 위로 띄우고(AliothLaunch) 허공에 팔을 휘두를 때마다 별이 진형을 곧게 가로지른다(AliothStrike 10타,
	                 0.5 · 0.45 · 0.2 · 0.15 … 초 간격으로 빨라짐 — 사용자 원안의 두 배 빠르기) → 손으로 돌아온다(AliothReturn)
	  셉텐트리오네스 컷신 — 왼 허리로 손을 모았다 치켜들면 별 일곱이 하늘 높이 오르고 카메라가 따라간다(SeptRise) → 별이 하나씩 적 진영으로
	                 레이저(SeptLaser — 별 이름이 화면 가운데, 매번 다른 화면 색, 카메라는 별을 보다 레이저 끝을 따라 아래로) → 일곱 발이 떨어진 자리
	                 (북두칠성 꼴)가 이어지며 진형 전체를 강타(SeptSlam — 화면 효과 · 가운데 "SEPTENTRIONES" · 별을 잇는 선 자국이 남는다)
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Common = require(script.Parent.Common)
local CombatVfx = require(script.Parent.Parent.CombatVfx)
local WeaponDefinitions = require(ReplicatedStorage.Shared.Combat.WeaponDefinitions)
local c = Common.c

local GOLD = c(255, 226, 140)
local WHITE = c(255, 250, 235)
local PALE = c(190, 214, 255)
local STAR = c(110, 180, 255) -- 별빛(파랑) — 무기 빛무리와 같은 결
local MELT = c(255, 90, 170)
local FUSION = c(220, 245, 255)

-- 북두칠성 꼴(무기 Orbit.Points — 별자리 가운데 기준 위 y · 뒤 z)과 별자리 선
local ORBIT = (WeaponDefinitions.Get("SevenStars") :: any).Orbit
local POINTS: { { number } } = ORBIT.Points
local LINES: { { number } } = ORBIT.Lines
local NAMES = {
	{ "MEGREZ", "메그레즈" },
	{ "MERAK", "메라크" },
	{ "ALIOTH", "알리오스" },
	{ "ALKAID", "알카이드" },
	{ "MIZAR", "미자르" },
	{ "PHECDA", "페크다" },
	{ "DUBHE", "두베" },
}

local Fx = {}

-- 배우마다 한 번의 시전 동안 쓰는 기억(남은 선 · 레이저 자리 · 카메라 자리)
local states: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local function st(ctx: any): any
	local s = states[ctx.Actor]
	if not s then
		s = {}
		states[ctx.Actor] = s
	end
	return s
end

local function sine(x: number): number
	return -(math.cos(math.pi * math.clamp(x, 0, 1)) - 1) / 2
end

-- 별자리 선(두 별 사이 빛줄)
local function line(ctx: any, a: Vector3, b: Vector3, color: Color3, width: number, life: number)
	ctx.Vfx.Beam(a, b, { Color = color, Width = width, Life = life })
end

-- 염동력: 손끝·별 둘레에 카메라를 보는 옅은 파문
local function ripple(ctx: any, at: Vector3, r: number?)
	local cam = workspace.CurrentCamera
	local face = if cam then CFrame.lookAt(at, cam.CFrame.Position) else CFrame.new(at)
	ctx.Vfx.Ring(face, { R0 = 0.1, R1 = r or 1.2, Color = PALE, Life = 0.3, Width = 0.06, Facing = true })
end

-- 별이 날아간 자리의 짧은 빛 꼬리(프레임마다 지난 자리 → 지금 자리)
local function streak(ctx: any, from: Vector3, to: Vector3, width: number?)
	if (to - from).Magnitude > 0.05 then
		ctx.Vfx.Beam(from, to, { Color = STAR, Width = width or 0.22, Life = 0.22 })
	end
end

-- 손끝(별을 받치는 자리)
local function fingertip(ctx: any): Vector3
	return ctx.Hand("R") + Vector3.new(0, 0.3, 0)
end

--[[
	별 i 를 이펙트가 직접 몬다: legs = { { 초, 끝 자리(Vector3 또는 그 자리를 돌려주는 함수) }, ... } 를 차례로(각 다리는 sineInOut),
	마지막 다리가 끝나면 놓는다(대형 자리로 — Pick 이면 손끝). 지나간 자리엔 빛 꼬리.
]]
local function fly(ctx: any, i: number, legs: { { any } }, width: number?)
	local weapons = ctx.Weapons
	if not weapons or not weapons.Drive then
		return
	end
	local function at(goal: any): Vector3
		return if typeof(goal) == "function" then goal() else goal
	end
	local from, last = ctx.Star(i), ctx.Star(i)
	local leg, t = 1, 0
	weapons:Drive(i, function(dt: number): Vector3?
		t += dt
		while legs[leg] and t >= legs[leg][1] do
			t -= legs[leg][1]
			from = at(legs[leg][2])
			leg += 1
		end
		local cur = legs[leg]
		if not cur then
			return nil
		end
		local p = from:Lerp(at(cur[2]), sine(t / cur[1]))
		streak(ctx, last, p, width)
		last = p
		return p
	end)
end

-- 대상 열(대상과 앞 거리가 같은 적 칸들)을 옆으로 가로지르는 두 끝(바닥 위 h — 카메라에서 먼 쪽부터). 칸을 모르면 대상 둘레 ±6
local function columnEnds(ctx: any, at: Vector3, h: number): (Vector3, Vector3)
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local home = ctx.Actor.Home.Position
	local along = (at - home):Dot(f)
	local v0, v1 = math.huge, -math.huge
	for _, t in ctx.EnemyTiles or {} do
		local d = t.Position - home
		if math.abs(d:Dot(f) - along) < 2 then
			v0, v1 = math.min(v0, d:Dot(r)), math.max(v1, d:Dot(r))
		end
	end
	if v0 > v1 then
		local v = (at - home):Dot(r)
		v0, v1 = v - 6, v + 6
	end
	local base = Vector3.new(home.X, ctx.Ground + h, home.Z) + f * along
	return base + r * (v0 - 2.5), base + r * (v1 + 2.5)
end

-- 내 행(시전자 라인)의 적 진영 앞 끝 · 뒤 끝(바닥 위 h). 칸을 모르면 가장 먼 대상 너머까지
local function rowEnds(ctx: any, h: number): (Vector3, Vector3)
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local home = ctx.Actor.Home.Position
	local u0, u1 = math.huge, -math.huge
	for _, t in ctx.EnemyTiles or {} do
		local d = t.Position - home
		if math.abs(d:Dot(r)) < 2 then
			u0, u1 = math.min(u0, d:Dot(f)), math.max(u1, d:Dot(f))
		end
	end
	if u0 > u1 then
		u0, u1 = 6, 6
		for _, p in ctx.Targets do
			local d = (p - home):Dot(f)
			u0, u1 = math.min(u0, d), math.max(u1, d)
		end
	end
	local base = Vector3.new(home.X, ctx.Ground + h, home.Z)
	return base + f * (u0 - 3), base + f * (u1 + 3)
end

--[[
	남는 흰 선(메라크): grow 초에 a → b 로 자라 남아 있다가, Flare(점)로 그 자리가 번쩍 터지고 Burst 로 통째로 터진다.
	안전장치: 터지지 않으면 8초 뒤 저절로 터진다.
]]
local function glowLine(a: Vector3, b: Vector3, width: number, grow: number): any
	local len = math.max(0.05, (b - a).Magnitude)
	local look = CFrame.lookAt(a, b)
	local core = CombatVfx.Part(Vector3.new(width, width, 0.05), look, WHITE)
	local glow = CombatVfx.Part(Vector3.new(width * 2.6, width * 2.6, 0.05), look, STAR)
	glow.Transparency = 0.7
	local function set(l: number, w: number)
		local cf = look * CFrame.new(0, 0, -l / 2)
		core.Size, core.CFrame = Vector3.new(w, w, l), cf
		glow.Size, glow.CFrame = Vector3.new(w * 2.6, w * 2.6, l), cf
	end
	local obj = { A = a, B = b, Gone = false }
	CombatVfx.Timed(grow, function(t)
		if not obj.Gone then
			set(math.max(0.05, len * t), width)
		end
	end)
	function obj.Flare(p: Vector3)
		if obj.Gone then
			return
		end
		CombatVfx.Flash(p, { Color = WHITE, Size = 3.5, Life = 0.2, Brightness = 6 })
		CombatVfx.Burst(p, { Count = 6, Colors = { STAR, WHITE }, Size = 0.18, Speed = 10, Gravity = 6, Life = 0.4 })
		CombatVfx.Timed(0.18, function(t)
			if not obj.Gone then
				set(len, width * (1 + 1.6 * (1 - t)))
			end
		end)
	end
	function obj.Burst()
		if obj.Gone then
			return
		end
		obj.Gone = true
		CombatVfx.Timed(0.4, function(t)
			set(len, width * (1 + 6 * t))
			core.Transparency, glow.Transparency = t, 0.7 + 0.3 * t
		end, function()
			core:Destroy()
			glow:Destroy()
		end)
	end
	task.delay(8, obj.Burst)
	return obj
end

-- 화면 가운데 글(별 이름 · 셉텐트리오네스): 크게 번졌다 자리 잡고 dur 초 뒤 사라진다. 관전 화면(Quiet)엔 안 띄운다
local function caption(ctx: any, big: string, small: string?, dur: number)
	if ctx.Quiet then
		return
	end
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "AttunerCaption"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.42)
	holder.Size = UDim2.fromScale(0.7, 0.18)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local function label(text: string, y: number, h: number, font: Enum.Font): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.Font = font
		l.Text = text
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(240, 248, 255)
		l.TextStrokeColor3 = Color3.fromRGB(60, 130, 255)
		l.TextTransparency = 1
		l.TextStrokeTransparency = 1
		l.Parent = holder
		return l
	end
	local title = label(big, 0, 0.68, Enum.Font.Garamond)
	local sub = if small then label(small, 0.7, 0.26, Enum.Font.GothamMedium) else nil
	gui.Parent = playerGui
	CombatVfx.Timed(dur, function(t)
		local a = dur * t
		local shown = math.min(1, a / 0.12) * (1 - math.clamp((a - (dur - 0.3)) / 0.3, 0, 1))
		title.TextTransparency = 1 - shown
		title.TextStrokeTransparency = 1 - 0.65 * shown
		if sub then
			sub.TextTransparency = 1 - 0.85 * shown
		end
		scale.Scale = 1 + 0.3 * (1 - math.min(1, a / 0.25)) ^ 2
	end, function()
		gui:Destroy()
	end)
end

local function spaced(s: string): string
	return (s:gsub(".", "%0 "):sub(1, -2))
end

--[[
	화면 색: preset(Saturation · Contrast · Brightness · Tint)에서 dur 초에 걸쳐 원래대로. Lighting 의 ColorCorrectionEffect 하나를 돌려 쓰고
	새로 부르면 앞 것은 손을 뗀다. 관전 화면(Quiet)은 손대지 않는다.
]]
local gradeToken: any = nil
local function grade(ctx: any, p: { [string]: any }, dur: number)
	if ctx.Quiet then
		return
	end
	local cc = Lighting:FindFirstChild("AttunerGrade") :: ColorCorrectionEffect?
	if not cc then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "AttunerGrade"
		made.Parent = Lighting
		cc = made
	end
	local effect = cc :: ColorCorrectionEffect
	local token = {}
	gradeToken = token
	local tint = p.Tint or Color3.new(1, 1, 1)
	CombatVfx.Timed(dur, function(t)
		if gradeToken ~= token then
			return
		end
		local k = (1 - t) ^ 2
		effect.Saturation = (p.Saturation or 0) * k
		effect.Contrast = (p.Contrast or 0) * k
		effect.Brightness = (p.Brightness or 0) * k
		effect.TintColor = Color3.new(1, 1, 1):Lerp(tint, k)
	end, function()
		if gradeToken == token then
			effect:Destroy()
			gradeToken = nil
		end
	end)
end

-- 레이저마다 다른 화면 색(사용자: "매 레이저마다 흑백 또는 각종 색깔 연출")
local LASER_GRADE = {
	{ Saturation = -1, Contrast = 0.45 },
	{ Tint = c(255, 120, 150), Contrast = 0.3, Saturation = 0.2 },
	{ Tint = c(110, 165, 255), Contrast = 0.35 },
	{ Tint = c(255, 214, 120), Contrast = 0.25, Saturation = 0.25 },
	{ Tint = c(196, 130, 255), Contrast = 0.3 },
	{ Tint = c(120, 255, 220), Contrast = 0.3 },
	{ Saturation = -1, Contrast = 0.9, Brightness = 0.08 },
}

-- 버릇: 별이 국자를 따라 손잡이 끝(알카이드)부터 국자 입(두베)까지 차례로 푸르게 반짝인다(별은 손을 따라 움직이니 반짝일 때마다 자리를 다시 읽는다)
local TRACE = { 4, 5, 3, 1, 6, 2, 7 }
function Fx.StarTwinkle(ctx: any)
	for k, i in TRACE do
		task.delay((k - 1) * 0.09, function()
			local p = ctx.Star(i)
			ctx.Vfx.Flash(p, { Color = PALE, Size = 0.9, Life = 0.3, Brightness = 4 })
			ctx.Vfx.Sparks(p, { Color = WHITE, Count = 2, Speed = 2, Accel = Vector3.new(0, 1.5, 0) })
		end)
	end
end

function Fx.Touchdown(ctx: any)
	local feet = Common.Feet(ctx)
	ctx.Vfx.Ring(CFrame.new(feet + Vector3.new(0, 0.12, 0)), { R0 = 0.5, R1 = 4, Color = GOLD, Life = 0.5, Width = 0.18, Height = 0.05 })
	ctx.Vfx.Sparks(feet + Vector3.new(0, 0.3, 0), { Color = WHITE, Count = 10, Accel = Vector3.new(0, 4, 0) })
end

function Fx.StarShield(ctx: any)
	local front = ctx.Root.Position + ctx.Forward * 2.4 + Vector3.new(0, 0.6, 0)
	local cf = CFrame.lookAt(front, front + ctx.Forward)
	ctx.Vfx.Ring(cf, { R0 = 0.5, R1 = 2.6, Color = GOLD, Life = 0.5, Width = 0.22, Facing = true })
	ctx.Vfx.Ring(cf, { R0 = 0.3, R1 = 1.6, Color = WHITE, Life = 0.35, Width = 0.12, Facing = true })
end

function Fx.StarBlink(ctx: any)
	local at = ctx.Root.Position
	ctx.Vfx.Flash(at, { Color = GOLD, Size = 6, Life = 0.25, Brightness = 4 })
	ctx.Vfx.Burst(at, { Count = 10, Color = WHITE, Size = 0.18, Speed = 8, Gravity = 0, Life = 0.4 })
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), GOLD)
end

--=== 별 꺼내기(공통) ===--

-- 별 하나를 꺼내는 순간: 손끝과 그 별 둘레에 염동력 파문, 별이 번쩍(ev.star)
function Fx.TeleGrab(ctx: any, ev: any)
	local i = (ev and ev.star) or 1
	ripple(ctx, ctx.Hand("R"), 1)
	task.delay(0.08, function()
		local p = ctx.Star(i)
		ripple(ctx, p, 0.8)
		ctx.Vfx.Flash(p, { Color = STAR, Size = 1.6, Life = 0.25, Brightness = 4 })
	end)
end

function Fx.StarHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = STAR, Size = 5, Life = 0.25, Brightness = 4 })
	ctx.Vfx.Sparks(p, { Color = WHITE, Count = 12, Speed = 16 })
	ctx.Vfx.Burst(p, { Count = 5, Color = MELT, Size = 0.2, Speed = 9, Gravity = 10, Life = 0.45 })
end

--=== 메그레즈 ===--

-- 팔을 오른쪽으로 확: 별이 대상 열 끝으로 날아가(0.1) 열을 가로질러 훑고(0.18) 잠깐 머물다(0.22) 손끝으로 돌아온다(0.35)
function Fx.MegrezFling(ctx: any)
	local a, b = columnEnds(ctx, ctx.Target, 1.6)
	ripple(ctx, ctx.Hand("R"), 1.4)
	fly(ctx, 1, { { 0.1, a }, { 0.18, b }, { 0.22, b }, { 0.35, function()
		return fingertip(ctx)
	end } }, 0.3)
	task.delay(0.1, function()
		ctx.Vfx.Flash(a, { Color = STAR, Size = 3, Life = 0.2, Brightness = 5 })
	end)
	task.delay(0.28, function()
		line(ctx, a, b, STAR, 0.5, 0.4)
	end)
end

--=== 메라크 ===--

-- 팔을 오른쪽 위로 휘두르면: 별이 내 행 앞 끝으로(0.09) → 행을 꿰뚫고 뒤 끝까지(0.2, 흰 선이 따라 자란다) → 머물다(0.3) → 손끝으로(0.4)
function Fx.MerakDash(ctx: any)
	local s = st(ctx)
	local a, b = rowEnds(ctx, 1.4)
	s.merakDone = {}
	ripple(ctx, ctx.Hand("R"), 1.4)
	fly(ctx, 2, { { 0.09, a }, { 0.2, b }, { 0.3, b }, { 0.4, function()
		return fingertip(ctx)
	end } }, 0.32)
	task.delay(0.09, function()
		s.merakLine = glowLine(a, b, 0.1, 0.2)
	end)
end

-- 1타: 별이 지나가며 벤다
function Fx.MerakPass(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = WHITE, Size = 5, Life = 0.2, Brightness = 5 })
	ctx.Vfx.Sparks(p, { Color = STAR, Count = 12, Speed = 18 })
end

-- 2~5타: 남은 선 위 무작위 자리가 번쩍 터진다 · 6타(마지막): 선이 통째로 터진다. 대상이 여럿이어도 타격 하나에 한 번(타격 번호로 가린다)
function Fx.MerakBurst(ctx: any, ev: any, at: Vector3?)
	local s = st(ctx)
	local obj = s.merakLine
	local i = (ev and ev.i) or 0
	if obj and s.merakDone and not s.merakDone[i] then
		s.merakDone[i] = true
		if i >= 6 then
			obj.Burst()
			ctx.Vfx.Flash(obj.A:Lerp(obj.B, 0.5), { Color = WHITE, Size = 10, Life = 0.35, Brightness = 6 })
			for k = 0, 6 do
				ctx.Vfx.Burst(obj.A:Lerp(obj.B, k / 6), { Count = 5, Colors = { STAR, WHITE }, Size = 0.2, Speed = 10, Gravity = 6, Life = 0.5 })
			end
		else
			obj.Flare(obj.A:Lerp(obj.B, 0.1 + 0.8 * math.random()))
		end
	end
	if at then
		ctx.Vfx.Sparks(at, { Color = WHITE, Count = 5, Speed = 12 })
	end
end

--=== 알리오스 ===--

-- 별을 적 진영 위로 띄운다(0.15초) — 그 뒤 손짓마다 AliothStrike 가 새 길을 준다. 별의 길 = { From, To(자리 또는 함수), T, D, Last? }
-- (2026-10-31 사용자: "알리오스 속도를 전체적으로 두 배" — 별이 나는 시간도 모두 절반)
function Fx.AliothLaunch(ctx: any)
	local s = st(ctx)
	local weapons = ctx.Weapons
	if not weapons or not weapons.Drive then
		return
	end
	s.aliothDone = {}
	local last = ctx.Star(3)
	s.aliothPath = { From = last, To = ctx.EnemyCenter + Vector3.new(0, 4.5, 0), T = 0, D = 0.15 }
	ripple(ctx, ctx.Hand("R"), 1.4)
	weapons:Drive(3, function(dt: number): Vector3?
		local p = s.aliothPath
		if not p then
			return nil
		end
		p.T += dt
		if p.Last and p.T >= p.D then
			s.aliothPath = nil
			return nil
		end
		local goal = if typeof(p.To) == "function" then p.To() else p.To
		local pos = p.From:Lerp(goal, sine(p.T / p.D))
		streak(ctx, last, pos, 0.26)
		last = pos
		return pos
	end)
end

-- 손짓 한 번: 별이 지금 자리에서 진형 안 무작위 자리로 곧게 내리긋는다(처음 셋은 크고 느리게 · 뒤로 갈수록 짧고 빠르게)
function Fx.AliothStrike(ctx: any, ev: any, at: Vector3?)
	local s = st(ctx)
	local i = (ev and ev.i) or 0
	if s.aliothPath and s.aliothDone and not s.aliothDone[i] then
		s.aliothDone[i] = true
		local box = Common.FieldBox(ctx)
		local rng = Random.new()
		local to = Common.BoxWorld(box, Vector3.new(rng:NextNumber(box.U0 + 1, box.U1 - 1), rng:NextNumber(box.V0 + 1, box.V1 - 1), rng:NextNumber(0.8, 3.2)))
		local d = if i <= 3 then 0.11 else 0.06
		s.aliothPath = { From = ctx.Star(3), To = to, T = 0, D = d }
		task.delay(d, function()
			ctx.Vfx.Flash(to, { Color = STAR, Size = 3, Life = 0.2, Brightness = 5 })
		end)
	end
	if at then
		ctx.Vfx.Flash(at, { Color = WHITE, Size = 3, Life = 0.16, Brightness = 4 })
		ctx.Vfx.Sparks(at, { Color = STAR, Count = 6, Speed = 14 })
	end
end

function Fx.AliothReturn(ctx: any)
	local s = st(ctx)
	if s.aliothPath then
		s.aliothPath = { From = ctx.Star(3), To = function()
			return fingertip(ctx)
		end, T = 0, D = 0.2, Last = true }
	end
end

--=== 셉텐트리오네스(컷신) ===--

-- 일곱 별이 레이저로 떨어질 자리: 북두칠성 꼴을 적 진영 바닥에 펼친다(화면 가로 = 앞 F 로 −z, 화면 세로 = 카메라에서 먼 쪽 −R 로 y)
local function dipperGround(ctx: any): { Vector3 }
	local box = Common.FieldBox(ctx)
	local cu, cv = (box.U0 + box.U1) / 2, (box.V0 + box.V1) / 2
	local hu, hv = (box.U1 - box.U0) / 2 - 1.5, (box.V1 - box.V0) / 2 - 1.5
	local zmax, ymax = 0.01, 0.01
	for _, p in POINTS do
		zmax, ymax = math.max(zmax, math.abs(p[3])), math.max(ymax, math.abs(p[2]))
	end
	local out = {}
	for i, p in POINTS do
		out[i] = Common.BoxWorld(box, Vector3.new(cu - p[3] / zmax * hu, cv - p[2] / ymax * hv, 0.1))
	end
	return out
end

local function camNow(s: any): CFrame
	return s.cam or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame) or CFrame.new()
end

-- 치켜든 손을 따라 별 일곱이 하늘로(Orbs Sky): 별마다 번쩍 · 손끝 파문, 카메라가 오르는 별자리를 따라 올라간다(ev.d 초)
function Fx.SeptRise(ctx: any, ev: any)
	local s = st(ctx)
	s.cam = nil
	s.sept = { Points = dipperGround(ctx), Slammed = false }
	ripple(ctx, ctx.Hand("R"), 2)
	for i = 1, 7 do
		ctx.Vfx.Flash(ctx.Star(i), { Color = STAR, Size = 1.6, Life = 0.3, Brightness = 4 })
	end
	local d = (ev and ev.d) or 1
	local from = camNow(s)
	local r = ctx.Forward:Cross(Vector3.yAxis)
	local home = ctx.Actor.Home.Position
	ctx.Shot(d, function(_, t)
		local sum = Vector3.zero
		for i = 1, 7 do
			sum += ctx.Star(i)
		end
		local mid = sum / 7
		local k = sine(t / d)
		local pos = (home + r * 13 + Vector3.new(0, 2, 0)):Lerp(home:Lerp(mid, 0.45) + r * 16 + Vector3.new(0, 3, 0), k)
		local cf = from:Lerp(CFrame.lookAt(pos, mid), sine(t / 0.4))
		s.cam = cf
		return cf
	end)
end

--[[
	레이저 한 발(ev.star = 별 번호, ev.nth = 몇 번째): 그 별을 올려다보며 이름이 화면 가운데에 뜨고(0.25) → 레이저가 바닥 자리로 GROW 초에 뻗어
	내려가며 화면 색이 바뀌고 카메라가 레이저 끝을 따라 내려간다 → 떨어진 자리를 본다. 다음 레이저가 다시 별을 올려다본다.
]]
local AIM, GROW = 0.25, 0.22
local function laser(ctx: any, i: number, g: Vector3)
	local outer = CombatVfx.Part(Vector3.new(0.5, 0.5, 0.05), CFrame.new(g), STAR)
	local core = CombatVfx.Part(Vector3.new(0.18, 0.18, 0.05), CFrame.new(g), WHITE)
	local LIFE = 0.35
	CombatVfx.Timed(GROW + LIFE, function(t)
		local a = t * (GROW + LIFE)
		local top = ctx.Star(i)
		local head = top:Lerp(g, math.min(1, a / GROW))
		local len = math.max(0.05, (head - top).Magnitude)
		local dir = if len > 0.06 then head else top - Vector3.new(0, 0.1, 0)
		local cf = CFrame.lookAt(top, dir) * CFrame.new(0, 0, -len / 2)
		local fade = math.clamp((a - GROW) / LIFE, 0, 1)
		outer.Size, outer.CFrame = Vector3.new(0.05 + 0.6 * (1 - fade), 0.05 + 0.6 * (1 - fade), len), cf
		core.Size, core.CFrame = Vector3.new(0.02 + 0.22 * (1 - fade), 0.02 + 0.22 * (1 - fade), len), cf
		outer.Transparency, core.Transparency = 0.25 + 0.75 * fade, fade
	end, function()
		outer:Destroy()
		core:Destroy()
	end)
	task.delay(GROW, function()
		ctx.Vfx.Flash(g, { Color = WHITE, Size = 6, Life = 0.3, Brightness = 6 })
		ctx.Vfx.Shockwave(Vector3.new(g.X, ctx.Ground + 0.1, g.Z), { Color = STAR, Radius = 5, Life = 0.45 })
	end)
end

function Fx.SeptLaser(ctx: any, ev: any)
	local s = st(ctx)
	local sept = s.sept or { Points = dipperGround(ctx), Slammed = false }
	s.sept = sept
	local i, k = (ev and ev.star) or 1, (ev and ev.nth) or 1
	local g = sept.Points[i]
	local name = NAMES[i]
	caption(ctx, spaced(name[1]), name[2], 0.85)
	task.delay(AIM, function()
		laser(ctx, i, g)
		grade(ctx, LASER_GRADE[k] or LASER_GRADE[1], 0.7)
		ctx.Vfx.Flash(ctx.Star(i), { Color = WHITE, Size = 2.4, Life = 0.25, Brightness = 6 })
	end)
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local from = camNow(s)
	ctx.Shot(0.95, function(_, t)
		local top = ctx.Star(i)
		local below = top + r * 9 - f * 3 + Vector3.new(0, -5, 0)
		local desired
		if t < AIM then
			desired = CFrame.lookAt(below, top)
		else
			local a = sine((t - AIM) / 0.32)
			desired = CFrame.lookAt(below:Lerp(g + r * 11 - f * 3 + Vector3.new(0, 4, 0), a), top:Lerp(g, a))
		end
		local cf = from:Lerp(desired, sine(t / AIM))
		s.cam = cf
		return cf
	end)
end

-- 레이저가 떨어진 자리에 있던 적: 작은 번쩍
function Fx.SeptLaserHit(ctx: any, _ev: any, at: Vector3?)
	if at then
		ctx.Vfx.Flash(at, { Color = STAR, Size = 3.5, Life = 0.2, Brightness = 4 })
		ctx.Vfx.Sparks(at, { Color = WHITE, Count = 8, Speed = 16 })
	end
end

-- 별을 잇는 선이 진형 바닥을 가르며 타오르고(0.3) 자국으로 남았다가(3.5) 천천히 사라진다(1.2)
local function scar(a: Vector3, b: Vector3)
	local len = math.max(0.05, (b - a).Magnitude)
	local cf = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2)
	local core = CombatVfx.Part(Vector3.new(0.5, 0.06, len), cf, WHITE)
	local glow = CombatVfx.Part(Vector3.new(1.6, 0.05, len), cf, STAR)
	local TOTAL = 5
	CombatVfx.Timed(TOTAL, function(t)
		local a2 = t * TOTAL
		local blaze = 1 - math.min(1, a2 / 0.3)
		local fade = math.clamp((a2 - 3.8) / 1.2, 0, 1)
		core.Size = Vector3.new(0.22 + 0.9 * blaze, 0.06, len)
		glow.Size = Vector3.new(0.9 + 2.4 * blaze, 0.05, len)
		core.Transparency = 0.15 + 0.85 * fade
		glow.Transparency = 0.55 + 0.45 * fade - 0.4 * blaze
	end, function()
		core:Destroy()
		glow:Destroy()
	end)
end

-- 마지막: 일곱 자리가 북두칠성 꼴로 이어지며 진형 전체를 강타 — 흑백 임팩트 → 흰 번쩍 → 색이 돌아옴 · 가운데 SEPTENTRIONES · 선 자국이 남는다.
-- 카메라는 진형 위 넓은 구도로 옮겨(선 자국이 다 보이게) 모션이 끝날 때까지 머문다. 큰 연출은 한 번(맞은 적마다 불린다)
function Fx.SeptSlam(ctx: any, _ev: any, at: Vector3?)
	local s = st(ctx)
	local sept = s.sept
	if sept and not sept.Slammed then
		sept.Slammed = true
		local P = sept.Points
		caption(ctx, spaced("SEPTENTRIONES"), "셉텐트리오네스", 1.7)
		grade(ctx, { Saturation = -1, Contrast = 1.2, Brightness = 0.25 }, 0.9)
		for i = 1, 7 do
			ctx.Vfx.Pillar(P[i], { Height = 14, Width = 2.2, Color = STAR, Life = 0.5 })
			ctx.Vfx.Shockwave(P[i] + Vector3.new(0, 0.05, 0), { Color = WHITE, Radius = 7, Life = 0.6 })
		end
		for _, pair in LINES do
			scar(P[pair[1]], P[pair[2]])
		end
		local center = ctx.EnemyCenter
		ctx.Vfx.Flash(center + Vector3.new(0, 3, 0), { Color = FUSION, Size = 30, Life = 0.6, Brightness = 10 })
		local f = ctx.Forward
		local r = f:Cross(Vector3.yAxis)
		local from = camNow(s)
		local goal = CFrame.lookAt(center + r * 24 - f * 2 + Vector3.new(0, 22, 0), center)
		ctx.Shot(1.5, function(_, t)
			local cf = from:Lerp(goal, sine(t / 0.45))
			s.cam = cf
			return cf
		end)
	end
	if at then
		ctx.Vfx.Sparks(at, { Color = WHITE, Count = 16, Speed = 24 })
		ctx.Vfx.Burst(at, { Count = 6, Color = MELT, Size = 0.24, Speed = 12, Gravity = 16, Life = 0.6 })
	end
end

return Fx
