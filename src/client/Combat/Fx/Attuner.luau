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
	  셉텐트리오네스 컷신 — 왼 허리로 손을 모았다 치켜들면 별 일곱이 하늘 높이 올라 바닥과 나란히 눕고 카메라가 따라간다(SeptRise — 레터박스 ·
	                 밤하늘 화면 · 누운 성반, 레이저는 수직으로) → 별이 하나씩 적 진영으로 레이저(SeptLaser — 별 이름표, 매번 다른 화면 색, 카메라는 별을 보다 레이저 끝을 따라 아래로,
	                 떨어진 자리에 룬 · 하늘과 바닥에 별자리 선이 한 줄씩) → 모으기(SeptGather) → 일곱 빛줄기가 한꺼번에 내리꽂혀 진형 전체를 강타
	                 (SeptSlam — 화면 효과 · 제목 카드 "SEPTENTRIONES" · 별을 잇는 선 자국이 남는다)
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

-- 화면 위 GUI(제목 카드 · 레터박스) 바탕. 관전 화면(Quiet)이나 PlayerGui 가 없으면 nil
local function screen(ctx: any, name: string, order: number): ScreenGui?
	if ctx.Quiet then
		return nil
	end
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order
	gui.Parent = playerGui
	return gui
end

local function spaced(s: string): string
	return (s:gsub(".", "%0 "):sub(1, -2))
end

--[[
	제목 카드(별 이름 · SEPTENTRIONES) — 극장판 필살기 이름표처럼: 가로 빛줄이 화면을 왼쪽에서 긋고, 오른쪽에서 미끄러져 들어온 큰 이름이
	빨강 · 청록으로 갈라졌다가(색수차) 하나로 모인다. 위엔 작은 머리글(로마 숫자 등).
	opts: Top · Big · Dur(초) · Y(화면 세로 자리) · Height(화면 세로 비율). 아랫줄은 없앴다(2026-10-31 질문 답)
]]
local function titleCard(ctx: any, opts: { [string]: any })
	local gui = screen(ctx, "AttunerTitle", 61)
	if not gui then
		return
	end
	local dur, y = opts.Dur or 0.85, opts.Y or 0.4
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.8, opts.Height or 0.2)
	holder.Parent = gui
	local function label(text: string, top: number, h: number, font: Enum.Font, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.fromScale(0.5, top)
		l.Size = UDim2.fromScale(1, h)
		l.Font = font
		l.Text = text
		l.TextScaled = true
		l.TextColor3 = color
		l.TextTransparency = 1
		l.TextStrokeColor3 = Color3.fromRGB(40, 110, 255)
		l.TextStrokeTransparency = 1
		l.Parent = holder
		return l
	end
	local head = label(opts.Top or "", 0, 0.16, Enum.Font.GothamMedium, Color3.fromRGB(170, 205, 255))
	local red = label(opts.Big, 0.18, 0.56, Enum.Font.Garamond, Color3.fromRGB(255, 70, 110))
	local cyan = label(opts.Big, 0.18, 0.56, Enum.Font.Garamond, Color3.fromRGB(70, 230, 255))
	local main = label(opts.Big, 0.18, 0.56, Enum.Font.Garamond, Color3.fromRGB(245, 250, 255))
	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.fromScale(0, y)
	bar.Size = UDim2.fromScale(0, 0)
	bar.Parent = gui
	local fadeEnds = Instance.new("UIGradient")
	fadeEnds.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fadeEnds.Parent = bar
	CombatVfx.Timed(dur, function(t)
		local a = dur * t
		local come = 1 - (1 - math.min(1, a / 0.22)) ^ 4
		local leave = math.clamp((a - (dur - 0.25)) / 0.25, 0, 1)
		local shown = math.min(1, a / 0.1) * (1 - leave)
		holder.Position = UDim2.fromScale(0.5 + 0.07 * (1 - come) - 0.04 * leave, y)
		local split = 0.018 * (1 - come) + 0.003 * math.sin(a * 60) * (1 - 0.7 * come)
		red.Position = UDim2.fromScale(0.5 - split, 0.18)
		cyan.Position = UDim2.fromScale(0.5 + split, 0.18)
		main.TextTransparency = 1 - shown
		main.TextStrokeTransparency = 1 - 0.7 * shown
		red.TextTransparency = 1 - 0.55 * shown
		cyan.TextTransparency = 1 - 0.55 * shown
		head.TextTransparency = 1 - 0.85 * shown
		local sweep = math.min(1, a / 0.3)
		bar.Size = UDim2.new(sweep, 0, 0, 2 + 4 * (1 - sweep))
		bar.BackgroundTransparency = 0.1 + 0.9 * math.clamp((a - 0.3) / 0.35, 0, 1)
	end, function()
		gui:Destroy()
	end)
end

-- 레터박스: 위아래 검은 띠가 0.35초에 들어와 total 초 끝 0.4초에 걸쳐 빠진다(극장판 컷신 화면비)
local function letterbox(ctx: any, total: number)
	local gui = screen(ctx, "AttunerLetterbox", 59)
	if not gui then
		return
	end
	local bars = {}
	for _, edge in { 0, 1 } do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.AnchorPoint = Vector2.new(0, edge)
		bar.Position = UDim2.fromScale(0, edge)
		bar.Size = UDim2.fromScale(1, 0)
		bar.Parent = gui
		table.insert(bars, bar)
	end
	CombatVfx.Timed(total, function(t)
		local a = total * t
		local k = sine(a / 0.35) * (1 - sine((a - (total - 0.4)) / 0.4))
		for _, bar in bars do
			bar.Size = UDim2.fromScale(1, 0.11 * k)
		end
	end, function()
		gui:Destroy()
	end)
end

-- 밤하늘: 컷신 동안 화면을 푸르게 어둡게(AttunerNight — 레이저마다 바뀌는 화면 색 AttunerGrade 와 따로 겹친다)
local function night(ctx: any, total: number)
	if ctx.Quiet then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "AttunerNight"
	cc.Parent = Lighting
	CombatVfx.Timed(total, function(t)
		local a = total * t
		local k = sine(a / 0.6) * (1 - sine((a - (total - 0.6)) / 0.6))
		cc.Brightness = -0.24 * k
		cc.Contrast = 0.25 * k
		cc.Saturation = -0.45 * k
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(150, 175, 255), k)
	end, function()
		cc:Destroy()
	end)
