--!strict
-- 공용 UI 스타일 헬퍼 (늪지대 테마: 짙은 녹갈색 반투명 패널 + 금빛 테두리)

local Players = game:GetService("Players")

local UIKit = {}

UIKit.Colors = {
	Panel = Color3.fromRGB(22, 28, 22),
	PanelLight = Color3.fromRGB(38, 46, 36),
	Stroke = Color3.fromRGB(196, 164, 92),
	Text = Color3.fromRGB(238, 232, 214),
	SubText = Color3.fromRGB(176, 186, 164),
	Health = Color3.fromRGB(196, 58, 52),
	HealthChip = Color3.fromRGB(250, 230, 200),
	Stamina = Color3.fromRGB(150, 196, 84),
	Poise = Color3.fromRGB(226, 190, 96),
	Poison = Color3.fromRGB(120, 220, 90),
	Crit = Color3.fromRGB(255, 176, 60),
	Bad = Color3.fromRGB(255, 96, 80),
	Good = Color3.fromRGB(130, 230, 150),
}

UIKit.Font = Enum.Font.GothamBold
UIKit.FontRegular = Enum.Font.Gotham
UIKit.FontTitle = Enum.Font.Fantasy

function UIKit.ScreenGui(name: string, order: number?): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = order or 1
	g.Parent = pg
	return g
end

function UIKit.Corner(parent: Instance, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

function UIKit.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or UIKit.Colors.Stroke
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0.35
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UIKit.Panel(parent: Instance, size: UDim2, pos: UDim2, anchor: Vector2?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = UIKit.Colors.Panel
	f.BackgroundTransparency = transparency or 0.2
	f.BorderSizePixel = 0
	f.Parent = parent
	UIKit.Corner(f, 10)
	UIKit.Stroke(f)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new(0, 0.15)
	grad.Parent = f
	return f
end

function UIKit.Label(parent: Instance, text: string, size: UDim2, pos: UDim2, textSize: number?, font: Enum.Font?, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = text
	l.Font = font or UIKit.Font
	l.TextSize = textSize or 16
	l.TextColor3 = color or UIKit.Colors.Text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.RichText = true
	l.Parent = parent
	local s = Instance.new("UIStroke")
	s.Thickness = 1
	s.Transparency = 0.55
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = l
	return l
end

export type Bar = { Frame: Frame, Fill: Frame, Chip: Frame?, Set: (self: Bar, ratio: number, instant: boolean?) -> (), Ratio: number }

-- 게이지 바 (체력바는 chip=true 로 늦게 줄어드는 흰 잔상 표시)
function UIKit.Bar(parent: Instance, size: UDim2, pos: UDim2, color: Color3, chip: boolean?): Bar
	local back = Instance.new("Frame")
	back.Size = size
	back.Position = pos
	back.BackgroundColor3 = Color3.fromRGB(10, 12, 10)
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.ClipsDescendants = true
	back.Parent = parent
	UIKit.Corner(back, 4)
	UIKit.Stroke(back, Color3.fromRGB(0, 0, 0), 1, 0.4)
	local chipFrame: Frame? = nil
	if chip then
		local c = Instance.new("Frame")
		c.Name = "Chip"
		c.Size = UDim2.fromScale(1, 1)
		c.BackgroundColor3 = UIKit.Colors.HealthChip
		c.BorderSizePixel = 0
		c.Parent = back
		UIKit.Corner(c, 4)
		chipFrame = c
	end
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	UIKit.Corner(fill, 4)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	g.Parent = fill
	local bar = { Frame = back, Fill = fill, Chip = chipFrame, Ratio = 1 } :: any
	local chipTarget = 1
	local chipTime = 0
	function bar.Set(self: any, ratio: number, instant: boolean?)
		ratio = math.clamp(ratio, 0, 1)
		self.Fill.Size = UDim2.fromScale(ratio, 1)
		if self.Chip then
			if ratio >= chipTarget or instant then
				chipTarget = ratio
				self.Chip.Size = UDim2.fromScale(ratio, 1)
			else
				chipTime = os.clock()
				local myTime = chipTime
				task.delay(0.45, function()
					if chipTime ~= myTime then
						return
					end
					chipTarget = ratio
					self.Chip:TweenSize(UDim2.fromScale(ratio, 1), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.35, true)
				end)
			end
		end
		self.Ratio = ratio
	end
	return bar :: Bar
end

function UIKit.Button(parent: Instance, text: string, size: UDim2, pos: UDim2, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = UIKit.Colors.PanelLight
	b.BackgroundTransparency = 0.1
	b.AutoButtonColor = true
	b.Text = text
	b.Font = UIKit.Font
	b.TextSize = 16
	b.TextColor3 = UIKit.Colors.Text
	b.Parent = parent
	UIKit.Corner(b, 8)
	UIKit.Stroke(b)
	b.Activated:Connect(onClick)
	return b
end

function UIKit.FormatTime(sec: number): string
	sec = math.max(0, math.floor(sec + 0.5))
	if sec >= 60 then
		return string.format("%d분 %02d초", sec // 60, sec % 60)
	end
	return string.format("%d초", sec)
end

return UIKit
