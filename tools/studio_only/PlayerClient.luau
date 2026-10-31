-- 달리기(LeftShift)와 순간이동 창(M). Studio 전용 StarterPlayerScripts.PlayerClient — 사본 tools/studio_only
-- 2026-10-31 사용자: "M 키 순간이동 목록도 화면 가운데에 크게" → 가운데 큰 창: 지역 카드(지역 이름 = 그 지역 한가운데로)와
-- 그 아래 명소 단추들. 목록은 서버가 TeleportRequest 의 속성 "Menu"(JSON)로 알려 준다 — 먼 곳 파트가 아직 안 내려와 있어도 다 보이게.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local WALK, RUN = 16, 30
local plr = Players.LocalPlayer
local remote = RS:WaitForChild("TeleportRequest")

local function hum()
	local c = plr.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

--=== 달리기 ===--
local function setSpeed(v)
	local h = hum()
	if h then
		h.WalkSpeed = v
	end
end

plr.CharacterAdded:Connect(function(c)
	local h = c:WaitForChild("Humanoid")
	h.WalkSpeed = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and RUN or WALK
end)
if hum() then
	setSpeed(WALK)
end

--=== 창 ===--
local INK = Color3.fromRGB(236, 232, 224)
local DIM = Color3.fromRGB(150, 146, 138)
local GOLD = Color3.fromRGB(226, 190, 110)

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local gui = make("ScreenGui", { Name = "IslandMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 }, plr:WaitForChild("PlayerGui"))

-- 오른쪽 아래 작은 단추(전투 단추가 왼쪽 아래를 쓴다)
local open = make("TextButton", {
	Size = UDim2.fromOffset(150, 36),
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -16),
	BackgroundColor3 = Color3.fromRGB(26, 26, 30),
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	Text = "순간이동  (M)",
	TextColor3 = INK,
	Font = Enum.Font.GothamMedium,
	TextSize = 15,
}, gui)
make("UICorner", {}, open)

-- 화면을 덮는 어둠. 누르면 닫힌다. Modal = 1인칭에서도 마우스가 풀린다
local shade = make("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	Modal = true,
	Visible = false,
}, gui)

local panel = make("Frame", {
	Size = UDim2.fromScale(0.74, 0.8),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
	Active = true, -- 창 안을 눌러도 뒤의 어둠(닫기)에 안 닿게
	Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 14) }, panel)
make("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.35 }, panel)
make("UISizeConstraint", { MinSize = Vector2.new(540, 380), MaxSize = Vector2.new(1180, 820) }, panel)

make("TextLabel", {
	Size = UDim2.new(1, -120, 0, 44),
	Position = UDim2.fromOffset(28, 18),
	BackgroundTransparency = 1,
	Text = "순간이동",
	TextColor3 = GOLD,
	Font = Enum.Font.GothamBold,
	TextSize = 30,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
make("TextLabel", {
	Size = UDim2.new(1, -120, 0, 20),
	Position = UDim2.fromOffset(30, 60),
	BackgroundTransparency = 1,
	Text = "지역 이름을 누르면 그 지역 한가운데로, 아래 단추는 명소로  ·  M 으로 닫기",
	TextColor3 = DIM,
	Font = Enum.Font.Gotham,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
local close = make("TextButton", {
	Size = UDim2.fromOffset(44, 44),
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 18),
	BackgroundColor3 = Color3.fromRGB(42, 42, 48),
	BorderSizePixel = 0,
	Text = "✕",
	TextColor3 = INK,
	Font = Enum.Font.GothamBold,
	TextSize = 22,
}, panel)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, close)

local list = make("ScrollingFrame", {
	Size = UDim2.new(1, -48, 1, -112),
	Position = UDim2.fromOffset(24, 96),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = GOLD,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, panel)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Wraps = true,
	Padding = UDim.new(0, 14),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list)
make("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, list)

local function setOpen(on)
	shade.Visible = on
	panel.Visible = on
end

local function go(request)
	remote:FireServer(request)
	setOpen(false)
end

local function button(parent, text, order, size, height, color)
	local b = make("TextButton", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = INK,
		Font = if size >= 20 then Enum.Font.GothamBold else Enum.Font.Gotham,
		TextSize = size,
		TextWrapped = true,
		LayoutOrder = order,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
	return b
end

-- 지역 카드: [지역 이름 — 한가운데로] 아래에 명소 단추들
local function rebuild()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local ok, menu = pcall(HttpService.JSONDecode, HttpService, remote:GetAttribute("Menu") or "[]")
	if not ok then
		return
	end
	for i, region in ipairs(menu) do
		local card = make("Frame", {
			Size = UDim2.fromOffset(252, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(30, 30, 36),
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, list)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
		make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, card)
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, card)
		if region.Center then
			button(card, region.Name, 0, 22, 46, Color3.fromRGB(64, 54, 36)).MouseButton1Click:Connect(function()
				go(region.Name)
			end)
		else
			make("TextLabel", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = region.Name, TextColor3 = GOLD, Font = Enum.Font.GothamBold, TextSize = 22, LayoutOrder = 0 }, card)
		end
		for j, spot in ipairs(region.Spots) do
			button(card, spot, j, 16, 34, Color3.fromRGB(44, 44, 52)).MouseButton1Click:Connect(function()
				go("spot:" .. region.Name .. "/" .. spot)
			end)
		end
	end
end
rebuild()
remote:GetAttributeChangedSignal("Menu"):Connect(rebuild)

open.MouseButton1Click:Connect(function()
	setOpen(not panel.Visible)
end)
shade.MouseButton1Click:Connect(function()
	setOpen(false)
end)
close.MouseButton1Click:Connect(function()
	setOpen(false)
end)

UIS.InputBegan:Connect(function(input, gp)
	if gp then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSpeed(RUN)
	elseif input.KeyCode == Enum.KeyCode.M then
		setOpen(not panel.Visible)
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSpeed(WALK)
	end
end)