end

--[[
	화면 색: Lighting 의 ColorCorrectionEffect(AttunerGrade) 하나를 돌려 쓴다. preset(Saturation · Contrast · Brightness · Tint)으로 확 들어갔다가
	0.35초에 걸쳐 hold 배로 가라앉아 머문다 — life 초가 지나면 0.4초에 걸쳐 사라지고, life 가 nil 이면 내 차례가 올 때(CombatVfx.MyTurn —
	BattleClient) 0.8초에 걸쳐 거둔다. 새 grade 가 오면 앞 것은 손을 뗀다. 관전 화면(Quiet)은 손대지 않는다.
	2026-10-31 사용자: "감마나 대비 이런거 마음대로 조절해도 되니까 … 막타에 제일 강하게 넣었다가 본인 턴 오면 다시 돌아오게"
]]
local gradeToken: any = nil
local function grade(ctx: any, p: { [string]: any }, hold: number, life: number?)
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
	local t = 0
	local endAt: number? = life
	local fade = if life then 0.4 else 0.8
	if not life then
		CombatVfx.UntilMyTurn(function()
			endAt = endAt or t
		end)
	end
	local tint = p.Tint or Color3.new(1, 1, 1)
	local function finish()
		if gradeToken == token then
			effect:Destroy()
			gradeToken = nil
		end
	end
	CombatVfx.Timed(if life then life + fade else 600, function(_, dt)
		if gradeToken ~= token then
			return
		end
		t += dt
		local k = hold + (1 - hold) * (1 - sine(t / 0.35))
		if endAt then
			local out = (t - endAt) / fade
			if out >= 1 then
				finish()
				return
			end
			k *= 1 - sine(out)
		end
		effect.Saturation = (p.Saturation or 0) * k
		effect.Contrast = (p.Contrast or 0) * k
		effect.Brightness = (p.Brightness or 0) * k
		effect.TintColor = Color3.new(1, 1, 1):Lerp(tint, k)
	end, finish)
end

