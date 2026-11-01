--!nocheck
--[[
	칼리스토 미리보기 자리표(2026-11-01): workspace.CallistoPreview 의 옛 고정 모델(편집 모드로 지어 둔 것) 자리마다 자리표(보이지 않는 Part,
	속성 Page)와 이름표를 두고 옛 모델은 지운다. 플레이하면 Combat/CallistoPreview 가 그 자리에 지금 모습(1·2·3페이즈)을 세운다. 보고: /previewmarks
]]
local HS = game:GetService("HttpService")
local lines = {}
local folder = workspace:FindFirstChild("CallistoPreview")
assert(folder, "CallistoPreview 없음")
local NAMES = { "1페이즈 · 관찰자", "2페이즈 · 성위 품은 자", "3페이즈 · 우주가 된 몸" }
for _, c in folder:GetChildren() do
	local page = tonumber(c.Name:match("_(%d)$"))
	if c:IsA("Model") and page then
		local cf = c:GetPivot()
		local mark = Instance.new("Part")
		mark.Name = "자리표_" .. page
		mark.Size = Vector3.new(2, 2, 1)
		mark.Transparency = 1
		mark.Anchored, mark.CanCollide, mark.CanQuery, mark.CanTouch = true, false, false, false
		mark.CFrame = cf
		mark:SetAttribute("Page", page)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(220, 40)
		gui.StudsOffset = Vector3.new(0, 4.6, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 120
		gui.Parent = mark
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = NAMES[page] .. "\n(플레이하면 보임)"
		label.TextColor3 = Color3.fromRGB(230, 236, 255)
		label.TextStrokeTransparency = 0.4
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Parent = gui
		mark.Parent = folder
		c:Destroy()
		table.insert(lines, string.format("%d페이즈 자리표 %s", page, tostring(cf.Position)))
	end
end
HS:PostAsync("http://127.0.0.1:34999/previewmarks", table.concat(lines, "\n"))
