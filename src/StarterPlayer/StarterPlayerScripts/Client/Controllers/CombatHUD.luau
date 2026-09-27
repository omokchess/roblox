--!strict
-- 전투 HUD: 체력/스태미나/강인도, 상태이상, 무기·기술 슬롯(쿨다운), 보스 체력바, 적 이름표,
-- 저체력 비네트, 사망 화면, 조작 도움말(H)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatusDefs = require(Shared.Combat.StatusDefs)
local WeaponDefs = require(Shared.Combat.WeaponDefs)
local MoveDefs = require(Shared.Combat.MoveDefs)
local UIKit = require(script.Parent.UIKit)
local CombatBus = require(script.Parent.CombatBus)
local CombatController = require(script.Parent.CombatController)
local LockOnController = require(script.Parent.LockOnController)

local player = Players.LocalPlayer
local CombatHUD = {}

local gui: ScreenGui
local hpBar: UIKit.Bar
local stBar: UIKit.Bar
local poiseBar: UIKit.Bar
local hpText: TextLabel
local weaponLabel: TextLabel
local statusRow: Frame
local slotFrames: { Frame } = {}
local skillFrames: { [string]: { frame: Frame, shade: Frame, cd: TextLabel, icon: TextLabel, name: TextLabel } } = {}
local bossFrame: Frame
local bossBar: UIKit.Bar
local bossName: TextLabel
local bossId: number? = nil
local vignette: { Frame } = {}
local deathFrame: Frame
local helpFrame: Frame
local plates: { [Model]: { gui: BillboardGui, bar: UIKit.Bar, status: TextLabel, lastHit: number } } = {}

local function parseStatuses(s: string?): { { id: string, n: number, t: number } }
	local out = {}
	if not s or s == "" then
		return out
	end
	for part in string.gmatch(s, "[^;]+") do
		local id, n, t = string.match(part, "^(%w+):(%-?%d+):([%d%.]+)$")
		if id then
			table.insert(out, { id = id, n = tonumber(n) or 1, t = tonumber(t) or 0 })
		end
	end
	return out
end

local function statusText(s: string?): string
	local parts = {}
	for _, st in parseStatuses(s) do
		local def = StatusDefs[st.id]
		if def and def.Debuff then
			table.insert(parts, def.Icon .. (if st.n > 1 and def.Kind ~= "Buildup" then tostring(st.n) else ""))
		end
	end
	return table.concat(parts, " ")
end