-- 레이저마다 다른 화면 색(사용자: "매 레이저마다 흑백 또는 각종 색깔 연출") — 갈수록 세지고(대비 · 밝기 · 채도 마음대로),
-- 0.35초에 걸쳐 원래대로 돌아왔다가 다음 레이저에 다시 바뀐다(질문 2 답). 마지막 강타가 가장 세고(SLAM_FLASH → 붉은 SLAM_GRADE) 내 차례가 올 때까지 남는다
local LASER_GRADE = {
	{ Saturation = -1, Contrast = 0.55, Brightness = 0.04 },
	{ Tint = c(255, 120, 160), Contrast = 0.5, Saturation = 0.35, Brightness = -0.06 },
	{ Tint = c(110, 160, 255), Contrast = 0.6, Saturation = -0.25, Brightness = -0.1 },
	{ Tint = c(255, 205, 105), Contrast = 0.65, Saturation = 0.45, Brightness = 0.06 },
	{ Tint = c(190, 120, 255), Contrast = 0.75, Saturation = 0.25, Brightness = -0.12 },
	{ Tint = c(105, 255, 215), Contrast = 0.85, Saturation = -0.35, Brightness = 0.08 },
	{ Saturation = -1, Contrast = 1.1, Brightness = 0.14 },
}
local SLAM_FLASH = { Saturation = -1, Contrast = 1.6, Brightness = 0.35 }
local SLAM_GRADE = { Tint = c(255, 110, 100), Contrast = 1.05, Saturation = 0.5, Brightness = 0.06 }

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
--[[
	2026-10-31 사용자: "전체적으로 셉텐트리오네스의 이팩트가 심심해. 이미지 레퍼런스랑 글자 레퍼런스 등등 여러개 참고해서 화려하게" →
	극장판 필살기 컷신의 문법을 빌렸다 — 레터박스 · 푸르게 어두운 밤하늘 화면 · 별자리 뒤에 도는 성반(아스트롤라베) · 별마다 이름표
	(로마 숫자 머리글 · 색수차로 갈라졌다 모이는 큰 이름 · 바이어 이름) · 별이 떨어질 때마다 하늘(별 사이)과 바닥(떨어진 자리 사이)에
	별자리 선이 한 줄씩 그어지고 떨어진 자리엔 룬이 돈다 → 강타 직전 모으기(SeptGather) → 일곱 빛줄기가 한꺼번에 내리꽂혀 선 자국이 타오른다.
]]

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

local function septOf(ctx: any): any
	local s = st(ctx)
	s.sept = s.sept or { Points = dipperGround(ctx), Slammed = false, Fired = {}, Pulse = 0 }
	return s.sept
end

--[[
	강타 때까지 남는 것(성반 · 룬 · 별자리 선): update(지난 초, 모으기 0~1, 거두기 0~1, dt) 를 매 프레임 부른다.
	sept.Gather 면 모으기가 0.3초에 1 로, 강타하면(sept.Slammed) 거두기가 0.35초에 1 로. 안전장치로 12초 뒤 지운다.
]]
local function held(sept: any, parts: { BasePart }, update: (number, number, number, number) -> ())
	local t, gk = 0, 0
	local slamAt: number? = nil
	CombatVfx.Timed(12, function(_, dt)
		t += dt
		if sept.Gather then
			gk = math.min(1, gk + dt / 0.3)
		end
		if sept.Slammed and not slamAt then
			slamAt = t
		end
		update(t, gk, if slamAt then math.min(1, (t - slamAt) / 0.35) else 0, dt)
	end, function()
		for _, p in parts do
			p:Destroy()
		end
	end)
end

-- 남는 빛줄: ends() 의 두 끝 사이(매 프레임 다시 읽어 별을 따라간다) — 0.25초에 앞 끝에서 뒤 끝으로 자라고, 모으면 굵어지고, 강타하면 사라진다.
-- flat 이면 바닥에 납작하게
local function heldLine(sept: any, ends: () -> (Vector3, Vector3), width: number, color: Color3, flat: boolean)
	local core = CombatVfx.Part(Vector3.new(width, width, 0.05), CFrame.new(), WHITE)
	local glow = CombatVfx.Part(Vector3.new(width, width, 0.05), CFrame.new(), color)
	core.Transparency, glow.Transparency = 1, 1
	held(sept, { core, glow }, function(t, gk, gone)
		local a, b = ends()
		local head = a:Lerp(b, sine(t / 0.25))
		local len = math.max(0.05, (head - a).Magnitude)
		local cf = CFrame.lookAt(a, if len > 0.06 then head else b) * CFrame.new(0, 0, -len / 2)
		local w = width * (1 + 2 * gk) * (1 + 2 * gone)
		core.Size, core.CFrame = Vector3.new(w, if flat then 0.04 else w, len), cf
		glow.Size, glow.CFrame = Vector3.new(w * 3, if flat then 0.03 else w * 3, len), cf
		core.Transparency = 0.1 + 0.9 * gone
		local base = 0.7 - 0.3 * gk
		glow.Transparency = base + (1 - base) * gone
	end)
