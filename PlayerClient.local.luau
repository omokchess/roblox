local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

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

--=== 섬 목록 ===--
-- 섬 이름은 지면 폴더에서 읽는다. 적어 두면 섬을 늘릴 때마다 손봐야 한다
local ORDER = { "평원", "숲", "늪지대", "탑의성역", "사막", "오염지대", "설원", "화산", "광산" }

local function islands()
	local have, out = {}, {}
	for _, g in ipairs(workspace.Surface.World:GetChildren()) do
		local nm = g.Name:match("^G_(.+)$")
		if nm then
			have[nm] = true
		end
	end
	for _, nm in ipairs(ORDER) do
		if have[nm] then
			out[#out + 1] = nm
			have[nm] = nil
		end
	end
	for nm in pairs(have) do
		out[#out + 1] = nm
	end
	return out
end

local gui = Instance.new("ScreenGui")
gui.Name = "IslandMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = plr:WaitForChild("PlayerGui")

local open = Instance.new("TextButton")
open.Size = UDim2.new(0, 130, 0, 34)
-- 프로젝트의 전투 버튼이 왼쪽 아래를 쓰므로 오른쪽 아래에 붙인다
open.AnchorPoint = Vector2.new(1, 1)
open.Position = UDim2.new(1, -16, 1, -16)
open.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
open.BackgroundTransparency = 0.15
open.BorderSizePixel = 0
open.Text = "섬 이동  (M)"
open.TextColor3 = Color3.fromRGB(236, 232, 224)
open.Font = Enum.Font.GothamMedium
open.TextSize = 15
open.Parent = gui
Instance.new("UICorner").Parent = open

local rows = #islands()
local panelH = math.min(40 + rows * 30, 320)
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 180, 0, panelH)
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -16, 1, -58)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner").Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Text = "어느 섬으로"
title.TextColor3 = Color3.fromRGB(176, 172, 164)
title.Font = Enum.Font.GothamMedium
title.TextSize = 14
title.Parent = panel

-- 섬이 늘어나도 되게 스크롤되는 목록으로 둔다
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -16, 1, -42)
list.Position = UDim2.new(0, 8, 0, 36)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.CanvasSize = UDim2.new(0, 0, 0, rows * 30)
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.Parent = list

for _, nm in ipairs(islands()) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 26)
	b.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
	b.BorderSizePixel = 0
	b.Text = nm
	b.TextColor3 = Color3.fromRGB(236, 232, 224)
	b.Font = Enum.Font.Gotham
	b.TextSize = 14
	b.Parent = list
	Instance.new("UICorner").Parent = b
	b.MouseButton1Click:Connect(function()
		remote:FireServer(nm)
		panel.Visible = false
	end)
end

local function toggle()
	panel.Visible = not panel.Visible
end
open.MouseButton1Click:Connect(toggle)

UIS.InputBegan:Connect(function(input, gp)
	if gp then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSpeed(RUN)
	elseif input.KeyCode == Enum.KeyCode.M then
		toggle()
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSpeed(WALK)
	end
end)