-- ── 구성 ─────────────────────────────────────────────────
local function buildMain()
	gui = UIKit.ScreenGui("SwampHUD", 4)
	local panel = UIKit.Panel(gui, UDim2.fromOffset(380, 104), UDim2.new(0, 18, 1, -18), Vector2.new(0, 1))
	weaponLabel = UIKit.Label(panel, "", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 6), 16)
	hpBar = UIKit.Bar(panel, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 32), UIKit.Colors.Health, true)
	hpText = UIKit.Label(hpBar.Frame, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 13)
	hpText.TextXAlignment = Enum.TextXAlignment.Center
	hpText.ZIndex = 5
	stBar = UIKit.Bar(panel, UDim2.new(1, -24, 0, 11), UDim2.fromOffset(12, 56), UIKit.Colors.Stamina, false)
	poiseBar = UIKit.Bar(panel, UDim2.new(1, -24, 0, 5), UDim2.fromOffset(12, 72), UIKit.Colors.Poise, false)
	local hint = UIKit.Label(panel, "H: 조작법", UDim2.new(1, -24, 0, 14), UDim2.fromOffset(12, 82), 12, UIKit.FontRegular, UIKit.Colors.SubText)
	hint.TextXAlignment = Enum.TextXAlignment.Right

	statusRow = Instance.new("Frame")
	statusRow.BackgroundTransparency = 1
	statusRow.Size = UDim2.fromOffset(380, 34)
	statusRow.Position = UDim2.new(0, 18, 1, -128)
	statusRow.AnchorPoint = Vector2.new(0, 1)
	statusRow.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = statusRow

	-- 무기 슬롯 + 기술 슬롯 (하단 중앙)
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.fromOffset(5 * 66 + 30, 70)
	bar.Position = UDim2.new(0.5, 0, 1, -14)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Parent = gui
	for i, id in WeaponDefs.Loadout do
		local def = WeaponDefs.Weapons[id]
		local f = UIKit.Panel(bar, UDim2.fromOffset(60, 60), UDim2.fromOffset((i - 1) * 66, 5), nil, 0.3)
		local icon = UIKit.Label(f, def.Icon, UDim2.fromScale(1, 0.7), UDim2.fromScale(0, 0.05), 28)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		local key = UIKit.Label(f, tostring(i), UDim2.fromOffset(16, 16), UDim2.fromOffset(4, 2), 12, nil, UIKit.Colors.SubText)
		key.TextXAlignment = Enum.TextXAlignment.Left
		local nm = UIKit.Label(f, def.DisplayName, UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, -16), 10, UIKit.FontRegular, UIKit.Colors.SubText)
		nm.TextXAlignment = Enum.TextXAlignment.Center
		f:SetAttribute("WeaponId", id)
		slotFrames[i] = f
	end
	for j, slot in { "E", "R" } do
		local f = UIKit.Panel(bar, UDim2.fromOffset(60, 60), UDim2.fromOffset(3 * 66 + 24 + (j - 1) * 66, 5), nil, 0.3)
		local icon = UIKit.Label(f, "", UDim2.fromScale(1, 0.7), UDim2.fromScale(0, 0.05), 28)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		local key = UIKit.Label(f, slot, UDim2.fromOffset(16, 16), UDim2.fromOffset(4, 2), 12, nil, UIKit.Colors.Stroke)
		key.TextXAlignment = Enum.TextXAlignment.Left
		local nm = UIKit.Label(f, "", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, -16), 10, UIKit.FontRegular, UIKit.Colors.SubText)
		nm.TextXAlignment = Enum.TextXAlignment.Center
		local shade = Instance.new("Frame")
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BackgroundTransparency = 0.35
		shade.BorderSizePixel = 0
		shade.AnchorPoint = Vector2.new(0, 1)
		shade.Position = UDim2.fromScale(0, 1)
		shade.Size = UDim2.fromScale(1, 0)
		shade.ZIndex = 3
		shade.Parent = f
		UIKit.Corner(shade, 10)
		local cd = UIKit.Label(f, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 20)
		cd.TextXAlignment = Enum.TextXAlignment.Center
		cd.ZIndex = 4
		skillFrames[slot] = { frame = f, shade = shade, cd = cd, icon = icon, name = nm }
	end

	-- 보스 바
	bossFrame = UIKit.Panel(gui, UDim2.fromOffset(620, 58), UDim2.new(0.5, 0, 0, 86), Vector2.new(0.5, 0), 0.25)
	bossName = UIKit.Label(bossFrame, "", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 4), 18, UIKit.FontTitle, Color3.fromRGB(190, 255, 220))
	bossName.TextXAlignment = Enum.TextXAlignment.Center
	bossBar = UIKit.Bar(bossFrame, UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 32), Color3.fromRGB(110, 210, 150), true)
	bossFrame.Visible = false

	-- 저체력 비네트
	local edges: { { size: UDim2, pos: UDim2, rot: number } } = {
		{ size = UDim2.new(1, 0, 0.18, 0), pos = UDim2.fromScale(0, 0), rot = 90 },
		{ size = UDim2.new(1, 0, 0.18, 0), pos = UDim2.fromScale(0, 0.82), rot = -90 },
		{ size = UDim2.new(0.12, 0, 1, 0), pos = UDim2.fromScale(0, 0), rot = 0 },
		{ size = UDim2.new(0.12, 0, 1, 0), pos = UDim2.fromScale(0.88, 0), rot = 180 },
	}
	for _, e in edges do
		local f = Instance.new("Frame")
		f.Size = e.size
		f.Position = e.pos
		f.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 1
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = e.rot
		g.Transparency = NumberSequence.new(0.2, 1)
		g.Parent = f
		table.insert(vignette, f)
	end

	-- 사망 화면
	deathFrame = Instance.new("Frame")
	deathFrame.Size = UDim2.fromScale(1, 1)
	deathFrame.BackgroundColor3 = Color3.fromRGB(10, 6, 6)
	deathFrame.BackgroundTransparency = 1
	deathFrame.Visible = false
	deathFrame.ZIndex = 20
	deathFrame.Parent = gui
	local dl = UIKit.Label(deathFrame, "쓰러졌습니다", UDim2.new(1, 0, 0, 60), UDim2.fromScale(0, 0.4), 46, UIKit.FontTitle, Color3.fromRGB(200, 60, 50))
	dl.TextXAlignment = Enum.TextXAlignment.Center
	dl.ZIndex = 21
	local dl2 = UIKit.Label(deathFrame, "늪의 안개 속에서 다시 깨어납니다…", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0.4, 62), 18, UIKit.FontRegular, UIKit.Colors.SubText)
	dl2.TextXAlignment = Enum.TextXAlignment.Center
	dl2.ZIndex = 21

	-- 도움말
	helpFrame = UIKit.Panel(gui, UDim2.fromOffset(330, 250), UDim2.new(1, -18, 0.5, 0), Vector2.new(1, 0.5), 0.15)
	local lines = {
		"<b>조작법</b>",
		"좌클릭  약공격 (연타 콤보)",
		"좌클릭 길게  충전 강공격",
		"F (길게)  방어 · 맞기 직전 = 패링",
		"Q  구르기 (무적 시간)",
		"E / R  무기 기술",
		"1 · 2 · 3  무기 교체",
		"T / 휠클릭  대상 고정",
		"",
		"<font color='#9FD58E'>패링 성공 → 다음 공격 반격(×1.8)</font>",
		"<font color='#E6C069'>등 뒤 공격 → 백어택(×1.35)</font>",
	}
	for i, text in lines do
		UIKit.Label(helpFrame, text, UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 8 + (i - 1) * 21), if i == 1 then 18 else 14, if i == 1 then nil else UIKit.FontRegular)
	end
	helpFrame.Visible = true
	task.delay(10, function()
		helpFrame.Visible = false
	end)