end

-- 떨어진 자리의 바닥 룬: 두 겹 원(바깥 열여섯 마디 · 안 일곱 마디)이 서로 반대로 돌며 강타 때까지 남는다
local RUNE: { { any } } = { { 16, 2.2, 0.6, STAR }, { 7, 1.3, -1, WHITE } } -- 마디 · 반지름 · 도는 빠르기(라디안/초) · 빛
local function groundRune(ctx: any, sept: any, g: Vector3)
	local at = Vector3.new(g.X, ctx.Ground + 0.06, g.Z)
	local parts, segs = {}, {}
	for ri, spec in RUNE do
		segs[ri] = {}
		for _ = 1, spec[1] do
			local p = CombatVfx.Part(Vector3.new(0.1, 0.04, 0.1), CFrame.new(at), spec[4])
			p.Transparency = 1
			table.insert(parts, p)
			table.insert(segs[ri], p)
		end
	end
	held(sept, parts, function(t, gk, gone)
		local open = 1 - (1 - math.min(1, t / 0.3)) ^ 3
		for ri, spec in RUNE do
			local n = spec[1]
			local R = spec[2] * open * (1 + 0.6 * gone)
			for k, p in segs[ri] do
				local a = k / n * math.pi * 2 + t * spec[3] * (1 + 3 * gk)
				p.CFrame = CFrame.new(at) * CFrame.Angles(0, -a, 0) * CFrame.new(R, 0, 0)
				p.Size = Vector3.new(0.1 + 0.08 * gk, 0.04, math.max(0.05, 2 * math.pi * R / n * 0.6))
				p.Transparency = 1 - (0.6 + 0.4 * gk) * (1 - gone)
			end
		end
	end)
end

--[[
	하늘 성반(아스트롤라베 — 2026-10-31 질문 답 "더 크고 화려하게"): 바닥과 나란히 누운 별자리 바로 위에 크게 눕는다(아래서 올려다보면 별 뒤).
	바깥 고리(64 마디) · 끊긴 고리(32) · 바깥 눈금(36, 셋마다 길게) · 금빛 룬 열둘 · 칠각성(7/3)과 꼭짓점 일곱 · 안쪽 고리(24) · 바퀴살 여덟 —
	고리마다 다른 빠르기로 서로 반대로 돈다. 레이저가 떨어질 때마다(sept.Pulse) 번쩍 밝아지고, 모으면 빨리 돌며 조여 들고, 강타하면 커지며 사라진다.
]]
local function astrolabe(ctx: any, sept: any)
	local parts = {}
	local function many(n: number, color: Color3): { Part }
		local list = {}
		for _ = 1, n do
			local p = CombatVfx.Part(Vector3.new(0.1, 0.1, 0.05), CFrame.new(ctx.EnemyCenter), color)
			p.Transparency = 1
			table.insert(parts, p)
			table.insert(list, p)
		end
		return list
	end
	local outer, dashed, ticks, runes = many(64, STAR), many(32, PALE), many(36, PALE), many(12, GOLD)
	local star7, marks, inner, spokes = many(7, PALE), many(7, WHITE), many(24, STAR), many(8, STAR)
	local turnA, turnB, turnC, turnD = 0, 0, 0, 0
	local radius: number? = nil
	local seenPulse, pk = sept.Pulse or 0, 0
	held(sept, parts, function(t, gk, gone, dt)
		local sum = Vector3.zero
		for i = 1, 7 do
			sum += ctx.Star(i)
		end
		local mid = sum / 7
		local spread = 0
		for i = 1, 7 do
			spread = math.max(spread, (ctx.Star(i) - mid).Magnitude)
		end
		local cur = radius or spread + 7
		cur += (spread + 7 - cur) * math.min(1, dt * 3)
		radius = cur
		if (sept.Pulse or 0) ~= seenPulse then
			seenPulse, pk = sept.Pulse, 1
		end
		pk *= math.exp(-dt * 5)
		local appear = sine(t / 0.9)
		local R = cur * (0.35 + 0.65 * appear) * (1 - 0.45 * gk) * (1 + 1.4 * gone)
		local seen = appear * (1 - gone)
		local spin = 1 + 6 * gk
		turnA += dt * 0.03 * spin
		turnB -= dt * 0.06 * spin
		turnC += dt * 0.1 * spin
		turnD -= dt * 0.04 * spin
		-- 바닥과 나란한 판(판의 z = 위아래). 별 빛무리(하늘에선 지름 약 4)가 판에 잘리지 않게 별보다 6 위
		-- (2026-10-31 사용자: "마법진에 북두칠성이 가려져서 안 보여. 아마 높이가 같거나")
		local base = CFrame.new(mid + Vector3.new(0, 6, 0)) * CFrame.Angles(math.pi / 2, 0, 0)
		local thick = (1 + 1.5 * gk) * (1 + 0.6 * pk)
		local function alpha(a: number): number
			return 1 - math.min(1, a + 0.3 * gk + 0.35 * pk) * seen
		end
		-- 고리: 마디를 반지름 r 에 접선으로(fill = 마디가 채우는 몫)
		local function ring(list: { Part }, r: number, turn: number, fill: number, w: number, a: number)
			local n = #list
			local chord = math.max(0.05, 2 * math.pi * r / n * fill)
			for k, p in list do
				local ang = (k / n + turn) * math.pi * 2
				p.CFrame = base * CFrame.Angles(0, 0, ang) * CFrame.new(r, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
				p.Size = Vector3.new(chord, w * thick, 0.05)
				p.Transparency = alpha(a)
			end
		end
		-- 바퀴살 · 눈금: 반지름 r0 → r1 로 뻗은 막대(longEvery 마다 두 배 길게)
		local function radial(list: { Part }, r0: number, r1: number, turn: number, w: number, a: number, longEvery: number?)
			local n = #list
			for k, p in list do
				local ang = (k / n + turn) * math.pi * 2
				local r1k = if longEvery and k % longEvery == 0 then 2 * r1 - r0 else r1
				p.CFrame = base * CFrame.Angles(0, 0, ang) * CFrame.new((r0 + r1k) / 2, 0, 0)
				p.Size = Vector3.new(math.max(0.05, r1k - r0), w * thick, 0.05)
				p.Transparency = alpha(a)
			end
		end
		ring(outer, R, turnA, 0.85, 0.18, 0.75)
		ring(dashed, R * 0.92, turnB, 0.45, 0.1, 0.6)
		radial(ticks, R * 1.03, R * 1.08, turnA, 0.07, 0.6, 3)
		ring(inner, R * 0.3, turnC, 0.7, 0.1, 0.65)
		radial(spokes, R * 0.3, R * 0.6, turnC, 0.05, 0.35)
		-- 금빛 룬: 0.8R 에 제자리에서 도는 마름모 열둘
		for k, p in runes do
			local ang = (k / 12 + turnC * 0.5) * math.pi * 2
			local s = R * 0.035 * thick
			p.CFrame = base * CFrame.Angles(0, 0, ang) * CFrame.new(R * 0.8, 0, 0) * CFrame.Angles(0, 0, math.pi / 4 + t)
			p.Size = Vector3.new(s, s, 0.05)
			p.Transparency = alpha(0.7)
		end
		-- 칠각성(7/3)과 꼭짓점 마디: 0.62R
		local vertex = {}
		for k, p in marks do
			local at = base * CFrame.Angles(0, 0, (k / 7 + turnD) * math.pi * 2) * CFrame.new(R * 0.62, 0, 0)
			local s = R * 0.04 * thick
			vertex[k] = at.Position
			p.CFrame = at * CFrame.Angles(0, 0, math.pi / 4)
			p.Size = Vector3.new(s, s, 0.05)
			p.Transparency = alpha(0.85)
		end
		for k, p in star7 do
			local a, b = vertex[k], vertex[(k + 2) % 7 + 1]
			p.CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b)
			p.Size = Vector3.new(0.08 * thick, 0.05, math.max(0.05, (b - a).Magnitude))
			p.Transparency = alpha(0.55)
		end
	end)