end

-- ── 적 이름표 ────────────────────────────────────────────
local function plateFor(model: Model)
	if plates[model] or model:GetAttribute("Boss") then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end
	local anchorAtt = root:FindFirstChild("HealthBar") :: Attachment?
	local g = Instance.new("BillboardGui")
	g.Name = "SwampPlate"
	g.Size = UDim2.fromOffset(150, 40)
	g.StudsOffsetWorldSpace = if anchorAtt then Vector3.zero else Vector3.new(0, 5, 0)
	g.Adornee = anchorAtt or root
	g.AlwaysOnTop = true
	g.MaxDistance = 80
	g.LightInfluence = 0
	g.Enabled = false
	local name = UIKit.Label(g, model:GetAttribute("DisplayName") :: string? or model.Name, UDim2.new(1, 0, 0, 16), UDim2.fromScale(0, 0), 14)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local bar = UIKit.Bar(g, UDim2.new(1, 0, 0, 8), UDim2.fromOffset(0, 18), Color3.fromRGB(200, 70, 60), true)
	local st = UIKit.Label(g, "", UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 27), 12)
	st.TextXAlignment = Enum.TextXAlignment.Center
	g.Parent = gui
	plates[model] = { gui = g, bar = bar, status = st, lastHit = 0 }
	local function update()
		bar:Set(hum.Health / math.max(1, hum.MaxHealth))
	end
	hum.HealthChanged:Connect(function()
		local p = plates[model]
		if p then
			p.lastHit = os.clock()
		end
		update()
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			local p = plates[model]
			if p then
				p.gui:Destroy()
				plates[model] = nil
			end
		end
	end)
	update()
end