end

-- 별 i 가 떨어지면: 둘 다 떨어진 별자리 선을 하늘(별 사이 — 별을 따라간다)과 바닥(떨어진 자리 사이 — 강타 때 선 자국이 이어받는 밑그림)에 긋는다
local function linkLines(ctx: any, sept: any, i: number)
	sept.Fired[i] = true
	for _, pair in LINES do
		local other = if pair[1] == i then pair[2] elseif pair[2] == i then pair[1] else nil
		if other and sept.Fired[other] then
			heldLine(sept, function()
				return ctx.Star(other), ctx.Star(i)
			end, 0.1, STAR, false)
			local lift = Vector3.new(0, 0.03, 0)
			local ga, gb = sept.Points[other] + lift, sept.Points[i] + lift
			heldLine(sept, function()
				return ga, gb
			end, 0.12, PALE, true)
		end
	end
end

--[[
	치켜든 손을 따라 별 일곱이 하늘로: 별마다 떨어질 자리 바로 위 SKY 높이로 올라가 별자리가 바닥과 나란히 눕는다(레이저가 수직으로 떨어지게 —
	2026-10-31 사용자: "더 높이 올라간 채로 완전 눕힌 후에 레이저를 수직으로 떨구는 식"). 별은 이펙트가 몰고(Drive) 강타 0.85초 뒤 놓는다.
	레터박스 · 밤하늘 화면 · 하늘 성반이 켜지고(ev.total 초 — 컷신 끝까지), 별마다 번쩍 · 손끝 파문, 카메라가 오르는 별자리를 따라 올라간다(ev.d 초)
]]
local SKY = 40 -- 질문 2 답
function Fx.SeptRise(ctx: any, ev: any)
	local s = st(ctx)
	s.cam = nil
	local sept = { Points = dipperGround(ctx), Slammed = false, Fired = {}, Pulse = 0 }
	s.sept = sept
	local d = (ev and ev.d) or 1
	if ctx.Weapons and ctx.Weapons.Drive then
		for i = 1, 7 do
			local from, goal = ctx.Star(i), sept.Points[i] + Vector3.new(0, SKY, 0)
			local t, after = -(i - 1) * 0.05, 0
			ctx.Weapons:Drive(i, function(dt: number): Vector3?
				t += dt
				if sept.Slammed then
					after += dt
					if after > 0.85 then
						return nil
					end
				end
				return from:Lerp(goal, sine(t / d)) + Vector3.new(0, math.sin(t * 1.6 + i) * 0.12, 0)
			end)
		end
	end
	local total = (ev and ev.total) or 9.5
	letterbox(ctx, total)
	night(ctx, total)
	astrolabe(ctx, sept)
	ripple(ctx, ctx.Hand("R"), 2)
	for i = 1, 7 do
		ctx.Vfx.Flash(ctx.Star(i), { Color = STAR, Size = 1.6, Life = 0.3, Brightness = 4 })
	end
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
		local pos = (home + r * 13 + Vector3.new(0, 2, 0)):Lerp(home:Lerp(mid, 0.35) + r * 18 + Vector3.new(0, 2, 0), k)
		local cf = from:Lerp(CFrame.lookAt(pos, mid), sine(t / 0.4))
		s.cam = cf
		return cf
	end)
end

--[[
	레이저 한 줄기: 세 겹(넓은 푸른 겉 · 흰 청 · 흰 심)이 별 i 에서 바닥 g 로 grow 초에 뻗어 life 초 머물다 가늘어지고,
	뻗는 동안 빛고리 셋이 줄기를 감아 내려간다. 닿으면 번쩍 · 충격파 · 파편. size = 굵기 배(강타 땐 크게)
]]
local AIM, GROW = 0.25, 0.22
local LAYERS: { { any } } = { { STAR, 1.4, 0.55 }, { PALE, 0.7, 0.3 }, { WHITE, 0.26, 0 } } -- 빛 · 굵기 · 투명도
local function laser(ctx: any, i: number, g: Vector3, size: number, grow: number, life: number)
	local parts: { Part } = {}
	for k, layer in LAYERS do
		parts[k] = CombatVfx.Part(Vector3.new(0.1, 0.1, 0.05), CFrame.new(g), layer[1])
		parts[k].Transparency = 1
	end
	CombatVfx.Timed(grow + life, function(t)
		local a = t * (grow + life)
		local top = ctx.Star(i)
		local head = top:Lerp(g, math.min(1, a / grow))
		local len = math.max(0.05, (head - top).Magnitude)
		local cf = CFrame.lookAt(top, if len > 0.06 then head else top - Vector3.new(0, 0.1, 0), ctx.Forward) * CFrame.new(0, 0, -len / 2)
		local fade = math.clamp((a - grow) / life, 0, 1)
		local w = size * (1 - fade) * (1 + 0.15 * math.sin(a * 50))
		for k, layer in LAYERS do
			local d = 0.03 + layer[2] * w
			parts[k].Size, parts[k].CFrame = Vector3.new(d, d, len), cf
			parts[k].Transparency = layer[3] + (1 - layer[3]) * fade
		end
	end, function()
		for _, p in parts do
			p:Destroy()
		end
	end)
	for k = 1, 3 do
		task.delay(grow * k / 3, function()
			local top = ctx.Star(i)
			local p = top:Lerp(g, k / 3)
			ctx.Vfx.Ring(CFrame.lookAt(p, p + (g - top).Unit, ctx.Forward), {
				R0 = 0.4 * size,
				R1 = 2.2 * size,
				Color = PALE,
				Life = 0.35,
				Width = 0.1 * size,
				Facing = true,
				Segments = 16,
			})
		end)
	end
	task.delay(grow, function()
		ctx.Vfx.Flash(g, { Color = WHITE, Size = 6 * size, Life = 0.3, Brightness = 6 })
		ctx.Vfx.Shockwave(Vector3.new(g.X, ctx.Ground + 0.1, g.Z), { Color = STAR, Radius = 5 * size, Life = 0.45 })
		ctx.Vfx.Burst(g, { Count = 8, Colors = { STAR, WHITE }, Size = 0.2, Speed = 14, Gravity = 20, Life = 0.5 })
	end)
end