-- ── 갱신 ─────────────────────────────────────────────────
local function refresh()
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not ch or not hum then
		return
	end
	local hpRatio = hum.Health / math.max(1, hum.MaxHealth)
	hpBar:Set(hpRatio)
	hpText.Text = string.format("%d / %d", math.floor(hum.Health + 0.5), math.floor(hum.MaxHealth))
	local maxSt = (ch:GetAttribute("MaxStamina") :: number?) or 100
	stBar:Set(((ch:GetAttribute("Stamina") :: number?) or maxSt) / maxSt, true)
	poiseBar:Set((ch:GetAttribute("Poise") :: number?) or 1, true)
	-- 무기 / 기술
	local wid = ch:GetAttribute("WeaponId") :: string?
	local w = wid and WeaponDefs.Weapons[wid]
	weaponLabel.Text = if w then string.format("%s  <b>%s</b>", w.Icon, w.DisplayName) else ""
	for _, f in slotFrames do
		local stroke = f:FindFirstChildOfClass("UIStroke")
		local on = f:GetAttribute("WeaponId") == wid
		if stroke then
			stroke.Transparency = if on then 0 else 0.6
			stroke.Thickness = if on then 2.5 else 1.5
		end
		f.BackgroundTransparency = if on then 0.1 else 0.45
	end
	for slot, sf in skillFrames do
		local moveId = w and w.Skills[slot]
		local move = moveId and MoveDefs.Moves[moveId]
		if move and moveId then
			sf.icon.Text = move.Icon or "✦"
			sf.name.Text = move.Name
			local cd = CombatController.Cooldown(moveId)
			local total = move.Cooldown or 1
			sf.shade.Size = UDim2.fromScale(1, math.clamp(cd / total, 0, 1))
			sf.cd.Text = if cd > 0.05 then string.format("%.0f", math.ceil(cd)) else ""
		else
			sf.icon.Text = ""
			sf.name.Text = ""
			sf.shade.Size = UDim2.fromScale(1, 0)
			sf.cd.Text = ""
		end
	end
	-- 상태이상 아이콘
	for _, c in statusRow:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for _, st in parseStatuses(ch:GetAttribute("Statuses") :: string?) do
		local def = StatusDefs[st.id]
		if def then
			local f = Instance.new("Frame")
			f.Size = UDim2.fromOffset(46, 32)
			f.BackgroundColor3 = UIKit.Colors.Panel
			f.BackgroundTransparency = 0.25
			f.Parent = statusRow
			UIKit.Corner(f, 6)
			UIKit.Stroke(f, def.Color, 1.5, 0.1)
			local label = if def.Kind == "Buildup" then string.format("%s%d%%", def.Icon, st.n) elseif st.n > 1 then string.format("%s×%d", def.Icon, st.n) else def.Icon
			local l = UIKit.Label(f, label, UDim2.fromScale(1, 0.62), UDim2.fromScale(0, 0), 14)
			l.TextXAlignment = Enum.TextXAlignment.Center
			local tl = UIKit.Label(f, string.format("%.0f", st.t), UDim2.fromScale(1, 0.38), UDim2.fromScale(0, 0.6), 11, UIKit.FontRegular, def.Color)
			tl.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
	-- 비네트
	local v = math.clamp((0.35 - hpRatio) / 0.35, 0, 1)
	for _, f in vignette do
		f.BackgroundTransparency = 1 - v * 0.55
	end
	-- 보스
	if bossId then
		local m = CombatBus.Model(bossId)
		local bh = m and m:FindFirstChildOfClass("Humanoid")
		if bh then
			bossBar:Set(bh.Health / math.max(1, bh.MaxHealth))
			local st = statusText(m and m:GetAttribute("Statuses") :: string?)
			local enraged = m and string.find((m:GetAttribute("Statuses") :: string?) or "", "Enraged") ~= nil
			bossName.Text = string.format("%s%s · %s %s", if enraged then "😡 " else "", (m :: Model):GetAttribute("Title") :: string? or "", (m :: Model):GetAttribute("DisplayName") :: string? or "", st)
		else
			bossId = nil
			bossFrame.Visible = false
		end
	end
	-- 적 이름표 표시 조건
	local locked = LockOnController.Target()
	local myRoot = ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	for model, p in plates do
		local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local h = model:FindFirstChildOfClass("Humanoid")
		local near = r ~= nil and myRoot ~= nil and (r.Position - myRoot.Position).Magnitude < 28
		local alive = h ~= nil and h.Health > 0
		p.gui.Enabled = alive and (model == locked or near or os.clock() - p.lastHit < 6)
		p.status.Text = statusText(model:GetAttribute("Statuses") :: string?)
	end
end

local function onEvent(kind: string, data: any, isLocal: boolean)
	if isLocal or type(data) ~= "table" then
		return
	end
	if kind == "Boss" then
		if data.on then
			bossId = data.i
			bossFrame.Visible = true
			bossFrame.BackgroundTransparency = 1
			TweenService:Create(bossFrame, TweenInfo.new(0.6), { BackgroundTransparency = 0.25 }):Play()
		elseif bossId == data.i then
			bossId = nil
			bossFrame.Visible = false
		end
	elseif kind == "Died" and bossId == data.i then
		task.delay(2.5, function()
			bossFrame.Visible = false
			bossId = nil
		end)
	end
end

local function watchDeath(ch: Model)
	local hum = ch:WaitForChild("Humanoid", 10) :: Humanoid?
	deathFrame.Visible = false
	deathFrame.BackgroundTransparency = 1
	if hum then
		hum.Died:Connect(function()
			deathFrame.Visible = true
			TweenService:Create(deathFrame, TweenInfo.new(1.2), { BackgroundTransparency = 0.35 }):Play()
		end)
	end
end

function CombatHUD.Start()
	buildMain()
	CombatBus.Subscribe(onEvent)
	for _, m in CollectionService:GetTagged("SwampEnemy") do
		if m:IsA("Model") then
			task.spawn(plateFor, m)
		end
	end
	CollectionService:GetInstanceAddedSignal("SwampEnemy"):Connect(function(m)
		if m:IsA("Model") then
			plateFor(m)
		end
	end)
	player.CharacterAdded:Connect(watchDeath)
	if player.Character then
		task.spawn(watchDeath, player.Character)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H then
			helpFrame.Visible = not helpFrame.Visible
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.08 then
			acc = 0
			refresh()
		end
	end)
end

return CombatHUD