--[[
	한 발(ev.star = 별 번호, ev.nth = 몇 번째): 그 별을 올려다보며 이름표가 뜨고 별로 빛이 빨려 든다(AIM) → 레이저가 바닥 자리로 뻗어
	내려가며 화면 색이 바뀌고 카메라가 레이저 끝을 따라 내려간다 → 떨어진 자리에 룬, 하늘 · 바닥에 별자리 선. 다음 레이저가 다시 별을 올려다본다.
]]
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII" }
function Fx.SeptLaser(ctx: any, ev: any)
	local s = st(ctx)
	local sept = septOf(ctx)
	local i, k = (ev and ev.star) or 1, (ev and ev.nth) or 1
	local g = sept.Points[i]
	titleCard(ctx, {
		Top = (ROMAN[k] or "I") .. "  /  VII",
		Big = spaced(NAMES[i][1]),
		Dur = 0.85,
	})
	local star = ctx.Star(i)
	local cam = workspace.CurrentCamera
	ctx.Vfx.Implode(star, { Color = PALE, Radius = 4, Count = 10, Life = AIM })
	ctx.Vfx.Ring(CFrame.lookAt(star, if cam then cam.CFrame.Position else star + ctx.Forward), {
		R0 = 3,
		R1 = 0.3,
		Color = WHITE,
		Life = AIM,
		Width = 0.08,
		Facing = true,
	})
	task.delay(AIM, function()
		laser(ctx, i, g, 1, GROW, 0.35)
		sept.Pulse += 1
		grade(ctx, LASER_GRADE[k] or LASER_GRADE[1], 0, 0.6)
		ctx.Vfx.Flash(ctx.Star(i), { Color = WHITE, Size = 2.4, Life = 0.25, Brightness = 6 })
	end)
	task.delay(AIM + GROW, function()
		groundRune(ctx, sept, g)
		linkLines(ctx, sept, i)
	end)
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local from = camNow(s)
	ctx.Shot(0.95, function(_, t)
		local top = ctx.Star(i)
		local below = top + r * 10 - f * 4 + Vector3.new(0, -14, 0)
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

-- 모으기(강타 직전, 팔을 내리치기 시작할 때): 별자리 선이 굵게 타오르고 성반이 빨리 돌며 조여 들고 별 일곱에 빛이 빨려 든다.
-- 카메라는 진형 옆 낮은 데서 하늘의 별자리를 올려다본다
function Fx.SeptGather(ctx: any)
	local s = st(ctx)
	local sept = s.sept
	if not sept then
		return
	end
	sept.Gather = true
	local sum = Vector3.zero
	for i = 1, 7 do
		local p = ctx.Star(i)
		sum += p
		ctx.Vfx.Implode(p, { Color = WHITE, Radius = 5, Count = 8, Life = 0.35 })
		ctx.Vfx.Flash(p, { Color = PALE, Size = 3, Life = 0.35, Brightness = 6 })
	end
	grade(ctx, { Saturation = -0.85, Contrast = 0.8, Brightness = -0.14 }, 0.7, 0.6)
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local center = ctx.EnemyCenter
	local from = camNow(s)
	local goal = CFrame.lookAt(center + r * 22 - f * 6 + Vector3.new(0, 1.5, 0), center:Lerp(sum / 7, 0.6))
	ctx.Shot(0.4, function(_, t)
		local cf = from:Lerp(goal, sine(t / 0.4))
		s.cam = cf
		return cf
	end)
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

--[[
	마지막: 별 일곱이 한꺼번에 굵은 빛줄기로 내리꽂히고(북두칠성 꼴) 바닥 밑그림이 선 자국으로 타오르며 진형 전체를 강타 —
	흑백 임팩트 → 강한 붉은 빛으로 남아 내 차례가 오면 돌아옴 · 진형 가운데서 큰 충격파 두 겹과 고리 · 제목 카드 SEPTENTRIONES. 성반 · 룬 · 하늘 선은 거둔다.
	카메라는 진형 위 넓은 구도로 옮겨(선 자국이 다 보이게) 모션이 끝날 때까지 머문다. 큰 연출은 한 번(맞은 적마다 불린다)
]]
function Fx.SeptSlam(ctx: any, _ev: any, at: Vector3?)
	local s = st(ctx)
	local sept = s.sept
	if sept and not sept.Slammed then
		sept.Slammed = true
		local P = sept.Points
		titleCard(ctx, {
			Top = "U R S A   M A J O R",
			Big = spaced("SEPTENTRIONES"),
			Dur = 1.7,
			Y = 0.42,
			Height = 0.26,
		})
		-- 막타가 가장 세다: 흑백 번쩍 → 강한 붉은 빛으로 남아 내 차례가 오면 돌아온다
		grade(ctx, SLAM_FLASH, 1, 0.15)
		task.delay(0.15, function()
			grade(ctx, SLAM_GRADE, 0.8)
		end)
		for i = 1, 7 do
			laser(ctx, i, P[i], 2.4, 0.08, 0.5)
			ctx.Vfx.Flash(ctx.Star(i), { Color = WHITE, Size = 4, Life = 0.3, Brightness = 8 })
			ctx.Vfx.Pillar(P[i], { Height = 18, Width = 2.6, Color = STAR, Life = 0.6 })
			ctx.Vfx.Shockwave(P[i] + Vector3.new(0, 0.05, 0), { Color = WHITE, Radius = 7, Life = 0.6 })
		end
		for _, pair in LINES do
			scar(P[pair[1]], P[pair[2]])
		end
		local center = ctx.EnemyCenter
		local floor = Vector3.new(center.X, ctx.Ground + 0.1, center.Z)
		ctx.Vfx.Flash(center + Vector3.new(0, 3, 0), { Color = FUSION, Size = 30, Life = 0.6, Brightness = 10 })
		ctx.Vfx.Shockwave(floor, { Color = FUSION, Radius = 22, Life = 0.9 })
		task.delay(0.12, function()
			ctx.Vfx.Shockwave(floor, { Color = STAR, Radius = 30, Life = 1.1 })
		end)
		ctx.Vfx.Ring(CFrame.new(floor + Vector3.new(0, 0.2, 0)), { R0 = 4, R1 = 26, Color = WHITE, Life = 1.2, Width = 0.6, Height = 0.3, Segments = 40 })
		ctx.Vfx.Burst(floor + Vector3.new(0, 1, 0), { Count = 24, Colors = { STAR, WHITE, MELT }, Size = 0.3, Speed = 30, Gravity = 30, Life = 0.9 })
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
