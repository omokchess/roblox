--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CharacterDefinitions = require(ReplicatedStorage.Shared.CharacterDefinitions)
local MotionPlayer = require(ReplicatedStorage.Shared.MotionPlayer)
local RotationUtil = require(ReplicatedStorage.Shared.RotationUtil)

local MotionEditorController = {}
MotionEditorController.__index = MotionEditorController

local MAX_MOTION_DURATION = 30
local MAX_MOTION_FRAMES = 300

--[[
	조작 창 크기.

	요청: "UI 자체를 문 애니메이터처럼 하나의 작은 창에 다 때려박는 식으로 하자는거야.
	       큰 화면에선 모션을 크게 보면서 수정 하고."

	예전에는 편집기가 화면을 통째로 덮고, 캐릭터는 가운데 작은 상자에만 보였다.
	이제는 반대다 — 화면 전체가 모션이고, 조작은 이 크기의 떠 있는 창 하나가 맡는다.
	창이 좁으므로 포즈/미리보기/속성은 나란히 놓지 않고 메뉴 줄로 한 장씩 갈아 끼운다.
]]
local WINDOW_DEFAULT_WIDTH = 560
local WINDOW_DEFAULT_HEIGHT = 500
-- 요청: "UI 창 크기 조절을 할 수 있어야 함." 오른쪽 아래 손잡이로 늘린다.
-- 이보다 작아지면 하단 독의 타임라인이 잘려 나가므로 최소치를 둔다.
local WINDOW_MIN_WIDTH = 430
local WINDOW_MIN_HEIGHT = 420

local JOINTS = { "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip", "Neck", "RootJoint" }
local PRESET_ORDER = {
	{ Key = "Basic", Label = "평타" },
	{ Key = "Heavy", Label = "강공격" },
	{ Key = "Skill1", Label = "스킬 1" },
	{ Key = "Skill2", Label = "스킬 2" },
	{ Key = "Skill3", Label = "스킬 3" },
	{ Key = "Ultimate", Label = "궁극기" },
	{ Key = "Guard", Label = "가드" },
	{ Key = "Dash", Label = "대시" },
	{ Key = "Idle", Label = "대기" },
	{ Key = "Walk", Label = "걷기" },
	{ Key = "Jump", Label = "점프" },
	{ Key = "Hit", Label = "피격" },
}
local STATUS_TYPES = {
	{ Key = "slow", Label = "둔화" },
	{ Key = "bleed", Label = "출혈" },
	{ Key = "burn", Label = "화상" },
	{ Key = "stun", Label = "기절" },
	{ Key = "airborne", Label = "에어본" },
}
local BUFF_TYPES = {
	{ Key = "damageUp", Label = "대미지 증가" },
	{ Key = "dotGuard", Label = "도트 피해 감소" },
	{ Key = "skillGuard", Label = "스킬 피해 감소" },
	{ Key = "moveSpeed", Label = "이동속도 증가" },
	{ Key = "shield", Label = "방어막" },
	{ Key = "iframe", Label = "무적 프레임" },
}
local EFFECT_PRESETS = {
	{ Key = "slash", Label = "베기" },
	{ Key = "spark", Label = "반짝임" },
	{ Key = "burst", Label = "폭발" },
	{ Key = "ring", Label = "링" },
	{ Key = "smoke", Label = "연기" },
}
local GIZMO_PARTS = {
	["Torso"] = "RootJoint",
	["Head"] = "Neck",
	["Right Arm"] = "Right Shoulder",
	["Left Arm"] = "Left Shoulder",
	["Right Leg"] = "Right Hip",
	["Left Leg"] = "Left Hip",
}
local GIZMO_PART_OPTIONS = {
	{ Name = "Torso", Label = "몸통" },
	{ Name = "Head", Label = "머리" },
	{ Name = "Right Arm", Label = "오른팔" },
	{ Name = "Left Arm", Label = "왼팔" },
	{ Name = "Right Leg", Label = "오른다리" },
	{ Name = "Left Leg", Label = "왼다리" },
}

local TORSO_CHILD_JOINTS = { "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }
local GIZMO_AXES = {
	{ Name = "X", Vector = Vector3.xAxis, Color = Color3.fromRGB(255, 82, 82) },
	{ Name = "Y", Vector = Vector3.yAxis, Color = Color3.fromRGB(94, 230, 112) },
	{ Name = "Z", Vector = Vector3.zAxis, Color = Color3.fromRGB(86, 145, 255) },
}
local GIZMO_REFERENCE_POINTS = {
	{ Id = "Up", Axis = "X", Direction = Vector3.yAxis, Color = Color3.fromRGB(255, 82, 82) },
	{ Id = "Down", Axis = "X", Direction = -Vector3.yAxis, Color = Color3.fromRGB(255, 82, 82) },
	{ Id = "Right", Axis = "Z", Direction = Vector3.xAxis, Color = Color3.fromRGB(86, 145, 255) },
	{ Id = "Left", Axis = "Z", Direction = -Vector3.xAxis, Color = Color3.fromRGB(86, 145, 255) },
	{ Id = "Front", Axis = "Y", Direction = -Vector3.zAxis, Color = Color3.fromRGB(94, 230, 112) },
	{ Id = "Back", Axis = "Y", Direction = Vector3.zAxis, Color = Color3.fromRGB(94, 230, 112) },
}
local GIZMO_RING_SEGMENTS = 32

--[[
	Moon Animator식 다크 에디터 팔레트.

	사양(추가&수정.md `## 모션 제작 기능`)
	  "UI를 Moon Animator의 UI를 베이스로 함."
	  "기존에 있던 얼불춤식 UIㅡ패널 형태는 폐기."

	예전 값은 나무·금박·양피지(공방 책상) 색이었다. 키 이름은 그대로 두고 **값만**
	바꾼다 — 6천 줄 전체가 이 표를 참조하므로, 이렇게 하면 위젯을 하나도 건드리지
	않고 화면 전체가 에디터 룩으로 바뀐다(기능 손실 0).

	키 이름은 이제 재질이 아니라 **역할**로 읽어야 한다:
	  Board/Wood/WoodDark = 창·독 배경 단계   WoodLight = 경계선
	  Panel/PanelAlt      = 패널·컨트롤 배경   Parchment = 본문 글자
	  Gold/GoldLight      = 키프레임 앰버(선택된 키)  Blue = 선택 하이라이트
]]
local THEME = {
	Board = Color3.fromRGB(24, 24, 26),
	Wood = Color3.fromRGB(37, 37, 40),
	WoodDark = Color3.fromRGB(18, 18, 20),
	WoodLight = Color3.fromRGB(62, 62, 70),
	Panel = Color3.fromRGB(30, 30, 33),
	PanelAlt = Color3.fromRGB(45, 45, 50),
	Gold = Color3.fromRGB(232, 179, 57),
	GoldLight = Color3.fromRGB(255, 205, 90),
	Parchment = Color3.fromRGB(228, 228, 232),
	Muted = Color3.fromRGB(150, 150, 158),
	Green = Color3.fromRGB(78, 201, 160),
	GreenDark = Color3.fromRGB(28, 90, 74),
	Cyan = Color3.fromRGB(79, 193, 255),
	Red = Color3.fromRGB(241, 76, 76),
	Blue = Color3.fromRGB(0, 122, 204),
}

local QUICK_TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function cframeAlongX(startPosition: Vector3, endPosition: Vector3): CFrame
	local direction = endPosition - startPosition
	local right = direction.Magnitude > 0.001 and direction.Unit or Vector3.xAxis
	local seed = math.abs(right:Dot(Vector3.yAxis)) > 0.98 and Vector3.zAxis or Vector3.yAxis
	local back = right:Cross(seed).Unit
	local up = back:Cross(right).Unit
	return CFrame.fromMatrix((startPosition + endPosition) * 0.5, right, up, back)
end

local function pointToSegmentDistance(point: Vector2, startPoint: Vector2, endPoint: Vector2): number
	local segment = endPoint - startPoint
	local lengthSquared = segment:Dot(segment)
	if lengthSquared < 0.001 then
		return (point - startPoint).Magnitude
	end
	local alpha = math.clamp((point - startPoint):Dot(segment) / lengthSquared, 0, 1)
	return (point - (startPoint + segment * alpha)).Magnitude
end

local function centeredJointTransform(motor: Motor6D, offset: any, pose: any, rotationData: any?): CFrame
	-- Motor6D normally rotates around its attachment (shoulder, neck, hip).
	-- C1^-1 places Part1's center in joint space, so wrapping the rotation
	-- around that point keeps the selected body part's own center fixed.
	local pivot = motor.C1:Inverse().Position
	local rotation = RotationUtil.ToCFrame(rotationData, pose)
	return CFrame.new(offset.X or 0, offset.Y or 0, offset.Z or 0) * CFrame.new(pivot) * rotation * CFrame.new(-pivot)
end

local function addStroke(target: GuiObject, color: Color3, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = target
	return stroke
end

local function addPadding(target: GuiObject, amount: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, amount)
	padding.PaddingBottom = UDim.new(0, amount)
	padding.PaddingLeft = UDim.new(0, amount)
	padding.PaddingRight = UDim.new(0, amount)
	padding.Parent = target
end

local function makePanel(parent: Instance, color: Color3?, strokeColor: Color3?): Frame
	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = color or THEME.Panel
	panel.BorderSizePixel = 0
	panel.Parent = parent
	-- Moon Animator 독은 평평하다. 예전의 양피지 그라디언트(위 흰색 → 아래 누런색)는
	-- 나무 책상 느낌을 내던 것이라 뺐다. 경계선도 2px 금테에서 1px 회색으로 낮춘다.
	addStroke(panel, strokeColor or THEME.WoodLight, 1)
	return panel
end

--[[
	예전에는 세로 나뭇결 + 가로 판자 이음새를 그려 "나무 책상"을 만들었다(얼불춤식).
	Moon Animator의 독은 무늬 없는 평면이라 이음새를 전부 걷어냈다.

	호출부가 30곳 가까이 되므로 **함수는 남겨 둔다** — 시그니처를 유지해야 호출부를
	하나도 안 고친다. 남은 역할은 두 가지다:
	  - ClipsDescendants: 예전 레이아웃이 이 값에 기대고 있어 그대로 둔다.
	  - 아래쪽 1px 구분선: 독과 독 사이를 가르는 에디터식 경계.
	columns는 이제 쓰지 않지만, 호출부 수정을 피하려고 인자만 받아 둔다.
]]
local function addWoodGrid(target: GuiObject, columns: number)
	target.ClipsDescendants = true
	local _ = columns

	local edge = Instance.new("Frame")
	edge.Name = "DockEdge"
	edge.Size = UDim2.new(1, 0, 0, 1)
	edge.Position = UDim2.new(0, 0, 1, -1)
	edge.BackgroundColor3 = THEME.WoodDark
	edge.BackgroundTransparency = 0.35
	edge.BorderSizePixel = 0
	edge.Active = false
	edge.ZIndex = 0
	edge.Parent = target
end

local function makeButton(parent: Instance, text: string, width: number?, height: number?): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(width or 110, height or 34)
	button.BackgroundColor3 = THEME.PanelAlt
	button.BorderSizePixel = 0
	button.TextColor3 = THEME.Parchment
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextWrapped = true
	button.Text = text
	button.AutoButtonColor = false
	button.Parent = parent
	button:SetAttribute("BaseColor", THEME.PanelAlt)
	button:SetAttribute("StrokeColor", THEME.WoodLight)
	local stroke = addStroke(button, THEME.WoodLight, 1)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, QUICK_TWEEN, { BackgroundColor3 = THEME.WoodLight }):Play()
		stroke.Color = THEME.Gold
	end)
	button.MouseLeave:Connect(function()
		TweenService
			:Create(button, QUICK_TWEEN, { BackgroundColor3 = button:GetAttribute("BaseColor") or THEME.PanelAlt })
			:Play()
		stroke.Color = button:GetAttribute("StrokeColor") or THEME.WoodLight
		button.TextTransparency = 0
	end)
	button.MouseButton1Down:Connect(function()
		button.TextTransparency = 0.18
	end)
	button.MouseButton1Up:Connect(function()
		button.TextTransparency = 0
	end)
	return button
end

local function styleButton(button: TextButton, accent: Color3, background: Color3?, textColor: Color3?)
	local base = background or THEME.PanelAlt
	button.BackgroundColor3 = base
	button.TextColor3 = textColor or accent
	button:SetAttribute("BaseColor", base)
	button:SetAttribute("StrokeColor", accent)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = accent
	end
end

local function makeInput(parent: Instance, placeholder: string, width: number): TextBox
	local input = Instance.new("TextBox")
	input.Size = UDim2.fromOffset(width, 34)
	input.BackgroundColor3 = THEME.PanelAlt
	input.BorderSizePixel = 0
	input.TextColor3 = THEME.Parchment
	input.PlaceholderColor3 = THEME.Muted
	input.PlaceholderText = placeholder
	input.Font = Enum.Font.RobotoMono
	input.TextSize = 11
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.ClearTextOnFocus = false
	input.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = input
	local stroke = addStroke(input, THEME.WoodLight, 1)
	input.Focused:Connect(function()
		stroke.Color = THEME.Gold
	end)
	input.FocusLost:Connect(function()
		stroke.Color = THEME.WoodLight
	end)
	return input
end

local function clearButtons(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function vector(x: number?, y: number?, z: number?): any
	return { X = x or 0, Y = y or 0, Z = z or 0 }
end

local function defaultWeapon(): any
	return {
		Position = vector(),
		Rotation = vector(),
		AssetId = "",
		Size = vector(0.35, 3, 0.12),
		FlipX = false,
		FlipY = false,
	}
end

local function copyVector(source: any): any
	return vector(source and source.X, source and source.Y, source and source.Z)
end

local function copyWeapon(source: any): any
	local weapon = source or defaultWeapon()
	return {
		Position = copyVector(weapon.Position),
		Rotation = copyVector(weapon.Rotation),
		AssetId = tostring(weapon.AssetId or ""),
		Size = copyVector(weapon.Size or vector(0.35, 3, 0.12)),
		FlipX = weapon.FlipX == true,
		FlipY = weapon.FlipY == true,
	}
end

local function wantedLayerKeys(frame: any, dualWield: boolean): { string }
	local keys = { "Player", "Weapon" }
	if dualWield then
		table.insert(keys, "DualWeapon")
	end
	for index = 1, #(frame.Decorations or {}) do
		table.insert(keys, "Decoration:" .. index)
	end
	return keys
end

local function normalizeLayerOrder(frame: any, dualWield: boolean): { string }
	local wanted = wantedLayerKeys(frame, dualWield)
	local allowed = {}
	for _, key in wanted do
		allowed[key] = true
	end
	local result = {}
	local used = {}
	for _, key in frame.LayerOrder or {} do
		if allowed[key] and not used[key] then
			table.insert(result, key)
			used[key] = true
		end
	end
	for _, key in wanted do
		if not used[key] then
			table.insert(result, key)
		end
	end
	frame.LayerOrder = result
	return result
end

local function layerDepth(frame: any, dualWield: boolean, key: string): number
	local order = normalizeLayerOrder(frame, dualWield)
	local playerIndex = table.find(order, "Player") or 1
	local itemIndex = table.find(order, key) or playerIndex
	return (itemIndex - playerIndex) * 0.08
end

local function copyFrame(source: any): any
	local joints = {}
	for name, pose in source.Joints or {} do
		joints[name] = copyVector(pose)
	end
	local jointOffsets = {}
	for name, offset in source.JointOffsets or {} do
		jointOffsets[name] = copyVector(offset)
	end
	local jointRotations = {}
	for name, rotation in source.JointRotations or {} do
		jointRotations[name] = {
			X = tonumber(rotation.X) or 0,
			Y = tonumber(rotation.Y) or 0,
			Z = tonumber(rotation.Z) or 0,
			W = tonumber(rotation.W) or 1,
		}
	end
	local decorations = {}
	for _, decoration in source.Decorations or {} do
		table.insert(decorations, {
			Name = tostring(decoration.Name or "장식"),
			AssetId = tostring(decoration.AssetId or ""),
			Attach = decoration.Attach == "Head" and "Head" or "Root",
			Offset = copyVector(decoration.Offset),
			Rotation = copyVector(decoration.Rotation),
			Size = copyVector(decoration.Size or vector(2, 2, 0.12)),
			Layer = tonumber(decoration.Layer) or 1,
		})
	end
	local layerOrder = {}
	for _, key in source.LayerOrder or {} do
		table.insert(layerOrder, tostring(key))
	end
	return {
		Time = source.Time,
		Joints = joints,
		JointRotations = jointRotations,
		JointOffsets = jointOffsets,
		CastDirection = source.CastDirection,
		RootOffset = copyVector(source.RootOffset),
		Weapon = copyWeapon(source.Weapon),
		DualWeapon = source.DualWeapon and copyWeapon(source.DualWeapon) or nil,
		HandSwap = source.HandSwap == true,
		Decorations = decorations,
		LayerOrder = layerOrder,
	}
end

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = deepCopy(child)
	end
	return result
end

local function normalizeAssetId(value: string): string
	local digits = string.match(value, "%d+")
	return digits and ("rbxassetid://" .. digits) or ""
end

local function normalizeHex(value: string): string
	local digits = string.upper(string.gsub(value, "[^%x]", ""))
	if #digits == 3 then
		digits = string.sub(digits, 1, 1):rep(2) .. string.sub(digits, 2, 2):rep(2) .. string.sub(digits, 3, 3):rep(2)
	end
	return #digits == 6 and ("#" .. digits) or "#FFFFFF"
end

local function colorFromHex(value: string): Color3
	local normalized = normalizeHex(value)
	return Color3.fromRGB(
		tonumber(string.sub(normalized, 2, 3), 16) or 255,
		tonumber(string.sub(normalized, 4, 5), 16) or 255,
		tonumber(string.sub(normalized, 6, 7), 16) or 255
	)
end

local function defaultCombat(presetKey: string): any
	local isUtility = presetKey == "Idle" or presetKey == "Walk" or presetKey == "Jump" or presetKey == "Hit"
	return {
		Enabled = not isUtility,
		Damage = presetKey == "Ultimate" and 60 or (presetKey == "Guard" or presetKey == "Dash") and 0 or 20,
		CooldownTurns = (presetKey == "Basic" or presetKey == "Heavy" or presetKey == "Ultimate") and 0 or 2,
		Knockback = 0,
		TargetCount = 1,
		CastDirection = "target",
		Ranged = false,
		UltimateGain = (presetKey == "Basic" or presetKey == "Heavy") and 5 or 10,
		DashDistance = presetKey == "Dash" and 120 or 0,
		HeavyAfter = presetKey == "Heavy" and 3 or 0,
		Statuses = {},
		Buffs = {},
	}
end

local function newMotion(id: string, name: string): any
	return {
		Id = id,
		Name = name,
		Description = "",
		Duration = 0.8,
		DualWield = false,
		Complete = false,
		Combat = defaultCombat(id),
		Frames = {
			{
				Time = 0,
				Joints = {},
				JointRotations = {},
				JointOffsets = {},
				CastDirection = "target",
				RootOffset = vector(),
				Weapon = defaultWeapon(),
				Decorations = {},
				LayerOrder = { "Player", "Weapon" },
			},
			{
				Time = 0.8,
				Joints = {},
				JointRotations = {},
				JointOffsets = {},
				RootOffset = vector(),
				Weapon = defaultWeapon(),
				Decorations = {},
				LayerOrder = { "Player", "Weapon" },
			},
		},
		Hits = {},
		Events = { Effects = {}, Projectiles = {}, Teleports = {} },
	}
end

local function makeSection(parent: Instance, text: string): TextButton
	local title = Instance.new("TextButton")
	title.Size = UDim2.new(1, 0, 0, 34)
	title.BackgroundColor3 = THEME.PanelAlt
	title.BorderSizePixel = 0
	title.TextColor3 = THEME.GoldLight
	title.Font = Enum.Font.RobotoMono
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "     ▼  " .. string.upper(text)
	title.AutoButtonColor = false
	title:SetAttribute("SectionTitle", string.upper(text))
	title:SetAttribute("IsSectionHeader", true)
	title:SetAttribute("Collapsed", false)
	title.Parent = parent
	addStroke(title, THEME.WoodLight, 1)
	local accent = Instance.new("Frame")
	accent.Name = "SectionAccent"
	accent.Size = UDim2.new(0, 4, 1, -8)
	accent.Position = UDim2.fromOffset(4, 4)
	accent.BackgroundColor3 = THEME.Green
	accent.BorderSizePixel = 0
	accent.Parent = title
	title.Activated:Connect(function()
		local collapsed = not title:GetAttribute("Collapsed")
		title:SetAttribute("Collapsed", collapsed)
		title.Text = string.format("     %s  %s", collapsed and "▶" or "▼", title:GetAttribute("SectionTitle"))
		local siblings = {}
		for _, child in title.Parent:GetChildren() do
			if child:IsA("GuiObject") then
				table.insert(siblings, child)
			end
		end
		table.sort(siblings, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		local found = false
		for _, sibling in siblings do
			if sibling == title then
				found = true
			elseif found and sibling:GetAttribute("IsSectionHeader") then
				break
			elseif found then
				sibling.Visible = not collapsed and sibling:GetAttribute("DetailActive") ~= false
			end
		end
	end)
	return title
end

local function makeDeskHeader(parent: Instance, index: string, titleText: string, caption: string, accent: Color3)
	local header = Instance.new("Frame")
	header.Name = "DeskHeader"
	header.Size = UDim2.new(1, 0, 0, 42)
	header.BackgroundColor3 = THEME.Wood
	header.BorderSizePixel = 0
	header.Parent = parent
	addStroke(header, THEME.WoodLight, 1)

	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(0, 5, 1, 0)
	accentBar.BackgroundColor3 = accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = header

	local indexLabel = Instance.new("TextLabel")
	indexLabel.Size = UDim2.fromOffset(42, 42)
	indexLabel.Position = UDim2.fromOffset(10, 0)
	indexLabel.BackgroundTransparency = 1
	indexLabel.Text = index
	indexLabel.TextColor3 = accent
	indexLabel.Font = Enum.Font.RobotoMono
	indexLabel.TextSize = 15
	indexLabel.TextXAlignment = Enum.TextXAlignment.Left
	indexLabel.Parent = header

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -58, 0, 22)
	label.Position = UDim2.fromOffset(52, 3)
	label.BackgroundTransparency = 1
	label.Text = titleText
	label.TextColor3 = THEME.GoldLight
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = header

	local captionLabel = Instance.new("TextLabel")
	captionLabel.Size = UDim2.new(1, -58, 0, 14)
	captionLabel.Position = UDim2.fromOffset(52, 24)
	captionLabel.BackgroundTransparency = 1
	captionLabel.Text = caption
	captionLabel.TextColor3 = THEME.Muted
	captionLabel.Font = Enum.Font.RobotoMono
	captionLabel.TextSize = 9
	captionLabel.TextXAlignment = Enum.TextXAlignment.Left
	captionLabel.Parent = header
	return header
end

function MotionEditorController:_resetPack(characterId: string?)
	local wantedCharacterId = tostring(characterId or self.SelectedCharacterId)
	self.AuthorCharacterId = CharacterDefinitions.IsValid(wantedCharacterId) and wantedCharacterId or "Berserker"
	self.ActivePreset = "Basic"
	self.PackName = "새 모션 세트"
	self.PackDescription = ""
	self.BodyColorHex = "#E8D5A3"
	self.PresetMotions = {}
	for _, preset in PRESET_ORDER do
		self.PresetMotions[preset.Key] = newMotion(preset.Key, preset.Label)
	end
	self.Motion = self.PresetMotions.Basic
	self.SelectedFrame = 1
	self.SelectedHit = 1
	self.CurrentPackId = nil
end

function MotionEditorController:_loadPackForEditing(packId: string, pack: any)
	self.CurrentPackId = packId
	self.SelectedPackId = packId
	self.PackName = pack.Name or "내 모션"
	self.PackDescription = pack.Description or ""
	self.BodyColorHex = pack.BodyColorHex or "#E8D5A3"
	local authorCharacterId = tostring(pack.AuthorCharacterId or self.SelectedCharacterId)
	self.AuthorCharacterId = CharacterDefinitions.IsValid(authorCharacterId) and authorCharacterId or "Berserker"
	self.PresetMotions = deepCopy(pack.Presets or {})
	for _, preset in PRESET_ORDER do
		if not self.PresetMotions[preset.Key] then
			self.PresetMotions[preset.Key] = newMotion(preset.Key, preset.Label)
		end
	end
	self.ActivePreset = self.PresetMotions[pack.ActivePreset] and pack.ActivePreset or "Basic"
	self.Motion = self.PresetMotions[self.ActivePreset]
	self.SelectedFrame = 1
	self.SelectedHit = 1
end

function MotionEditorController:_setInventoryOpen(enabled: boolean)
	self.InventoryGui.Enabled = enabled
	if self.LaunchGui then
		self.LaunchGui.Enabled = not enabled
	end
	if enabled then
		self.Gui.Enabled = false
		self.CreationGui.Enabled = false
		self:_refreshInventorySelector()
	end
end

function MotionEditorController:_setCreationOpen(enabled: boolean)
	self.CreationGui.Enabled = enabled
	if self.LaunchGui then
		self.LaunchGui.Enabled = not enabled
	end
	if enabled then
		self.Gui.Enabled = false
		self.InventoryGui.Enabled = false
		self:_refreshCreationSelector()
	end
end

function MotionEditorController:_refreshCreationSelector()
	if not self.CreationGui then
		return
	end
	local definition = CharacterDefinitions.Get(self.CreationCharacterId)
	self.CreationTitle.Text = string.format("%s · %s", definition.Name, definition.Role)
	self.CreationDescription.Text = string.format(
		"%s\nHP %d   이동 %.2f   평타 %d   고유 기술 %s / %d",
		definition.Description,
		definition.MaxHealth,
		definition.MoveSpeed,
		definition.BasicPower,
		definition.Skill.Name,
		definition.Skill.Power
	)
	for characterId, characterButton in self.CreationCharacterButtons do
		local selected = characterId == self.CreationCharacterId
		characterButton.BackgroundColor3 = selected and THEME.GreenDark or THEME.PanelAlt
		characterButton.TextColor3 = selected and THEME.Green or THEME.Parchment
	end
end

function MotionEditorController:_buildCreationSelector()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MotionCreationSelectorGui"
	gui.Enabled = false
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 21
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.CreationGui = gui

	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(5, 4, 3)
	shade.BackgroundTransparency = 0.08
	shade.BorderSizePixel = 0
	shade.Parent = gui

	local panel = makePanel(gui, THEME.Board, THEME.Green)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(920, 620)
	addWoodGrid(panel, 18)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function updateScale()
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(size.X / 980, size.Y / 670), 0.55, 1)
	end
	updateScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Position = UDim2.fromOffset(24, 14)
	heading.Size = UDim2.fromOffset(700, 42)
	heading.Text = "모션 제작 · 기준 직업 선택"
	heading.TextColor3 = THEME.Green
	heading.Font = Enum.Font.GothamBlack
	heading.TextSize = 24
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Parent = panel

	local close = makeButton(panel, "취소 ×", 90, 34)
	close.Position = UDim2.new(1, -110, 0, 18)
	styleButton(close, THEME.Red)
	close.Activated:Connect(function()
		self:_setCreationOpen(false)
	end)

	local characterList = Instance.new("ScrollingFrame")
	characterList.Position = UDim2.fromOffset(22, 68)
	characterList.Size = UDim2.fromOffset(876, 390)
	characterList.BackgroundColor3 = THEME.Panel
	characterList.BorderSizePixel = 0
	characterList.ScrollBarThickness = 7
	characterList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	characterList.CanvasSize = UDim2.new()
	characterList.Parent = panel
	addStroke(characterList, THEME.WoodLight, 2)
	addPadding(characterList, 8)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(206, 112)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = characterList
	self.CreationCharacterButtons = {}
	for index, definition in CharacterDefinitions.All() do
		local characterButton = Instance.new("TextButton")
		characterButton.LayoutOrder = index
		characterButton.BackgroundColor3 = THEME.PanelAlt
		characterButton.BorderSizePixel = 0
		characterButton.Text = string.format(
			"%s  [%s]\nHP %d  이동 %.2f\n평타 %d  기술 %d",
			definition.Name,
			definition.Role,
			definition.MaxHealth,
			definition.MoveSpeed,
			definition.BasicPower,
			definition.Skill.Power
		)
		characterButton.TextColor3 = THEME.Parchment
		characterButton.TextWrapped = true
		characterButton.Font = Enum.Font.GothamBold
		characterButton.TextSize = 13
		characterButton.Parent = characterList
		addStroke(characterButton, definition.Color, 2)
		self.CreationCharacterButtons[definition.Id] = characterButton
		characterButton.Activated:Connect(function()
			self.CreationCharacterId = definition.Id
			self:_refreshCreationSelector()
		end)
	end

	local info = makePanel(panel, THEME.PanelAlt, THEME.WoodLight)
	info.Position = UDim2.fromOffset(22, 474)
	info.Size = UDim2.fromOffset(650, 124)
	self.CreationTitle = Instance.new("TextLabel")
	self.CreationTitle.BackgroundTransparency = 1
	self.CreationTitle.Position = UDim2.fromOffset(14, 8)
	self.CreationTitle.Size = UDim2.new(1, -28, 0, 25)
	self.CreationTitle.TextColor3 = THEME.GoldLight
	self.CreationTitle.Font = Enum.Font.GothamBold
	self.CreationTitle.TextSize = 17
	self.CreationTitle.TextXAlignment = Enum.TextXAlignment.Left
	self.CreationTitle.Parent = info
	self.CreationDescription = Instance.new("TextLabel")
	self.CreationDescription.BackgroundTransparency = 1
	self.CreationDescription.Position = UDim2.fromOffset(14, 36)
	self.CreationDescription.Size = UDim2.new(1, -28, 0, 76)
	self.CreationDescription.TextColor3 = THEME.Parchment
	self.CreationDescription.Font = Enum.Font.Gotham
	self.CreationDescription.TextSize = 13
	self.CreationDescription.TextWrapped = true
	self.CreationDescription.TextXAlignment = Enum.TextXAlignment.Left
	self.CreationDescription.TextYAlignment = Enum.TextYAlignment.Top
	self.CreationDescription.Parent = info

	local start = makeButton(panel, "이 직업 모션 제작", 204, 64)
	start.Position = UDim2.fromOffset(694, 504)
	styleButton(start, THEME.Green, THEME.GreenDark)
	start.Activated:Connect(function()
		self.SelectedCharacterId = self.CreationCharacterId
		self:_resetPack(self.CreationCharacterId)
		self:_setCreationOpen(false)
		self:_setOpen(true)
		self:_refreshAll()
	end)
	self:_refreshCreationSelector()
end

function MotionEditorController:_refreshInventorySelector()
	if not self.InventoryGui then
		return
	end
	local definition = CharacterDefinitions.Get(self.SelectedCharacterId)
	self.SelectorTitle.Text = string.format("%s · %s", definition.Name, definition.Role)
	self.SelectorDescription.Text = string.format(
		"%s\nHP %d   이동 %.2f   평타 %d   고유 기술 %s / %d",
		definition.Description,
		definition.MaxHealth,
		definition.MoveSpeed,
		definition.BasicPower,
		definition.Skill.Name,
		definition.Skill.Power
	)
	for characterId, button in self.CharacterSelectorButtons do
		local selected = characterId == self.SelectedCharacterId
		button.BackgroundColor3 = selected and THEME.GreenDark or THEME.PanelAlt
		button.TextColor3 = selected and THEME.Green or THEME.Parchment
	end
	for _, child in self.PackSelectorList:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local newButton = makeButton(self.PackSelectorList, "+ 새 모션 세트", 0, 48)
	newButton.Size = UDim2.new(1, -8, 0, 48)
	newButton.LayoutOrder = 0
	styleButton(newButton, THEME.Green, THEME.GreenDark)
	newButton.Activated:Connect(function()
		self.SelectedPackId = nil
		self:_refreshInventorySelector()
	end)
	local ids = {}
	for packId in self.Inventory.Packs or {} do
		table.insert(ids, tostring(packId))
	end
	table.sort(ids)
	local equippedId = self.Inventory.Equipped and self.Inventory.Equipped[self.SelectedCharacterId]
	for index, packId in ids do
		local pack = self.Inventory.Packs[packId]
		local authorCharacterId = tostring(pack.AuthorCharacterId or "")
		local authorLabel = CharacterDefinitions.IsValid(authorCharacterId)
				and CharacterDefinitions.Get(authorCharacterId).Name
			or "공용"
		local selected = packId == self.SelectedPackId
		local equipped = packId == equippedId
		local button = makeButton(
			self.PackSelectorList,
			string.format(
				"%s%s  ·  제작 기준 %s\n%s",
				equipped and "[장착] " or "",
				pack.Name or "이름 없는 모션",
				authorLabel,
				pack.Description or ""
			),
			0,
			58
		)
		button.Size = UDim2.new(1, -8, 0, 58)
		button.LayoutOrder = index
		button.TextWrapped = true
		button.TextXAlignment = Enum.TextXAlignment.Left
		styleButton(
			button,
			selected and THEME.GoldLight or THEME.Parchment,
			selected and THEME.WoodLight or THEME.PanelAlt
		)
		button.Activated:Connect(function()
			self.SelectedPackId = packId
			self:_refreshInventorySelector()
		end)
	end
	local selectedPack = self.SelectedPackId and self.Inventory.Packs[self.SelectedPackId]
	self.EquipSelectorButton.Text = selectedPack and "선택 모션 장착" or "기본 모션 사용"
	self.EditSelectorButton.Text = selectedPack and "선택 모션 편집" or "새 모션 제작"
	self.SelectorProgress.Text = string.format("최고 기록  %d / 30층", tonumber(self.Inventory.HighestFloor) or 0)
end

function MotionEditorController:_buildInventorySelector()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MotionInventoryGui"
	gui.Enabled = false
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.InventoryGui = gui

	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(5, 4, 3)
	shade.BackgroundTransparency = 0.08
	shade.BorderSizePixel = 0
	shade.Parent = gui

	local panel = makePanel(gui, THEME.Board, THEME.Gold)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(1040, 650)
	addWoodGrid(panel, 20)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function updateScale()
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 700), 0.55, 1)
	end
	updateScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Position = UDim2.fromOffset(24, 14)
	heading.Size = UDim2.fromOffset(700, 42)
	heading.Text = "모션 인벤토리 · 직업별 모션 장착"
	heading.TextColor3 = THEME.GoldLight
	heading.Font = Enum.Font.GothamBlack
	heading.TextSize = 24
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Parent = panel

	local close = makeButton(panel, "닫기 ×", 90, 34)
	close.Position = UDim2.new(1, -110, 0, 18)
	styleButton(close, THEME.Red)
	close.Activated:Connect(function()
		self:_setInventoryOpen(false)
	end)

	local characterList = Instance.new("ScrollingFrame")
	characterList.Position = UDim2.fromOffset(22, 68)
	characterList.Size = UDim2.fromOffset(636, 432)
	characterList.BackgroundColor3 = THEME.Panel
	characterList.BorderSizePixel = 0
	characterList.ScrollBarThickness = 7
	characterList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	characterList.CanvasSize = UDim2.new()
	characterList.Parent = panel
	addStroke(characterList, THEME.WoodLight, 2)
	addPadding(characterList, 8)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(196, 112)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = characterList
	self.CharacterSelectorButtons = {}
	for index, definition in CharacterDefinitions.All() do
		local button = Instance.new("TextButton")
		button.LayoutOrder = index
		button.BackgroundColor3 = THEME.PanelAlt
		button.BorderSizePixel = 0
		button.Text = string.format(
			"%s  [%s]\nHP %d  이동 %.2f\n평타 %d  기술 %d",
			definition.Name,
			definition.Role,
			definition.MaxHealth,
			definition.MoveSpeed,
			definition.BasicPower,
			definition.Skill.Power
		)
		button.TextColor3 = THEME.Parchment
		button.TextWrapped = true
		button.Font = Enum.Font.GothamBold
		button.TextSize = 13
		button.Parent = characterList
		addStroke(button, definition.Color, 2)
		self.CharacterSelectorButtons[definition.Id] = button
		button.Activated:Connect(function()
			self.SelectedCharacterId = definition.Id
			self.SelectedPackId = self.Inventory.Equipped and self.Inventory.Equipped[definition.Id]
			self:_refreshInventorySelector()
		end)
	end

	local packList = Instance.new("ScrollingFrame")
	packList.Position = UDim2.fromOffset(676, 68)
	packList.Size = UDim2.fromOffset(342, 432)
	packList.BackgroundColor3 = THEME.Panel
	packList.BorderSizePixel = 0
	packList.ScrollBarThickness = 7
	packList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	packList.CanvasSize = UDim2.new()
	packList.Parent = panel
	addStroke(packList, THEME.WoodLight, 2)
	addPadding(packList, 6)
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = packList
	self.PackSelectorList = packList

	local info = makePanel(panel, THEME.PanelAlt, THEME.WoodLight)
	info.Position = UDim2.fromOffset(22, 516)
	info.Size = UDim2.fromOffset(636, 112)
	self.SelectorTitle = Instance.new("TextLabel")
	self.SelectorTitle.BackgroundTransparency = 1
	self.SelectorTitle.Position = UDim2.fromOffset(14, 8)
	self.SelectorTitle.Size = UDim2.new(1, -28, 0, 25)
	self.SelectorTitle.TextColor3 = THEME.GoldLight
	self.SelectorTitle.Font = Enum.Font.GothamBold
	self.SelectorTitle.TextSize = 17
	self.SelectorTitle.TextXAlignment = Enum.TextXAlignment.Left
	self.SelectorTitle.Parent = info
	self.SelectorDescription = Instance.new("TextLabel")
	self.SelectorDescription.BackgroundTransparency = 1
	self.SelectorDescription.Position = UDim2.fromOffset(14, 36)
	self.SelectorDescription.Size = UDim2.new(1, -28, 0, 64)
	self.SelectorDescription.TextColor3 = THEME.Parchment
	self.SelectorDescription.Font = Enum.Font.Gotham
	self.SelectorDescription.TextSize = 13
	self.SelectorDescription.TextWrapped = true
	self.SelectorDescription.TextXAlignment = Enum.TextXAlignment.Left
	self.SelectorDescription.TextYAlignment = Enum.TextYAlignment.Top
	self.SelectorDescription.Parent = info

	self.SelectorProgress = Instance.new("TextLabel")
	self.SelectorProgress.BackgroundTransparency = 1
	self.SelectorProgress.Position = UDim2.fromOffset(676, 510)
	self.SelectorProgress.Size = UDim2.fromOffset(342, 26)
	self.SelectorProgress.TextColor3 = THEME.GoldLight
	self.SelectorProgress.Font = Enum.Font.RobotoMono
	self.SelectorProgress.TextSize = 13
	self.SelectorProgress.Parent = panel
	self.EquipSelectorButton = makeButton(panel, "선택 모션 장착", 164, 42)
	self.EquipSelectorButton.Position = UDim2.fromOffset(676, 542)
	styleButton(self.EquipSelectorButton, THEME.Blue)
	self.EditSelectorButton = makeButton(panel, "선택 모션 편집", 170, 42)
	self.EditSelectorButton.Position = UDim2.fromOffset(848, 542)
	styleButton(self.EditSelectorButton, THEME.Green, THEME.GreenDark)
	local unequip = makeButton(panel, "기본 모션", 164, 34)
	unequip.Position = UDim2.fromOffset(676, 594)
	styleButton(unequip, THEME.Muted)

	self.EquipSelectorButton.Activated:Connect(function()
		if not self.SelectedPackId then
			return
		end
		self.Remotes.EquipMotion:FireServer(self.SelectedCharacterId, self.SelectedPackId or "")
	end)
	unequip.Activated:Connect(function()
		self.SelectedPackId = nil
		self.Remotes.EquipMotion:FireServer(self.SelectedCharacterId, "")
	end)
	self.EditSelectorButton.Activated:Connect(function()
		local pack = self.SelectedPackId and self.Inventory.Packs[self.SelectedPackId]
		if pack then
			self:_loadPackForEditing(self.SelectedPackId, pack)
		else
			self:_resetPack()
		end
		self:_setInventoryOpen(false)
		self:_setOpen(true)
		self:_refreshAll()
	end)
	self:_refreshInventorySelector()
end

function MotionEditorController.new(remotes: Folder, editorButton: TextButton, inventoryButton: TextButton)
	local self = setmetatable({}, MotionEditorController)
	self.Remotes = remotes
	self.SelectedGizmoPart = "Torso"
	self.HoveredGizmoReference = nil
	self.SelectedFrame = 1
	self.SelectedHit = 1
	self.SelectedEventType = "Effects"
	self.SelectedEvent = 1
	self.SelectedDecoration = 1
	self.SelectedStatus = 1
	self.SelectedBuff = 1
	self.JointEditMode = "Rotate"
	self.OnionEnabled = false
	self.FrameOverviewOpen = false
	self.FrameOverviewSize = 72
	self.FrameOverviewHeight = 180
	self.FrameClipboard = nil
	self.WeaponClipboard = nil
	self.UndoStack = {}
	self.DragState = nil
	self.ActiveTouches = {}
	self.CameraState = {
		Focus = Vector3.new(0, 0.8, 0),
		Yaw = math.pi,
		Pitch = 0,
		Distance = 13.5,
	}
	self.LaunchGui = editorButton:FindFirstAncestorOfClass("ScreenGui")
	self.Inventory = { Packs = {}, Equipped = {}, SelectedCharacterId = "Berserker", HighestFloor = 0 }
	self.SelectedCharacterId = "Berserker"
	self.CreationCharacterId = "Berserker"
	self.AuthorCharacterId = "Berserker"
	self.SelectedPackId = nil
	self.CurrentPackId = nil
	self.ActivePreset = "Basic"
	self.PackName = "내 무기"
	self.PackDescription = ""
	self.BodyColorHex = "#E8D5A3"
	self.PresetMotions = {}
	for _, preset in PRESET_ORDER do
		self.PresetMotions[preset.Key] = newMotion(preset.Key, preset.Label)
	end
	self.Motion = self.PresetMotions[self.ActivePreset]
	self:_buildUi()
	self:_buildInventorySelector()
	self:_buildCreationSelector()
	self:_bindShortcuts()
	editorButton.Activated:Connect(function()
		self:_setInventoryOpen(false)
		self.CreationCharacterId = self.SelectedCharacterId
		self:_setCreationOpen(true)
		self.Remotes.RequestInventory:FireServer()
	end)
	inventoryButton.Activated:Connect(function()
		self:_setInventoryOpen(true)
		self.Remotes.RequestInventory:FireServer()
	end)
	remotes.MotionSaved.OnClientEvent:Connect(function(ok, message, motion, packId)
		self.Status.Text = message
		self.Status.TextColor3 = ok and Color3.fromRGB(110, 235, 145) or Color3.fromRGB(255, 100, 100)
		if ok and motion then
			self.CurrentPackId = packId or self.CurrentPackId
			self.SelectedPackId = packId or self.SelectedPackId
			if motion.Presets then
				self.PresetMotions = motion.Presets
				self.PackName = motion.Name or self.PackName
				self.PackDescription = motion.Description or self.PackDescription
				self.BodyColorHex = motion.BodyColorHex or self.BodyColorHex
				local authorCharacterId = tostring(motion.AuthorCharacterId or self.AuthorCharacterId)
				self.AuthorCharacterId = CharacterDefinitions.IsValid(authorCharacterId) and authorCharacterId
					or "Berserker"
				self.ActivePreset = motion.ActivePreset or self.ActivePreset
				self.Motion = self.PresetMotions[self.ActivePreset] or self.PresetMotions.Basic
			else
				self.PresetMotions[self.ActivePreset] = motion
				self.Motion = motion
			end
			self.SelectedFrame = math.min(self.SelectedFrame, #self.Motion.Frames)
			self:_refreshAll()
		end
	end)
	remotes.InventoryState.OnClientEvent:Connect(function(state)
		if typeof(state) ~= "table" then
			return
		end
		self.Inventory = state
		if CharacterDefinitions.IsValid(tostring(state.SelectedCharacterId)) then
			self.SelectedCharacterId = tostring(state.SelectedCharacterId)
		end
		local equipped = state.Equipped and state.Equipped[self.SelectedCharacterId]
		if not self.SelectedPackId or not state.Packs[self.SelectedPackId] then
			self.SelectedPackId = equipped
		end
		self:_refreshInventorySelector()
	end)
	remotes.RequestInventory:FireServer()
	return self
end

function MotionEditorController:_setOpen(enabled: boolean)
	self.Gui.Enabled = enabled
	if self.LaunchGui then
		self.LaunchGui.Enabled = not enabled
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not enabled)
	end)
	if enabled then
		self:_resetEditorCamera()
		self:_applySelectedFrame()
	else
		self.DragState = nil
	end
end

function MotionEditorController:_pushUndo()
	table.insert(self.UndoStack, { Motion = deepCopy(self.Motion) })
	if #self.UndoStack > 40 then
		table.remove(self.UndoStack, 1)
	end
end

function MotionEditorController:_undo()
	local previous = table.remove(self.UndoStack)
	if not previous then
		self.Status.Text = "  STATUS\n  되돌릴 편집 내역이 없습니다."
		return
	end
	self.Motion = previous.Motion
	self.PresetMotions[self.ActivePreset] = self.Motion
	self.SelectedFrame = math.clamp(self.SelectedFrame, 1, #self.Motion.Frames)
	self.SelectedHit = 1
	self:_refreshAll()
	self.Status.Text = "  STATUS\n  마지막 편집을 되돌렸습니다."
end

function MotionEditorController:_cameraCFrame(): CFrame
	local state = self.CameraState
	local rotation = CFrame.fromEulerAnglesYXZ(state.Pitch, state.Yaw, 0)
	local position = state.Focus + rotation:VectorToWorldSpace(Vector3.new(0, 0, state.Distance))
	return CFrame.lookAt(position, state.Focus)
end

-- 마우스가 조작 창 위에 있는지. 휠을 카메라에 넘길지 목록에 넘길지 가른다.
function MotionEditorController:_pointerOverWindow(pointer: Vector2): boolean
	local window = self.Window
	if not window or not window.Visible then
		return false
	end
	local min = window.AbsolutePosition
	local max = min + window.AbsoluteSize
	return pointer.X >= min.X and pointer.Y >= min.Y and pointer.X <= max.X and pointer.Y <= max.Y
end

function MotionEditorController:_updateEditorCamera()
	if self.EditorCamera then
		self.EditorCamera.CFrame = self:_cameraCFrame()
	end
	if self.CameraReadout then
		self.CameraReadout.Text = string.format("%d%%", math.floor(1200 / self.CameraState.Distance + 0.5))
	end
end

function MotionEditorController:_resetEditorCamera()
	--[[
		뷰포트가 화면 전체가 되면서(작은 상자 → 전체 화면) 같은 거리인데도 캐릭터가
		훨씬 크게 잡혀 발이 화면 밖으로 잘렸다. 초점을 몸 한가운데(뿌리 높이)로 내리고
		거리를 조금 띄워 R6 전신(대략 -3 ~ +2.5)이 여유 있게 들어오도록 맞춘다.
	]]
	self.CameraState.Focus = Vector3.new(0, 0, 0)
	self.CameraState.Yaw = math.pi
	self.CameraState.Pitch = 0
	self.CameraState.Distance = 16
	self:_updateEditorCamera()
end

function MotionEditorController:_projectWorld(worldPosition: Vector3): (Vector2?, number)
	local viewport = self.Viewport
	local camera = self.EditorCamera
	if not viewport or not camera then
		return nil, 0
	end
	local relative = camera.CFrame:PointToObjectSpace(worldPosition)
	local depth = -relative.Z
	if depth <= 0.05 then
		return nil, depth
	end
	local size = viewport.AbsoluteSize
	local focal = size.Y / (2 * math.tan(math.rad(camera.FieldOfView) * 0.5))
	return Vector2.new(size.X * 0.5 + relative.X * focal / depth, size.Y * 0.5 - relative.Y * focal / depth), depth
end

function MotionEditorController:_handleWorldPosition(name: string): Vector3?
	if name == "Weapon" then
		local weapon = self.PreviewWeapon
		return weapon and weapon.CFrame:PointToWorldSpace(Vector3.new(0, -weapon.Size.Y * 0.5, 0)) or nil
	elseif name == "WeaponTip" then
		local weapon = self.PreviewWeapon
		return weapon and weapon.CFrame:PointToWorldSpace(Vector3.new(0, weapon.Size.Y * 0.5, 0)) or nil
	elseif name == "DualWeapon" then
		local weapon = self.PreviewDualWeapon
		return self.Motion.DualWield
				and weapon
				and weapon.CFrame:PointToWorldSpace(Vector3.new(0, -weapon.Size.Y * 0.5, 0))
			or nil
	elseif name == "DualWeaponTip" then
		local weapon = self.PreviewDualWeapon
		return self.Motion.DualWield
				and weapon
				and weapon.CFrame:PointToWorldSpace(Vector3.new(0, weapon.Size.Y * 0.5, 0))
			or nil
	elseif name == "Hitbox" then
		return self.HitboxPreview.Transparency < 1 and self.HitboxPreview.Position or nil
	elseif name == "HitboxSize" then
		if self.HitboxPreview.Transparency >= 1 then
			return nil
		end
		return self.HitboxPreview.CFrame:PointToWorldSpace(self.HitboxPreview.Size * 0.5)
	elseif name == "HitboxRotate" then
		return self.HitboxPreview.Transparency < 1
				and self.HitboxPreview.CFrame:PointToWorldSpace(
					Vector3.new(0, self.HitboxPreview.Size.Y * 0.5 + 0.6, 0)
				)
			or nil
	elseif name == "Event" then
		return self.EventPreview.Transparency < 1 and self.EventPreview.Position or nil
	elseif name == "EventSize" then
		return self.SelectedEventType ~= "Teleports"
				and self.EventPreview.Transparency < 1
				and self.EventPreview.CFrame:PointToWorldSpace(self.EventPreview.Size * 0.5)
			or nil
	elseif name == "EventRotate" then
		return self.SelectedEventType ~= "Teleports"
				and self.EventPreview.Transparency < 1
				and self.EventPreview.CFrame:PointToWorldSpace(Vector3.new(0, self.EventPreview.Size.Y * 0.5 + 0.6, 0))
			or nil
	elseif name == "Decoration" then
		local visual = self.DecorationPreviews and self.DecorationPreviews[self.SelectedDecoration]
		return visual and visual.Transparency < 1 and visual.Position or nil
	elseif name == "DecorationRotate" then
		local visual = self.DecorationPreviews and self.DecorationPreviews[self.SelectedDecoration]
		return visual
				and visual.Transparency < 1
				and visual.CFrame:PointToWorldSpace(Vector3.new(0, visual.Size.Y * 0.5 + 0.5, 0))
			or nil
	end
	return nil
end

local function wrappedAngle(value: number): number
	return (value + 180) % 360 - 180
end

function MotionEditorController:_dragWeaponTip(key: string, pointer: Vector2)
	local part = key == "DualWeapon" and self.PreviewDualWeapon or self.PreviewWeapon
	if not part then
		return
	end
	local grip = part.CFrame:PointToWorldSpace(Vector3.new(0, -part.Size.Y * 0.5, 0))
	local tip = part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y * 0.5, 0))
	local gripScreen = self:_projectWorld(grip)
	local tipScreen = self:_projectWorld(tip)
	if not gripScreen or not tipScreen then
		return
	end
	local currentDelta = tipScreen - gripScreen
	local wantedDelta = pointer - gripScreen
	if wantedDelta.Magnitude < 8 or currentDelta.Magnitude < 2 then
		return
	end
	local currentAngle = math.deg(math.atan2(-currentDelta.X, -currentDelta.Y))
	local wantedAngle = math.deg(math.atan2(-wantedDelta.X, -wantedDelta.Y))
	local frame = self.Motion.Frames[self.SelectedFrame]
	frame[key] = frame[key] or defaultWeapon()
	local weapon = frame[key]
	weapon.Rotation.Z = math.clamp((weapon.Rotation.Z or 0) + wrappedAngle(wantedAngle - currentAngle), -180, 180)
	local unitsPerPixel = self.CameraState.Distance / math.max(280, self.Viewport.AbsoluteSize.Y)
	weapon.Size.Y = math.clamp(wantedDelta.Magnitude * unitsPerPixel, 0.1, 12)
	self:_applySelectedFrame()
	self:_refreshWeaponFields()
	self:_refreshDualFields()
end

function MotionEditorController:_dragRotationPoint(kind: string, pointer: Vector2)
	local part: BasePart? = nil
	local rotation: any = nil
	if kind == "HitboxRotate" then
		local hit = self:_selectedHit()
		part = self.HitboxPreview
		rotation = hit and hit.Hitbox.Rotation
	elseif kind == "DecorationRotate" then
		local decoration = self:_selectedDecoration()
		part = self.DecorationPreviews and self.DecorationPreviews[self.SelectedDecoration]
		rotation = decoration and decoration.Rotation
	elseif kind == "EventRotate" then
		local event = self:_selectedFrameEvent()
		part = self.EventPreview
		rotation = event and event.Rotation
	end
	if not part or not rotation then
		return
	end
	local center = self:_projectWorld(part.Position)
	local top = self:_projectWorld(part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y * 0.5, 0)))
	if not center or not top then
		return
	end
	local currentDelta = top - center
	local wantedDelta = pointer - center
	if wantedDelta.Magnitude < 8 then
		return
	end
	local currentAngle = math.deg(math.atan2(-currentDelta.X, -currentDelta.Y))
	local wantedAngle = math.deg(math.atan2(-wantedDelta.X, -wantedDelta.Y))
	rotation.Z = math.clamp((rotation.Z or 0) + wrappedAngle(wantedAngle - currentAngle), -360, 360)
	if kind == "HitboxRotate" then
		self:_refreshHitFields()
	elseif kind == "DecorationRotate" then
		self:_refreshDecorationFields()
	else
		self:_refreshEventFields()
	end
	self:_applySelectedFrame()
end

function MotionEditorController:_updateHandles()
	if not self.Gui.Enabled or not self.Viewport or not self.Viewport.Visible then
		return
	end
	for name, marker in self.Handles or {} do
		local minimumSize = UserInputService.TouchEnabled and 28 or 16
		local maximumSize = UserInputService.TouchEnabled and 46 or 36
		local markerSize = math.clamp(math.floor(20 * 13.5 / self.CameraState.Distance + 0.5), minimumSize, maximumSize)
		-- AbsoluteSize and the 3D projection are physical pixels, while UDim offsets
		-- below an ancestor UIScale are logical pixels. Undo that scale so the point
		-- remains on the rendered limb instead of drifting toward the viewport origin.
		local uiScale = math.max(0.01, self.EditorScale and self.EditorScale.Scale or 1)
		local logicalMarkerSize = markerSize / uiScale
		marker.Size = UDim2.fromOffset(logicalMarkerSize, logicalMarkerSize)
		local position = self:_handleWorldPosition(name)
		local projected, depth = position and self:_projectWorld(position) or nil, 0
		if position then
			projected, depth = self:_projectWorld(position)
		end
		marker.Visible = projected ~= nil and depth > 0
		if projected then
			marker.Position = UDim2.fromOffset(
				projected.X / uiScale - logicalMarkerSize * 0.5,
				projected.Y / uiScale - logicalMarkerSize * 0.5
			)
		end
	end
	self:_updateJointGizmo()
end

function MotionEditorController:_bodyPartAtPoint(pointer: Vector2): BasePart?
	local bestPart: BasePart? = nil
	local bestDepth = math.huge
	for partName in GIZMO_PARTS do
		local part = self.PreviewRig:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			local minimum = Vector2.new(math.huge, math.huge)
			local maximum = Vector2.new(-math.huge, -math.huge)
			local visibleCorners = 0
			local nearestDepth = math.huge
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local corner = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5)
						local projected, depth = self:_projectWorld(corner)
						if projected and depth > 0 then
							visibleCorners += 1
							minimum = Vector2.new(math.min(minimum.X, projected.X), math.min(minimum.Y, projected.Y))
							maximum = Vector2.new(math.max(maximum.X, projected.X), math.max(maximum.Y, projected.Y))
							nearestDepth = math.min(nearestDepth, depth)
						end
					end
				end
			end
			local padding = UserInputService.TouchEnabled and 12 or 5
			if
				visibleCorners > 0
				and pointer.X >= minimum.X - padding
				and pointer.Y >= minimum.Y - padding
				and pointer.X <= maximum.X + padding
				and pointer.Y <= maximum.Y + padding
				and nearestDepth < bestDepth
			then
				bestPart = part
				bestDepth = nearestDepth
			end
		end
	end
	return bestPart
end

function MotionEditorController:_refreshBodyPartButtons()
	for partName, button in self.BodyPartButtons or {} do
		local selected = partName == self.SelectedGizmoPart
		styleButton(button, selected and THEME.GoldLight or THEME.Green)
	end
end

function MotionEditorController:_selectGizmoPart(partName: string): boolean
	local part = GIZMO_PARTS[partName] and self.PreviewRig:FindFirstChild(partName)
	if not part or not part:IsA("BasePart") then
		return false
	end
	self.SelectedGizmoPart = partName
	if self.SelectionBox then
		self.SelectionBox.Adornee = part
	end
	self:_refreshBodyPartButtons()
	self:_updateHandles()
	return true
end

function MotionEditorController:_selectBodyPart(pointer: Vector2): boolean
	local part = self:_bodyPartAtPoint(pointer)
	return part ~= nil and self:_selectGizmoPart(part.Name)
end

function MotionEditorController:_updateHoveredBodyPart(pointer: Vector2?)
	if not self.HoverSelectionBox then
		return
	end
	local part = pointer and self:_bodyPartAtPoint(pointer) or nil
	self.HoverSelectionBox.Adornee = part
end

function MotionEditorController:_selectedGizmoDefinition(): (BasePart?, string?)
	local partName = self.SelectedGizmoPart
	local jointName = partName and GIZMO_PARTS[partName]
	local part = partName and self.PreviewRig:FindFirstChild(partName)
	return part and part:IsA("BasePart") and part or nil, jointName
end

function MotionEditorController:_addJointWorldOffset(frame: any, jointName: string, worldDelta: Vector3)
	local motor = self:_motor(jointName)
	if not motor or not motor.Part0 then
		return
	end
	local localDelta = (motor.Part0.CFrame * motor.C0):VectorToObjectSpace(worldDelta)
	frame.JointOffsets = frame.JointOffsets or {}
	local offset = frame.JointOffsets[jointName] or vector()
	for _, axis in { "X", "Y", "Z" } do
		offset[axis] = math.clamp(offset[axis] + localDelta[axis], -6, 6)
	end
	frame.JointOffsets[jointName] = offset
end

function MotionEditorController:_offsetHeldWeapon(frame: any, selectedPart: BasePart, worldDelta: Vector3)
	local function compensate(motor: Motor6D?, weapon: any)
		if not motor or motor.Part0 ~= selectedPart then
			return
		end
		local localDelta = selectedPart.CFrame:VectorToObjectSpace(-worldDelta)
		for _, axis in { "X", "Y", "Z" } do
			weapon.Position[axis] = math.clamp(weapon.Position[axis] + localDelta[axis], -8, 8)
		end
	end
	frame.Weapon = frame.Weapon or defaultWeapon()
	frame.DualWeapon = frame.DualWeapon or defaultWeapon()
	compensate(self.PreviewWeaponMotor, frame.Weapon)
	compensate(self.PreviewDualWeaponMotor, frame.DualWeapon)
end

function MotionEditorController:_moveSelectedPart(worldDelta: Vector3)
	local selectedPart, jointName = self:_selectedGizmoDefinition()
	if not selectedPart or not jointName then
		return
	end
	local frame = self.Motion.Frames[self.SelectedFrame]
	self:_addJointWorldOffset(frame, jointName, worldDelta)
	if self.SelectedGizmoPart == "Torso" then
		-- RootJoint translation normally carries the entire R6 hierarchy. Apply the
		-- inverse delta to each child joint so only the torso itself moves.
		for _, childJoint in TORSO_CHILD_JOINTS do
			self:_addJointWorldOffset(frame, childJoint, -worldDelta)
		end
	else
		-- Weapons use the arm as Part0. Counter-translate the weapon transform so
		-- moving an arm does not silently rewrite the weapon's world position.
		self:_offsetHeldWeapon(frame, selectedPart, worldDelta)
	end
	self:_applySelectedFrame()
end

function MotionEditorController:_rotationAngleAtPoint(_axisName: string, pointer: Vector2): number?
	local selectedPart = self:_selectedGizmoDefinition()
	if not selectedPart then
		return nil
	end
	local center = self:_projectWorld(selectedPart.Position)
	if not center then
		return nil
	end
	local radial = pointer - center
	if radial.Magnitude < 2 then
		return nil
	end
	return math.deg(math.atan2(radial.Y, radial.X))
end

function MotionEditorController:_rotationViewSign(axisName: string, reference: any?): number
	local worldAxis = axisName == "X" and Vector3.xAxis or axisName == "Y" and Vector3.yAxis or Vector3.zAxis
	local selectedPart = self:_selectedGizmoDefinition()
	if selectedPart then
		local worldDirection = reference and reference.Direction
			or (axisName == "X" and Vector3.yAxis or axisName == "Y" and -Vector3.zAxis or Vector3.xAxis)
		local center = self:_projectWorld(selectedPart.Position)
		local positiveDirection = CFrame.fromAxisAngle(worldAxis, math.rad(1)):VectorToWorldSpace(worldDirection)
		local startPoint = self:_projectWorld(selectedPart.Position + worldDirection)
		local positivePoint = self:_projectWorld(selectedPart.Position + positiveDirection)
		if center and startPoint and positivePoint then
			local startRadial = startPoint - center
			local positiveRadial = positivePoint - center
			if startRadial.Magnitude > 0.001 and positiveRadial.Magnitude > 0.001 then
				local startAngle = math.deg(math.atan2(startRadial.Y, startRadial.X))
				local positiveAngle = math.deg(math.atan2(positiveRadial.Y, positiveRadial.X))
				local screenDelta = wrappedAngle(positiveAngle - startAngle)
				if math.abs(screenDelta) > 0.0001 then
					return screenDelta > 0 and 1 or -1
				end
			end
		end
	end
	local viewDot = worldAxis:Dot(self.EditorCamera.CFrame.LookVector)
	return viewDot >= 0 and 1 or -1
end

function MotionEditorController:_jointLocalAxis(jointName: string, worldAxis: Vector3): Vector3
	local motor = self:_motor(jointName)
	if not motor or not motor.Part0 then
		return worldAxis
	end
	return (motor.Part0.CFrame * motor.C0):VectorToObjectSpace(worldAxis).Unit
end

function MotionEditorController:_dragGizmo(axisName: string, mode: string, delta: Vector2, pointer: Vector2)
	local selectedPart, jointName = self:_selectedGizmoDefinition()
	if not selectedPart or not jointName then
		return
	end
	local drag = self.DragState
	local worldAxis = axisName == "X" and Vector3.xAxis or axisName == "Y" and Vector3.yAxis or Vector3.zAxis
	if mode == "Move" then
		local center = self:_projectWorld(selectedPart.Position)
		local endpoint = self:_projectWorld(selectedPart.Position + worldAxis)
		if not center or not endpoint then
			return
		end
		-- An axis can point almost directly into the camera. Keep that depth axis
		-- editable with horizontal dragging instead of producing a dead handle.
		local projectedAxis = endpoint - center
		local screenAxis = projectedAxis.Magnitude >= 0.5 and projectedAxis.Unit or Vector2.new(1, 0)
		local unitsPerPixel = self.CameraState.Distance / math.max(280, self.Viewport.AbsoluteSize.Y)
		self:_moveSelectedPart(worldAxis * delta:Dot(screenAxis) * unitsPerPixel)
	else
		local frame = self.Motion.Frames[self.SelectedFrame]
		local pose = frame.Joints[jointName] or vector()
		if drag and drag.Kind == "Gizmo" then
			local rotationDelta = drag.RotationDelta or 0
			local pointerAngle = self:_rotationAngleAtPoint(axisName, pointer)
			if pointerAngle then
				if drag.LastPointerAngle then
					local angularDelta = wrappedAngle(pointerAngle - drag.LastPointerAngle)
					local directionSign = 1
					if drag.InitialViewSign then
						directionSign = drag.InitialViewSign
					end
					drag.RotationDelta = rotationDelta + angularDelta * directionSign
				end
				drag.LastPointerAngle = pointerAngle
			end
			local snappedDelta = math.round((drag.RotationDelta or 0) / 5) * 5
			if drag.StartRotation then
				local jointAxis = self:_jointLocalAxis(jointName, worldAxis)
				local rotation = CFrame.fromAxisAngle(jointAxis, math.rad(snappedDelta)) * drag.StartRotation
				frame.JointRotations = frame.JointRotations or {}
				frame.JointRotations[jointName] = RotationUtil.FromCFrame(rotation)
				pose = RotationUtil.ToEuler(rotation)
			end
		else
			pose[axisName] = math.round(((pose[axisName] or 0) + (delta.X - delta.Y) * 0.7) / 5) * 5
			frame.JointRotations = frame.JointRotations or {}
			frame.JointRotations[jointName] = RotationUtil.FromCFrame(RotationUtil.FromEuler(pose))
		end
		frame.Joints[jointName] = pose
		self:_applySelectedFrame()
	end
end

function MotionEditorController:_dragTransform(name: string, delta: Vector2)
	local camera = self.EditorCamera
	if not camera then
		return
	end
	local unitsPerPixel = self.CameraState.Distance / math.max(280, self.Viewport.AbsoluteSize.Y)
	local worldDelta = camera.CFrame.RightVector * (delta.X * unitsPerPixel)
		+ camera.CFrame.UpVector * (-delta.Y * unitsPerPixel)
	if name == "Weapon" and self.PreviewWeaponMotor and self.PreviewWeaponMotor.Part0 then
		local frame = self.Motion.Frames[self.SelectedFrame]
		frame.Weapon = frame.Weapon or defaultWeapon()
		local localDelta = self.PreviewWeaponMotor.Part0.CFrame:VectorToObjectSpace(worldDelta)
		for _, axis in { "X", "Y", "Z" } do
			frame.Weapon.Position[axis] = math.clamp(frame.Weapon.Position[axis] + localDelta[axis], -8, 8)
		end
		self:_applySelectedFrame()
	elseif name == "DualWeapon" and self.PreviewDualWeaponMotor and self.PreviewDualWeaponMotor.Part0 then
		local frame = self.Motion.Frames[self.SelectedFrame]
		frame.DualWeapon = frame.DualWeapon or defaultWeapon()
		local localDelta = self.PreviewDualWeaponMotor.Part0.CFrame:VectorToObjectSpace(worldDelta)
		for _, axis in { "X", "Y", "Z" } do
			frame.DualWeapon.Position[axis] = math.clamp(frame.DualWeapon.Position[axis] + localDelta[axis], -8, 8)
		end
		self:_applySelectedFrame()
	elseif name == "Root" then
		local frame = self.Motion.Frames[self.SelectedFrame]
		frame.RootOffset = frame.RootOffset or vector()
		local root = self.PreviewRig:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local localDelta = (self.PreviewRootBase or CFrame.identity):VectorToObjectSpace(worldDelta)
			for _, axis in { "X", "Y", "Z" } do
				frame.RootOffset[axis] = math.clamp(frame.RootOffset[axis] + localDelta[axis], -20, 20)
			end
			self:_applySelectedFrame()
		end
	elseif name == "Hitbox" then
		local hit = self:_selectedHit()
		local root = self.PreviewRig:FindFirstChild("HumanoidRootPart")
		if hit and root and root:IsA("BasePart") then
			local localDelta = root.CFrame:VectorToObjectSpace(worldDelta)
			for _, axis in { "X", "Y", "Z" } do
				hit.Hitbox.Offset[axis] = math.clamp(hit.Hitbox.Offset[axis] + localDelta[axis], -20, 20)
			end
			self:_updateHitboxPreview()
		end
	elseif name == "HitboxSize" then
		local hit = self:_selectedHit()
		if hit then
			hit.Hitbox.Size.X = math.clamp(hit.Hitbox.Size.X + delta.X * unitsPerPixel * 2, 0.25, 20)
			hit.Hitbox.Size.Y = math.clamp(hit.Hitbox.Size.Y - delta.Y * unitsPerPixel * 2, 0.25, 20)
			self:_updateHitboxPreview()
		end
	elseif name == "EventSize" then
		local event = self:_selectedFrameEvent()
		if event then
			event.Size.X = math.clamp(math.abs(event.Size.X) + delta.X * unitsPerPixel * 2, 0.1, 20)
			event.Size.Y = math.clamp(math.abs(event.Size.Y) - delta.Y * unitsPerPixel * 2, 0.1, 20)
			self:_refreshEventFields()
		end
	elseif name == "Event" then
		local event = self:_selectedFrameEvent()
		local root = self.PreviewRig:FindFirstChild("HumanoidRootPart")
		if event and root and root:IsA("BasePart") then
			local localDelta = root.CFrame:VectorToObjectSpace(worldDelta)
			for _, axis in { "X", "Y", "Z" } do
				event.Offset[axis] = math.clamp(event.Offset[axis] + localDelta[axis], -20, 20)
			end
			self:_refreshEventFields()
		end
	elseif name == "Decoration" then
		local frame = self.Motion.Frames[self.SelectedFrame]
		local decoration = frame.Decorations and frame.Decorations[self.SelectedDecoration]
		local parent = decoration
			and (
				decoration.Attach == "Head" and self.PreviewRig:FindFirstChild("Head")
				or self.PreviewRig:FindFirstChild("HumanoidRootPart")
			)
		if decoration and parent and parent:IsA("BasePart") then
			local localDelta = parent.CFrame:VectorToObjectSpace(worldDelta)
			for _, axis in { "X", "Y", "Z" } do
				decoration.Offset[axis] = math.clamp(decoration.Offset[axis] + localDelta[axis], -20, 20)
			end
			self:_syncDecorations(frame)
		end
	end
end

function MotionEditorController:_makeHandle(parent: GuiObject, name: string, color: Color3, glyph: string): TextButton
	local marker = Instance.new("TextButton")
	marker.Name = name .. "Handle"
	marker.Size = UDim2.fromOffset(20, 20)
	marker.BackgroundColor3 = color
	marker.BorderSizePixel = 0
	marker.Text = glyph
	marker.TextColor3 = Color3.fromRGB(10, 10, 10)
	marker.Font = Enum.Font.GothamBlack
	marker.TextSize = 11
	marker.ZIndex = 12
	marker.AutoButtonColor = false
	marker.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = marker
	addStroke(marker, Color3.new(0, 0, 0), 2)
	marker.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self:_pushUndo()
			self.DragState = {
				Kind = "Handle",
				Name = name,
				Last = Vector2.new(input.Position.X, input.Position.Y),
				Button = input.UserInputType,
			}
		end
	end)
	return marker
end

function MotionEditorController:_makeGizmoPart(parent: Instance, name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 1
	part.Parent = parent
	return part
end

function MotionEditorController:_ringPoint(
	center: Vector3,
	axisName: string,
	angle: number,
	radius: number,
	rotation: CFrame?
): Vector3
	local cosine = math.cos(angle) * radius
	local sine = math.sin(angle) * radius
	local offset
	if axisName == "X" then
		offset = Vector3.new(0, cosine, sine)
	elseif axisName == "Y" then
		offset = Vector3.new(cosine, 0, sine)
	else
		offset = Vector3.new(cosine, sine, 0)
	end
	return center + (rotation or CFrame.identity):VectorToWorldSpace(offset)
end

function MotionEditorController:_currentGizmoRotation(): CFrame
	-- The transform gizmo follows the selected part's position, but its axes stay
	-- fixed in editor world space. Rotating a limb must not rotate the controls.
	return CFrame.identity
end

function MotionEditorController:_buildJointGizmo()
	local model = Instance.new("Model")
	model.Name = "JointTransformGizmo"
	model.Parent = self.World
	self.JointGizmo = model
	self.GizmoVisuals = { Move = {}, Rotate = {}, Reference = {} }
	for _, axis in GIZMO_AXES do
		self.GizmoVisuals.Move[axis.Name] = {
			Shaft = self:_makeGizmoPart(model, "Move" .. axis.Name .. "Shaft", axis.Color),
			Head = self:_makeGizmoPart(model, "Move" .. axis.Name .. "Head", axis.Color),
		}
		local ring = {}
		for segmentIndex = 1, GIZMO_RING_SEGMENTS do
			ring[segmentIndex] =
				self:_makeGizmoPart(model, "Rotate" .. axis.Name .. string.format("%02d", segmentIndex), axis.Color)
		end
		self.GizmoVisuals.Rotate[axis.Name] = ring
	end
	for _, reference in GIZMO_REFERENCE_POINTS do
		local point = self:_makeGizmoPart(model, "RotateReference" .. reference.Id, reference.Color)
		point.Shape = Enum.PartType.Ball
		table.insert(self.GizmoVisuals.Reference, {
			Id = reference.Id,
			Axis = reference.Axis,
			Direction = reference.Direction,
			Part = point,
		})
	end
end

function MotionEditorController:_updateJointGizmo()
	if not self.GizmoVisuals then
		return
	end
	local selectedPart = self:_selectedGizmoDefinition()
	local visible = self.Gui.Enabled and self.Viewport.Visible and selectedPart ~= nil
	local center = selectedPart and selectedPart.Position or Vector3.zero
	local gizmoRotation = self:_currentGizmoRotation()
	local radius = 2.15
	for _, axis in GIZMO_AXES do
		local move = self.GizmoVisuals.Move[axis.Name]
		local showMove = visible and self.JointEditMode == "Move"
		local startPosition = center + axis.Vector * 0.35
		local endPosition = center + axis.Vector * radius
		move.Shaft.Transparency = showMove and 0.06 or 1
		move.Head.Transparency = showMove and 0.02 or 1
		move.Shaft.Size = Vector3.new((endPosition - startPosition).Magnitude, 0.09, 0.09)
		move.Shaft.CFrame = cframeAlongX(startPosition, endPosition)
		move.Head.Size = Vector3.new(0.38, 0.38, 0.38)
		move.Head.CFrame = cframeAlongX(endPosition - axis.Vector * 0.12, endPosition + axis.Vector * 0.12)
			* CFrame.Angles(math.rad(45), math.rad(45), 0)

		local ring = self.GizmoVisuals.Rotate[axis.Name]
		local showRing = visible and self.JointEditMode == "Rotate"
		for segmentIndex, segment in ring do
			local angleA = (segmentIndex - 1) / GIZMO_RING_SEGMENTS * math.pi * 2
			local angleB = segmentIndex / GIZMO_RING_SEGMENTS * math.pi * 2
			local pointA = self:_ringPoint(center, axis.Name, angleA, radius * 0.78, gizmoRotation)
			local pointB = self:_ringPoint(center, axis.Name, angleB, radius * 0.78, gizmoRotation)
			segment.Transparency = showRing and 0.12 or 1
			segment.Size = Vector3.new((pointB - pointA).Magnitude, 0.075, 0.075)
			segment.CFrame = cframeAlongX(pointA, pointB)
		end
	end
	for _, reference in self.GizmoVisuals.Reference do
		local point = reference.Part
		local activeReference = self.DragState
			and self.DragState.Kind == "Gizmo"
			and self.DragState.ReferenceId == reference.Id
		local emphasized = self.HoveredGizmoReference == reference.Id or activeReference
		local pointSize = emphasized and 0.84 or 0.54
		point.Size = Vector3.new(pointSize, pointSize, pointSize)
		point.Position = center + gizmoRotation:VectorToWorldSpace(reference.Direction) * radius * 0.78
		point.Transparency = visible and self.JointEditMode == "Rotate" and 0.02 or 1
	end
end

function MotionEditorController:_gizmoReferenceAtPoint(pointer: Vector2): any?
	if self.JointEditMode ~= "Rotate" or not self.GizmoVisuals then
		return nil
	end
	local threshold = UserInputService.TouchEnabled and 34 or 20
	local nearest = nil
	local nearestDistance = threshold
	for _, reference in self.GizmoVisuals.Reference do
		local projected = self:_projectWorld(reference.Part.Position)
		if projected then
			local distance = (pointer - projected).Magnitude
			if distance <= nearestDistance then
				nearest = reference
				nearestDistance = distance
			end
		end
	end
	return nearest
end

function MotionEditorController:_updateHoveredGizmoReference(pointer: Vector2?)
	local reference = pointer and self:_gizmoReferenceAtPoint(pointer) or nil
	self.HoveredGizmoReference = reference and reference.Id or nil
end

function MotionEditorController:_gizmoAxisAtPoint(pointer: Vector2): string?
	local selectedPart = self:_selectedGizmoDefinition()
	if not selectedPart then
		return nil
	end
	local center = selectedPart.Position
	local gizmoRotation = self:_currentGizmoRotation()
	local radius = 2.15
	local threshold = UserInputService.TouchEnabled and 20 or 9
	local bestAxis: string? = nil
	local bestDistance = threshold
	local reference = self:_gizmoReferenceAtPoint(pointer)
	if reference then
		return reference.Axis
	end
	for _, axis in GIZMO_AXES do
		if self.JointEditMode == "Move" then
			local startPoint = self:_projectWorld(center + axis.Vector * 0.35)
			local endPoint = self:_projectWorld(center + axis.Vector * radius)
			if startPoint and endPoint then
				local distance = pointToSegmentDistance(pointer, startPoint, endPoint)
				if distance <= bestDistance then
					bestDistance = distance
					bestAxis = axis.Name
				end
			end
		else
			for segmentIndex = 1, GIZMO_RING_SEGMENTS do
				local angleA = (segmentIndex - 1) / GIZMO_RING_SEGMENTS * math.pi * 2
				local angleB = segmentIndex / GIZMO_RING_SEGMENTS * math.pi * 2
				local worldA = self:_ringPoint(center, axis.Name, angleA, radius * 0.78, gizmoRotation)
				local worldB = self:_ringPoint(center, axis.Name, angleB, radius * 0.78, gizmoRotation)
				local pointA = self:_projectWorld(worldA)
				local pointB = self:_projectWorld(worldB)
				if pointA and pointB then
					local distance = pointToSegmentDistance(pointer, pointA, pointB)
					if distance <= bestDistance then
						bestDistance = distance
						bestAxis = axis.Name
					end
				end
			end
		end
	end
	return bestAxis
end

function MotionEditorController:_buildDirectManipulation(viewport: ViewportFrame)
	viewport.Active = true
	self.Handles = {}
	self.Handles.Weapon = self:_makeHandle(viewport, "Weapon", Color3.fromRGB(255, 160, 80), "W")
	self.Handles.WeaponTip = self:_makeHandle(viewport, "WeaponTip", Color3.fromRGB(255, 205, 100), "T")
	self.Handles.DualWeapon = self:_makeHandle(viewport, "DualWeapon", Color3.fromRGB(255, 190, 95), "L")
	self.Handles.DualWeaponTip = self:_makeHandle(viewport, "DualWeaponTip", Color3.fromRGB(255, 225, 135), "T")
	self.Handles.Hitbox = self:_makeHandle(viewport, "Hitbox", THEME.Red, "H")
	self.Handles.HitboxSize = self:_makeHandle(viewport, "HitboxSize", Color3.new(1, 1, 1), "↘")
	self.Handles.HitboxRotate = self:_makeHandle(viewport, "HitboxRotate", THEME.GoldLight, "↻")
	self.Handles.Event = self:_makeHandle(viewport, "Event", THEME.Cyan, "E")
	self.Handles.EventSize = self:_makeHandle(viewport, "EventSize", Color3.new(1, 1, 1), "↘")
	self.Handles.EventRotate = self:_makeHandle(viewport, "EventRotate", THEME.GoldLight, "↻")
	self.Handles.Decoration = self:_makeHandle(viewport, "Decoration", Color3.fromRGB(255, 105, 205), "D")
	self.Handles.DecorationRotate = self:_makeHandle(viewport, "DecorationRotate", THEME.GoldLight, "↻")
	self:_buildJointGizmo()

	local function isInsideViewport(position: Vector2): boolean
		local minimum = viewport.AbsolutePosition
		local maximum = minimum + viewport.AbsoluteSize
		return position.X >= minimum.X
			and position.Y >= minimum.Y
			and position.X <= maximum.X
			and position.Y <= maximum.Y
	end

	local function beginViewportInput(input)
		local position = Vector2.new(input.Position.X, input.Position.Y)
		if input.UserInputType == Enum.UserInputType.Touch then
			self.ActiveTouches[input] = position
			local touches = {}
			for _, touchPosition in self.ActiveTouches do
				table.insert(touches, touchPosition)
			end
			if #touches >= 2 and (not self.DragState or self.DragState.Kind ~= "Handle") then
				local center = (touches[1] + touches[2]) * 0.5
				self.DragState = {
					Kind = "TouchCamera",
					Last = center,
					LastDistance = (touches[1] - touches[2]).Magnitude,
					Button = Enum.UserInputType.Touch,
				}
			elseif not self.DragState then
				self.DragState = { Kind = "Orbit", Last = position, Button = Enum.UserInputType.Touch }
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- Camera orbit is intentionally independent from left-button editing.
			-- Holding RMB while dragging a handle must not discard that edit drag.
			if not self.CameraDragState then
				self.CameraDragState = { Kind = "Orbit", Last = position, Button = input.UserInputType }
			end
		elseif
			input.UserInputType == Enum.UserInputType.MouseButton3
			or (
				input.UserInputType == Enum.UserInputType.MouseButton1
				and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			)
		then
			self.DragState = { Kind = "Pan", Last = position, Button = input.UserInputType }
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not self.DragState then
			local localPointer = position - viewport.AbsolutePosition
			-- Reference points are intentional axis controls, so resolve them before
			-- the nearby ring segments and lock that choice for the whole drag.
			local gizmoReference = self:_gizmoReferenceAtPoint(localPointer)
			local gizmoAxis = gizmoReference and gizmoReference.Axis or self:_gizmoAxisAtPoint(localPointer)
			if gizmoAxis then
				self:_pushUndo()
				local _, jointName = self:_selectedGizmoDefinition()
				local frame = self.Motion.Frames[self.SelectedFrame]
				local pose = jointName and frame.Joints[jointName]
				local rotation = jointName
						and RotationUtil.ToCFrame(frame.JointRotations and frame.JointRotations[jointName], pose)
					or nil
				local viewSign = self:_rotationViewSign(gizmoAxis, gizmoReference)
				local pointerAngle = self.JointEditMode == "Rotate"
						and self:_rotationAngleAtPoint(gizmoAxis, localPointer)
					or nil
				self.DragState = {
					Kind = "Gizmo",
					Axis = gizmoAxis,
					Mode = self.JointEditMode,
					Last = position,
					StartRotation = rotation,
					RotationDelta = 0,
					LastPointerAngle = pointerAngle,
					ReferenceId = gizmoReference and gizmoReference.Id or nil,
					Reference = gizmoReference,
					InitialViewSign = viewSign,
					Button = input.UserInputType,
				}
			else
				self:_selectBodyPart(localPointer)
			end
		end
	end

	viewport.InputBegan:Connect(function(input)
		beginViewportInput(input)
	end)

	-- MouseButton2 can be consumed by Roblox's camera layer before a
	-- ViewportFrame receives InputBegan. Capture it globally, but only while
	-- the pointer is inside this editor viewport.
	UserInputService.InputBegan:Connect(function(input)
		if
			self.Gui.Enabled
			and viewport.Visible
			and input.UserInputType == Enum.UserInputType.MouseButton2
			and isInsideViewport(Vector2.new(input.Position.X, input.Position.Y))
		then
			beginViewportInput(input)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not self.Gui.Enabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local mouse = UserInputService:GetMouseLocation()
			--[[
				요청: "스크롤 내리면 줌아웃도 같이 됨 / 스크롤 올리면 줌 인 됨."

				뷰포트가 화면 전체가 된 뒤로 "뷰포트 안"이 **언제나 참**이 됐다. 그래서
				조작 창 안에서 목록을 굴려도 휠이 카메라까지 갔다. 창 위에서는 휠을
				카메라에 넘기지 않는다 — 그 자리 스크롤은 목록 몫이다.
			]]
			if self:_pointerOverWindow(mouse) then
				return
			end
			local min = viewport.AbsolutePosition
			local max = min + viewport.AbsoluteSize
			if mouse.X >= min.X and mouse.Y >= min.Y and mouse.X <= max.X and mouse.Y <= max.Y then
				self.CameraState.Distance = math.clamp(self.CameraState.Distance - input.Position.Z * 1.2, 4, 28)
				self:_updateEditorCamera()
			end
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local pointer = Vector2.new(input.Position.X, input.Position.Y)
			if isInsideViewport(pointer) and not self.DragState then
				local localPointer = pointer - viewport.AbsolutePosition
				self:_updateHoveredBodyPart(localPointer)
				self:_updateHoveredGizmoReference(localPointer)
			else
				self:_updateHoveredBodyPart(nil)
				self:_updateHoveredGizmoReference(nil)
			end
		end
		local current = Vector2.new(input.Position.X, input.Position.Y)
		local cameraDrag = self.CameraDragState
		if cameraDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
			local cameraDelta = current - cameraDrag.Last
			cameraDrag.Last = current
			self.CameraState.Yaw -= cameraDelta.X * 0.008
			self.CameraState.Pitch = math.clamp(self.CameraState.Pitch - cameraDelta.Y * 0.008, -1.35, 1.35)
			self:_updateEditorCamera()
			-- Preserve an active left-button edit without applying the same pointer
			-- delta to both the camera and the selected joint/handle. Advancing its
			-- origin also prevents a jump when RMB is released and editing resumes.
			if self.DragState then
				self.DragState.Last = current
				if self.DragState.Kind == "Gizmo" and self.DragState.Mode == "Rotate" then
					self.DragState.LastPointerAngle =
						self:_rotationAngleAtPoint(self.DragState.Axis, current - viewport.AbsolutePosition)
				end
			end
			return
		end

		local drag = self.DragState
		if
			not drag
			or (
				input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch
			)
		then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			self.ActiveTouches[input] = current
		end
		local delta = current - drag.Last
		drag.Last = current
		if drag.Kind == "Gizmo" then
			self:_dragGizmo(drag.Axis, drag.Mode, delta, current - viewport.AbsolutePosition)
		elseif drag.Kind == "Handle" then
			local localPointer = current - viewport.AbsolutePosition
			if drag.Name == "WeaponTip" then
				self:_dragWeaponTip("Weapon", localPointer)
			elseif drag.Name == "DualWeaponTip" then
				self:_dragWeaponTip("DualWeapon", localPointer)
			elseif drag.Name == "HitboxRotate" or drag.Name == "DecorationRotate" or drag.Name == "EventRotate" then
				self:_dragRotationPoint(drag.Name, localPointer)
			else
				self:_dragTransform(drag.Name, delta)
			end
		elseif drag.Kind == "Orbit" then
			self.CameraState.Yaw -= delta.X * 0.008
			self.CameraState.Pitch = math.clamp(self.CameraState.Pitch - delta.Y * 0.008, -1.35, 1.35)
			self:_updateEditorCamera()
		elseif drag.Kind == "Pan" then
			local amount = self.CameraState.Distance / math.max(240, viewport.AbsoluteSize.Y)
			self.CameraState.Focus -= self.EditorCamera.CFrame.RightVector * delta.X * amount
			self.CameraState.Focus += self.EditorCamera.CFrame.UpVector * delta.Y * amount
			self:_updateEditorCamera()
		elseif drag.Kind == "TouchCamera" then
			local touches = {}
			for _, touchPosition in self.ActiveTouches do
				table.insert(touches, touchPosition)
			end
			if #touches >= 2 then
				local center = (touches[1] + touches[2]) * 0.5
				local distance = (touches[1] - touches[2]).Magnitude
				local centerDelta = center - drag.Last
				local amount = self.CameraState.Distance / math.max(240, viewport.AbsoluteSize.Y)
				self.CameraState.Focus -= self.EditorCamera.CFrame.RightVector * centerDelta.X * amount
				self.CameraState.Focus += self.EditorCamera.CFrame.UpVector * centerDelta.Y * amount
				self.CameraState.Distance =
					math.clamp(self.CameraState.Distance - (distance - (drag.LastDistance or distance)) * 0.025, 4, 28)
				drag.Last = center
				drag.LastDistance = distance
				self:_updateEditorCamera()
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			self.ActiveTouches[input] = nil
		end
		if self.CameraDragState and self.CameraDragState.Button == input.UserInputType then
			self.CameraDragState = nil
		end
		if self.DragState and self.DragState.Button == input.UserInputType then
			self.DragState = nil
		end
	end)

	self.HandleConnection = RunService.RenderStepped:Connect(function()
		self:_updateHandles()
	end)
end

function MotionEditorController:_playPreview()
	self.HitboxPreview.Transparency = 1
	self.Status.Text = "  STATUS\n  전체 타임라인 재생 중..."
	self.Status.TextColor3 = THEME.Cyan
	MotionPlayer.Play(self.PreviewRig, self.Motion)
	task.delay(self.Motion.Duration + 0.05, function()
		if self.Gui.Parent then
			self:_applySelectedFrame()
			self.Status.Text = "  STATUS\n  재생 완료"
			self.Status.TextColor3 = THEME.Muted
		end
	end)
end

function MotionEditorController:_savePack()
	self.Remotes.SaveMotion:FireServer({
		PackId = self.CurrentPackId,
		Pack = {
			Name = self.PackName,
			Description = self.PackDescription,
			BodyColorHex = self.BodyColorHex,
			AuthorCharacterId = self.AuthorCharacterId,
			ActivePreset = self.ActivePreset,
			Presets = self.PresetMotions,
		},
	})
end

function MotionEditorController:_bindShortcuts()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not self.Gui.Enabled or UserInputService:GetFocusedTextBox() then
			return
		end
		local control = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		if control and input.KeyCode == Enum.KeyCode.S then
			self:_savePack()
		elseif control and input.KeyCode == Enum.KeyCode.Z then
			self:_undo()
		elseif control and input.KeyCode == Enum.KeyCode.C then
			self:_copyCurrentFrame()
		elseif control and input.KeyCode == Enum.KeyCode.V then
			self:_pasteCurrentFrame()
		elseif control and input.KeyCode == Enum.KeyCode.X then
			self:_cutCurrentFrame()
		elseif control and input.KeyCode == Enum.KeyCode.D then
			self:_duplicateHit()
		elseif control and input.KeyCode == Enum.KeyCode.Q then
			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			if shift then
				self:_pasteWeaponImage()
			else
				self:_copyWeaponImage()
			end
		elseif input.KeyCode == Enum.KeyCode.Left then
			self:_selectFrame(math.max(1, self.SelectedFrame - 1))
		elseif input.KeyCode == Enum.KeyCode.Right then
			self:_selectFrame(math.min(#self.Motion.Frames, self.SelectedFrame + 1))
		elseif input.KeyCode == Enum.KeyCode.Delete then
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				self:_deleteFrame()
			else
				self:_deleteHit()
			end
		elseif input.KeyCode == Enum.KeyCode.Space then
			self:_playPreview()
		end
	end)
end

function MotionEditorController:_buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MotionEditorGui"
	gui.Enabled = false
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.Gui = gui

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = THEME.WoodDark
	-- 예전엔 이 판이 화면을 불투명하게 덮고 그 위에 전체화면 패널을 얹었다. 이제는
	-- 전체화면 뷰포트가 배경이므로 덮으면 안 된다.
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local panel = makePanel(gui, THEME.Board, THEME.Gold)
	panel.Name = "Workshop"
	panel.Size = UDim2.fromScale(1, 1)
	panel.Position = UDim2.fromScale(0, 0)
	addStroke(panel, THEME.WoodLight, 5)
	addWoodGrid(panel, 28)

	local editorScale = Instance.new("UIScale")
	editorScale.Name = "ResponsiveScale"
	editorScale.Parent = panel
	self.EditorScale = editorScale
	local function refreshScale()
		local currentCamera = workspace.CurrentCamera
		local viewportSize = currentCamera and currentCamera.ViewportSize or Vector2.new(1280, 720)
		if self.RefreshResponsive then
			self.RefreshResponsive(viewportSize)
			return
		end
		local scale = math.clamp(math.min(viewportSize.X / 1280, viewportSize.Y / 720), 0.5, 1.1)
		editorScale.Scale = scale
		panel.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
	refreshScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		refreshScale()
	end)

	local header = makePanel(panel, THEME.Wood, THEME.Gold)
	header.Name = "Header"
	header.Size = UDim2.new(1, -16, 0, 64)
	header.Position = UDim2.fromOffset(8, 8)
	addWoodGrid(header, 18)

	local brandMark = Instance.new("Frame")
	brandMark.Size = UDim2.fromOffset(34, 34)
	brandMark.Position = UDim2.fromOffset(14, 14)
	brandMark.BackgroundColor3 = THEME.GreenDark
	brandMark.BorderSizePixel = 0
	brandMark.Parent = header
	addStroke(brandMark, THEME.Green, 2)
	local brandGlyph = Instance.new("TextLabel")
	brandGlyph.Size = UDim2.fromScale(1, 1)
	brandGlyph.BackgroundTransparency = 1
	brandGlyph.Text = "M"
	brandGlyph.TextColor3 = Color3.new(1, 1, 1)
	brandGlyph.Font = Enum.Font.GothamBlack
	brandGlyph.TextSize = 17
	brandGlyph.Parent = brandMark

	local brand = Instance.new("TextLabel")
	brand.BackgroundTransparency = 1
	brand.Size = UDim2.fromOffset(188, 24)
	brand.Position = UDim2.fromOffset(58, 8)
	brand.Text = "CRAFTROYALE"
	brand.TextColor3 = THEME.Gold
	brand.Font = Enum.Font.GothamBlack
	brand.TextSize = 20
	brand.TextXAlignment = Enum.TextXAlignment.Left
	brand.Parent = header
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -570, 0, 24)
	title.Position = UDim2.fromOffset(252, 8)
	title.Text = "R6  /  모션 공방"
	title.TextColor3 = THEME.Green
	title.Font = Enum.Font.GothamBold
	title.TextSize = 17
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header
	local shortcutHelp = makeButton(header, "단축키", 74, 30)
	shortcutHelp.Position = UDim2.new(1, -264, 0, 17)
	styleButton(shortcutHelp, THEME.Cyan)
	local loadTop = makeButton(header, "인벤토리", 82, 30)
	loadTop.Name = "LoadButton"
	loadTop.Position = UDim2.new(1, -444, 0, 17)
	styleButton(loadTop, THEME.Blue)
	local saveTop = makeButton(header, "저장", 82, 30)
	saveTop.Name = "SaveButton"
	saveTop.Position = UDim2.new(1, -356, 0, 17)
	styleButton(saveTop, THEME.Green, THEME.GreenDark, Color3.new(1, 1, 1))
	loadTop.Activated:Connect(function()
		self:_setOpen(false)
		self:_setInventoryOpen(true)
		self.Remotes.RequestInventory:FireServer()
	end)
	saveTop.Activated:Connect(function()
		self:_savePack()
	end)
	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Size = UDim2.new(1, -550, 0, 20)
	subtitle.Position = UDim2.fromOffset(253, 37)
	subtitle.Text = "POSE / WEAPON / HITBOX / FX / FRAME AUTHORING"
	subtitle.TextColor3 = THEME.Muted
	subtitle.Font = Enum.Font.RobotoMono
	subtitle.TextSize = 11
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = header
	local sessionTag = Instance.new("TextLabel")
	sessionTag.BackgroundColor3 = THEME.Panel
	sessionTag.BorderSizePixel = 0
	sessionTag.Size = UDim2.fromOffset(176, 30)
	sessionTag.Position = UDim2.new(1, -630, 0, 17)
	sessionTag.Text = "●  편집  /  평타"
	sessionTag.TextColor3 = THEME.Green
	sessionTag.Font = Enum.Font.RobotoMono
	sessionTag.TextSize = 11
	sessionTag.Parent = header
	self.HeaderPresetLabel = sessionTag
	addStroke(sessionTag, THEME.GreenDark, 1)
	local close = makeButton(header, "닫기  ×", 78, 30)
	close.Position = UDim2.new(1, -88, 0, 17)
	styleButton(close, THEME.Red)
	close.Activated:Connect(function()
		self:_setOpen(false)
	end)
	local shortcutPanel = makePanel(panel, THEME.Panel, THEME.Gold)
	shortcutPanel.Name = "ShortcutHelp"
	shortcutPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	shortcutPanel.Position = UDim2.fromScale(0.5, 0.5)
	shortcutPanel.Size = UDim2.fromOffset(460, 420)
	shortcutPanel.Visible = false
	shortcutPanel.ZIndex = 50
	local shortcutConstraint = Instance.new("UISizeConstraint")
	shortcutConstraint.MaxSize = Vector2.new(460, 520)
	shortcutConstraint.MinSize = Vector2.new(300, 300)
	shortcutConstraint.Parent = shortcutPanel
	local shortcutTitle = Instance.new("TextLabel")
	shortcutTitle.Size = UDim2.new(1, 0, 0, 48)
	shortcutTitle.BackgroundColor3 = THEME.Wood
	shortcutTitle.BorderSizePixel = 0
	shortcutTitle.Text = "CRAFTROYALE  /  공방 단축키"
	shortcutTitle.TextColor3 = THEME.GoldLight
	shortcutTitle.Font = Enum.Font.GothamBold
	shortcutTitle.TextSize = 17
	shortcutTitle.ZIndex = 51
	shortcutTitle.Parent = shortcutPanel
	local shortcutBody = Instance.new("TextLabel")
	shortcutBody.Size = UDim2.new(1, -32, 1, -112)
	shortcutBody.Position = UDim2.fromOffset(16, 60)
	shortcutBody.BackgroundTransparency = 1
	shortcutBody.Text = table.concat({
		"Ctrl + S     전체 프리셋 서버 검증 및 저장",
		"Ctrl + Z     마지막 편집 되돌리기 (최대 40회)",
		"Ctrl + C     현재 프레임 복사",
		"Ctrl + V     현재 프레임 붙여넣기",
		"Ctrl + X     현재 프레임 잘라내기",
		"Ctrl + D     선택 히트박스 복제",
		"Ctrl + Q     현재 무기 이미지 복사",
		"Ctrl+Shift+Q 복사한 무기 이미지 붙여넣기",
		"← / →        이전 / 다음 프레임",
		"Delete       선택 판정 삭제",
		"Shift+Delete 현재 프레임 삭제",
		"Space        전체 타임라인 재생",
		"오른쪽 드래그 카메라 회전",
		"Shift+왼쪽 / 가운데 드래그 카메라 이동",
		"휠           카메라 확대 / 축소",
	}, "\n\n")
	shortcutBody.TextColor3 = THEME.Parchment
	shortcutBody.Font = Enum.Font.RobotoMono
	shortcutBody.TextSize = 13
	shortcutBody.TextXAlignment = Enum.TextXAlignment.Left
	shortcutBody.TextYAlignment = Enum.TextYAlignment.Top
	shortcutBody.ZIndex = 51
	shortcutBody.Parent = shortcutPanel
	local shortcutClose = makeButton(shortcutPanel, "확인", 140, 34)
	shortcutClose.AnchorPoint = Vector2.new(0.5, 1)
	shortcutClose.Position = UDim2.new(0.5, 0, 1, -14)
	shortcutClose.ZIndex = 51
	styleButton(shortcutClose, THEME.Green, THEME.GreenDark, Color3.new(1, 1, 1))
	shortcutHelp.Activated:Connect(function()
		shortcutPanel.Visible = true
	end)
	shortcutClose.Activated:Connect(function()
		shortcutPanel.Visible = false
	end)
	local presetBar = Instance.new("Frame")
	presetBar.Name = "PresetBar"
	presetBar.Size = UDim2.new(1, -12, 0, 64)
	presetBar.Position = UDim2.fromOffset(6, 6)
	presetBar.BackgroundColor3 = THEME.Panel
	presetBar.BorderSizePixel = 0
	presetBar.Parent = panel
	addStroke(presetBar, THEME.WoodLight, 1)
	local presetPadding = Instance.new("UIPadding")
	presetPadding.PaddingTop = UDim.new(0, 4)
	presetPadding.PaddingBottom = UDim.new(0, 4)
	presetPadding.PaddingLeft = UDim.new(0, 5)
	presetPadding.PaddingRight = UDim.new(0, 5)
	presetPadding.Parent = presetBar
	local presetLayout = Instance.new("UIGridLayout")
	presetLayout.CellPadding = UDim2.fromOffset(4, 4)
	presetLayout.CellSize = UDim2.new(1 / 6, -5, 0, 26)
	presetLayout.FillDirection = Enum.FillDirection.Horizontal
	presetLayout.FillDirectionMaxCells = 6
	presetLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	presetLayout.SortOrder = Enum.SortOrder.LayoutOrder
	presetLayout.Parent = presetBar
	self.PresetButtons = {}
	for index, preset in PRESET_ORDER do
		local presetButton = makeButton(presetBar, preset.Label, 76, 26)
		presetButton.TextSize = 10
		presetButton.LayoutOrder = index
		presetButton.Activated:Connect(function()
			self:_switchPreset(preset.Key)
		end)
		self.PresetButtons[preset.Key] = presetButton
	end

	local workArea = Instance.new("Frame")
	workArea.Name = "WorkArea"
	workArea.BackgroundTransparency = 1
	workArea.Size = UDim2.new(1, -16, 1, -236)
	workArea.Position = UDim2.fromOffset(8, 78)
	workArea.Parent = panel

	local mobileTabs = makePanel(panel, THEME.Panel, THEME.Gold)
	mobileTabs.Name = "MobileEditorTabs"
	mobileTabs.Size = UDim2.new(1, -16, 0, 36)
	mobileTabs.Position = UDim2.fromOffset(8, 78)
	mobileTabs.Visible = false

	local bottomDock = makePanel(panel, THEME.Panel, THEME.Gold)
	bottomDock.Name = "BottomDock"
	bottomDock.Size = UDim2.new(1, -16, 0, 142)
	bottomDock.Position = UDim2.new(0, 8, 1, -150)
	local categoryBar = Instance.new("ScrollingFrame")
	categoryBar.Name = "CategoryBar"
	categoryBar.Size = UDim2.new(1, -12, 0, 36)
	categoryBar.Position = UDim2.fromOffset(6, 6)
	categoryBar.BackgroundTransparency = 1
	categoryBar.BorderSizePixel = 0
	categoryBar.ScrollBarThickness = 3
	categoryBar.ScrollBarImageColor3 = THEME.Gold
	categoryBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	categoryBar.CanvasSize = UDim2.new()
	categoryBar.Parent = bottomDock
	local categoryLayout = Instance.new("UIListLayout")
	categoryLayout.FillDirection = Enum.FillDirection.Horizontal
	categoryLayout.Padding = UDim.new(0, 5)
	categoryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	categoryLayout.Parent = categoryBar
	local categoryHint = Instance.new("TextLabel")
	categoryHint.Name = "CategoryHint"
	categoryHint.Size = UDim2.new(1, -12, 0, 24)
	categoryHint.Position = UDim2.fromOffset(6, 42)
	categoryHint.BackgroundTransparency = 1
	categoryHint.Text = "프레임  /  시간·포즈·타임라인"
	categoryHint.TextColor3 = THEME.Muted
	categoryHint.Font = Enum.Font.RobotoMono
	categoryHint.TextSize = 10
	categoryHint.TextXAlignment = Enum.TextXAlignment.Left
	categoryHint.Parent = bottomDock
	categoryHint.Visible = false
	local detailBar = Instance.new("ScrollingFrame")
	detailBar.Name = "DetailCategoryBar"
	-- 오른쪽 끝 134px는 '총 모션 길이' 입력이 쓴다(요청 6). 상세 버튼들이 그 위로
	-- 흘러가지 않도록 스크롤 폭 자체를 줄인다.
	detailBar.Size = UDim2.new(1, -146, 0, 30)
	detailBar.Position = UDim2.fromOffset(6, 42)
	detailBar.BackgroundTransparency = 1
	detailBar.BorderSizePixel = 0
	detailBar.ScrollBarThickness = 3
	detailBar.ScrollBarImageColor3 = THEME.Cyan
	detailBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	detailBar.CanvasSize = UDim2.new()
	detailBar.Parent = bottomDock
	local detailLayout = Instance.new("UIListLayout")
	detailLayout.FillDirection = Enum.FillDirection.Horizontal
	detailLayout.Padding = UDim.new(0, 4)
	detailLayout.Parent = detailBar
	self.BottomCategoryButtons = {}
	self.BottomDetailButtons = {}
	local mobilePose = makeButton(mobileTabs, "포즈", 100, 30)
	mobilePose.Size = UDim2.new(1 / 3, -5, 0, 30)
	mobilePose.Position = UDim2.fromOffset(3, 3)
	local mobilePreview = makeButton(mobileTabs, "미리보기", 100, 30)
	mobilePreview.Size = UDim2.new(1 / 3, -5, 0, 30)
	mobilePreview.Position = UDim2.new(1 / 3, 2, 0, 3)
	local mobileProperties = makeButton(mobileTabs, "속성", 100, 30)
	mobileProperties.Size = UDim2.new(1 / 3, -5, 0, 30)
	mobileProperties.Position = UDim2.new(2 / 3, 1, 0, 3)

	local leftShell = makePanel(workArea, THEME.Panel, THEME.WoodLight)
	leftShell.Name = "PoseTools"
	leftShell.Size = UDim2.new(0, 164, 1, 0)
	local leftHeader =
		makeDeskHeader(leftShell, "01", "프레임과 포즈", "KEYFRAME / POSE / BASE STATS", THEME.Green)
	leftHeader.Visible = false

	local controls = Instance.new("ScrollingFrame")
	controls.Name = "PoseControls"
	controls.Size = UDim2.new(1, -10, 1, -10)
	controls.Position = UDim2.fromOffset(5, 5)
	controls.BackgroundTransparency = 1
	controls.BorderSizePixel = 0
	controls.ScrollBarThickness = 5
	controls.ScrollBarImageColor3 = THEME.Gold
	controls.AutomaticCanvasSize = Enum.AutomaticSize.Y
	controls.CanvasSize = UDim2.new()
	controls.Parent = leftShell
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = controls

	local centerShell = makePanel(workArea, THEME.Panel, THEME.Gold)
	centerShell.Name = "PreviewDesk"
	centerShell.Size = UDim2.new(1, -536, 1, 0)
	centerShell.Position = UDim2.fromOffset(172, 0)
	local centerHeader =
		makeDeskHeader(centerShell, "02", "모션 미리보기", "DIRECT MANIPULATION / CAMERA", THEME.Gold)
	centerHeader.Visible = false
	presetBar.Parent = centerShell

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.Size = UDim2.new(1, -12, 1, -82)
	viewport.Position = UDim2.fromOffset(6, 76)
	viewport.BackgroundColor3 = THEME.WoodDark
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(170, 160, 145)
	viewport.LightColor = Color3.fromRGB(255, 230, 175)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	--[[
		요청: "UI 자체를 문 애니메이터처럼 하나의 작은 창에 다 때려박는 식으로.
		       큰 화면에선 모션을 크게 보면서 수정 하고."

		그래서 뷰포트는 더 이상 가운데 패널(centerShell) 안에 갇힌 작은 상자가 아니라
		**화면 전체를 채우는 배경**이다. 조작 창은 이 위에 떠 있는다. 부모를 gui로 두고
		ZIndex를 0으로 깔아, 창(ZIndex 5)이 항상 위에 오게 한다.
		크기는 RefreshResponsive가 매번 (1,1)로 맞춘다.
	]]
	viewport.Parent = gui
	viewport.ZIndex = 0
	-- 가짜 지평선(금색 가로줄)은 작은 상자 시절 바닥을 암시하던 장치다. 이제 3D 격자
	-- 바닥(EditorGridLine)이 실제로 보이므로 화면을 가로지르는 줄은 방해만 된다.
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	self.World = world
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 2.5, 12), Vector3.new(0, 1.8, 0))
	camera.FieldOfView = 45
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	self.Viewport = viewport
	self.EditorCamera = camera
	local source = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
	--[[
		`Character`가 생겼다고 파츠까지 붙은 건 아니다. 파츠가 붙기 전에 복제하면
		**Humanoid만 들어 있고 BasePart가 0개인 껍데기**가 나온다 — 실제로 그 상태라
		미리보기에 아무것도 보이지 않았다(리그 GetExtentsSize가 0,0,0이었다).

		편집기는 R6 관절(Right Shoulder / Left Hip / …)을 다루므로 최소한 뿌리와
		몸통까지는 기다린다. 타임아웃을 두어 아바타가 R6가 아니어도 멈추지 않게 한다.
	]]
	source:WaitForChild("Humanoid", 10)
	source:WaitForChild("HumanoidRootPart", 10)
	source:WaitForChild("Torso", 10)
	local wasArchivable = source.Archivable
	source.Archivable = true
	local clone = source:Clone()
	source.Archivable = wasArchivable
	for _, item in clone:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = item.Name == "HumanoidRootPart"
			item.CanCollide = false
		end
	end
	clone:PivotTo(CFrame.new())
	clone.Parent = world
	self.PreviewRig = clone
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.Name = "SelectedBodyPart"
	selectionBox.Color3 = THEME.GoldLight
	selectionBox.SurfaceColor3 = THEME.Gold
	selectionBox.SurfaceTransparency = 0.92
	selectionBox.LineThickness = 0.035
	selectionBox.Adornee = clone:FindFirstChild(self.SelectedGizmoPart)
	selectionBox.Parent = world
	self.SelectionBox = selectionBox
	local hoverSelectionBox = Instance.new("SelectionBox")
	hoverSelectionBox.Name = "HoveredBodyPart"
	hoverSelectionBox.Color3 = THEME.Green
	hoverSelectionBox.SurfaceColor3 = THEME.Green
	hoverSelectionBox.SurfaceTransparency = 0.88
	hoverSelectionBox.LineThickness = 0.045
	hoverSelectionBox.Adornee = nil
	hoverSelectionBox.Parent = world
	self.HoverSelectionBox = hoverSelectionBox
	local previewRoot = clone:FindFirstChild("HumanoidRootPart")
	if previewRoot and previewRoot:IsA("BasePart") then
		self.PreviewRootBase = previewRoot.CFrame
	end
	local floorY: number? = nil
	local rightLeg = clone:FindFirstChild("Right Leg")
	local leftLeg = clone:FindFirstChild("Left Leg")
	for _, leg in { rightLeg, leftLeg } do
		if leg and leg:IsA("BasePart") then
			local legBottom = leg.Position.Y - leg.Size.Y * 0.5
			floorY = floorY and math.min(floorY, legBottom) or legBottom
		end
	end
	floorY = floorY or -3
	local previewFloor = Instance.new("Part")
	previewFloor.Name = "EditorFloor"
	previewFloor.Anchored = true
	previewFloor.CanCollide = false
	previewFloor.CanQuery = false
	previewFloor.CastShadow = false
	-- 예전엔 스터드가 박힌 갈색 벽돌 바닥(공방 책상 위)이었다. Moon Animator의 뷰포트는
	-- 무늬 없는 어두운 바닥에 격자선만 얹혀 있으므로, 재질을 평평하게 낮추고 색도
	-- 패널 배경과 같은 계열로 맞춘다. 격자선은 아래 EditorGridLine이 그대로 그린다.
	previewFloor.Material = Enum.Material.SmoothPlastic
	previewFloor.TopSurface = Enum.SurfaceType.Smooth
	previewFloor.BottomSurface = Enum.SurfaceType.Smooth
	previewFloor.Color = THEME.WoodDark
	previewFloor.Size = Vector3.new(80, 0.5, 50)
	previewFloor.CFrame = CFrame.new(0, floorY - 0.25, 0)
	previewFloor.Parent = world
	self.PreviewFloor = previewFloor
	for x = -40, 40, 5 do
		local line = Instance.new("Part")
		line.Name = x == 0 and "EditorGridXAxis" or "EditorGridLine"
		line.Anchored = true
		line.CanCollide = false
		line.CanQuery = false
		line.CastShadow = false
		line.Material = Enum.Material.Neon
		line.Color = x == 0 and THEME.Red or Color3.fromRGB(96, 96, 106)
		line.Transparency = x == 0 and 0.15 or 0.48
		line.Size = Vector3.new(x == 0 and 0.08 or 0.035, 0.015, 50)
		line.CFrame = CFrame.new(x, floorY + 0.012, 0)
		line.Parent = world
	end
	for z = -25, 25, 5 do
		local line = Instance.new("Part")
		line.Name = z == 0 and "EditorGridZAxis" or "EditorGridLine"
		line.Anchored = true
		line.CanCollide = false
		line.CanQuery = false
		line.CastShadow = false
		line.Material = Enum.Material.Neon
		line.Color = z == 0 and THEME.Blue or Color3.fromRGB(96, 96, 106)
		line.Transparency = z == 0 and 0.15 or 0.48
		line.Size = Vector3.new(80, 0.015, z == 0 and 0.08 or 0.035)
		line.CFrame = CFrame.new(0, floorY + 0.013, z)
		line.Parent = world
	end
	-- (예전엔 여기서 가짜 지평선 GroundLine을 숨겼다. 그 프레임 자체를 없앴다.)
	self:_ensurePreviewWeapon()
	self:_ensurePreviewDualWeapon()
	self:_ensureDecorationPreviews()
	self:_ensureOnionRig()
	local hitbox = Instance.new("Part")
	hitbox.Name = "SelectedHitbox"
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.Material = Enum.Material.ForceField
	hitbox.Color = Color3.fromRGB(255, 70, 70)
	hitbox.Transparency = 0.5
	hitbox.Transparency = 1
	hitbox.Parent = world
	self.HitboxPreview = hitbox
	local eventPreview = Instance.new("Part")
	eventPreview.Name = "SelectedFrameEvent"
	eventPreview.Anchored = true
	eventPreview.CanCollide = false
	eventPreview.CanQuery = false
	eventPreview.Material = Enum.Material.Neon
	eventPreview.Color = THEME.Cyan
	eventPreview.Size = Vector3.new(2, 2, 0.12)
	eventPreview.Transparency = 1
	eventPreview.Parent = world
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local decal = Instance.new("Decal")
		decal.Name = face == Enum.NormalId.Front and "EventImageFront" or "EventImageBack"
		decal.Face = face
		decal.Transparency = 1
		decal.Parent = eventPreview
	end
	self.EventPreview = eventPreview
	self:_buildDirectManipulation(viewport)

	local viewportBadge = Instance.new("TextLabel")
	viewportBadge.Name = "ViewportBadge"
	viewportBadge.Size = UDim2.fromOffset(176, 28)
	viewportBadge.Position = UDim2.fromOffset(8, 8)
	viewportBadge.BackgroundColor3 = THEME.Panel
	viewportBadge.BackgroundTransparency = 0.08
	viewportBadge.BorderSizePixel = 0
	viewportBadge.Text = "평타  /  FRAME 01"
	viewportBadge.TextColor3 = THEME.Green
	viewportBadge.Font = Enum.Font.RobotoMono
	viewportBadge.TextSize = 10
	viewportBadge.ZIndex = 20
	viewportBadge.Parent = viewport
	addStroke(viewportBadge, THEME.GreenDark, 1)
	self.ViewportBadge = viewportBadge

	local cameraTools = Instance.new("Frame")
	cameraTools.Name = "CameraTools"
	cameraTools.Size = UDim2.fromOffset(258, 32)
	cameraTools.Position = UDim2.new(1, -266, 0, 8)
	cameraTools.BackgroundColor3 = THEME.Panel
	cameraTools.BackgroundTransparency = 0.08
	cameraTools.BorderSizePixel = 0
	cameraTools.ZIndex = 20
	cameraTools.Parent = viewport
	addStroke(cameraTools, THEME.Gold, 1)
	local frontCamera = makeButton(cameraTools, "정면", 48, 24)
	frontCamera.Position = UDim2.fromOffset(4, 4)
	frontCamera.ZIndex = 21
	local sideCamera = makeButton(cameraTools, "측면", 48, 24)
	sideCamera.Position = UDim2.fromOffset(55, 4)
	sideCamera.ZIndex = 21
	local topCamera = makeButton(cameraTools, "상단", 48, 24)
	topCamera.Position = UDim2.fromOffset(106, 4)
	topCamera.ZIndex = 21
	local resetCamera = makeButton(cameraTools, "초기화", 55, 24)
	resetCamera.Position = UDim2.fromOffset(157, 4)
	resetCamera.ZIndex = 21
	self.CameraReadout = Instance.new("TextLabel")
	self.CameraReadout.Size = UDim2.fromOffset(40, 24)
	self.CameraReadout.Position = UDim2.fromOffset(214, 4)
	self.CameraReadout.BackgroundTransparency = 1
	self.CameraReadout.TextColor3 = THEME.GoldLight
	self.CameraReadout.Font = Enum.Font.RobotoMono
	self.CameraReadout.TextSize = 10
	self.CameraReadout.ZIndex = 21
	self.CameraReadout.Parent = cameraTools
	frontCamera.Activated:Connect(function()
		self.CameraState.Yaw = math.pi
		self.CameraState.Pitch = 0
		self:_updateEditorCamera()
	end)
	sideCamera.Activated:Connect(function()
		self.CameraState.Yaw = math.pi * 0.5
		self.CameraState.Pitch = 0
		self:_updateEditorCamera()
	end)
	topCamera.Activated:Connect(function()
		self.CameraState.Yaw = math.pi
		self.CameraState.Pitch = -1.25
		self:_updateEditorCamera()
	end)
	resetCamera.Activated:Connect(function()
		self:_resetEditorCamera()
	end)
	self:_resetEditorCamera()

	local directHint = Instance.new("TextLabel")
	directHint.Size = UDim2.new(1, -16, 0, 36)
	directHint.Position = UDim2.fromOffset(8, 46)
	directHint.BackgroundColor3 = THEME.Panel
	directHint.BackgroundTransparency = 0.2
	directHint.BorderSizePixel = 0
	directHint.Text =
		"점을 드래그해 포즈·무기·판정을 이동  |  우클릭: 회전  |  Shift+좌클릭/휠클릭: 이동  |  휠: 줌"
	directHint.TextColor3 = THEME.Parchment
	directHint.Font = Enum.Font.RobotoMono
	directHint.TextSize = 10
	directHint.TextWrapped = true
	directHint.ZIndex = 18
	directHint.Parent = viewport

	local timelineLabel = Instance.new("TextLabel")
	timelineLabel.Size = UDim2.new(1, -12, 0, 22)
	timelineLabel.Position = UDim2.new()
	timelineLabel.BackgroundTransparency = 1
	timelineLabel.Text = "TIMELINE   ▲ 프레임(끌어서 간격 조절)   H 판정   E 이펙트"
	timelineLabel.TextColor3 = THEME.Muted
	timelineLabel.Font = Enum.Font.RobotoMono
	timelineLabel.TextSize = 10
	timelineLabel.TextXAlignment = Enum.TextXAlignment.Left
	timelineLabel.Parent = controls
	--[[
		요청: "프레임도 초 단위가 아니라 픽셀로얄 모션공방처럼 삼각형 놔서 프레임마다
		       사이의 간격을 직접 정할 수 있게 해줘."

		예전에는 프레임이 **같은 폭 버튼**으로 죽 늘어섰다. 그래서 화면상 간격이 실제
		시간과 아무 상관이 없었다 — 0.02초 뒤 프레임이나 2초 뒤 프레임이나 똑같이 생겼고,
		간격을 바꾸려면 옆의 입력칸에 초를 타이핑해야 했다.

		이제는 눈금자다. 삼각형(▼)이 자기 시간 위치에 놓이고, 끌면 그 자리가 곧 시간이라
		앞뒤 간격이 즉시 바뀐다. 그래서 가로 배치를 UIListLayout에 맡기지 않고
		_timelineFraction으로 직접 계산해 놓는다.
	]]
	local timeline = Instance.new("ScrollingFrame")
	timeline.Name = "Timeline"
	timeline.Size = UDim2.new(1, -12, 0, 52)
	timeline.Position = UDim2.new()
	timeline.BackgroundColor3 = THEME.PanelAlt
	timeline.BorderSizePixel = 0
	timeline.ScrollBarThickness = 0
	timeline.ScrollingEnabled = false
	timeline.AutomaticCanvasSize = Enum.AutomaticSize.None
	timeline.CanvasSize = UDim2.new()
	timeline.ClipsDescendants = true
	timeline.Parent = controls
	addStroke(timeline, THEME.WoodLight, 1)
	self.Timeline = timeline

	local overviewHeader = Instance.new("Frame")
	overviewHeader.Name = "FrameOverviewHeader"
	overviewHeader.Size = UDim2.new(1, -12, 0, 30)
	overviewHeader.Position = UDim2.new()
	overviewHeader.BackgroundColor3 = THEME.Wood
	overviewHeader.BorderSizePixel = 0
	overviewHeader.Parent = controls
	addStroke(overviewHeader, THEME.WoodLight, 1)
	self.FrameOverviewToggle = makeButton(overviewHeader, "▶ 프레임 몰아보기", 160, 24)
	self.FrameOverviewToggle.Position = UDim2.fromOffset(4, 3)
	styleButton(self.FrameOverviewToggle, THEME.Gold)
	local overviewMinus = makeButton(overviewHeader, "◀", 30, 24)
	overviewMinus.Position = UDim2.new(1, -104, 0, 3)
	styleButton(overviewMinus, THEME.Gold)
	self.FrameOverviewSizeLabel = Instance.new("TextLabel")
	self.FrameOverviewSizeLabel.Size = UDim2.fromOffset(38, 24)
	self.FrameOverviewSizeLabel.Position = UDim2.new(1, -70, 0, 3)
	self.FrameOverviewSizeLabel.BackgroundTransparency = 1
	self.FrameOverviewSizeLabel.TextColor3 = THEME.Parchment
	self.FrameOverviewSizeLabel.Font = Enum.Font.RobotoMono
	self.FrameOverviewSizeLabel.TextSize = 10
	self.FrameOverviewSizeLabel.Parent = overviewHeader
	local overviewPlus = makeButton(overviewHeader, "▶", 30, 24)
	overviewPlus.Position = UDim2.new(1, -34, 0, 3)
	styleButton(overviewPlus, THEME.Gold)
	local overview = Instance.new("ScrollingFrame")
	overview.Name = "FrameOverview"
	overview.Size = UDim2.new(1, -12, 0, 180)
	overview.Position = UDim2.new()
	overview.BackgroundColor3 = THEME.PanelAlt
	overview.BorderSizePixel = 0
	overview.ScrollBarThickness = 5
	overview.ScrollBarImageColor3 = THEME.Gold
	overview.AutomaticCanvasSize = Enum.AutomaticSize.X
	overview.CanvasSize = UDim2.new()
	overview.Visible = false
	overview.Parent = controls
	addStroke(overview, THEME.Gold, 1)
	local overviewLayout = Instance.new("UIListLayout")
	overviewLayout.FillDirection = Enum.FillDirection.Horizontal
	overviewLayout.Padding = UDim.new(0, 6)
	overviewLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	overviewLayout.Parent = overview
	self.FrameOverview = overview
	local overviewResize = makeButton(controls, "↕", 44, 12)
	overviewResize.Name = "FrameOverviewResize"
	overviewResize.AnchorPoint = Vector2.zero
	overviewResize.Position = UDim2.new()
	overviewResize.Size = UDim2.new(1, -12, 0, 12)
	overviewResize.Visible = false
	overviewResize.ZIndex = 24
	overviewResize.TextSize = 9
	styleButton(overviewResize, THEME.Gold)
	self.FrameOverviewResize = overviewResize
	overviewResize.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self.OverviewResizeDrag = { StartY = input.Position.Y, StartHeight = self.FrameOverviewHeight }
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local drag = self.OverviewResizeDrag
		if
			not drag
			or (
				input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch
			)
		then
			return
		end
		self:_setFrameOverviewHeight(drag.StartHeight - (input.Position.Y - drag.StartY))
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			self.OverviewResizeDrag
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			self.OverviewResizeDrag = nil
		end
	end)
	self.FrameOverviewToggle.Activated:Connect(function()
		self.FrameOverviewOpen = not self.FrameOverviewOpen
		self.FrameOverview.Visible = self.FrameOverviewOpen
		self.FrameOverviewResize.Visible = self.FrameOverviewOpen
		self.FrameOverviewToggle.Text = self.FrameOverviewOpen and "▼ 프레임 몰아보기"
			or "▶ 프레임 몰아보기"
		self:_refreshFrameOverview()
	end)
	overviewMinus.Activated:Connect(function()
		self.FrameOverviewSize = math.max(52, self.FrameOverviewSize - 8)
		self:_refreshFrameOverview()
	end)
	overviewPlus.Activated:Connect(function()
		self.FrameOverviewSize = math.min(128, self.FrameOverviewSize + 8)
		self:_refreshFrameOverview()
	end)

	local rightShell = makePanel(workArea, THEME.Panel, THEME.WoodLight)
	rightShell.Name = "Properties"
	rightShell.Size = UDim2.new(0, 356, 1, 0)
	rightShell.Position = UDim2.new(1, -356, 0, 0)
	local rightHeader = makeDeskHeader(rightShell, "03", "선택 속성", "WEAPON / HITBOX / FX / COMBAT", THEME.Cyan)
	rightHeader.Visible = false

	local properties = Instance.new("ScrollingFrame")
	properties.Name = "PropertyControls"
	properties.Size = UDim2.new(1, -10, 1, -10)
	properties.Position = UDim2.fromOffset(5, 5)
	properties.BackgroundTransparency = 1
	properties.BorderSizePixel = 0
	properties.ScrollBarThickness = 5
	properties.ScrollBarImageColor3 = THEME.Gold
	properties.AutomaticCanvasSize = Enum.AutomaticSize.Y
	properties.CanvasSize = UDim2.new()
	properties.Parent = rightShell
	local propertyList = Instance.new("UIListLayout")
	propertyList.Padding = UDim.new(0, 6)
	propertyList.SortOrder = Enum.SortOrder.LayoutOrder
	propertyList.Parent = properties

	local presetInfoSection = makeSection(controls, "프리셋 정보")
	local packIdentityRow = Instance.new("Frame")
	packIdentityRow.Size = UDim2.new(1, 0, 0, 38)
	packIdentityRow.BackgroundTransparency = 1
	packIdentityRow.Parent = controls
	self.PackNameInput = makeInput(packIdentityRow, "무기 이름", 150)
	self.PackNameInput.Size = UDim2.new(0.68, -3, 0, 34)
	self.BodyColorInput = makeInput(packIdentityRow, "색상 #RRGGBB", 100)
	self.BodyColorInput.Size = UDim2.new(0.32, -3, 0, 34)
	self.BodyColorInput.Position = UDim2.new(0.68, 3, 0, 0)
	local packDescriptionRow = Instance.new("Frame")
	packDescriptionRow.Size = UDim2.new(1, 0, 0, 38)
	packDescriptionRow.BackgroundTransparency = 1
	packDescriptionRow.Parent = controls
	self.PackDescriptionInput = makeInput(packDescriptionRow, "무기 설명", 220)
	self.PackDescriptionInput.Size = UDim2.new(1, 0, 0, 34)
	for _, input in { self.PackNameInput, self.PackDescriptionInput, self.BodyColorInput } do
		input.FocusLost:Connect(function()
			self:_commitPackIdentity()
		end)
	end
	local presetInfoRow = Instance.new("Frame")
	presetInfoRow.Size = UDim2.new(1, 0, 0, 38)
	presetInfoRow.BackgroundTransparency = 1
	presetInfoRow.Parent = controls
	self.MotionNameInput = makeInput(presetInfoRow, "모션 표시 이름", 150)
	self.MotionNameInput.Size = UDim2.new(1, -100, 0, 34)
	self.PresetCompleteButton = makeButton(presetInfoRow, "미완성", 94, 34)
	self.PresetCompleteButton.Position = UDim2.new(1, -94, 0, 0)
	styleButton(self.PresetCompleteButton, THEME.Red)
	self.MotionNameInput.FocusLost:Connect(function()
		self:_pushUndo()
		self.Motion.Name =
			string.sub(self.MotionNameInput.Text ~= "" and self.MotionNameInput.Text or self.Motion.Name, 1, 32)
		self:_refreshPresetBar()
	end)
	local presetDescriptionRow = Instance.new("Frame")
	presetDescriptionRow.Size = UDim2.new(1, 0, 0, 38)
	presetDescriptionRow.BackgroundTransparency = 1
	presetDescriptionRow.Parent = controls
	self.MotionDescriptionInput = makeInput(presetDescriptionRow, "이 프리셋의 스킬 설명", 220)
	self.MotionDescriptionInput.Size = UDim2.new(1, 0, 0, 34)
	self.MotionDescriptionInput.FocusLost:Connect(function()
		self:_pushUndo()
		self.Motion.Description = string.sub(self.MotionDescriptionInput.Text, 1, 120)
	end)
	self.PresetCompleteButton.Activated:Connect(function()
		self:_pushUndo()
		self.Motion.Complete = not self.Motion.Complete
		self:_refreshPresetBar()
	end)

	local frameSection = makeSection(controls, "프레임")
	local frameNavigation = Instance.new("Frame")
	frameNavigation.Size = UDim2.new(1, 0, 0, 38)
	frameNavigation.BackgroundTransparency = 1
	frameNavigation.Parent = controls
	local previous = makeButton(frameNavigation, "◀", 44, 36)
	styleButton(previous, THEME.Gold)
	self.FrameButton = makeButton(frameNavigation, "프레임 1 / 2", 100, 36)
	self.FrameButton.Size = UDim2.new(1, -100, 0, 36)
	self.FrameButton.Position = UDim2.fromOffset(50, 0)
	styleButton(self.FrameButton, THEME.Green, THEME.GreenDark, Color3.new(1, 1, 1))
	local nextFrame = makeButton(frameNavigation, "▶", 44, 36)
	nextFrame.Position = UDim2.new(1, -44, 0, 0)
	styleButton(nextFrame, THEME.Gold)
	previous.Activated:Connect(function()
		self:_selectFrame(math.max(1, self.SelectedFrame - 1))
	end)
	nextFrame.Activated:Connect(function()
		self:_selectFrame(math.min(#self.Motion.Frames, self.SelectedFrame + 1))
	end)
	local frameCommands = Instance.new("Frame")
	frameCommands.Size = UDim2.new(1, 0, 0, 38)
	frameCommands.BackgroundTransparency = 1
	frameCommands.Parent = controls
	local add = makeButton(frameCommands, "+ 프레임", 90, 34)
	add.Size = UDim2.new(0.22, -3, 0, 34)
	styleButton(add, THEME.Green)
	local copy = makeButton(frameCommands, "복사", 80, 34)
	copy.Size = UDim2.new(0.2, -3, 0, 34)
	copy.Position = UDim2.new(0.22, 2, 0, 0)
	styleButton(copy, THEME.Gold)
	local paste = makeButton(frameCommands, "붙여넣기", 80, 34)
	paste.Size = UDim2.new(0.22, -3, 0, 34)
	paste.Position = UDim2.new(0.42, 4, 0, 0)
	styleButton(paste, THEME.Cyan)
	local cut = makeButton(frameCommands, "잘라내기", 70, 34)
	cut.Size = UDim2.new(0.2, -3, 0, 34)
	cut.Position = UDim2.new(0.64, 6, 0, 0)
	styleButton(cut, Color3.fromRGB(197, 108, 255))
	local delete = makeButton(frameCommands, "삭제", 80, 34)
	delete.Size = UDim2.new(0.16, -3, 0, 34)
	delete.Position = UDim2.new(0.84, 8, 0, 0)
	styleButton(delete, THEME.Red)
	add.Activated:Connect(function()
		self:_insertFrame(true)
	end)
	copy.Activated:Connect(function()
		self:_copyCurrentFrame()
	end)
	paste.Activated:Connect(function()
		self:_pasteCurrentFrame()
	end)
	cut.Activated:Connect(function()
		self:_cutCurrentFrame()
	end)
	delete.Activated:Connect(function()
		self:_deleteFrame()
	end)
	local frameTimeRow = Instance.new("Frame")
	frameTimeRow.Size = UDim2.new(1, 0, 0, 36)
	frameTimeRow.BackgroundTransparency = 1
	frameTimeRow.Parent = controls
	local frameTimeLabel = Instance.new("TextLabel")
	frameTimeLabel.Size = UDim2.new(0.5, -4, 1, 0)
	frameTimeLabel.BackgroundTransparency = 1
	frameTimeLabel.Text = "현재 프레임 시간"
	frameTimeLabel.TextColor3 = THEME.Parchment
	frameTimeLabel.Font = Enum.Font.Gotham
	frameTimeLabel.TextSize = 11
	frameTimeLabel.TextXAlignment = Enum.TextXAlignment.Left
	frameTimeLabel.Parent = frameTimeRow
	self.FrameTimeInput = makeInput(frameTimeRow, "초", 80)
	self.FrameTimeInput.Size = UDim2.new(0.5, -2, 0, 34)
	self.FrameTimeInput.Position = UDim2.new(0.5, 2, 0, 0)
	self.FrameTimeInput.FocusLost:Connect(function()
		local frame = self.Motion.Frames[self.SelectedFrame]
		local previousTime = self.SelectedFrame > 1 and self.Motion.Frames[self.SelectedFrame - 1].Time or 0
		local nextTime = self.SelectedFrame < #self.Motion.Frames and self.Motion.Frames[self.SelectedFrame + 1].Time
			or MAX_MOTION_DURATION
		self:_pushUndo()
		frame.Time = math.clamp(tonumber(self.FrameTimeInput.Text) or frame.Time, previousTime, nextTime)
		self:_refreshAll()
	end)

	--[[
		총 모션 길이 입력.

		요청: "총 모션 길이는 타이핑으로 직접 정할 수 있게 해줘."
		요청(위치): "첨부 한 사진의 빨간 박스 위치에" — 상세줄(장식 설정 …) 오른쪽 끝.
		그래서 포즈 목록이 아니라 **하단 독**에 직접 붙인다.

		총 길이 = 마지막 프레임의 시간이다. 그래서 여기에 숫자를 넣는 것은 **맨 끝
		삼각형을 그 자리로 옮기는 것**과 같다 — 끌어서 맞추기 어려운 값을 정확히
		넣을 때 쓴다. 바로 앞 프레임보다 뒤에 있어야 하므로 그만큼은 가둔다.
	]]
	local durationRow = Instance.new("Frame")
	durationRow.Name = "TotalDurationRow"
	durationRow.Size = UDim2.fromOffset(128, 27)
	durationRow.Position = UDim2.new(1, -134, 0, 43)
	durationRow.BackgroundTransparency = 1
	durationRow.Parent = bottomDock
	local durationLabel = Instance.new("TextLabel")
	durationLabel.Size = UDim2.fromOffset(46, 27)
	durationLabel.BackgroundTransparency = 1
	durationLabel.Text = "총 길이"
	durationLabel.TextColor3 = THEME.Muted
	durationLabel.Font = Enum.Font.RobotoMono
	durationLabel.TextSize = 10
	durationLabel.TextXAlignment = Enum.TextXAlignment.Left
	durationLabel.Parent = durationRow
	self.DurationInput = makeInput(durationRow, "초", 78)
	self.DurationInput.Size = UDim2.fromOffset(78, 27)
	self.DurationInput.Position = UDim2.fromOffset(48, 0)
	self.DurationInput.TextSize = 10
	self.DurationInput.FocusLost:Connect(function()
		local frames = self.Motion.Frames
		local last = frames[#frames]
		if not last then
			return
		end
		local floor = #frames > 1 and frames[#frames - 1].Time + 0.01 or 0.01
		self:_pushUndo()
		last.Time = math.clamp(tonumber(self.DurationInput.Text) or last.Time, floor, MAX_MOTION_DURATION)
		self:_refreshAll()
	end)

	local jointSection = makeSection(controls, "직접 관절 조작")
	local jointHint = Instance.new("TextLabel")
	jointHint.Size = UDim2.new(1, 0, 0, 82)
	jointHint.BackgroundColor3 = THEME.PanelAlt
	jointHint.BorderSizePixel = 0
	jointHint.Text =
		"부위에 커서를 올리면 연두색으로 표시됩니다.\n미리보기나 좌측 버튼으로 부위를 선택하세요.\n회전은 5도 단위이며 금색 점은 90도 기준점입니다."
	jointHint.TextColor3 = THEME.Parchment
	jointHint.Font = Enum.Font.RobotoMono
	jointHint.TextSize = 11
	jointHint.TextXAlignment = Enum.TextXAlignment.Left
	jointHint.TextYAlignment = Enum.TextYAlignment.Top
	jointHint.TextWrapped = true
	jointHint.Parent = controls
	addPadding(jointHint, 8)
	addStroke(jointHint, THEME.Wood, 1)
	local poseCommandRow = Instance.new("Frame")
	poseCommandRow.Size = UDim2.new(1, 0, 0, 38)
	poseCommandRow.BackgroundTransparency = 1
	poseCommandRow.Parent = controls
	self.OnionButton = makeButton(poseCommandRow, "잔상 OFF", 80, 34)
	self.OnionButton.Size = UDim2.new(0.34, -4, 0, 34)
	styleButton(self.OnionButton, THEME.Blue)
	local mirrorPose = makeButton(poseCommandRow, "좌우 반전", 80, 34)
	mirrorPose.Size = UDim2.new(0.33, -4, 0, 34)
	mirrorPose.Position = UDim2.new(0.34, 2, 0, 0)
	styleButton(mirrorPose, Color3.fromRGB(197, 108, 255))
	local resetPose = makeButton(poseCommandRow, "포즈 초기화", 80, 34)
	resetPose.Size = UDim2.new(0.33, -2, 0, 34)
	resetPose.Position = UDim2.new(0.67, 2, 0, 0)
	styleButton(resetPose, THEME.Red)
	self.OnionButton.Activated:Connect(function()
		self.OnionEnabled = not self.OnionEnabled
		self.OnionButton.Text = self.OnionEnabled and "잔상 ON" or "잔상 OFF"
		self:_updateOnionRig()
	end)
	mirrorPose.Activated:Connect(function()
		self:_mirrorCurrentPose()
	end)
	resetPose.Activated:Connect(function()
		self:_resetCurrentPose()
	end)

	local combatSection = makeSection(properties, "프리셋 전투 설정")
	local combatRowOne = Instance.new("Frame")
	combatRowOne.Size = UDim2.new(1, 0, 0, 38)
	combatRowOne.BackgroundTransparency = 1
	combatRowOne.Parent = properties
	self.CombatDamageInput = makeInput(combatRowOne, "대미지", 80)
	self.CombatDamageInput.Size = UDim2.new(0.34, -3, 0, 34)
	self.CombatCooldownInput = makeInput(combatRowOne, "쿨타임(턴)", 80)
	self.CombatCooldownInput.Size = UDim2.new(0.33, -3, 0, 34)
	self.CombatCooldownInput.Position = UDim2.new(0.34, 3, 0, 0)
	self.CombatKnockbackInput = makeInput(combatRowOne, "넉백", 80)
	self.CombatKnockbackInput.Size = UDim2.new(0.33, -3, 0, 34)
	self.CombatKnockbackInput.Position = UDim2.new(0.67, 6, 0, 0)
	local combatRowTwo = Instance.new("Frame")
	combatRowTwo.Size = UDim2.new(1, 0, 0, 38)
	combatRowTwo.BackgroundTransparency = 1
	combatRowTwo.Parent = properties
	self.CastDirectionButton = makeButton(combatRowTwo, "대상 바라보기", 110, 34)
	self.CastDirectionButton.Size = UDim2.new(0.46, -3, 0, 34)
	styleButton(self.CastDirectionButton, THEME.Cyan)
	self.TargetCountButton = makeButton(combatRowTwo, "대상 1인", 90, 34)
	self.TargetCountButton.Size = UDim2.new(0.27, -3, 0, 34)
	self.TargetCountButton.Position = UDim2.new(0.46, 3, 0, 0)
	styleButton(self.TargetCountButton, THEME.Gold)
	self.RangedButton = makeButton(combatRowTwo, "근거리", 80, 34)
	self.RangedButton.Size = UDim2.new(0.27, -3, 0, 34)
	self.RangedButton.Position = UDim2.new(0.73, 6, 0, 0)
	styleButton(self.RangedButton, Color3.fromRGB(255, 160, 80))
	self.CastDirectionButton.Activated:Connect(function()
		self:_cycleCastDirection()
	end)
	self.TargetCountButton.Activated:Connect(function()
		local combat = self:_combat()
		self:_pushUndo()
		combat.TargetCount = (combat.TargetCount or 1) % 3 + 1
		self:_refreshCombatFields()
	end)
	self.RangedButton.Activated:Connect(function()
		local combat = self:_combat()
		self:_pushUndo()
		combat.Ranged = not combat.Ranged
		self:_refreshCombatFields()
	end)
	for _, input in { self.CombatDamageInput, self.CombatCooldownInput, self.CombatKnockbackInput } do
		input.FocusLost:Connect(function()
			self:_commitCombatFields()
		end)
	end
	self.CombatSpecialRow = Instance.new("Frame")
	self.CombatSpecialRow.Size = UDim2.new(1, 0, 0, 38)
	self.CombatSpecialRow.BackgroundTransparency = 1
	self.CombatSpecialRow.Parent = properties
	self.HeavyAfterInput = makeInput(self.CombatSpecialRow, "평타 후 강공격 1~5", 110)
	self.UltimateGainInput = makeInput(self.CombatSpecialRow, "궁 게이지 0~35", 110)
	self.DashDistanceInput = makeInput(self.CombatSpecialRow, "대시 거리 0~320", 110)
	for _, input in { self.HeavyAfterInput, self.UltimateGainInput, self.DashDistanceInput } do
		input.FocusLost:Connect(function()
			self:_commitCombatSpecialFields()
		end)
	end

	local statusCommands = Instance.new("Frame")
	statusCommands.Size = UDim2.new(1, 0, 0, 38)
	statusCommands.BackgroundTransparency = 1
	statusCommands.Parent = properties
	self.AddStatusButton = makeButton(statusCommands, "+ 상태이상", 90, 34)
	self.AddStatusButton.Size = UDim2.new(0.34, -3, 0, 34)
	styleButton(self.AddStatusButton, THEME.Red)
	self.StatusCycleButton = makeButton(statusCommands, "상태 0 / 0", 100, 34)
	self.StatusCycleButton.Size = UDim2.new(0.42, -3, 0, 34)
	self.StatusCycleButton.Position = UDim2.new(0.34, 3, 0, 0)
	styleButton(self.StatusCycleButton, THEME.Gold)
	self.DeleteStatusButton = makeButton(statusCommands, "삭제", 60, 34)
	self.DeleteStatusButton.Size = UDim2.new(0.24, -3, 0, 34)
	self.DeleteStatusButton.Position = UDim2.new(0.76, 6, 0, 0)
	styleButton(self.DeleteStatusButton, THEME.Red)
	self.AddStatusButton.Activated:Connect(function()
		self:_addStatus()
	end)
	self.StatusCycleButton.Activated:Connect(function()
		self:_cycleStatus()
	end)
	self.DeleteStatusButton.Activated:Connect(function()
		self:_deleteStatus()
	end)
	local statusFields = Instance.new("Frame")
	statusFields.Size = UDim2.new(1, 0, 0, 38)
	statusFields.BackgroundTransparency = 1
	statusFields.Parent = properties
	self.StatusFrameInput = makeInput(statusFields, "적용 F", 70)
	self.StatusFrameInput.Size = UDim2.new(0.25, -3, 0, 34)
	self.StatusPowerInput = makeInput(statusFields, "위력", 70)
	self.StatusPowerInput.Size = UDim2.new(0.25, -3, 0, 34)
	self.StatusPowerInput.Position = UDim2.new(0.25, 3, 0, 0)
	self.StatusStacksInput = makeInput(statusFields, "스택", 70)
	self.StatusStacksInput.Size = UDim2.new(0.25, -3, 0, 34)
	self.StatusStacksInput.Position = UDim2.new(0.5, 6, 0, 0)
	self.StatusDurationInput = makeInput(statusFields, "지속 턴", 70)
	self.StatusDurationInput.Size = UDim2.new(0.25, -3, 0, 34)
	self.StatusDurationInput.Position = UDim2.new(0.75, 9, 0, 0)
	for _, input in { self.StatusFrameInput, self.StatusPowerInput, self.StatusStacksInput, self.StatusDurationInput } do
		input.FocusLost:Connect(function()
			self:_commitStatusFields()
		end)
	end

	local buffCommands = Instance.new("Frame")
	buffCommands.Size = UDim2.new(1, 0, 0, 38)
	buffCommands.BackgroundTransparency = 1
	buffCommands.Parent = properties
	self.AddBuffButton = makeButton(buffCommands, "+ 버프", 90, 34)
	self.AddBuffButton.Size = UDim2.new(0.34, -3, 0, 34)
	styleButton(self.AddBuffButton, THEME.Cyan)
	self.BuffCycleButton = makeButton(buffCommands, "버프 0 / 0", 100, 34)
	self.BuffCycleButton.Size = UDim2.new(0.42, -3, 0, 34)
	self.BuffCycleButton.Position = UDim2.new(0.34, 3, 0, 0)
	styleButton(self.BuffCycleButton, THEME.Gold)
	self.DeleteBuffButton = makeButton(buffCommands, "삭제", 60, 34)
	self.DeleteBuffButton.Size = UDim2.new(0.24, -3, 0, 34)
	self.DeleteBuffButton.Position = UDim2.new(0.76, 6, 0, 0)
	styleButton(self.DeleteBuffButton, THEME.Red)
	self.AddBuffButton.Activated:Connect(function()
		self:_addBuff()
	end)
	self.BuffCycleButton.Activated:Connect(function()
		self:_cycleBuff()
	end)
	self.DeleteBuffButton.Activated:Connect(function()
		self:_deleteBuff()
	end)
	local buffFields = Instance.new("Frame")
	buffFields.Size = UDim2.new(1, 0, 0, 38)
	buffFields.BackgroundTransparency = 1
	buffFields.Parent = properties
	self.BuffFrameInput = makeInput(buffFields, "적용 F", 80)
	self.BuffFrameInput.Size = UDim2.new(0.34, -3, 0, 34)
	self.BuffValueInput = makeInput(buffFields, "값", 80)
	self.BuffValueInput.Size = UDim2.new(0.33, -3, 0, 34)
	self.BuffValueInput.Position = UDim2.new(0.34, 3, 0, 0)
	self.BuffDurationInput = makeInput(buffFields, "지속 턴", 80)
	self.BuffDurationInput.Size = UDim2.new(0.33, -3, 0, 34)
	self.BuffDurationInput.Position = UDim2.new(0.67, 6, 0, 0)
	for _, input in { self.BuffFrameInput, self.BuffValueInput, self.BuffDurationInput } do
		input.FocusLost:Connect(function()
			self:_commitBuffFields()
		end)
	end
	self.CombatBudgetLabel = Instance.new("TextLabel")
	self.CombatBudgetLabel.Size = UDim2.new(1, 0, 0, 32)
	self.CombatBudgetLabel.BackgroundColor3 = THEME.PanelAlt
	self.CombatBudgetLabel.BorderSizePixel = 0
	self.CombatBudgetLabel.TextColor3 = THEME.GoldLight
	self.CombatBudgetLabel.Font = Enum.Font.RobotoMono
	self.CombatBudgetLabel.TextSize = 11
	self.CombatBudgetLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.CombatBudgetLabel.Parent = properties
	addPadding(self.CombatBudgetLabel, 8)
	addStroke(self.CombatBudgetLabel, THEME.Wood, 1)

	local weaponSection = makeSection(properties, "프레임별 무기")
	local weaponAssetRow = Instance.new("Frame")
	weaponAssetRow.Size = UDim2.new(1, 0, 0, 38)
	weaponAssetRow.BackgroundTransparency = 1
	weaponAssetRow.Parent = properties
	self.WeaponAssetInput = makeInput(weaponAssetRow, "Roblox 이미지 ID", 170)
	self.WeaponAssetInput.Size = UDim2.new(1, -86, 0, 34)
	local applyWeapon = makeButton(weaponAssetRow, "추가", 80, 34)
	applyWeapon.Position = UDim2.new(1, -80, 0, 0)
	styleButton(applyWeapon, THEME.Cyan)
	applyWeapon.Activated:Connect(function()
		self:_pushUndo()
		local frame = self.Motion.Frames[self.SelectedFrame]
		frame.Weapon = frame.Weapon or defaultWeapon()
		frame.Weapon.AssetId = normalizeAssetId(self.WeaponAssetInput.Text)
		self:_applySelectedFrame()
	end)
	local weaponClipboardRow = Instance.new("Frame")
	weaponClipboardRow.Size = UDim2.new(1, 0, 0, 38)
	weaponClipboardRow.BackgroundTransparency = 1
	weaponClipboardRow.Parent = properties
	local copyWeaponButton = makeButton(weaponClipboardRow, "무기 이미지 복사", 130, 34)
	copyWeaponButton.Size = UDim2.new(0.5, -3, 0, 34)
	styleButton(copyWeaponButton, THEME.Gold)
	local pasteWeaponButton = makeButton(weaponClipboardRow, "무기 이미지 붙여넣기", 130, 34)
	pasteWeaponButton.Size = UDim2.new(0.5, -3, 0, 34)
	pasteWeaponButton.Position = UDim2.new(0.5, 3, 0, 0)
	styleButton(pasteWeaponButton, THEME.Cyan)
	copyWeaponButton.Activated:Connect(function()
		self:_copyWeaponImage()
	end)
	pasteWeaponButton.Activated:Connect(function()
		self:_pasteWeaponImage()
	end)
	local weaponTransformRow = Instance.new("Frame")
	weaponTransformRow.Size = UDim2.new(1, 0, 0, 38)
	weaponTransformRow.BackgroundTransparency = 1
	weaponTransformRow.Parent = properties
	self.WeaponRotationInput = makeInput(weaponTransformRow, "회전 Z", 90)
	self.WeaponRotationInput.Size = UDim2.new(0.38, -3, 0, 34)
	self.WeaponSizeXInput = makeInput(weaponTransformRow, "너비", 80)
	self.WeaponSizeXInput.Size = UDim2.new(0.31, -3, 0, 34)
	self.WeaponSizeXInput.Position = UDim2.new(0.38, 3, 0, 0)
	self.WeaponSizeYInput = makeInput(weaponTransformRow, "높이", 80)
	self.WeaponSizeYInput.Size = UDim2.new(0.31, -3, 0, 34)
	self.WeaponSizeYInput.Position = UDim2.new(0.69, 6, 0, 0)
	for _, input in { self.WeaponRotationInput, self.WeaponSizeXInput, self.WeaponSizeYInput } do
		input.FocusLost:Connect(function()
			self:_commitWeaponFields()
		end)
	end
	local weaponHint = Instance.new("TextLabel")
	weaponHint.Size = UDim2.new(1, 0, 0, 44)
	weaponHint.BackgroundColor3 = THEME.PanelAlt
	weaponHint.BorderSizePixel = 0
	weaponHint.Text =
		"주황 W점을 드래그해 현재 프레임의 무기를 이동합니다. 이미지 ID와 크기·기울기도 프레임마다 저장됩니다."
	weaponHint.TextColor3 = THEME.Muted
	weaponHint.Font = Enum.Font.RobotoMono
	weaponHint.TextSize = 10
	weaponHint.TextWrapped = true
	weaponHint.Parent = properties
	addStroke(weaponHint, THEME.Wood, 1)
	self.DualToggle = makeButton(properties, "쌍수 무기  OFF", 220, 36)
	self.DualToggle.Size = UDim2.new(1, 0, 0, 36)
	styleButton(self.DualToggle, Color3.fromRGB(255, 170, 80))
	self.DualToggle.Activated:Connect(function()
		self:_pushUndo()
		self.Motion.DualWield = not self.Motion.DualWield
		local frame = self.Motion.Frames[self.SelectedFrame]
		if self.Motion.DualWield and not frame.DualWeapon then
			frame.DualWeapon = defaultWeapon()
		end
		normalizeLayerOrder(frame, self.Motion.DualWield)
		self:_refreshDualFields()
		self:_refreshLayerList()
		self:_applySelectedFrame()
	end)
	local dualAssetRow = Instance.new("Frame")
	dualAssetRow.Size = UDim2.new(1, 0, 0, 38)
	dualAssetRow.BackgroundTransparency = 1
	dualAssetRow.Parent = properties
	self.DualAssetInput = makeInput(dualAssetRow, "왼손 이미지 ID", 170)
	self.DualAssetInput.Size = UDim2.new(1, -86, 0, 34)
	local applyDual = makeButton(dualAssetRow, "추가", 80, 34)
	applyDual.Position = UDim2.new(1, -80, 0, 0)
	styleButton(applyDual, Color3.fromRGB(255, 170, 80))
	applyDual.Activated:Connect(function()
		self:_pushUndo()
		self.Motion.DualWield = true
		local frame = self.Motion.Frames[self.SelectedFrame]
		frame.DualWeapon = frame.DualWeapon or defaultWeapon()
		frame.DualWeapon.AssetId = normalizeAssetId(self.DualAssetInput.Text)
		normalizeLayerOrder(frame, true)
		self:_refreshDualFields()
		self:_refreshLayerList()
		self:_applySelectedFrame()
	end)
	local dualTransformRow = Instance.new("Frame")
	dualTransformRow.Size = UDim2.new(1, 0, 0, 38)
	dualTransformRow.BackgroundTransparency = 1
	dualTransformRow.Parent = properties
	self.DualRotationInput = makeInput(dualTransformRow, "회전 Z", 80)
	self.DualRotationInput.Size = UDim2.new(0.34, -3, 0, 34)
	self.DualSizeXInput = makeInput(dualTransformRow, "너비", 80)
	self.DualSizeXInput.Size = UDim2.new(0.33, -3, 0, 34)
	self.DualSizeXInput.Position = UDim2.new(0.34, 3, 0, 0)
	self.DualSizeYInput = makeInput(dualTransformRow, "높이", 80)
	self.DualSizeYInput.Size = UDim2.new(0.33, -3, 0, 34)
	self.DualSizeYInput.Position = UDim2.new(0.67, 6, 0, 0)
	for _, input in { self.DualRotationInput, self.DualSizeXInput, self.DualSizeYInput } do
		input.FocusLost:Connect(function()
			self:_commitDualFields()
		end)
	end
	local weaponToggleRow = Instance.new("Frame")
	weaponToggleRow.Size = UDim2.new(1, 0, 0, 38)
	weaponToggleRow.BackgroundTransparency = 1
	weaponToggleRow.Parent = properties
	self.MainFlipXButton = makeButton(weaponToggleRow, "오른손 좌우", 70, 34)
	self.MainFlipXButton.Size = UDim2.new(0.2, -3, 0, 34)
	self.MainFlipYButton = makeButton(weaponToggleRow, "오른손 상하", 70, 34)
	self.MainFlipYButton.Size = UDim2.new(0.2, -3, 0, 34)
	self.MainFlipYButton.Position = UDim2.new(0.2, 3, 0, 0)
	self.DualFlipXButton = makeButton(weaponToggleRow, "왼손 좌우", 70, 34)
	self.DualFlipXButton.Size = UDim2.new(0.2, -3, 0, 34)
	self.DualFlipXButton.Position = UDim2.new(0.4, 6, 0, 0)
	self.DualFlipYButton = makeButton(weaponToggleRow, "왼손 상하", 70, 34)
	self.DualFlipYButton.Size = UDim2.new(0.2, -3, 0, 34)
	self.DualFlipYButton.Position = UDim2.new(0.6, 9, 0, 0)
	self.HandSwapButton = makeButton(weaponToggleRow, "손 변경", 70, 34)
	self.HandSwapButton.Size = UDim2.new(0.2, -3, 0, 34)
	self.HandSwapButton.Position = UDim2.new(0.8, 12, 0, 0)
	for _, button in
		{
			self.MainFlipXButton,
			self.MainFlipYButton,
			self.DualFlipXButton,
			self.DualFlipYButton,
			self.HandSwapButton,
		}
	do
		styleButton(button, Color3.fromRGB(197, 108, 255))
	end
	self.MainFlipXButton.Activated:Connect(function()
		self:_toggleWeaponFlag("Weapon", "FlipX")
	end)
	self.MainFlipYButton.Activated:Connect(function()
		self:_toggleWeaponFlag("Weapon", "FlipY")
	end)
	self.DualFlipXButton.Activated:Connect(function()
		self:_toggleWeaponFlag("DualWeapon", "FlipX")
	end)
	self.DualFlipYButton.Activated:Connect(function()
		self:_toggleWeaponFlag("DualWeapon", "FlipY")
	end)
	self.HandSwapButton.Activated:Connect(function()
		self:_pushUndo()
		local frame = self.Motion.Frames[self.SelectedFrame]
		frame.HandSwap = not frame.HandSwap
		self:_applySelectedFrame()
		self:_refreshWeaponToggleButtons()
	end)

	local decorationSection = makeSection(properties, "프레임별 장식")
	local decorationAddRow = Instance.new("Frame")
	decorationAddRow.Size = UDim2.new(1, 0, 0, 38)
	decorationAddRow.BackgroundTransparency = 1
	decorationAddRow.Parent = properties
	self.DecorationAssetInput = makeInput(decorationAddRow, "장식 이미지 ID", 170)
	self.DecorationAssetInput.Size = UDim2.new(1, -86, 0, 34)
	local addDecoration = makeButton(decorationAddRow, "+ 추가", 80, 34)
	addDecoration.Position = UDim2.new(1, -80, 0, 0)
	styleButton(addDecoration, Color3.fromRGB(255, 105, 205))
	addDecoration.Activated:Connect(function()
		self:_addDecoration()
	end)
	local decorationNavRow = Instance.new("Frame")
	decorationNavRow.Size = UDim2.new(1, 0, 0, 38)
	decorationNavRow.BackgroundTransparency = 1
	decorationNavRow.Parent = properties
	self.DecorationCycle = makeButton(decorationNavRow, "장식 0 / 0", 150, 34)
	self.DecorationCycle.Size = UDim2.new(0.45, -3, 0, 34)
	styleButton(self.DecorationCycle, THEME.Gold)
	self.DecorationNameInput = makeInput(decorationNavRow, "장식 이름", 100)
	self.DecorationNameInput.Size = UDim2.new(0.35, -3, 0, 34)
	self.DecorationNameInput.Position = UDim2.new(0.45, 3, 0, 0)
	local deleteDecoration = makeButton(decorationNavRow, "삭제", 60, 34)
	deleteDecoration.Size = UDim2.new(0.2, -3, 0, 34)
	deleteDecoration.Position = UDim2.new(0.8, 6, 0, 0)
	styleButton(deleteDecoration, THEME.Red)
	self.DecorationCycle.Activated:Connect(function()
		self:_cycleDecoration()
	end)
	deleteDecoration.Activated:Connect(function()
		self:_deleteDecoration()
	end)
	local decorationTransformRow = Instance.new("Frame")
	decorationTransformRow.Size = UDim2.new(1, 0, 0, 38)
	decorationTransformRow.BackgroundTransparency = 1
	decorationTransformRow.Parent = properties
	self.DecorationRotationInput = makeInput(decorationTransformRow, "회전 Z", 80)
	self.DecorationRotationInput.Size = UDim2.new(0.3, -3, 0, 34)
	self.DecorationSizeXInput = makeInput(decorationTransformRow, "너비", 80)
	self.DecorationSizeXInput.Size = UDim2.new(0.28, -3, 0, 34)
	self.DecorationSizeXInput.Position = UDim2.new(0.3, 3, 0, 0)
	self.DecorationSizeYInput = makeInput(decorationTransformRow, "높이", 80)
	self.DecorationSizeYInput.Size = UDim2.new(0.28, -3, 0, 34)
	self.DecorationSizeYInput.Position = UDim2.new(0.58, 6, 0, 0)
	self.DecorationAttachButton = makeButton(decorationTransformRow, "몸통", 50, 34)
	self.DecorationAttachButton.Size = UDim2.new(0.14, -3, 0, 34)
	self.DecorationAttachButton.Position = UDim2.new(0.86, 9, 0, 0)
	styleButton(self.DecorationAttachButton, Color3.fromRGB(255, 105, 205))
	self.DecorationAttachButton.Activated:Connect(function()
		local decoration = self:_selectedDecoration()
		if decoration then
			self:_pushUndo()
			decoration.Attach = decoration.Attach == "Head" and "Root" or "Head"
			self:_refreshDecorationFields()
			self:_syncDecorations(self.Motion.Frames[self.SelectedFrame])
		end
	end)
	for _, input in
		{
			self.DecorationAssetInput,
			self.DecorationNameInput,
			self.DecorationRotationInput,
			self.DecorationSizeXInput,
			self.DecorationSizeYInput,
		}
	do
		input.FocusLost:Connect(function()
			self:_commitDecorationFields()
		end)
	end
	local decorationHint = Instance.new("TextLabel")
	decorationHint.Size = UDim2.new(1, 0, 0, 44)
	decorationHint.BackgroundColor3 = THEME.PanelAlt
	decorationHint.BorderSizePixel = 0
	decorationHint.Text =
		"장식은 프레임마다 최대 5개입니다. 분홍 D점을 드래그하고 머리/몸통 부착을 선택할 수 있습니다."
	decorationHint.TextColor3 = THEME.Muted
	decorationHint.Font = Enum.Font.RobotoMono
	decorationHint.TextSize = 10
	decorationHint.TextWrapped = true
	decorationHint.Parent = properties
	addStroke(decorationHint, THEME.Wood, 1)

	local layerTitle = Instance.new("TextLabel")
	layerTitle.Size = UDim2.new(1, 0, 0, 28)
	layerTitle.BackgroundColor3 = THEME.PanelAlt
	layerTitle.BorderSizePixel = 0
	layerTitle.Text = "  LAYER STACK  ·  아래에서 뒤 → 위에서 앞"
	layerTitle.TextColor3 = THEME.GoldLight
	layerTitle.Font = Enum.Font.RobotoMono
	layerTitle.TextSize = 10
	layerTitle.TextXAlignment = Enum.TextXAlignment.Left
	layerTitle.Parent = properties
	addStroke(layerTitle, THEME.Wood, 1)

	local layerList = Instance.new("Frame")
	layerList.Name = "LayerStack"
	layerList.Size = UDim2.new(1, 0, 0, 64)
	layerList.BackgroundColor3 = THEME.PanelAlt
	layerList.BorderSizePixel = 0
	layerList.Parent = properties
	addStroke(layerList, THEME.WoodLight, 1)
	local layerLayout = Instance.new("UIListLayout")
	layerLayout.Padding = UDim.new(0, 3)
	layerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	layerLayout.Parent = layerList
	self.LayerList = layerList
	UserInputService.InputChanged:Connect(function(input)
		local drag = self.LayerDrag
		if not drag or not self.Gui.Enabled then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local localY = input.Position.Y - layerList.AbsolutePosition.Y
		local targetIndex = math.clamp(math.floor(localY / 31) + 1, 1, #drag.Order)
		if targetIndex ~= drag.Index then
			self:_moveLayer(drag.Index, targetIndex)
			drag.Index = targetIndex
			drag.Order = self.Motion.Frames[self.SelectedFrame].LayerOrder
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			self.LayerDrag
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			self.LayerDrag = nil
		end
	end)

	local hitSection = makeSection(properties, "프레임별 히트 이벤트")
	local hitCommands = Instance.new("Frame")
	hitCommands.Size = UDim2.new(1, 0, 0, 38)
	hitCommands.BackgroundTransparency = 1
	hitCommands.Parent = properties
	local addHit = makeButton(hitCommands, "+ 판정", 80, 34)
	addHit.Size = UDim2.new(0.25, -3, 0, 34)
	styleButton(addHit, THEME.Red)
	self.HitCycle = makeButton(hitCommands, "판정 0 / 0", 80, 34)
	self.HitCycle.Size = UDim2.new(0.3, -3, 0, 34)
	self.HitCycle.Position = UDim2.new(0.25, 3, 0, 0)
	styleButton(self.HitCycle, THEME.Gold)
	local duplicateHit = makeButton(hitCommands, "복제", 70, 34)
	duplicateHit.Size = UDim2.new(0.22, -3, 0, 34)
	duplicateHit.Position = UDim2.new(0.55, 6, 0, 0)
	styleButton(duplicateHit, THEME.Cyan)
	local deleteHit = makeButton(hitCommands, "삭제", 80, 34)
	deleteHit.Size = UDim2.new(0.23, -3, 0, 34)
	deleteHit.Position = UDim2.new(0.77, 9, 0, 0)
	styleButton(deleteHit, THEME.Red)
	addHit.Activated:Connect(function()
		self:_addHit()
	end)
	duplicateHit.Activated:Connect(function()
		self:_duplicateHit()
	end)
	self.HitCycle.Activated:Connect(function()
		local hits = self:_frameHits()
		if #hits > 0 then
			self.SelectedHit = self.SelectedHit % #hits + 1
			self:_refreshHitFields()
		end
	end)
	deleteHit.Activated:Connect(function()
		self:_deleteHit()
	end)
	local hitFields = Instance.new("Frame")
	hitFields.Size = UDim2.new(1, 0, 0, 38)
	hitFields.BackgroundTransparency = 1
	hitFields.Parent = properties
	self.AttackIdInput = makeInput(hitFields, "AttackId", 150)
	self.AttackIdInput.Size = UDim2.new(0.6, -4, 0, 34)
	self.RatioInput = makeInput(hitFields, "대미지 비율 0~1", 100)
	self.RatioInput.Size = UDim2.new(0.4, -2, 0, 34)
	self.RatioInput.Position = UDim2.new(0.6, 4, 0, 0)
	self.AttackIdInput.FocusLost:Connect(function()
		local hit = self:_selectedHit()
		if hit then
			hit.AttackId = self.AttackIdInput.Text
		end
	end)
	self.RatioInput.FocusLost:Connect(function()
		local hit = self:_selectedHit()
		if hit then
			hit.DamageRatio = math.clamp(tonumber(self.RatioInput.Text) or hit.DamageRatio, 0, 1)
			self:_refreshHitFields()
		end
	end)
	local hitRotationRow = Instance.new("Frame")
	hitRotationRow.Size = UDim2.new(1, 0, 0, 38)
	hitRotationRow.BackgroundTransparency = 1
	hitRotationRow.Parent = properties
	self.HitRotationInput = makeInput(hitRotationRow, "판정 회전 Z", 120)
	self.HitRotationInput.Size = UDim2.new(0.5, -3, 0, 34)
	self.HitDepthInput = makeInput(hitRotationRow, "판정 깊이", 120)
	self.HitDepthInput.Size = UDim2.new(0.5, -3, 0, 34)
	self.HitDepthInput.Position = UDim2.new(0.5, 3, 0, 0)
	self.HitRotationInput.FocusLost:Connect(function()
		self:_commitHitFields()
	end)
	self.HitDepthInput.FocusLost:Connect(function()
		self:_commitHitFields()
	end)
	local hitHint = Instance.new("TextLabel")
	hitHint.Size = UDim2.new(1, 0, 0, 44)
	hitHint.BackgroundColor3 = THEME.PanelAlt
	hitHint.BorderSizePixel = 0
	hitHint.Text =
		"붉은 H점을 드래그해 판정을 이동하고, 흰색 ↘점을 드래그해 크기를 조절합니다."
	hitHint.TextColor3 = THEME.Muted
	hitHint.Font = Enum.Font.RobotoMono
	hitHint.TextSize = 10
	hitHint.TextWrapped = true
	hitHint.Parent = properties
	addStroke(hitHint, THEME.Wood, 1)

	local frameEventSection = makeSection(properties, "프레임 이벤트")
	local eventTypeRow = Instance.new("Frame")
	eventTypeRow.Size = UDim2.new(1, 0, 0, 38)
	eventTypeRow.BackgroundTransparency = 1
	eventTypeRow.Parent = properties
	local addEffect = makeButton(eventTypeRow, "+ 이펙트", 80, 34)
	addEffect.Size = UDim2.new(0.34, -4, 0, 34)
	styleButton(addEffect, THEME.Cyan)
	local addProjectile = makeButton(eventTypeRow, "+ 투사체", 80, 34)
	addProjectile.Size = UDim2.new(0.33, -4, 0, 34)
	addProjectile.Position = UDim2.new(0.34, 2, 0, 0)
	styleButton(addProjectile, Color3.fromRGB(255, 160, 80))
	local addTeleport = makeButton(eventTypeRow, "+ 텔레포트", 80, 34)
	addTeleport.Size = UDim2.new(0.33, -2, 0, 34)
	addTeleport.Position = UDim2.new(0.67, 2, 0, 0)
	styleButton(addTeleport, Color3.fromRGB(197, 108, 255))
	addEffect.Activated:Connect(function()
		self:_addFrameEvent("Effects")
	end)
	addProjectile.Activated:Connect(function()
		self:_addFrameEvent("Projectiles")
	end)
	addTeleport.Activated:Connect(function()
		self:_addFrameEvent("Teleports")
	end)
	local eventNavRow = Instance.new("Frame")
	eventNavRow.Size = UDim2.new(1, 0, 0, 38)
	eventNavRow.BackgroundTransparency = 1
	eventNavRow.Parent = properties
	self.EventCycle = makeButton(eventNavRow, "이벤트 0 / 0", 150, 34)
	self.EventCycle.Size = UDim2.new(0.48, -3, 0, 34)
	styleButton(self.EventCycle, THEME.Gold)
	self.EventPresetButton = makeButton(eventNavRow, "FX: 베기", 80, 34)
	self.EventPresetButton.Size = UDim2.new(0.28, -3, 0, 34)
	self.EventPresetButton.Position = UDim2.new(0.48, 3, 0, 0)
	styleButton(self.EventPresetButton, THEME.Cyan)
	local deleteEvent = makeButton(eventNavRow, "삭제", 80, 34)
	deleteEvent.Size = UDim2.new(0.24, -3, 0, 34)
	deleteEvent.Position = UDim2.new(0.76, 6, 0, 0)
	styleButton(deleteEvent, THEME.Red)
	self.EventCycle.Activated:Connect(function()
		self:_cycleFrameEvent()
	end)
	self.EventPresetButton.Activated:Connect(function()
		self:_cycleEffectPreset()
	end)
	deleteEvent.Activated:Connect(function()
		self:_deleteFrameEvent()
	end)
	local eventAssetRow = Instance.new("Frame")
	eventAssetRow.Size = UDim2.new(1, 0, 0, 38)
	eventAssetRow.BackgroundTransparency = 1
	eventAssetRow.Parent = properties
	self.EventAssetInput = makeInput(eventAssetRow, "이펙트/투사체 이미지 ID", 180)
	self.EventAssetInput.Size = UDim2.new(0.7, -3, 0, 34)
	self.EventDurationInput = makeInput(eventAssetRow, "지속 초", 80)
	self.EventDurationInput.Size = UDim2.new(0.3, -3, 0, 34)
	self.EventDurationInput.Position = UDim2.new(0.7, 3, 0, 0)
	local eventTransformRow = Instance.new("Frame")
	eventTransformRow.Size = UDim2.new(1, 0, 0, 38)
	eventTransformRow.BackgroundTransparency = 1
	eventTransformRow.Parent = properties
	self.EventRotationInput = makeInput(eventTransformRow, "회전 Z", 80)
	self.EventRotationInput.Size = UDim2.new(0.34, -3, 0, 34)
	self.EventSizeXInput = makeInput(eventTransformRow, "너비/거리", 80)
	self.EventSizeXInput.Size = UDim2.new(0.33, -3, 0, 34)
	self.EventSizeXInput.Position = UDim2.new(0.34, 3, 0, 0)
	self.EventSizeYInput = makeInput(eventTransformRow, "높이", 80)
	self.EventSizeYInput.Size = UDim2.new(0.33, -3, 0, 34)
	self.EventSizeYInput.Position = UDim2.new(0.67, 6, 0, 0)
	local eventStyleRow = Instance.new("Frame")
	eventStyleRow.Size = UDim2.new(1, 0, 0, 38)
	eventStyleRow.BackgroundTransparency = 1
	eventStyleRow.Parent = properties
	self.EventColorInput = makeInput(eventStyleRow, "색상 #RRGGBB", 100)
	self.EventColorInput.Size = UDim2.new(0.34, -3, 0, 34)
	self.EventOpacityInput = makeInput(eventStyleRow, "투명도 0~1", 80)
	self.EventOpacityInput.Size = UDim2.new(0.26, -3, 0, 34)
	self.EventOpacityInput.Position = UDim2.new(0.34, 3, 0, 0)
	self.EventFlipXButton = makeButton(eventStyleRow, "좌우 반전", 70, 34)
	self.EventFlipXButton.Size = UDim2.new(0.2, -3, 0, 34)
	self.EventFlipXButton.Position = UDim2.new(0.6, 6, 0, 0)
	self.EventFlipYButton = makeButton(eventStyleRow, "상하 반전", 70, 34)
	self.EventFlipYButton.Size = UDim2.new(0.2, -3, 0, 34)
	self.EventFlipYButton.Position = UDim2.new(0.8, 9, 0, 0)
	styleButton(self.EventFlipXButton, Color3.fromRGB(197, 108, 255))
	styleButton(self.EventFlipYButton, Color3.fromRGB(197, 108, 255))
	self.EventFlipXButton.Activated:Connect(function()
		self:_toggleFrameEventFlag("FlipX")
	end)
	self.EventFlipYButton.Activated:Connect(function()
		self:_toggleFrameEventFlag("FlipY")
	end)
	local projectileDirectionRow = Instance.new("Frame")
	projectileDirectionRow.Size = UDim2.new(1, 0, 0, 38)
	projectileDirectionRow.BackgroundTransparency = 1
	projectileDirectionRow.Parent = properties
	self.EventDirectionButton = makeButton(projectileDirectionRow, "바라보는 방향", 120, 34)
	self.EventDirectionButton.Size = UDim2.new(0.45, -3, 0, 34)
	styleButton(self.EventDirectionButton, Color3.fromRGB(255, 160, 80))
	self.EventAngleInput = makeInput(projectileDirectionRow, "고정 각도", 80)
	self.EventAngleInput.Size = UDim2.new(0.275, -3, 0, 34)
	self.EventAngleInput.Position = UDim2.new(0.45, 3, 0, 0)
	self.EventSpeedInput = makeInput(projectileDirectionRow, "속도", 80)
	self.EventSpeedInput.Size = UDim2.new(0.275, -3, 0, 34)
	self.EventSpeedInput.Position = UDim2.new(0.725, 6, 0, 0)
	self.EventDirectionButton.Activated:Connect(function()
		self:_cycleProjectileDirection()
	end)
	local eventFrameRow = Instance.new("Frame")
	eventFrameRow.Size = UDim2.new(1, 0, 0, 38)
	eventFrameRow.BackgroundTransparency = 1
	eventFrameRow.Parent = properties
	local eventFrameLabel = Instance.new("TextLabel")
	eventFrameLabel.Size = UDim2.new(0.6, -3, 1, 0)
	eventFrameLabel.BackgroundTransparency = 1
	eventFrameLabel.Text = "시작 프레임은 현재 프레임"
	eventFrameLabel.TextColor3 = THEME.Parchment
	eventFrameLabel.Font = Enum.Font.Gotham
	eventFrameLabel.TextSize = 11
	eventFrameLabel.TextXAlignment = Enum.TextXAlignment.Left
	eventFrameLabel.Parent = eventFrameRow
	self.EventEndFrameInput = makeInput(eventFrameRow, "종료 F", 90)
	self.EventEndFrameInput.Size = UDim2.new(0.4, -3, 0, 34)
	self.EventEndFrameInput.Position = UDim2.new(0.6, 3, 0, 0)
	for _, input in
		{
			self.EventAssetInput,
			self.EventDurationInput,
			self.EventRotationInput,
			self.EventSizeXInput,
			self.EventSizeYInput,
			self.EventColorInput,
			self.EventOpacityInput,
			self.EventAngleInput,
			self.EventSpeedInput,
			self.EventEndFrameInput,
		}
	do
		input.FocusLost:Connect(function()
			self:_commitFrameEventFields()
		end)
	end
	local eventHint = Instance.new("TextLabel")
	eventHint.Size = UDim2.new(1, 0, 0, 44)
	eventHint.BackgroundColor3 = THEME.PanelAlt
	eventHint.BorderSizePixel = 0
	eventHint.Text =
		"청록 E점을 드래그해 이벤트 위치를 정합니다. 텔레포트의 너비/거리는 X 이동량으로 사용됩니다."
	eventHint.TextColor3 = THEME.Muted
	eventHint.Font = Enum.Font.RobotoMono
	eventHint.TextSize = 10
	eventHint.TextWrapped = true
	eventHint.Parent = properties
	addStroke(eventHint, THEME.Wood, 1)

	local validationSection = makeSection(properties, "검증 및 재생")
	local play = makeButton(properties, "▶  전체 타임라인 재생", 250, 38)
	self.PlayButton = play
	play.Size = UDim2.new(1, 0, 0, 38)
	styleButton(play, THEME.Cyan)
	play.Activated:Connect(function()
		self:_playPreview()
	end)
	local save = makeButton(properties, "◆  서버 검증 + 세션 저장", 250, 42)
	self.SaveButton = save
	save.Size = UDim2.new(1, 0, 0, 42)
	styleButton(save, THEME.Green, THEME.GreenDark, Color3.new(1, 1, 1))
	save.Activated:Connect(function()
		self:_savePack()
	end)
	self.Status = Instance.new("TextLabel")
	self.Status.Size = UDim2.new(1, 0, 0, 72)
	self.Status.BackgroundColor3 = THEME.PanelAlt
	self.Status.BorderSizePixel = 0
	self.Status.TextWrapped = true
	self.Status.TextColor3 = THEME.Muted
	self.Status.Font = Enum.Font.RobotoMono
	self.Status.TextSize = 12
	self.Status.TextXAlignment = Enum.TextXAlignment.Left
	self.Status.Text =
		"  STATUS\n  프레임의 포즈, 무기와 판정을 편집한 뒤 서버 검증으로 저장하세요."
	self.Status.Parent = properties
	addStroke(self.Status, THEME.WoodLight, 1)

	-- ADOFAI-style dock: the timeline stays visible at the bottom, all detailed
	-- settings live on the right, and the left rail contains editing commands.
	timelineLabel.Parent = bottomDock
	timelineLabel.Size = UDim2.new(1, -12, 0, 18)
	timelineLabel.Position = UDim2.fromOffset(6, 72)
	timeline.Parent = bottomDock
	timeline.Size = UDim2.new(1, -12, 0, 44)
	timeline.Position = UDim2.fromOffset(6, 90)

	-- Match CRAFTROYALE's authoring flow: frame controls and timeline first,
	-- then pose tools and weapon metadata.
	frameSection.LayoutOrder = 0
	frameNavigation.LayoutOrder = 1
	frameCommands.LayoutOrder = 2
	frameTimeRow.LayoutOrder = 3
	timelineLabel.LayoutOrder = 4
	timeline.LayoutOrder = 5
	overviewHeader.LayoutOrder = 6
	overview.LayoutOrder = 7
	overviewResize.LayoutOrder = 8
	jointSection.LayoutOrder = 9
	jointHint.LayoutOrder = 10
	poseCommandRow.LayoutOrder = 11
	presetInfoSection.LayoutOrder = 19
	packIdentityRow.LayoutOrder = 20
	packDescriptionRow.LayoutOrder = 21
	presetInfoRow.LayoutOrder = 22
	presetDescriptionRow.LayoutOrder = 23
	local movedSettings = {}
	for _, child in controls:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(movedSettings, child)
		end
	end
	table.sort(movedSettings, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index, child in movedSettings do
		child.LayoutOrder = -400 + index
		child.Parent = properties
	end
	local propertyOrder = 100
	for _, child in properties:GetChildren() do
		if child:IsA("GuiObject") and child.LayoutOrder >= 0 then
			propertyOrder += 1
			child.LayoutOrder = propertyOrder
		end
	end

	local commandSection = makeSection(controls, "편집 명령")
	commandSection.LayoutOrder = 1
	local function makeRailCommand(text: string, accent: Color3, order: number, callback: () -> ())
		local button = makeButton(controls, text, 140, 36)
		button.Size = UDim2.new(1, 0, 0, 36)
		button.LayoutOrder = order
		button.TextSize = 11
		styleButton(button, accent)
		button.Activated:Connect(callback)
		return button
	end
	makeRailCommand("▶  재생", THEME.Cyan, 2, function()
		self:_playPreview()
	end)
	makeRailCommand("↶  되돌리기", THEME.Blue, 3, function()
		self:_undo()
	end)
	makeRailCommand("▣  프레임 복사", THEME.Gold, 4, function()
		self:_copyCurrentFrame()
	end)
	makeRailCommand("▤  프레임 붙여넣기", THEME.Green, 5, function()
		self:_pasteCurrentFrame()
	end)
	makeRailCommand("✂  잘라내기", Color3.fromRGB(197, 108, 255), 6, function()
		self:_cutCurrentFrame()
	end)
	makeRailCommand("＋  새 프레임", THEME.Green, 7, function()
		self:_insertFrame(true)
	end)
	makeRailCommand("×  프레임 삭제", THEME.Red, 8, function()
		self:_deleteFrame()
	end)
	local editModeSection = makeSection(controls, "부위 편집 방식")
	editModeSection.LayoutOrder = 9
	local editModeRow = Instance.new("Frame")
	editModeRow.Size = UDim2.new(1, 0, 0, 36)
	editModeRow.BackgroundTransparency = 1
	editModeRow.LayoutOrder = 10
	editModeRow.Parent = controls
	self.JointModeButtons = {}
	local function refreshEditModeButtons()
		styleButton(self.JointModeButtons.Move, self.JointEditMode == "Move" and THEME.GoldLight or THEME.Cyan)
		styleButton(self.JointModeButtons.Rotate, self.JointEditMode == "Rotate" and THEME.GoldLight or THEME.Green)
	end
	for index, option in
		{
			{ Key = "Move", Label = "직접 이동" },
			{ Key = "Rotate", Label = "회전" },
		}
	do
		local modeKey = option.Key
		local button = makeButton(editModeRow, option.Label, 68, 34)
		button.Size = UDim2.new(0.5, -3, 0, 34)
		button.Position = UDim2.new((index - 1) * 0.5, index == 1 and 0 or 3, 0, 0)
		button.TextSize = 11
		button.Activated:Connect(function()
			self.JointEditMode = modeKey
			refreshEditModeButtons()
			self:_updateJointGizmo()
		end)
		self.JointModeButtons[modeKey] = button
	end
	refreshEditModeButtons()

	local bodyPartSection = makeSection(controls, "부위 선택")
	bodyPartSection.LayoutOrder = 11
	self.BodyPartButtons = {}
	for rowIndex = 1, 3 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundTransparency = 1
		row.LayoutOrder = 11 + rowIndex
		row.Parent = controls
		for columnIndex = 1, 2 do
			local option = GIZMO_PART_OPTIONS[(rowIndex - 1) * 2 + columnIndex]
			local partName = option.Name
			local button = makeButton(row, option.Label, 68, 32)
			button.Size = UDim2.new(0.5, -3, 0, 32)
			button.Position = UDim2.new((columnIndex - 1) * 0.5, columnIndex == 1 and 0 or 3, 0, 0)
			button.TextSize = 10
			button.Activated:Connect(function()
				self:_selectGizmoPart(partName)
			end)
			self.BodyPartButtons[partName] = button
		end
	end
	self:_refreshBodyPartButtons()

	validationSection.Visible = false
	play.Visible = false
	save.Visible = false

	local propertyEmptyState = Instance.new("TextLabel")
	propertyEmptyState.Name = "PropertyEmptyState"
	propertyEmptyState.Size = UDim2.new(1, 0, 0, 108)
	propertyEmptyState.BackgroundColor3 = THEME.PanelAlt
	propertyEmptyState.BorderSizePixel = 0
	propertyEmptyState.TextColor3 = THEME.Muted
	propertyEmptyState.Font = Enum.Font.RobotoMono
	propertyEmptyState.TextSize = 13
	propertyEmptyState.TextWrapped = true
	propertyEmptyState.Text =
		"하단에서 세부 항목을 선택하면\n해당 프레임의 설정이 여기에 표시됩니다."
	propertyEmptyState.LayoutOrder = -1000
	propertyEmptyState.Parent = properties
	addStroke(propertyEmptyState, THEME.WoodLight, 1)

	local frameSettings = {
		frameSection,
		frameNavigation,
		frameCommands,
		frameTimeRow,
		overviewHeader,
		overview,
		overviewResize,
	}
	local poseSettings = { jointSection, jointHint, poseCommandRow }
	local presetSettings = {
		presetInfoSection,
		packIdentityRow,
		packDescriptionRow,
		presetInfoRow,
		presetDescriptionRow,
	}
	local eventSettings = {
		frameEventSection,
		eventTypeRow,
		eventNavRow,
		eventAssetRow,
		eventTransformRow,
		eventStyleRow,
		projectileDirectionRow,
		eventFrameRow,
		eventHint,
	}
	local decorationMainSettings = { decorationSection, decorationAddRow, decorationNavRow }
	local decorationTransformSettings = { decorationSection, decorationTransformRow, decorationHint }
	local decorationLayerSettings = { decorationSection, layerTitle, layerList }
	local weaponMainSettings = {
		weaponSection,
		weaponAssetRow,
		weaponClipboardRow,
		weaponTransformRow,
		weaponHint,
	}
	local weaponDualSettings = {
		weaponSection,
		self.DualToggle,
		dualAssetRow,
		dualTransformRow,
		weaponToggleRow,
	}
	local weaponFrameSettings = { weaponSection, weaponAssetRow, weaponClipboardRow }
	local combatSettings = {
		combatSection,
		combatRowOne,
		combatRowTwo,
		self.CombatSpecialRow,
		self.CombatBudgetLabel,
	}
	local statusSettings = { combatSection, statusCommands, statusFields, self.CombatBudgetLabel }
	local buffSettings = { combatSection, buffCommands, buffFields, self.CombatBudgetLabel }
	local hitListSettings = { hitSection, hitCommands }
	local hitTransformSettings = { hitSection, hitRotationRow, hitHint }
	local hitDamageSettings = { hitSection, hitFields }

	local categoryDefinitions = {
		{
			Key = "Frame",
			Label = "프레임",
			Hint = "시간·포즈·타임라인",
			Color = THEME.Green,
			Details = {
				{ Label = "타임라인", Members = frameSettings },
				{ Label = "포즈", Members = poseSettings },
				{ Label = "프리셋 정보", Members = presetSettings },
			},
		},
		{
			Key = "Effect",
			Label = "이펙트",
			Hint = "FX·투사체·텔레포트",
			Color = THEME.Cyan,
			Details = {
				{ Label = "공격 FX", Members = eventSettings, EventType = "Effects" },
				{ Label = "투사체", Members = eventSettings, EventType = "Projectiles" },
				{ Label = "텔레포트", Members = eventSettings, EventType = "Teleports" },
			},
		},
		{
			Key = "Decoration",
			Label = "장식",
			Hint = "이미지·위치·레이어",
			Color = Color3.fromRGB(255, 105, 205),
			Details = {
				{ Label = "장식 설정", Members = decorationMainSettings },
				{ Label = "앵커·회전", Members = decorationTransformSettings },
				{ Label = "레이어", Members = decorationLayerSettings },
			},
		},
		{
			Key = "Weapon",
			Label = "무기",
			Hint = "주무기·쌍수·프레임 이미지",
			Color = THEME.Gold,
			Details = {
				{ Label = "주무기", Members = weaponMainSettings },
				{ Label = "쌍수", Members = weaponDualSettings },
				{ Label = "프레임 이미지", Members = weaponFrameSettings },
			},
		},
		{
			Key = "Status",
			Label = "버프&디버프",
			Hint = "상태이상·버프·적용 프레임",
			Color = THEME.Blue,
			Details = {
				{ Label = "전투 수치", Members = combatSettings },
				{ Label = "상태이상", Members = statusSettings },
				{ Label = "버프", Members = buffSettings },
			},
		},
		{
			Key = "Hitbox",
			Label = "판정",
			Hint = "히트박스·대미지·회전",
			Color = THEME.Red,
			Details = {
				{ Label = "판정 목록", Members = hitListSettings },
				{ Label = "크기·회전", Members = hitTransformSettings },
				{ Label = "프레임 대미지", Members = hitDamageSettings },
			},
		},
	}
	local propertyObjects = {}
	for _, child in properties:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(propertyObjects, child)
		end
	end
	local function hidePropertySettings()
		for _, child in propertyObjects do
			child:SetAttribute("DetailActive", false)
			child.Visible = false
		end
		propertyEmptyState:SetAttribute("DetailActive", false)
		propertyEmptyState.Visible = false
		properties.CanvasPosition = Vector2.zero
	end
	local function showPropertySettings(members)
		hidePropertySettings()
		propertyEmptyState:SetAttribute("DetailActive", false)
		propertyEmptyState.Visible = false
		for _, member in members do
			if member and member.Parent == properties then
				member:SetAttribute("DetailActive", true)
				member.Visible = true
			end
		end
		properties.CanvasPosition = Vector2.zero
	end
	local activeCategory = "Frame"
	local lastDetailByCategory = {}
	local function selectCategory(definition)
		activeCategory = definition.Key
		categoryHint.Text = string.format("%s  /  %s", definition.Label, definition.Hint)
		for key, button in self.BottomCategoryButtons do
			local selected = key == activeCategory
			styleButton(
				button,
				selected and definition.Color or THEME.WoodLight,
				selected and THEME.PanelAlt or THEME.Panel
			)
		end
		for _, child in detailBar:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		self.BottomDetailButtons = {}
		local function activateDetail(detailIndex)
			local detail = definition.Details[detailIndex]
			local detailButton = self.BottomDetailButtons[detailIndex]
			if not detail or not detailButton then
				return
			end
			lastDetailByCategory[definition.Key] = detailIndex
			for _, candidate in self.BottomDetailButtons do
				styleButton(
					candidate,
					candidate == detailButton and definition.Color or THEME.WoodLight,
					THEME.PanelAlt
				)
			end
			if detail.EventType then
				self.SelectedEventType = detail.EventType
				self.SelectedEvent = 1
				self:_refreshEventFields()
			end
			showPropertySettings(detail.Members)
		end
		for index, detail in definition.Details do
			local detailButton = makeButton(detailBar, detail.Label, 112, 27)
			detailButton.Size = UDim2.fromOffset(112, 27)
			detailButton.LayoutOrder = index
			detailButton.TextSize = 10
			styleButton(detailButton, THEME.WoodLight, THEME.PanelAlt)
			detailButton.Activated:Connect(function()
				activateDetail(index)
			end)
			table.insert(self.BottomDetailButtons, detailButton)
		end
		activateDetail(lastDetailByCategory[definition.Key] or 1)
	end
	for index, definition in categoryDefinitions do
		local button = makeButton(categoryBar, definition.Label, 120, 34)
		button.Name = definition.Key .. "Category"
		button.Size = UDim2.fromOffset(120, 33)
		button.LayoutOrder = index
		button.TextSize = 11
		button.Activated:Connect(function()
			selectCategory(definition)
		end)
		self.BottomCategoryButtons[definition.Key] = button
	end
	selectCategory(categoryDefinitions[1])
	local mobilePage = "Preview"
	local function applyMobilePage()
		if not self.MobileEditorMode then
			leftShell.Visible = true
			centerShell.Visible = true
			rightShell.Visible = true
			return
		end
		leftShell.Visible = mobilePage == "Pose"
		centerShell.Visible = mobilePage == "Preview"
		rightShell.Visible = mobilePage == "Properties"
		styleButton(mobilePose, mobilePage == "Pose" and THEME.Green or THEME.WoodLight, THEME.PanelAlt)
		styleButton(mobilePreview, mobilePage == "Preview" and THEME.Green or THEME.WoodLight, THEME.PanelAlt)
		styleButton(mobileProperties, mobilePage == "Properties" and THEME.Green or THEME.WoodLight, THEME.PanelAlt)
	end
	mobilePose.Activated:Connect(function()
		mobilePage = "Pose"
		applyMobilePage()
	end)
	mobilePreview.Activated:Connect(function()
		mobilePage = "Preview"
		applyMobilePage()
	end)
	mobileProperties.Activated:Connect(function()
		mobilePage = "Properties"
		applyMobilePage()
	end)
	--[[
		제목줄을 잡아 창을 옮긴다 (문 애니메이터처럼 떠 있는 창).

		제목줄 위의 버튼들(저장·인벤토리·닫기)은 TextButton이라 입력을 자기가 먹으므로
		버튼을 눌러도 드래그가 시작되지 않는다. 좌표는 화면 픽셀이지만 창은 UIScale로
		scale배 그려지므로, 이동량을 scale로 나눠 커서와 창이 어긋나지 않게 한다.
	]]
	--[[
		삼각형을 끌어 프레임 간격을 직접 정한다(요청).

		핸들러를 삼각형마다 붙이지 않고 여기 한 번만 단다. 끄는 동안 타임라인이 다시
		그려지면 잡고 있던 버튼이 사라지는데, **번호(index)로 추적**하면 그래도 끊기지
		않기 때문이다. 앞뒤 프레임 시간 사이로 가두어 순서가 뒤집히지 않게 한다.
	]]
	UserInputService.InputChanged:Connect(function(input)
		local index = self.TimelineDrag
		if not index then
			return
		end
		-- 창 이동·크기 조절과 같은 안전장치. 버튼을 뗀 신호를 놓쳐도 스스로 풀린다.
		if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			self.TimelineDrag = nil
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local frames = self.Motion.Frames
		local frame = frames[index]
		local track = self.Timeline
		if not frame or not track then
			return
		end
		local width = math.max(track.AbsoluteSize.X, 1)
		local fraction = (input.Position.X - track.AbsolutePosition.X) / width
		local before = index > 1 and frames[index - 1].Time or 0
		local following = index < #frames and frames[index + 1].Time or MAX_MOTION_DURATION
		-- 최소 간격 0.01초: 삼각형이 완전히 겹쳐 집을 수 없게 되는 것을 막는다.
		frame.Time = math.clamp(self:_timelineTimeAt(fraction), before + 0.01, following)
		self:_repositionTimelineMarkers()
		if self.FrameTimeInput then
			self.FrameTimeInput.Text = string.format("%.3f", frames[self.SelectedFrame].Time)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			self.TimelineDrag
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			self.TimelineDrag = nil
			-- 놓을 때 한 번만 전체 갱신: 총 길이·미리보기·썸네일이 새 간격을 따라간다.
			self:_refreshAll()
		end
	end)

	self.WindowOffset = Vector2.new(24, 24)
	self.WindowSize = Vector2.new(WINDOW_DEFAULT_WIDTH, WINDOW_DEFAULT_HEIGHT)
	-- 휠 줌이 "창 위인지"를 판단할 수 있도록 창을 들고 있는다(요청 3).
	self.Window = panel

	--[[
		오른쪽 아래 크기 조절 손잡이 (요청 5).

		제목줄 드래그와 같은 방식이되 위치가 아니라 크기를 바꾼다. 화면 밖으로 커지는
		것과 너무 작아져 하단 독이 잘리는 것은 RefreshResponsive가 가둔다.
	]]
	do
		local grip = Instance.new("TextButton")
		grip.Name = "ResizeGrip"
		-- 16px로 잡았더니 몇 픽셀만 빗나가도 창 본체를 잡아 엉뚱하게 움직였다.
		-- 잡기 쉽도록 넓히고, 어디를 잡아야 하는지 보이게 배경도 살짝 준다.
		grip.Size = UDim2.fromOffset(24, 24)
		grip.Position = UDim2.new(1, -26, 1, -26)
		grip.BackgroundColor3 = THEME.PanelAlt
		grip.BackgroundTransparency = 0.35
		grip.Text = "◢"
		grip.TextColor3 = THEME.Parchment
		grip.TextSize = 15
		grip.Font = Enum.Font.GothamBold
		grip.AutoButtonColor = false
		grip.ZIndex = 30
		grip.Parent = panel

		local resizing = false
		local startPointer = Vector2.zero
		local startSize = Vector2.zero
		grip.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				resizing = true
				startPointer = Vector2.new(input.Position.X, input.Position.Y)
				startSize = self.WindowSize
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if not resizing then
				return
			end
			-- InputEnded를 한 번이라도 놓치면 창이 영원히 마우스를 따라다닌다(실제로 그랬다).
			-- 버튼이 정말 눌려 있는지 매번 확인해 스스로 풀리게 한다.
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				resizing = false
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local delta = Vector2.new(input.Position.X, input.Position.Y) - startPointer
			local scale = math.max(editorScale.Scale, 0.01)
			self.WindowSize = startSize + delta / scale
			local currentCamera = workspace.CurrentCamera
			self.RefreshResponsive(currentCamera and currentCamera.ViewportSize or Vector2.new(1280, 720))
		end)
		UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				resizing = false
			end
		end)
	end

	do
		local dragging = false
		local dragStart = Vector2.zero
		local originStart = Vector2.zero
		local function pointer(input: InputObject): Vector2
			return Vector2.new(input.Position.X, input.Position.Y)
		end
		local function isPointer(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
		end
		header.InputBegan:Connect(function(input)
			if isPointer(input) then
				dragging = true
				dragStart = pointer(input)
				originStart = self.WindowOffset
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			-- 위 크기 조절과 같은 이유의 안전장치. 버튼을 뗀 신호를 놓쳐도 스스로 풀린다.
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				dragging = false
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local scale = math.max(self.EditorScale and self.EditorScale.Scale or 1, 0.01)
			self.WindowOffset = originStart + (pointer(input) - dragStart) / scale
			local currentCamera = workspace.CurrentCamera
			if self.RefreshResponsive then
				self.RefreshResponsive(currentCamera and currentCamera.ViewportSize or Vector2.new(1280, 720))
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if isPointer(input) then
				dragging = false
			end
		end)
	end

	self.RefreshResponsive = function(viewportSize: Vector2)
		-- 화면 폭과 무관하게 **항상** 창 배치다. 넓은 화면이라고 편집기를 펼치면
		-- 모션을 볼 자리가 사라진다(요청: "큰 화면에선 모션을 크게 보면서 수정").
		local mobile = true
		self.MobileEditorMode = mobile
		local scale = math.clamp(math.min(viewportSize.X / 900, viewportSize.Y / 640), 0.6, 1)
		editorScale.Scale = scale

		-- 창 크기는 손잡이로 바뀌는 상태값이다(요청 5). 화면 밖으로 커지지 않게 가둔다.
		local windowWidth =
			math.clamp(self.WindowSize.X, WINDOW_MIN_WIDTH, math.max(WINDOW_MIN_WIDTH, viewportSize.X / scale - 8))
		local windowHeight =
			math.clamp(self.WindowSize.Y, WINDOW_MIN_HEIGHT, math.max(WINDOW_MIN_HEIGHT, viewportSize.Y / scale - 8))
		self.WindowSize = Vector2.new(windowWidth, windowHeight)
		panel.Size = UDim2.fromOffset(windowWidth, windowHeight)

		-- 뷰포트는 창 밖에 있다. 화면 전체가 모션이다.
		viewport.Position = UDim2.new()
		viewport.Size = UDim2.fromScale(1, 1)

		-- 제목줄 드래그로 창이 화면 밖으로 빠져나가지 않게 가둔다.
		-- UIScale이 창을 scale배로 그리므로 실제 차지 크기로 계산한다.
		local maxX = math.max(0, viewportSize.X - windowWidth * scale)
		local maxY = math.max(0, viewportSize.Y - windowHeight * scale)
		self.WindowOffset =
			Vector2.new(math.clamp(self.WindowOffset.X, 0, maxX), math.clamp(self.WindowOffset.Y, 0, maxY))
		panel.Position = UDim2.fromOffset(self.WindowOffset.X, self.WindowOffset.Y)

		mobileTabs.Visible = true
		if mobile then
			-- 제목줄: 아이콘 + 이름 + 오른쪽에 단축키/인벤토리/저장/닫기
			header.Size = UDim2.new(1, -8, 0, 42)
			header.Position = UDim2.fromOffset(4, 4)
			brandMark.Size = UDim2.fromOffset(26, 26)
			brandMark.Position = UDim2.fromOffset(8, 8)
			brand.Size = UDim2.fromOffset(104, 22)
			brand.Position = UDim2.fromOffset(40, 10)
			brand.Text = "모션 공방"
			brand.TextSize = 13
			title.Visible = false
			subtitle.Visible = false
			sessionTag.Visible = false
			shortcutHelp.Visible = true
			shortcutHelp.Size = UDim2.fromOffset(46, 22)
			shortcutHelp.Position = UDim2.new(1, -226, 0, 10)
			loadTop.Size = UDim2.fromOffset(70, 22)
			loadTop.Position = UDim2.new(1, -176, 0, 10)
			saveTop.Size = UDim2.fromOffset(48, 22)
			saveTop.Position = UDim2.new(1, -102, 0, 10)
			close.Size = UDim2.fromOffset(48, 22)
			close.Position = UDim2.new(1, -50, 0, 10)

			-- 메뉴 줄(포즈 / 미리보기 / 속성) — 창이 좁으니 한 장씩 갈아 끼운다.
			mobileTabs.Position = UDim2.fromOffset(4, 50)
			mobileTabs.Size = UDim2.new(1, -8, 0, 30)

			presetBar.Size = UDim2.new(1, -10, 0, 56)
			presetBar.Position = UDim2.fromOffset(5, 5)
			presetLayout.CellSize = UDim2.new(1 / 4, -4, 0, 24)
			presetLayout.FillDirectionMaxCells = 4

			--[[
				하단 독 높이(요청 1·2 수정).

				카테고리줄 36 + 상세줄 30 + TIMELINE 라벨 22 + 눈금자 52 + 여백 = 152.
				예전엔 130으로 잡아 눈금자 아래(밑변 레일·프레임 번호)가 독 밖으로
				삐져나가 노란 테두리를 넘고 번호가 반쯤 잘렸다.
			]]
			local dockHeight = 152
			workArea.Position = UDim2.fromOffset(4, 84)
			workArea.Size = UDim2.new(1, -8, 1, -(84 + dockHeight + 8))
			bottomDock.Size = UDim2.new(1, -8, 0, dockHeight)
			bottomDock.Position = UDim2.new(0, 4, 1, -(dockHeight + 4))
			for _, shell in { leftShell, centerShell, rightShell } do
				shell.Position = UDim2.new()
				shell.Size = UDim2.fromScale(1, 1)
			end
			shortcutPanel.Size = UDim2.fromOffset(windowWidth - 32, windowHeight - 56)
			shortcutBody.TextSize = 11
		else
			brand.Size = UDim2.fromOffset(188, 24)
			brand.Text = "CRAFTROYALE"
			brand.TextSize = 20
			title.Visible = true
			subtitle.Visible = true
			sessionTag.Visible = true
			shortcutHelp.Visible = true
			shortcutHelp.Position = UDim2.new(1, -264, 0, 17)
			loadTop.Position = UDim2.new(1, -444, 0, 17)
			saveTop.Position = UDim2.new(1, -356, 0, 17)
			close.Position = UDim2.new(1, -88, 0, 17)
			presetBar.Size = UDim2.new(1, -12, 0, 64)
			presetBar.Position = UDim2.fromOffset(6, 6)
			presetLayout.CellSize = UDim2.new(1 / 6, -5, 0, 26)
			presetLayout.FillDirectionMaxCells = 6
			workArea.Position = UDim2.fromOffset(8, 78)
			workArea.Size = UDim2.new(1, -16, 1, -236)
			bottomDock.Size = UDim2.new(1, -16, 0, 142)
			bottomDock.Position = UDim2.new(0, 8, 1, -150)
			leftShell.Size = UDim2.new(0, 164, 1, 0)
			leftShell.Position = UDim2.new()
			centerShell.Size = UDim2.new(1, -536, 1, 0)
			centerShell.Position = UDim2.fromOffset(172, 0)
			rightShell.Size = UDim2.new(0, 356, 1, 0)
			rightShell.Position = UDim2.new(1, -356, 0, 0)
			viewport.Position = UDim2.fromOffset(6, 76)
			viewport.Size = UDim2.new(1, -12, 1, -82)
			shortcutPanel.Size = UDim2.fromOffset(460, 420)
			shortcutBody.TextSize = 13
		end
		applyMobilePage()
	end
	local currentCamera = workspace.CurrentCamera
	self.RefreshResponsive(currentCamera and currentCamera.ViewportSize or Vector2.new(1280, 720))
	self:_refreshAll()
end

function MotionEditorController:_ensurePreviewWeapon()
	local existing = self.PreviewRig:FindFirstChild("MotionWeapon", true)
	local existingMotor = self:_motor("MotionWeaponMotor")
	if existing and existing:IsA("BasePart") and existingMotor then
		self.PreviewWeapon = existing
		self.PreviewWeaponMotor = existingMotor
		self:_ensureWeaponDecals(existing)
		return
	end
	local rightArm = self.PreviewRig:FindFirstChild("Right Arm")
	if not rightArm or not rightArm:IsA("BasePart") then
		return
	end
	local weapon = Instance.new("Part")
	weapon.Name = "MotionWeapon"
	weapon.Size = Vector3.new(0.35, 3, 0.45)
	weapon.Color = Color3.fromRGB(210, 215, 225)
	weapon.Material = Enum.Material.Metal
	weapon.CanCollide = false
	weapon.Parent = self.PreviewRig
	self.PreviewWeapon = weapon
	self:_ensureWeaponDecals(weapon)
	local motor = Instance.new("Motor6D")
	motor.Name = "MotionWeaponMotor"
	motor.Part0 = rightArm
	motor.Part1 = weapon
	motor.C0 = CFrame.new(0, -1.25, 0) * CFrame.Angles(0, 0, math.rad(-10))
	motor.C1 = CFrame.new(0, 1.2, 0)
	motor.Parent = rightArm
	self.PreviewWeaponMotor = motor
end

function MotionEditorController:_ensurePreviewDualWeapon()
	local leftArm = self.PreviewRig:FindFirstChild("Left Arm")
	if not leftArm or not leftArm:IsA("BasePart") then
		return
	end
	local weapon = Instance.new("Part")
	weapon.Name = "MotionDualWeapon"
	weapon.Size = Vector3.new(0.35, 3, 0.12)
	weapon.Color = Color3.fromRGB(205, 210, 220)
	weapon.Material = Enum.Material.Metal
	weapon.CanCollide = false
	weapon.Transparency = 1
	weapon.Parent = self.PreviewRig
	self:_ensureWeaponDecals(weapon)
	local motor = Instance.new("Motor6D")
	motor.Name = "MotionDualWeaponMotor"
	motor.Part0 = leftArm
	motor.Part1 = weapon
	motor.C0 = CFrame.new(0, -1.25, 0) * CFrame.Angles(0, 0, math.rad(10))
	motor.C1 = CFrame.new(0, 1.2, 0)
	motor.Parent = leftArm
	self.PreviewDualWeapon = weapon
	self.PreviewDualWeaponMotor = motor
end

function MotionEditorController:_ensureDecorationPreviews()
	self.DecorationPreviews = {}
	for index = 1, 5 do
		local visual = Instance.new("Part")
		visual.Name = "MotionDecoration" .. index
		visual.Anchored = true
		visual.CanCollide = false
		visual.CanQuery = false
		visual.Size = Vector3.new(2, 2, 0.12)
		visual.Transparency = 1
		visual.Parent = self.World
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local decal = Instance.new("Decal")
			decal.Face = face
			decal.Transparency = 1
			decal.Parent = visual
		end
		self.DecorationPreviews[index] = visual
	end
end

function MotionEditorController:_syncDecorations(frame: any)
	frame.Decorations = frame.Decorations or {}
	normalizeLayerOrder(frame, self.Motion.DualWield)
	for index, visual in self.DecorationPreviews do
		local decoration = frame.Decorations[index]
		if not decoration then
			visual.Transparency = 1
			for _, decal in visual:GetChildren() do
				if decal:IsA("Decal") then
					decal.Transparency = 1
				end
			end
			continue
		end
		local parent = decoration.Attach == "Head" and self.PreviewRig:FindFirstChild("Head")
			or self.PreviewRig:FindFirstChild("HumanoidRootPart")
		if not parent or not parent:IsA("BasePart") then
			continue
		end
		local size = decoration.Size or vector(2, 2, 0.12)
		visual.Size = Vector3.new(math.max(0.1, math.abs(size.X)), math.max(0.1, math.abs(size.Y)), 0.12)
		local rotation = decoration.Rotation or vector()
		local offset = decoration.Offset or vector()
		visual.CFrame = parent.CFrame
			* CFrame.new(
				offset.X,
				offset.Y,
				offset.Z + layerDepth(frame, self.Motion.DualWield, "Decoration:" .. index)
			)
			* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		local assetId = normalizeAssetId(tostring(decoration.AssetId or ""))
		visual.Transparency = assetId == "" and 0.4 or 0.9
		for _, decal in visual:GetChildren() do
			if decal:IsA("Decal") then
				decal.Texture = assetId
				decal.Transparency = assetId == "" and 1 or 0
			end
		end
	end
end

function MotionEditorController:_ensureOnionRig()
	local onion = self.PreviewRig:Clone()
	onion.Name = "OnionRig"
	for _, item in onion:GetDescendants() do
		if item:IsA("BasePart") then
			item.Color = Color3.fromRGB(90, 130, 255)
			item.Transparency = item.Name == "HumanoidRootPart" and 1 or 0.62
			item.LocalTransparencyModifier = 0
			item.CanCollide = false
		elseif item:IsA("Decal") then
			item.Transparency = 1
		end
	end
	onion.Parent = self.World
	self.OnionRig = onion
	self.OnionDecorationPreviews = {}
	for index = 1, 5 do
		local visual = Instance.new("Part")
		visual.Name = "OnionDecoration" .. index
		visual.Anchored = true
		visual.CanCollide = false
		visual.CanQuery = false
		visual.Transparency = 1
		visual.Size = Vector3.new(2, 2, 0.12)
		visual.Parent = self.World
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local decal = Instance.new("Decal")
			decal.Face = face
			decal.Color3 = Color3.fromRGB(110, 145, 255)
			decal.Transparency = 1
			decal.Parent = visual
		end
		self.OnionDecorationPreviews[index] = visual
	end
	self:_updateOnionRig()
end

function MotionEditorController:_onionMotor(name: string): Motor6D?
	for _, item in self.OnionRig:GetDescendants() do
		if item:IsA("Motor6D") and item.Name == name then
			return item
		end
	end
	return nil
end

function MotionEditorController:_updateOnionRig()
	if not self.OnionRig then
		return
	end
	local visible = self.OnionEnabled and self.SelectedFrame > 1
	for _, item in self.OnionRig:GetDescendants() do
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = visible and 0 or 1
		end
	end
	for _, visual in self.OnionDecorationPreviews or {} do
		visual.Transparency = 1
		for _, decal in visual:GetChildren() do
			if decal:IsA("Decal") then
				decal.Transparency = 1
			end
		end
	end
	if not visible then
		return
	end
	local frame = self.Motion.Frames[self.SelectedFrame - 1]
	local root = self.OnionRig:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and self.PreviewRootBase then
		local offset = frame.RootOffset or vector()
		root.CFrame = self.PreviewRootBase * CFrame.new(offset.X, offset.Y, offset.Z)
	end
	for _, jointName in JOINTS do
		local motor = self:_onionMotor(jointName)
		local pose = frame.Joints[jointName] or vector()
		local offset = (frame.JointOffsets and frame.JointOffsets[jointName]) or vector()
		if motor then
			motor.Transform =
				centeredJointTransform(motor, offset, pose, frame.JointRotations and frame.JointRotations[jointName])
		end
	end
	local rightArm = self.OnionRig:FindFirstChild("Right Arm")
	local leftArm = self.OnionRig:FindFirstChild("Left Arm")
	local mainMotor = self:_onionMotor("MotionWeaponMotor")
	local dualMotor = self:_onionMotor("MotionDualWeaponMotor")
	local weapon = frame.Weapon or defaultWeapon()
	local dualWeapon = frame.DualWeapon or defaultWeapon()
	if rightArm and rightArm:IsA("BasePart") and leftArm and leftArm:IsA("BasePart") then
		if mainMotor then
			mainMotor.Part0 = frame.HandSwap and leftArm or rightArm
			mainMotor.Transform = CFrame.new(
				weapon.Position.X,
				weapon.Position.Y,
				weapon.Position.Z + layerDepth(frame, self.Motion.DualWield, "Weapon")
			) * CFrame.Angles(math.rad(weapon.Rotation.X), math.rad(weapon.Rotation.Y), math.rad(weapon.Rotation.Z)) * CFrame.Angles(
				weapon.FlipY and math.pi or 0,
				weapon.FlipX and math.pi or 0,
				0
			)
		end
		if dualMotor then
			dualMotor.Part0 = frame.HandSwap and rightArm or leftArm
			dualMotor.Transform = CFrame.new(
				dualWeapon.Position.X,
				dualWeapon.Position.Y,
				dualWeapon.Position.Z + layerDepth(frame, self.Motion.DualWield, "DualWeapon")
			) * CFrame.Angles(
				math.rad(dualWeapon.Rotation.X),
				math.rad(dualWeapon.Rotation.Y),
				math.rad(dualWeapon.Rotation.Z)
			) * CFrame.Angles(dualWeapon.FlipY and math.pi or 0, dualWeapon.FlipX and math.pi or 0, 0)
		end
	end
	local onionWeapon = self.OnionRig:FindFirstChild("MotionWeapon", true)
	local onionDual = self.OnionRig:FindFirstChild("MotionDualWeapon", true)
	if onionWeapon and onionWeapon:IsA("BasePart") then
		self:_syncWeaponPart(onionWeapon, weapon, true)
		onionWeapon.Color = Color3.fromRGB(90, 130, 255)
		onionWeapon.Transparency = 0.52
		onionWeapon.LocalTransparencyModifier = 0
	end
	if onionDual and onionDual:IsA("BasePart") then
		self:_syncWeaponPart(onionDual, dualWeapon, self.Motion.DualWield)
		onionDual.Color = Color3.fromRGB(90, 130, 255)
		onionDual.Transparency = self.Motion.DualWield and 0.52 or 1
		onionDual.LocalTransparencyModifier = 0
	end
	for index, visual in self.OnionDecorationPreviews or {} do
		local decoration = frame.Decorations and frame.Decorations[index]
		local parent = decoration and (decoration.Attach == "Head" and self.OnionRig:FindFirstChild("Head") or root)
		if decoration and parent and parent:IsA("BasePart") then
			local size = decoration.Size or vector(2, 2, 0.12)
			visual.Size = Vector3.new(math.max(0.1, math.abs(size.X)), math.max(0.1, math.abs(size.Y)), 0.12)
			visual.CFrame = parent.CFrame
				* CFrame.new(
					decoration.Offset.X,
					decoration.Offset.Y,
					decoration.Offset.Z + layerDepth(frame, self.Motion.DualWield, "Decoration:" .. index)
				)
				* CFrame.Angles(
					math.rad(decoration.Rotation.X),
					math.rad(decoration.Rotation.Y),
					math.rad(decoration.Rotation.Z)
				)
			local assetId = normalizeAssetId(tostring(decoration.AssetId or ""))
			for _, decal in visual:GetChildren() do
				if decal:IsA("Decal") then
					decal.Texture = assetId
					decal.Transparency = assetId == "" and 1 or 0.68
				end
			end
		end
	end
end

function MotionEditorController:_ensureWeaponDecals(weapon: BasePart)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local name = face == Enum.NormalId.Front and "WeaponImageFront" or "WeaponImageBack"
		local decal = weapon:FindFirstChild(name)
		if not decal then
			decal = Instance.new("Decal")
			decal.Name = name
			decal.Parent = weapon
		end
		if decal:IsA("Decal") then
			decal.Face = face
		end
	end
end

function MotionEditorController:_syncWeaponPart(weapon: BasePart?, weaponData: any, enabled: boolean?)
	if not weapon then
		return
	end
	local size = weaponData.Size or vector(0.35, 3, 0.12)
	weapon.Size = Vector3.new(
		math.clamp(tonumber(size.X) or 0.35, 0.1, 12),
		math.clamp(tonumber(size.Y) or 3, 0.1, 12),
		math.clamp(tonumber(size.Z) or 0.12, 0.05, 4)
	)
	local assetId = normalizeAssetId(tostring(weaponData.AssetId or ""))
	if enabled == false then
		weapon.Transparency = 1
	else
		weapon.Transparency = assetId == "" and 0 or 0.88
	end
	for _, name in { "WeaponImageFront", "WeaponImageBack" } do
		local decal = weapon:FindFirstChild(name)
		if decal and decal:IsA("Decal") then
			decal.Texture = assetId
			decal.Transparency = (enabled == false or assetId == "") and 1 or 0
		end
	end
end

function MotionEditorController:_syncWeaponAppearance(weaponData: any)
	self:_syncWeaponPart(self.PreviewWeapon, weaponData, true)
end

function MotionEditorController:_motor(name: string): Motor6D?
	for _, item in self.PreviewRig:GetDescendants() do
		if item:IsA("Motor6D") and item.Name == name then
			return item
		end
	end
	return nil
end

function MotionEditorController:_frameHits(): { any }
	local result = {}
	for _, hit in self.Motion.Hits do
		if hit.Frame == self.SelectedFrame then
			table.insert(result, hit)
		end
	end
	return result
end

function MotionEditorController:_selectedHit(): any?
	return self:_frameHits()[self.SelectedHit]
end

function MotionEditorController:_selectedDecoration(): any?
	local frame = self.Motion.Frames[self.SelectedFrame]
	frame.Decorations = frame.Decorations or {}
	return frame.Decorations[self.SelectedDecoration]
end

function MotionEditorController:_moveLayer(fromIndex: number, toIndex: number)
	local frame = self.Motion.Frames[self.SelectedFrame]
	local order = normalizeLayerOrder(frame, self.Motion.DualWield)
	if fromIndex == toIndex or not order[fromIndex] then
		return
	end
	local key = table.remove(order, fromIndex)
	table.insert(order, math.clamp(toIndex, 1, #order + 1), key)
	frame.LayerOrder = order
	self:_refreshLayerList()
	self:_applySelectedFrame()
end

function MotionEditorController:_refreshLayerList()
	if not self.LayerList then
		return
	end
	clearButtons(self.LayerList)
	local frame = self.Motion.Frames[self.SelectedFrame]
	local order = normalizeLayerOrder(frame, self.Motion.DualWield)
	local labels = {
		Player = "플레이어",
		Weapon = "오른손 무기",
		DualWeapon = "왼손 무기",
	}
	for index, key in order do
		local label = labels[key]
		local decorationIndex = string.match(key, "^Decoration:(%d+)$")
		if decorationIndex then
			local decoration = frame.Decorations[tonumber(decorationIndex)]
			label = decoration and ("장식 · " .. tostring(decoration.Name or decorationIndex))
				or ("장식 " .. decorationIndex)
		end
		local button = makeButton(self.LayerList, string.format("≡  %02d  %s", index, label or key), 220, 28)
		button.Size = UDim2.new(1, -6, 0, 28)
		button.Position = UDim2.fromOffset(3, 0)
		button.LayoutOrder = index
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextSize = 10
		styleButton(button, key == "Player" and THEME.Green or THEME.Gold)
		button.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				self:_pushUndo()
				self.LayerDrag = { Index = index, Order = order }
			end
		end)
	end
	self.LayerList.Size = UDim2.new(1, 0, 0, math.max(34, #order * 31 + 6))
end

function MotionEditorController:_removeDecorationLayer(frame: any, removedIndex: number)
	local remapped = {}
	for _, key in normalizeLayerOrder(frame, self.Motion.DualWield) do
		local index = tonumber(string.match(key, "^Decoration:(%d+)$"))
		if not index or index < removedIndex then
			table.insert(remapped, key)
		elseif index > removedIndex then
			table.insert(remapped, "Decoration:" .. (index - 1))
		end
	end
	frame.LayerOrder = remapped
end

function MotionEditorController:_addDecoration()
	local frame = self.Motion.Frames[self.SelectedFrame]
	frame.Decorations = frame.Decorations or {}
	if #frame.Decorations >= 5 then
		self.Status.Text = "  STATUS\n  한 프레임에는 장식을 최대 5개까지 배치할 수 있습니다."
		return
	end
	self:_pushUndo()
	table.insert(frame.Decorations, {
		Name = "장식 " .. (#frame.Decorations + 1),
		AssetId = normalizeAssetId(self.DecorationAssetInput.Text),
		Attach = "Root",
		Offset = vector(0, 2, -0.6),
		Rotation = vector(),
		Size = vector(2, 2, 0.12),
		Layer = #frame.Decorations + 1,
	})
	normalizeLayerOrder(frame, self.Motion.DualWield)
	self.SelectedDecoration = #frame.Decorations
	self:_refreshDecorationFields()
	self:_refreshLayerList()
	self:_syncDecorations(frame)
end

function MotionEditorController:_cycleDecoration()
	local frame = self.Motion.Frames[self.SelectedFrame]
	frame.Decorations = frame.Decorations or {}
	if #frame.Decorations > 0 then
		self.SelectedDecoration = self.SelectedDecoration % #frame.Decorations + 1
		self:_refreshDecorationFields()
	end
end

function MotionEditorController:_deleteDecoration()
	local frame = self.Motion.Frames[self.SelectedFrame]
	frame.Decorations = frame.Decorations or {}
	if not frame.Decorations[self.SelectedDecoration] then
		return
	end
	self:_pushUndo()
	self:_removeDecorationLayer(frame, self.SelectedDecoration)
	table.remove(frame.Decorations, self.SelectedDecoration)
	normalizeLayerOrder(frame, self.Motion.DualWield)
	self.SelectedDecoration = math.clamp(self.SelectedDecoration, 1, math.max(1, #frame.Decorations))
	self:_refreshDecorationFields()
	self:_refreshLayerList()
	self:_syncDecorations(frame)
end

function MotionEditorController:_commitDecorationFields()
	local decoration = self:_selectedDecoration()
	if not decoration then
		return
	end
	self:_pushUndo()
	decoration.AssetId = normalizeAssetId(self.DecorationAssetInput.Text)
	decoration.Name =
		string.sub(self.DecorationNameInput.Text ~= "" and self.DecorationNameInput.Text or decoration.Name, 1, 24)
	decoration.Rotation.Z = math.clamp(tonumber(self.DecorationRotationInput.Text) or decoration.Rotation.Z, -360, 360)
	decoration.Size.X = math.clamp(tonumber(self.DecorationSizeXInput.Text) or decoration.Size.X, 0.1, 12)
	decoration.Size.Y = math.clamp(tonumber(self.DecorationSizeYInput.Text) or decoration.Size.Y, 0.1, 12)
	self:_refreshDecorationFields()
	self:_refreshLayerList()
	self:_syncDecorations(self.Motion.Frames[self.SelectedFrame])
end

function MotionEditorController:_refreshDecorationFields()
	local frame = self.Motion.Frames[self.SelectedFrame]
	frame.Decorations = frame.Decorations or {}
	self.SelectedDecoration = math.clamp(self.SelectedDecoration, 1, math.max(1, #frame.Decorations))
	local decoration = frame.Decorations[self.SelectedDecoration]
	self.DecorationCycle.Text =
		string.format("장식 %d / %d", #frame.Decorations > 0 and self.SelectedDecoration or 0, #frame.Decorations)
	self.DecorationAssetInput.Text = decoration and tostring(decoration.AssetId or "") or ""
	self.DecorationNameInput.Text = decoration and tostring(decoration.Name or "장식") or ""
	self.DecorationRotationInput.Text = decoration and string.format("%.1f", decoration.Rotation.Z or 0) or ""
	self.DecorationSizeXInput.Text = decoration and string.format("%.2f", decoration.Size.X or 2) or ""
	self.DecorationSizeYInput.Text = decoration and string.format("%.2f", decoration.Size.Y or 2) or ""
	self.DecorationAttachButton.Text = decoration and (decoration.Attach == "Head" and "머리" or "몸통") or "부착"
end

function MotionEditorController:_eventBucket(kind: string): { any }
	self.Motion.Events = self.Motion.Events or { Effects = {}, Projectiles = {}, Teleports = {} }
	self.Motion.Events[kind] = self.Motion.Events[kind] or {}
	return self.Motion.Events[kind]
end

function MotionEditorController:_frameEvents(kind: string?): { any }
	local bucket = self:_eventBucket(kind or self.SelectedEventType)
	local result = {}
	for _, event in bucket do
		if event.Frame == self.SelectedFrame then
			table.insert(result, event)
		end
	end
	return result
end

function MotionEditorController:_selectedFrameEvent(): any?
	return self:_frameEvents()[self.SelectedEvent]
end

function MotionEditorController:_addFrameEvent(kind: string)
	self:_pushUndo()
	self.SelectedEventType = kind
	local bucket = self:_eventBucket(kind)
	local event = {
		Frame = self.SelectedFrame,
		AssetId = "",
		Offset = vector(0, 1, -2),
		Size = vector(2, 2, 0.12),
		Rotation = vector(),
		Duration = 0.35,
		ColorHex = kind == "Projectiles" and "#FFA050" or "#45F3FF",
		Opacity = 1,
		FlipX = false,
		FlipY = false,
		DirectionMode = "facing",
		FixedAngle = 0,
		Speed = 12,
		EndFrame = self.SelectedFrame,
		EffectPreset = "slash",
	}
	if kind == "Teleports" then
		event.Offset = vector(4, 0, 0)
		event.Size = vector(4, 0, 0)
	elseif kind == "Projectiles" then
		event.Duration = 0.8
		event.Size = vector(1.5, 0.6, 0.12)
	end
	table.insert(bucket, event)
	self.SelectedEvent = #self:_frameEvents(kind)
	self:_refreshEventFields()
end

function MotionEditorController:_cycleEffectPreset()
	local event = self:_selectedFrameEvent()
	if not event or self.SelectedEventType ~= "Effects" then
		return
	end
	local current = 1
	for index, preset in EFFECT_PRESETS do
		if preset.Key == event.EffectPreset then
			current = index
			break
		end
	end
	self:_pushUndo()
	event.EffectPreset = EFFECT_PRESETS[current % #EFFECT_PRESETS + 1].Key
	self:_refreshEventFields()
end

function MotionEditorController:_cycleFrameEvent()
	local events = self:_frameEvents()
	if #events > 0 then
		self.SelectedEvent = self.SelectedEvent % #events + 1
		self:_refreshEventFields()
		return
	end
	local order = { "Effects", "Projectiles", "Teleports" }
	local current = table.find(order, self.SelectedEventType) or 1
	for offset = 1, #order do
		local kind = order[(current + offset - 1) % #order + 1]
		if #self:_frameEvents(kind) > 0 then
			self.SelectedEventType = kind
			self.SelectedEvent = 1
			self:_refreshEventFields()
			return
		end
	end
end

function MotionEditorController:_deleteFrameEvent()
	local selected = self:_selectedFrameEvent()
	if not selected then
		return
	end
	self:_pushUndo()
	local bucket = self:_eventBucket(self.SelectedEventType)
	for index, event in bucket do
		if event == selected then
			table.remove(bucket, index)
			break
		end
	end
	self.SelectedEvent = 1
	self:_refreshEventFields()
end

function MotionEditorController:_commitFrameEventFields()
	local event = self:_selectedFrameEvent()
	if not event then
		return
	end
	self:_pushUndo()
	event.AssetId = normalizeAssetId(self.EventAssetInput.Text)
	event.Duration = math.clamp(tonumber(self.EventDurationInput.Text) or event.Duration, 0.05, 10)
	event.Rotation.Z = math.clamp(tonumber(self.EventRotationInput.Text) or event.Rotation.Z, -360, 360)
	event.Size.X = math.clamp(tonumber(self.EventSizeXInput.Text) or event.Size.X, -20, 20)
	event.Size.Y = math.clamp(tonumber(self.EventSizeYInput.Text) or event.Size.Y, -20, 20)
	event.ColorHex = normalizeHex(self.EventColorInput.Text)
	event.Opacity = math.clamp(tonumber(self.EventOpacityInput.Text) or event.Opacity or 1, 0, 1)
	event.FixedAngle = math.clamp(tonumber(self.EventAngleInput.Text) or event.FixedAngle or 0, -180, 180)
	event.Speed = math.clamp(tonumber(self.EventSpeedInput.Text) or event.Speed or 12, 1, 100)
	event.EndFrame = math.clamp(
		math.floor(tonumber(self.EventEndFrameInput.Text) or event.EndFrame or event.Frame),
		event.Frame,
		#self.Motion.Frames
	)
	if self.SelectedEventType == "Teleports" then
		event.Offset.X = math.clamp(tonumber(self.EventSizeXInput.Text) or event.Offset.X, -20, 20)
		event.Offset.Y = math.clamp(tonumber(self.EventSizeYInput.Text) or event.Offset.Y, -20, 20)
	end
	self:_refreshEventFields()
end

function MotionEditorController:_cycleProjectileDirection()
	local event = self:_selectedFrameEvent()
	if not event or self.SelectedEventType ~= "Projectiles" then
		return
	end
	local order = { "target", "facing", "fixed" }
	local index = table.find(order, event.DirectionMode) or 2
	self:_pushUndo()
	event.DirectionMode = order[index % #order + 1]
	self:_refreshEventFields()
end

function MotionEditorController:_toggleFrameEventFlag(flag: string)
	local event = self:_selectedFrameEvent()
	if not event then
		return
	end
	self:_pushUndo()
	event[flag] = event[flag] ~= true
	self:_refreshEventFields()
end

function MotionEditorController:_refreshEventFields()
	local events = self:_frameEvents()
	self.SelectedEvent = math.clamp(self.SelectedEvent, 1, math.max(1, #events))
	local event = events[self.SelectedEvent]
	local labels = { Effects = "이펙트", Projectiles = "투사체", Teleports = "텔레포트" }
	self.EventCycle.Text = string.format(
		"%s %d / %d",
		labels[self.SelectedEventType] or "이벤트",
		#events > 0 and self.SelectedEvent or 0,
		#events
	)
	self.EventAssetInput.Text = event and tostring(event.AssetId or "") or ""
	self.EventDurationInput.Text = event and string.format("%.2f", event.Duration or 0.35) or ""
	self.EventRotationInput.Text = event and string.format("%.1f", event.Rotation.Z or 0) or ""
	self.EventSizeXInput.Text = event
			and string.format("%.2f", self.SelectedEventType == "Teleports" and event.Offset.X or event.Size.X or 0)
		or ""
	self.EventSizeYInput.Text = event
			and string.format("%.2f", self.SelectedEventType == "Teleports" and event.Offset.Y or event.Size.Y or 0)
		or ""
	self.EventColorInput.Text = event and normalizeHex(tostring(event.ColorHex or "#FFFFFF")) or ""
	self.EventOpacityInput.Text = event and string.format("%.2f", event.Opacity or 1) or ""
	self.EventAngleInput.Text = event and string.format("%.1f", event.FixedAngle or 0) or ""
	self.EventSpeedInput.Text = event and string.format("%.1f", event.Speed or 12) or ""
	self.EventEndFrameInput.Text = event and tostring(event.EndFrame or event.Frame or self.SelectedFrame) or ""
	local directionLabels = { target = "대상 방향", facing = "바라보는 방향", fixed = "고정 각도" }
	local effectLabels = {}
	for _, preset in EFFECT_PRESETS do
		effectLabels[preset.Key] = preset.Label
	end
	self.EventPresetButton.Text = event and ("FX: " .. (effectLabels[event.EffectPreset or "slash"] or "베기"))
		or "FX 선택"
	self.EventPresetButton.Visible = self.SelectedEventType == "Effects"
	self.EventDirectionButton.Text = event and directionLabels[event.DirectionMode or "facing"] or "투사체 방향"
	self.EventDirectionButton.Active = self.SelectedEventType == "Projectiles"
	self.EventAngleInput.TextEditable = self.SelectedEventType == "Projectiles"
		and event
		and event.DirectionMode == "fixed"
	styleButton(
		self.EventFlipXButton,
		event and event.FlipX and THEME.Green or Color3.fromRGB(197, 108, 255),
		event and event.FlipX and THEME.GreenDark or THEME.PanelAlt
	)
	styleButton(
		self.EventFlipYButton,
		event and event.FlipY and THEME.Green or Color3.fromRGB(197, 108, 255),
		event and event.FlipY and THEME.GreenDark or THEME.PanelAlt
	)
	self:_updateEventPreview()
end

function MotionEditorController:_updateEventPreview()
	local event = self:_selectedFrameEvent()
	local root = self.PreviewRig:FindFirstChild("HumanoidRootPart")
	if not event or not root or not root:IsA("BasePart") then
		self.EventPreview.Transparency = 1
		for _, decal in self.EventPreview:GetChildren() do
			if decal:IsA("Decal") then
				decal.Transparency = 1
			end
		end
		return
	end
	if self.SelectedEventType == "Teleports" then
		self.EventPreview.Shape = Enum.PartType.Ball
		self.EventPreview.Size = Vector3.new(0.8, 0.8, 0.8)
		self.EventPreview.CFrame = root.CFrame * CFrame.new(event.Offset.X, event.Offset.Y, event.Offset.Z)
		self.EventPreview.Color = Color3.fromRGB(197, 108, 255)
		self.EventPreview.Transparency = 0.3
		for _, decal in self.EventPreview:GetChildren() do
			if decal:IsA("Decal") then
				decal.Transparency = 1
			end
		end
		return
	end
	local effectPreset = tostring(event.EffectPreset or "slash")
	self.EventPreview.Shape = self.SelectedEventType == "Effects"
			and (effectPreset == "spark" or effectPreset == "burst" or effectPreset == "smoke")
			and Enum.PartType.Ball
		or (self.SelectedEventType == "Effects" and effectPreset == "ring" and Enum.PartType.Cylinder)
		or Enum.PartType.Block
	local presetScale = effectPreset == "spark" and 0.45 or effectPreset == "burst" and 0.8 or 1
	self.EventPreview.Size = Vector3.new(
		math.max(0.1, math.abs(event.Size.X) * presetScale),
		math.max(0.1, math.abs(event.Size.Y) * presetScale),
		0.12
	)
	self.EventPreview.CFrame = root.CFrame
		* CFrame.new(event.Offset.X, event.Offset.Y, event.Offset.Z)
		* CFrame.Angles(0, 0, math.rad(event.Rotation.Z or 0))
		* CFrame.Angles(event.FlipY and math.pi or 0, event.FlipX and math.pi or 0, 0)
	if self.SelectedEventType == "Effects" and effectPreset == "ring" then
		self.EventPreview.CFrame *= CFrame.Angles(0, math.pi * 0.5, 0)
	end
	local assetId = normalizeAssetId(tostring(event.AssetId or ""))
	local opacity = math.clamp(tonumber(event.Opacity) or 1, 0, 1)
	local color = colorFromHex(tostring(event.ColorHex or "#FFFFFF"))
	self.EventPreview.Color = color
	self.EventPreview.Transparency = assetId == "" and (1 - opacity * 0.6) or 1
	for _, decal in self.EventPreview:GetChildren() do
		if decal:IsA("Decal") then
			decal.Texture = assetId
			decal.Color3 = color
			decal.Transparency = assetId == "" and 1 or 1 - opacity
		end
	end
end

function MotionEditorController:_selectFrame(index: number)
	self.SelectedFrame = math.clamp(index, 1, #self.Motion.Frames)
	self.SelectedHit = 1
	self.SelectedEvent = 1
	self.SelectedDecoration = 1
	self.SelectedStatus = 1
	self.SelectedBuff = 1
	self:_refreshAll()
end

function MotionEditorController:_switchPreset(key: string)
	local motion = self.PresetMotions[key]
	if not motion or key == self.ActivePreset then
		return
	end
	self.ActivePreset = key
	self.Motion = motion
	self.SelectedFrame = 1
	self.SelectedHit = 1
	self.SelectedEvent = 1
	self.SelectedDecoration = 1
	self.UndoStack = {}
	self:_refreshAll()
end

function MotionEditorController:_refreshPresetBar()
	local activeLabel = self.ActivePreset
	for _, preset in PRESET_ORDER do
		local button = self.PresetButtons[preset.Key]
		local motion = self.PresetMotions[preset.Key]
		if button and motion then
			if preset.Key == self.ActivePreset then
				activeLabel = preset.Label
			end
			button.Text = (motion.Name ~= preset.Label and motion.Name or preset.Label)
				.. (motion.Complete and "  ✓" or "")
			if preset.Key == self.ActivePreset then
				styleButton(button, THEME.Green, THEME.GreenDark, Color3.new(1, 1, 1))
			elseif motion.Complete then
				styleButton(button, THEME.Green, Color3.fromRGB(20, 45, 26), THEME.Green)
			else
				styleButton(button, THEME.WoodLight)
			end
		end
	end
	if self.HeaderPresetLabel then
		local definition = CharacterDefinitions.Get(self.AuthorCharacterId)
		self.HeaderPresetLabel.Text = string.format("●  %s 모션 세트  /  %s", definition.Name, activeLabel)
	end
	if self.ViewportBadge then
		self.ViewportBadge.Text = string.format("%s  /  FRAME %02d", activeLabel, self.SelectedFrame)
	end
	self.MotionNameInput.Text = self.Motion.Name
	self.MotionDescriptionInput.Text = tostring(self.Motion.Description or "")
	self.PackNameInput.Text = self.PackName
	self.PackDescriptionInput.Text = self.PackDescription
	self.BodyColorInput.Text = self.BodyColorHex
	self.PresetCompleteButton.Text = self.Motion.Complete and "완성 ✓" or "미완성"
	styleButton(
		self.PresetCompleteButton,
		self.Motion.Complete and THEME.Green or THEME.Red,
		self.Motion.Complete and THEME.GreenDark or THEME.PanelAlt
	)
end

function MotionEditorController:_applyBodyColor()
	local color = colorFromHex(self.BodyColorHex)
	for _, name in { "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		local part = self.PreviewRig and self.PreviewRig:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
		end
	end
end

function MotionEditorController:_commitPackIdentity()
	self.PackName = string.sub(self.PackNameInput.Text ~= "" and self.PackNameInput.Text or self.PackName, 1, 32)
	self.PackDescription = string.sub(self.PackDescriptionInput.Text, 1, 160)
	self.BodyColorHex = normalizeHex(self.BodyColorInput.Text)
	self:_applyBodyColor()
	self:_refreshPresetBar()
end

function MotionEditorController:_combat(): any
	self.Motion.Combat = self.Motion.Combat or defaultCombat(self.ActivePreset)
	return self.Motion.Combat
end

function MotionEditorController:_commitCombatFields()
	local combat = self:_combat()
	self:_pushUndo()
	combat.Damage = math.clamp(
		math.floor(tonumber(self.CombatDamageInput.Text) or combat.Damage),
		0,
		self.ActivePreset == "Ultimate" and 100 or 60
	)
	combat.CooldownTurns = (
		self.ActivePreset == "Basic"
		or self.ActivePreset == "Heavy"
		or self.ActivePreset == "Ultimate"
	)
			and 0
		or math.clamp(math.floor(tonumber(self.CombatCooldownInput.Text) or combat.CooldownTurns), 0, 10)
	combat.Knockback = math.clamp(math.floor(tonumber(self.CombatKnockbackInput.Text) or combat.Knockback), 0, 200)
	self:_refreshCombatFields()
end

function MotionEditorController:_cycleCastDirection()
	local combat = self:_combat()
	local order = { "target", "preserve", "away" }
	local current = self:_castDirectionAt(self.SelectedFrame)
	local index = table.find(order, current) or 1
	self:_pushUndo()
	self.Motion.Frames[self.SelectedFrame].CastDirection = order[index % #order + 1]
	combat.CastDirection = self.Motion.Frames[self.SelectedFrame].CastDirection
	self:_refreshCombatFields()
end

function MotionEditorController:_castDirectionAt(frameIndex: number): string
	for index = frameIndex, 1, -1 do
		local direction = self.Motion.Frames[index].CastDirection
		if direction then
			return direction
		end
	end
	return self:_combat().CastDirection or "target"
end

function MotionEditorController:_addStatus()
	local combat = self:_combat()
	combat.Statuses = combat.Statuses or {}
	local nextType = STATUS_TYPES[(#combat.Statuses % #STATUS_TYPES) + 1]
	self:_pushUndo()
	table.insert(combat.Statuses, {
		Type = nextType.Key,
		ApplyFrame = self.SelectedFrame,
		Power = (nextType.Key == "bleed" or nextType.Key == "burn") and 2 or 0,
		Stacks = (nextType.Key == "bleed" or nextType.Key == "burn") and 2 or 0,
		DurationTurns = 1,
	})
	self.SelectedStatus = #combat.Statuses
	self:_refreshCombatFields()
end

function MotionEditorController:_cycleStatus()
	local statuses = self:_combat().Statuses or {}
	if #statuses > 0 then
		self.SelectedStatus = self.SelectedStatus % #statuses + 1
		self:_refreshCombatFields()
	end
end

function MotionEditorController:_deleteStatus()
	local statuses = self:_combat().Statuses or {}
	if not statuses[self.SelectedStatus] then
		return
	end
	self:_pushUndo()
	table.remove(statuses, self.SelectedStatus)
	self.SelectedStatus = math.clamp(self.SelectedStatus, 1, math.max(1, #statuses))
	self:_refreshCombatFields()
end

function MotionEditorController:_commitStatusFields()
	local statuses = self:_combat().Statuses or {}
	local status = statuses[self.SelectedStatus]
	if not status then
		return
	end
	self:_pushUndo()
	status.ApplyFrame =
		math.clamp(math.floor(tonumber(self.StatusFrameInput.Text) or status.ApplyFrame), 1, #self.Motion.Frames)
	status.Power = math.clamp(math.floor(tonumber(self.StatusPowerInput.Text) or status.Power), 0, 9)
	status.Stacks = math.clamp(math.floor(tonumber(self.StatusStacksInput.Text) or status.Stacks), 0, 3)
	status.DurationTurns =
		math.clamp(math.floor(tonumber(self.StatusDurationInput.Text) or status.DurationTurns), 0, 10)
	self:_refreshCombatFields()
end

function MotionEditorController:_addBuff()
	local combat = self:_combat()
	combat.Buffs = combat.Buffs or {}
	local validTypes = self.ActivePreset == "Ultimate" and BUFF_TYPES
		or { table.unpack(BUFF_TYPES, 1, #BUFF_TYPES - 1) }
	local nextType = validTypes[(#combat.Buffs % #validTypes) + 1]
	self:_pushUndo()
	table.insert(combat.Buffs, {
		Type = nextType.Key,
		ApplyFrame = self.SelectedFrame,
		Value = nextType.Key == "iframe" and 5 or 10,
		DurationTurns = nextType.Key == "iframe" and 0 or 2,
	})
	self.SelectedBuff = #combat.Buffs
	self:_refreshCombatFields()
end

function MotionEditorController:_cycleBuff()
	local buffs = self:_combat().Buffs or {}
	if #buffs > 0 then
		self.SelectedBuff = self.SelectedBuff % #buffs + 1
		self:_refreshCombatFields()
	end
end

function MotionEditorController:_deleteBuff()
	local buffs = self:_combat().Buffs or {}
	if not buffs[self.SelectedBuff] then
		return
	end
	self:_pushUndo()
	table.remove(buffs, self.SelectedBuff)
	self.SelectedBuff = math.clamp(self.SelectedBuff, 1, math.max(1, #buffs))
	self:_refreshCombatFields()
end

function MotionEditorController:_commitBuffFields()
	local buffs = self:_combat().Buffs or {}
	local buff = buffs[self.SelectedBuff]
	if not buff then
		return
	end
	self:_pushUndo()
	buff.ApplyFrame =
		math.clamp(math.floor(tonumber(self.BuffFrameInput.Text) or buff.ApplyFrame), 1, #self.Motion.Frames)
	buff.Value = math.clamp(tonumber(self.BuffValueInput.Text) or buff.Value, 0, buff.Type == "iframe" and 30 or 50)
	buff.DurationTurns = buff.Type == "iframe" and 0
		or math.clamp(math.floor(tonumber(self.BuffDurationInput.Text) or buff.DurationTurns), 0, 10)
	self:_refreshCombatFields()
end

function MotionEditorController:_combatBudget(combat: any): number
	local cost = math.floor((tonumber(combat.Damage) or 0) * (self.ActivePreset == "Ultimate" and 1 or 1.5) + 0.5)
	if self.ActivePreset ~= "Basic" and self.ActivePreset ~= "Heavy" and self.ActivePreset ~= "Ultimate" then
		cost += math.max(0, 3 - (tonumber(combat.CooldownTurns) or 0)) * 8
	end
	cost += math.floor((tonumber(combat.Knockback) or 0) / 5) * 2
	cost += ((tonumber(combat.TargetCount) or 1) - 1) * 10
	local defaultGain = (self.ActivePreset == "Basic" or self.ActivePreset == "Heavy") and 5 or 10
	if self.ActivePreset ~= "Ultimate" then
		cost += math.max(0, math.floor(((tonumber(combat.UltimateGain) or defaultGain) - defaultGain) / 5)) * 3
	end
	for _, status in combat.Statuses or {} do
		if status.Type == "bleed" or status.Type == "burn" then
			cost += (status.Power or 0) * 4 + (status.Stacks or 0) * 5
		else
			cost += (status.DurationTurns or 0) * ((status.Type == "stun" or status.Type == "airborne") and 15 or 8)
		end
	end
	for _, buff in combat.Buffs or {} do
		cost += math.floor((tonumber(buff.Value) or 0) * (buff.Type == "iframe" and 3 or 0.5))
		cost += (tonumber(buff.DurationTurns) or 0) * 3
	end
	return math.floor(cost + 0.5)
end

function MotionEditorController:_refreshCombatFields()
	local combat = self:_combat()
	local castLabels =
		{ target = "대상 바라보기", preserve = "현재 방향 유지", away = "대상 반대 보기" }
	self.CombatDamageInput.Text = tostring(math.floor(combat.Damage or 0))
	self.CombatCooldownInput.Text = tostring(math.floor(combat.CooldownTurns or 0))
	self.CombatCooldownInput.TextEditable = self.ActivePreset ~= "Basic"
		and self.ActivePreset ~= "Heavy"
		and self.ActivePreset ~= "Ultimate"
	self.CombatKnockbackInput.Text = tostring(math.floor(combat.Knockback or 0))
	self.HeavyAfterInput.Text = tostring(math.floor(combat.HeavyAfter or 3))
	self.UltimateGainInput.Text = tostring(math.floor(combat.UltimateGain or 0))
	self.DashDistanceInput.Text = tostring(math.floor(combat.DashDistance or 120))
	local showHeavy = self.ActivePreset == "Heavy"
	local showGain = self.ActivePreset == "Basic"
		or self.ActivePreset == "Heavy"
		or self.ActivePreset == "Skill1"
		or self.ActivePreset == "Skill2"
		or self.ActivePreset == "Skill3"
	local showDash = self.ActivePreset == "Dash"
	self.CombatSpecialRow.Visible = showHeavy or showGain or showDash
	self.HeavyAfterInput.Visible = showHeavy
	self.UltimateGainInput.Visible = showGain
	self.DashDistanceInput.Visible = showDash
	if showHeavy and showGain then
		self.HeavyAfterInput.Size = UDim2.new(0.5, -3, 0, 34)
		self.HeavyAfterInput.Position = UDim2.new()
		self.UltimateGainInput.Size = UDim2.new(0.5, -3, 0, 34)
		self.UltimateGainInput.Position = UDim2.new(0.5, 3, 0, 0)
	elseif showGain then
		self.UltimateGainInput.Size = UDim2.new(1, 0, 0, 34)
		self.UltimateGainInput.Position = UDim2.new()
	elseif showDash then
		self.DashDistanceInput.Size = UDim2.new(1, 0, 0, 34)
		self.DashDistanceInput.Position = UDim2.new()
	end
	self.CastDirectionButton.Text = castLabels[self:_castDirectionAt(self.SelectedFrame)] or castLabels.target
	self.TargetCountButton.Text = string.format("대상 %d인", combat.TargetCount or 1)
	self.RangedButton.Text = combat.Ranged and "원거리" or "근거리"
	styleButton(
		self.RangedButton,
		combat.Ranged and THEME.Cyan or Color3.fromRGB(255, 160, 80),
		combat.Ranged and Color3.fromRGB(14, 50, 55) or THEME.PanelAlt
	)
	local statuses = combat.Statuses or {}
	self.SelectedStatus = math.clamp(self.SelectedStatus, 1, math.max(1, #statuses))
	local status = statuses[self.SelectedStatus]
	local statusLabels = {}
	for _, entry in STATUS_TYPES do
		statusLabels[entry.Key] = entry.Label
	end
	self.StatusCycleButton.Text = status
			and string.format("%s %d/%d", statusLabels[status.Type] or status.Type, self.SelectedStatus, #statuses)
		or "상태 0 / 0"
	self.StatusFrameInput.Text = status and tostring(status.ApplyFrame or 1) or ""
	self.StatusPowerInput.Text = status and tostring(status.Power or 0) or ""
	self.StatusStacksInput.Text = status and tostring(status.Stacks or 0) or ""
	self.StatusDurationInput.Text = status and tostring(status.DurationTurns or 0) or ""
	local buffs = combat.Buffs or {}
	self.SelectedBuff = math.clamp(self.SelectedBuff, 1, math.max(1, #buffs))
	local buff = buffs[self.SelectedBuff]
	local buffLabels = {}
	for _, entry in BUFF_TYPES do
		buffLabels[entry.Key] = entry.Label
	end
	self.BuffCycleButton.Text = buff
			and string.format("%s %d/%d", buffLabels[buff.Type] or buff.Type, self.SelectedBuff, #buffs)
		or "버프 0 / 0"
	self.BuffFrameInput.Text = buff and tostring(buff.ApplyFrame or 1) or ""
	self.BuffValueInput.Text = buff and tostring(buff.Value or 0) or ""
	self.BuffDurationInput.Text = buff and tostring(buff.DurationTurns or 0) or ""
	local budget = self:_combatBudget(combat)
	self.CombatBudgetLabel.Text = string.format("프리셋 예산  %d / 100", budget)
	self.CombatBudgetLabel.TextColor3 = budget <= 100 and THEME.GoldLight or THEME.Red
end

function MotionEditorController:_mirrorCurrentPose()
	self:_pushUndo()
	local frame = self.Motion.Frames[self.SelectedFrame]
	local pairs = {
		{ "Right Shoulder", "Left Shoulder" },
		{ "Right Hip", "Left Hip" },
	}
	for _, pair in pairs do
		local right = copyVector(frame.Joints[pair[1]])
		local left = copyVector(frame.Joints[pair[2]])
		right.Y = -right.Y
		right.Z = -right.Z
		left.Y = -left.Y
		left.Z = -left.Z
		frame.Joints[pair[1]] = left
		frame.Joints[pair[2]] = right
		frame.JointRotations = frame.JointRotations or {}
		frame.JointRotations[pair[1]] = nil
		frame.JointRotations[pair[2]] = nil
		frame.JointOffsets = frame.JointOffsets or {}
		local rightOffset = copyVector(frame.JointOffsets[pair[1]])
		local leftOffset = copyVector(frame.JointOffsets[pair[2]])
		rightOffset.X = -rightOffset.X
		leftOffset.X = -leftOffset.X
		frame.JointOffsets[pair[1]] = leftOffset
		frame.JointOffsets[pair[2]] = rightOffset
	end
	frame.RootOffset = frame.RootOffset or vector()
	frame.RootOffset.X = -frame.RootOffset.X
	self:_refreshAll()
end

function MotionEditorController:_resetCurrentPose()
	self:_pushUndo()
	local frame = self.Motion.Frames[self.SelectedFrame]
	frame.Joints = {}
	frame.JointRotations = {}
	frame.JointOffsets = {}
	frame.RootOffset = vector()
	self:_refreshAll()
end

--[[
	눈금자 좌우 여백. **비율**로 잡는다 — 창이 UIScale로 축소돼도 삼각형 위치와
	마우스 좌표가 어긋나지 않게 하려면 픽셀이 아니라 비율이어야 한다.
]]
local TIMELINE_PAD = 0.05

--[[
	눈금자의 전체 길이(초).

	처음에는 `마지막 프레임 시간 × 1.25`로 잡았는데, 그러면 **마지막 삼각형을 끌 때
	눈금자도 같이 늘었다 줄어** 삼각형이 언제나 같은 자리(77%)에 붙어 있는 것처럼
	보였다 — 즉 맨 끝 프레임만 간격 조절이 불가능했다.

	그래서 눈금자를 0.5초 배수로 끊어 고정한다. 늘어날 땐 바로 늘리고, 줄어들 땐
	절반 아래로 내려갈 때만 줄인다(경계에서 출렁이지 않게 하는 히스테리시스).
]]
function MotionEditorController:_timelineSpan(): number
	local frames = self.Motion.Frames
	local last = frames[#frames]
	local duration = math.max(last and last.Time or 0, 0.05)
	local step = 0.5
	local needed = math.max(math.ceil(duration / step) * step, step)
	local current = self.TimelineSpanValue
	if not current or needed > current or duration < current * 0.4 then
		self.TimelineSpanValue = needed
	end
	return self.TimelineSpanValue
end

-- 시간 → 눈금자 가로 비율(0~1)
function MotionEditorController:_timelineFraction(time: number): number
	local span = self.TimelineSpan or self:_timelineSpan()
	return TIMELINE_PAD + math.clamp(time / span, 0, 1) * (1 - TIMELINE_PAD * 2)
end

-- 눈금자 가로 비율 → 시간 (삼각형을 끌 때 쓴다)
function MotionEditorController:_timelineTimeAt(fraction: number): number
	local span = self.TimelineSpan or self:_timelineSpan()
	local inner = (fraction - TIMELINE_PAD) / (1 - TIMELINE_PAD * 2)
	return math.clamp(inner, 0, 1) * span
end

--[[
	삼각형 눈금자의 세로 배치.

	요청: "역삼각형이 아니라 정상각형으로", "그 삼각형의 중앙을 관통하는 선",
	      "삼각형의 밑변, 그리고 A 점(제일 위에 있는 꼭짓점)을 지나는 선들도".

	     ─────────────  ← APEX 레일 (A점을 지나는 가로선)
	          ▲          ← 정삼각형. 중앙을 세로선이 관통한다
	     ─────────────  ← BASE 레일 (밑변을 지나는 가로선)
]]
-- 하단 독이 내주는 세로 공간이 60px 남짓이다. 그보다 크게 잡으면 밑변 레일과
-- 프레임 번호가 잘려 보이지 않는다(실제로 74px로 잡았다가 아래가 통째로 잘렸다).
local TIMELINE_APEX_Y = 15
local TIMELINE_BASE_Y = 33
local TIMELINE_MARK_WIDTH = 18

--[[
	삼각형과 간격 라벨을 현재 시간에 맞춰 다시 놓는다.

	끄는 중에는 통째로 다시 만들지 않고 이것만 부른다 — 다시 만들면 잡고 있던 버튼이
	사라져 드래그가 끊긴다.
]]
function MotionEditorController:_repositionTimelineMarkers()
	for index, marker in self.TimelineMarkers or {} do
		local frame = self.Motion.Frames[index]
		if frame then
			local fraction = self:_timelineFraction(frame.Time)
			marker.Triangle.Position = UDim2.new(fraction, -TIMELINE_MARK_WIDTH / 2, 0, TIMELINE_APEX_Y)
			-- 삼각형 중앙을 위아래로 관통하는 선. 꼭짓점 위·밑변 아래로 조금 더 뻗어
			-- '관통'이 눈에 보이게 한다.
			marker.Through.Position = UDim2.new(fraction, 0, 0, TIMELINE_APEX_Y - 5)
			marker.Index.Position = UDim2.new(fraction, -16, 0, TIMELINE_BASE_Y + 2)
		end
	end
	for index, gap in self.TimelineGaps or {} do
		local a = self.Motion.Frames[index]
		local b = self.Motion.Frames[index + 1]
		if a and b then
			local middle = (self:_timelineFraction(a.Time) + self:_timelineFraction(b.Time)) / 2
			gap.Position = UDim2.new(middle, -26, 0, 0)
			-- 사양의 핵심 수치는 '이 프레임이 몇 초냐'가 아니라 '앞 프레임과 얼마나 떨어졌냐'다.
			gap.Text = string.format("%.2f", b.Time - a.Time)
		end
	end
end

function MotionEditorController:_refreshTimeline()
	for _, child in self.Timeline:GetChildren() do
		if not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	self.TimelineSpan = self:_timelineSpan()
	self.TimelineMarkers = {}
	self.TimelineGaps = {}

	-- 두 가로 레일: 꼭짓점(A)을 지나는 선과 밑변을 지나는 선.
	for _, rail in
		{
			{ Name = "ApexRail", Y = TIMELINE_APEX_Y, Color = THEME.WoodLight, Transparency = 0.35 },
			{ Name = "BaseRail", Y = TIMELINE_BASE_Y, Color = THEME.WoodLight, Transparency = 0 },
		}
	do
		local line = Instance.new("Frame")
		line.Name = rail.Name
		line.Size = UDim2.new(1 - TIMELINE_PAD * 2, 0, 0, 1)
		line.Position = UDim2.new(TIMELINE_PAD, 0, 0, rail.Y)
		line.BackgroundColor3 = rail.Color
		line.BackgroundTransparency = rail.Transparency
		line.BorderSizePixel = 0
		line.Parent = self.Timeline
	end

	for index in self.Motion.Frames do
		local hasHit = false
		local hasEvent = false
		for _, hit in self.Motion.Hits do
			if hit.Frame == index then
				hasHit = true
				break
			end
		end
		for _, kind in { "Effects", "Projectiles", "Teleports" } do
			for _, event in self:_eventBucket(kind) do
				if event.Frame == index then
					hasEvent = true
					break
				end
			end
		end

		local color = THEME.Muted
		if index == self.SelectedFrame then
			color = THEME.Green
		elseif hasHit then
			color = THEME.Red
		elseif hasEvent then
			color = THEME.Cyan
		end

		-- 삼각형 중앙을 관통하는 세로선. 삼각형보다 먼저 만들어 뒤에 깔리게 한다.
		local through = Instance.new("Frame")
		through.Name = "FrameThrough" .. index
		through.Size = UDim2.fromOffset(1, TIMELINE_BASE_Y - TIMELINE_APEX_Y + 10)
		through.BackgroundColor3 = color
		through.BackgroundTransparency = index == self.SelectedFrame and 0.1 or 0.55
		through.BorderSizePixel = 0
		through.ZIndex = 2
		through.Parent = self.Timeline

		local triangle = Instance.new("TextButton")
		triangle.Name = "FrameMarker" .. index
		triangle.Size = UDim2.fromOffset(TIMELINE_MARK_WIDTH, TIMELINE_BASE_Y - TIMELINE_APEX_Y)
		triangle.BackgroundTransparency = 1
		-- 요청: 역삼각형(▼) → 정삼각형(▲). 밑변이 아래 레일에 얹힌다.
		triangle.Text = "▲"
		triangle.TextColor3 = color
		-- 요청: 선택 시 색만 바뀌고 **크기는 그대로**. 크기가 변하면 삼각형 꼭짓점이
		-- 위아래로 흔들려 눈금자 위 위치가 달라 보인다.
		triangle.TextSize = 16
		triangle.Font = Enum.Font.GothamBold
		triangle.AutoButtonColor = false
		triangle.ZIndex = 3
		triangle.Parent = self.Timeline

		local label = Instance.new("TextLabel")
		label.Name = "FrameIndex" .. index
		label.Size = UDim2.fromOffset(32, 14)
		label.BackgroundTransparency = 1
		label.Text = string.format("%d%s%s", index, hasHit and " H" or "", hasEvent and " E" or "")
		label.TextColor3 = color
		label.Font = Enum.Font.RobotoMono
		label.TextSize = 10
		label.Parent = self.Timeline

		self.TimelineMarkers[index] = { Triangle = triangle, Index = label, Through = through }

		triangle.InputBegan:Connect(function(input)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			-- 1번 프레임은 모션의 시작점이라 고정한다. 간격을 재는 기준이 흔들리면 안 된다.
			if index > 1 then
				self:_pushUndo()
				self.TimelineDrag = index
			end
			self:_selectFrame(index)
		end)

		if index < #self.Motion.Frames then
			local gap = Instance.new("TextLabel")
			gap.Name = "FrameGap" .. index
			gap.Size = UDim2.fromOffset(52, 14)
			gap.BackgroundTransparency = 1
			gap.TextColor3 = THEME.Muted
			gap.Font = Enum.Font.RobotoMono
			gap.TextSize = 10
			gap.Parent = self.Timeline
			self.TimelineGaps[index] = gap
		end
	end

	self:_repositionTimelineMarkers()
end

function MotionEditorController:_setFrameOverviewHeight(value: number)
	self.FrameOverviewHeight = math.clamp(math.floor(value + 0.5), 96, 420)
	if self.FrameOverview then
		self.FrameOverview.Size = UDim2.new(1, -12, 0, self.FrameOverviewHeight)
	end
	if self.FrameOverviewResize then
		self.FrameOverviewResize.Size = UDim2.new(1, -12, 0, 12)
	end
end

function MotionEditorController:_refreshFrameOverview()
	self:_setFrameOverviewHeight(self.FrameOverviewHeight)
	self.FrameOverviewSizeLabel.Text = tostring(self.FrameOverviewSize)
	if not self.FrameOverviewOpen then
		for _, child in self.FrameOverview:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		return
	end
	for _, child in self.FrameOverview:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local size = self.FrameOverviewSize
	for index, frame in self.Motion.Frames do
		local card = Instance.new("TextButton")
		card.Name = "FrameCard" .. index
		card.Size = UDim2.fromOffset(size, size + 22)
		card.BackgroundColor3 = index == self.SelectedFrame and THEME.GreenDark or THEME.Panel
		card.BorderSizePixel = 0
		card.Text = ""
		card.LayoutOrder = index
		card.Parent = self.FrameOverview
		local hasHit = false
		for _, hit in self.Motion.Hits do
			if hit.Frame == index then
				hasHit = true
				break
			end
		end
		addStroke(card, index == self.SelectedFrame and THEME.Green or hasHit and THEME.Red or THEME.WoodLight, 2)
		local thumbnail = Instance.new("ViewportFrame")
		thumbnail.Size = UDim2.new(1, -6, 1, -27)
		thumbnail.Position = UDim2.fromOffset(3, 3)
		thumbnail.BackgroundColor3 = Color3.fromRGB(8, 7, 6)
		thumbnail.BorderSizePixel = 0
		thumbnail.Ambient = Color3.fromRGB(180, 170, 155)
		thumbnail.LightColor = Color3.fromRGB(255, 230, 175)
		thumbnail.Parent = card
		local world = Instance.new("WorldModel")
		world.Parent = thumbnail
		local rig = self.PreviewRig:Clone()
		rig.Name = "FramePose"
		for _, item in rig:GetDescendants() do
			if item:IsA("BasePart") then
				item.CanCollide = false
				item.Anchored = item.Name == "HumanoidRootPart"
			elseif item:IsA("Script") or item:IsA("LocalScript") then
				item:Destroy()
			end
		end
		rig:PivotTo(CFrame.new())
		rig.Parent = world
		for _, jointName in JOINTS do
			local pose = frame.Joints[jointName] or vector()
			local offset = (frame.JointOffsets and frame.JointOffsets[jointName]) or vector()
			for _, item in rig:GetDescendants() do
				if item:IsA("Motor6D") and item.Name == jointName then
					item.Transform = centeredJointTransform(
						item,
						offset,
						pose,
						frame.JointRotations and frame.JointRotations[jointName]
					)
					break
				end
			end
		end
		local root = rig:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local offset = frame.RootOffset or vector()
			root.CFrame = CFrame.new(offset.X, offset.Y, offset.Z)
		end
		local weapon = frame.Weapon or defaultWeapon()
		local thumbnailWeapon = rig:FindFirstChild("MotionWeapon", true)
		if thumbnailWeapon and thumbnailWeapon:IsA("BasePart") then
			self:_syncWeaponPart(thumbnailWeapon, weapon, true)
		end
		local thumbnailDual = rig:FindFirstChild("MotionDualWeapon", true)
		if thumbnailDual and thumbnailDual:IsA("BasePart") then
			self:_syncWeaponPart(thumbnailDual, frame.DualWeapon or defaultWeapon(), self.Motion.DualWield)
		end
		local mainMotor = rig:FindFirstChild("MotionWeaponMotor", true)
		local dualMotor = rig:FindFirstChild("MotionDualWeaponMotor", true)
		local rightArm = rig:FindFirstChild("Right Arm")
		local leftArm = rig:FindFirstChild("Left Arm")
		if
			mainMotor
			and mainMotor:IsA("Motor6D")
			and rightArm
			and rightArm:IsA("BasePart")
			and leftArm
			and leftArm:IsA("BasePart")
		then
			mainMotor.Part0 = frame.HandSwap and leftArm or rightArm
			mainMotor.Transform = CFrame.new(
				weapon.Position.X,
				weapon.Position.Y,
				weapon.Position.Z + layerDepth(frame, self.Motion.DualWield, "Weapon")
			) * CFrame.Angles(math.rad(weapon.Rotation.X), math.rad(weapon.Rotation.Y), math.rad(weapon.Rotation.Z)) * CFrame.Angles(
				weapon.FlipY and math.pi or 0,
				weapon.FlipX and math.pi or 0,
				0
			)
		end
		local dualWeapon = frame.DualWeapon or defaultWeapon()
		if
			dualMotor
			and dualMotor:IsA("Motor6D")
			and rightArm
			and rightArm:IsA("BasePart")
			and leftArm
			and leftArm:IsA("BasePart")
		then
			dualMotor.Part0 = frame.HandSwap and rightArm or leftArm
			dualMotor.Transform = CFrame.new(
				dualWeapon.Position.X,
				dualWeapon.Position.Y,
				dualWeapon.Position.Z + layerDepth(frame, self.Motion.DualWield, "DualWeapon")
			) * CFrame.Angles(
				math.rad(dualWeapon.Rotation.X),
				math.rad(dualWeapon.Rotation.Y),
				math.rad(dualWeapon.Rotation.Z)
			) * CFrame.Angles(dualWeapon.FlipY and math.pi or 0, dualWeapon.FlipX and math.pi or 0, 0)
		end
		for decorationIndex, decoration in frame.Decorations or {} do
			local parent = decoration.Attach == "Head" and rig:FindFirstChild("Head") or root
			if parent and parent:IsA("BasePart") then
				local visual = Instance.new("Part")
				visual.Name = "FrameDecoration" .. decorationIndex
				visual.Anchored = true
				visual.CanCollide = false
				visual.Size = Vector3.new(
					math.max(0.1, math.abs(decoration.Size.X or 2)),
					math.max(0.1, math.abs(decoration.Size.Y or 2)),
					0.12
				)
				visual.Transparency = 1
				visual.CFrame = parent.CFrame
					* CFrame.new(
						decoration.Offset.X,
						decoration.Offset.Y,
						decoration.Offset.Z + layerDepth(frame, self.Motion.DualWield, "Decoration:" .. decorationIndex)
					)
					* CFrame.Angles(
						math.rad(decoration.Rotation.X),
						math.rad(decoration.Rotation.Y),
						math.rad(decoration.Rotation.Z)
					)
				visual.Parent = world
				local assetId = normalizeAssetId(tostring(decoration.AssetId or ""))
				for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
					local decal = Instance.new("Decal")
					decal.Face = face
					decal.Texture = assetId
					decal.Transparency = assetId == "" and 1 or 0
					decal.Parent = visual
				end
			end
		end
		local camera = Instance.new("Camera")
		camera.FieldOfView = 48
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, 10), Vector3.new(0, 1.1, 0))
		camera.Parent = thumbnail
		thumbnail.CurrentCamera = camera
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 20)
		label.Position = UDim2.new(0, 0, 1, -20)
		label.BackgroundTransparency = 1
		label.Text = string.format("%dF · %.2fs", index, frame.Time)
		label.TextColor3 = hasHit and THEME.Red or THEME.Parchment
		label.Font = Enum.Font.RobotoMono
		label.TextSize = math.clamp(math.floor(size / 8), 9, 13)
		label.Parent = card
		card.Activated:Connect(function()
			self:_selectFrame(index)
		end)
	end
end

function MotionEditorController:_refreshHitFields()
	local hits = self:_frameHits()
	self.SelectedHit = math.clamp(self.SelectedHit, 1, math.max(1, #hits))
	self.HitCycle.Text = string.format("판정 %d / %d", #hits > 0 and self.SelectedHit or 0, #hits)
	local hit = hits[self.SelectedHit]
	self.AttackIdInput.Text = hit and hit.AttackId or ""
	self.RatioInput.Text = hit and string.format("%.2f", hit.DamageRatio) or ""
	self.HitRotationInput.Text = hit and string.format("%.1f", (hit.Hitbox.Rotation and hit.Hitbox.Rotation.Z) or 0)
		or ""
	self.HitDepthInput.Text = hit and string.format("%.2f", hit.Hitbox.Size.Z) or ""
	self:_updateHitboxPreview()
end

function MotionEditorController:_refreshWeaponFields()
	local frame = self.Motion.Frames[self.SelectedFrame]
	local weapon = frame.Weapon or defaultWeapon()
	frame.Weapon = weapon
	weapon.Size = weapon.Size or vector(0.35, 3, 0.12)
	self.WeaponAssetInput.Text = tostring(weapon.AssetId or "")
	self.WeaponRotationInput.Text = string.format("%.1f", weapon.Rotation.Z or 0)
	self.WeaponSizeXInput.Text = string.format("%.2f", weapon.Size.X or 0.35)
	self.WeaponSizeYInput.Text = string.format("%.2f", weapon.Size.Y or 3)
end

function MotionEditorController:_refreshDualFields()
	local frame = self.Motion.Frames[self.SelectedFrame]
	local weapon = frame.DualWeapon or defaultWeapon()
	if self.Motion.DualWield then
		frame.DualWeapon = weapon
	end
	weapon.Size = weapon.Size or vector(0.35, 3, 0.12)
	self.DualToggle.Text = self.Motion.DualWield and "쌍수 무기  ON" or "쌍수 무기  OFF"
	styleButton(
		self.DualToggle,
		self.Motion.DualWield and THEME.Green or Color3.fromRGB(255, 170, 80),
		self.Motion.DualWield and THEME.GreenDark or THEME.PanelAlt
	)
	self.DualAssetInput.Text = tostring(weapon.AssetId or "")
	self.DualRotationInput.Text = string.format("%.1f", weapon.Rotation.Z or 0)
	self.DualSizeXInput.Text = string.format("%.2f", weapon.Size.X or 0.35)
	self.DualSizeYInput.Text = string.format("%.2f", weapon.Size.Y or 3)
end

function MotionEditorController:_refreshAll()
	self.FrameButton.Text = string.format("프레임 %d / %d", self.SelectedFrame, #self.Motion.Frames)
	self.Motion.Duration = self.Motion.Frames[#self.Motion.Frames].Time
	self:_refreshPresetBar()
	self.FrameTimeInput.Text = string.format("%.3f", self.Motion.Frames[self.SelectedFrame].Time)
	if self.DurationInput and not self.DurationInput:IsFocused() then
		self.DurationInput.Text = string.format("%.3f", self.Motion.Duration)
	end
	self:_refreshTimeline()
	self:_refreshFrameOverview()
	self:_refreshHitFields()
	self:_refreshWeaponFields()
	self:_refreshDualFields()
	self:_refreshWeaponToggleButtons()
	self:_refreshDecorationFields()
	self:_refreshLayerList()
	self:_refreshEventFields()
	self:_refreshCombatFields()
	self:_applySelectedFrame()
	self:_applyBodyColor()
end

function MotionEditorController:_commitCombatSpecialFields()
	local combat = self:_combat()
	self:_pushUndo()
	combat.HeavyAfter = self.ActivePreset == "Heavy"
			and math.clamp(math.floor(tonumber(self.HeavyAfterInput.Text) or combat.HeavyAfter or 3), 1, 5)
		or 0
	combat.UltimateGain = self.ActivePreset ~= "Ultimate"
			and math.clamp(math.floor(tonumber(self.UltimateGainInput.Text) or combat.UltimateGain or 0), 0, 35)
		or 0
	combat.DashDistance = self.ActivePreset == "Dash"
			and math.clamp(math.floor(tonumber(self.DashDistanceInput.Text) or combat.DashDistance or 120), 0, 320)
		or 0
	self:_refreshCombatFields()
end

function MotionEditorController:_applySelectedFrame()
	local frame = self.Motion.Frames[self.SelectedFrame]
	normalizeLayerOrder(frame, self.Motion.DualWield)
	local root = self.PreviewRig:FindFirstChild("HumanoidRootPart")
	frame.RootOffset = frame.RootOffset or vector()
	if root and root:IsA("BasePart") and self.PreviewRootBase then
		root.CFrame = self.PreviewRootBase * CFrame.new(frame.RootOffset.X, frame.RootOffset.Y, frame.RootOffset.Z)
	end
	for _, jointName in JOINTS do
		local motor = self:_motor(jointName)
		local pose = frame.Joints[jointName] or vector()
		local offset = (frame.JointOffsets and frame.JointOffsets[jointName]) or vector()
		if motor then
			motor.Transform =
				centeredJointTransform(motor, offset, pose, frame.JointRotations and frame.JointRotations[jointName])
		end
	end
	local weapon = frame.Weapon or defaultWeapon()
	frame.Weapon = weapon
	local rightArm = self.PreviewRig:FindFirstChild("Right Arm")
	local leftArm = self.PreviewRig:FindFirstChild("Left Arm")
	if self.PreviewWeaponMotor and rightArm and leftArm and rightArm:IsA("BasePart") and leftArm:IsA("BasePart") then
		self.PreviewWeaponMotor.Part0 = frame.HandSwap and leftArm or rightArm
		self.PreviewWeaponMotor.C0 = CFrame.new(0, -1.25, 0)
			* CFrame.Angles(0, 0, math.rad(frame.HandSwap and 10 or -10))
	end
	if
		self.PreviewDualWeaponMotor
		and rightArm
		and leftArm
		and rightArm:IsA("BasePart")
		and leftArm:IsA("BasePart")
	then
		self.PreviewDualWeaponMotor.Part0 = frame.HandSwap and rightArm or leftArm
		self.PreviewDualWeaponMotor.C0 = CFrame.new(0, -1.25, 0)
			* CFrame.Angles(0, 0, math.rad(frame.HandSwap and -10 or 10))
	end
	if self.PreviewWeaponMotor then
		local position = weapon.Position
		local rotation = weapon.Rotation
		self.PreviewWeaponMotor.Transform = CFrame.new(
			position.X,
			position.Y,
			position.Z + layerDepth(frame, self.Motion.DualWield, "Weapon")
		) * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z)) * CFrame.Angles(
			weapon.FlipY and math.pi or 0,
			weapon.FlipX and math.pi or 0,
			0
		)
	end
	self:_syncWeaponAppearance(weapon)
	local dualWeapon = frame.DualWeapon or defaultWeapon()
	if self.PreviewDualWeaponMotor then
		self.PreviewDualWeaponMotor.Transform = CFrame.new(
			dualWeapon.Position.X,
			dualWeapon.Position.Y,
			dualWeapon.Position.Z + layerDepth(frame, self.Motion.DualWield, "DualWeapon")
		) * CFrame.Angles(
			math.rad(dualWeapon.Rotation.X),
			math.rad(dualWeapon.Rotation.Y),
			math.rad(dualWeapon.Rotation.Z)
		) * CFrame.Angles(dualWeapon.FlipY and math.pi or 0, dualWeapon.FlipX and math.pi or 0, 0)
	end
	self:_syncWeaponPart(self.PreviewDualWeapon, dualWeapon, self.Motion.DualWield)
	self:_syncDecorations(frame)
	self:_updateHitboxPreview()
	self:_updateEventPreview()
	self:_updateOnionRig()
end

function MotionEditorController:_updateHitboxPreview()
	local hit = self:_selectedHit()
	local root = self.PreviewRig:FindFirstChild("HumanoidRootPart")
	if not hit or not root or not root:IsA("BasePart") then
		self.HitboxPreview.Transparency = 1
		return
	end
	local hitbox = hit.Hitbox
	hitbox.Rotation = hitbox.Rotation or vector()
	self.HitboxPreview.Size = Vector3.new(hitbox.Size.X, hitbox.Size.Y, hitbox.Size.Z)
	self.HitboxPreview.CFrame = root.CFrame
		* CFrame.new(hitbox.Offset.X, hitbox.Offset.Y, hitbox.Offset.Z)
		* CFrame.Angles(
			math.rad(hitbox.Rotation.X or 0),
			math.rad(hitbox.Rotation.Y or 0),
			math.rad(hitbox.Rotation.Z or 0)
		)
	self.HitboxPreview.Transparency = 0.5
end

function MotionEditorController:_commitWeaponFields()
	local frame = self.Motion.Frames[self.SelectedFrame]
	frame.Weapon = frame.Weapon or defaultWeapon()
	frame.Weapon.Size = frame.Weapon.Size or vector(0.35, 3, 0.12)
	self:_pushUndo()
	frame.Weapon.Rotation.Z = math.clamp(tonumber(self.WeaponRotationInput.Text) or frame.Weapon.Rotation.Z, -180, 180)
	frame.Weapon.Size.X = math.clamp(tonumber(self.WeaponSizeXInput.Text) or frame.Weapon.Size.X, 0.1, 12)
	frame.Weapon.Size.Y = math.clamp(tonumber(self.WeaponSizeYInput.Text) or frame.Weapon.Size.Y, 0.1, 12)
	self:_applySelectedFrame()
	self:_refreshWeaponFields()
end

function MotionEditorController:_commitDualFields()
	local frame = self.Motion.Frames[self.SelectedFrame]
	frame.DualWeapon = frame.DualWeapon or defaultWeapon()
	frame.DualWeapon.Size = frame.DualWeapon.Size or vector(0.35, 3, 0.12)
	self:_pushUndo()
	self.Motion.DualWield = true
	frame.DualWeapon.Rotation.Z =
		math.clamp(tonumber(self.DualRotationInput.Text) or frame.DualWeapon.Rotation.Z, -180, 180)
	frame.DualWeapon.Size.X = math.clamp(tonumber(self.DualSizeXInput.Text) or frame.DualWeapon.Size.X, 0.1, 12)
	frame.DualWeapon.Size.Y = math.clamp(tonumber(self.DualSizeYInput.Text) or frame.DualWeapon.Size.Y, 0.1, 12)
	self:_applySelectedFrame()
	self:_refreshDualFields()
end

function MotionEditorController:_toggleWeaponFlag(key: string, flag: string)
	self:_pushUndo()
	local frame = self.Motion.Frames[self.SelectedFrame]
	frame[key] = frame[key] or defaultWeapon()
	frame[key][flag] = not frame[key][flag]
	if key == "DualWeapon" then
		self.Motion.DualWield = true
	end
	self:_applySelectedFrame()
	self:_refreshWeaponToggleButtons()
end

function MotionEditorController:_refreshWeaponToggleButtons()
	local frame = self.Motion.Frames[self.SelectedFrame]
	local main = frame.Weapon or defaultWeapon()
	local dual = frame.DualWeapon or defaultWeapon()
	local buttons = {
		{ self.MainFlipXButton, main.FlipX },
		{ self.MainFlipYButton, main.FlipY },
		{ self.DualFlipXButton, dual.FlipX },
		{ self.DualFlipYButton, dual.FlipY },
		{ self.HandSwapButton, frame.HandSwap },
	}
	for _, entry in buttons do
		styleButton(
			entry[1],
			entry[2] and THEME.Green or Color3.fromRGB(197, 108, 255),
			entry[2] and THEME.GreenDark or THEME.PanelAlt
		)
	end
end

function MotionEditorController:_commitHitFields()
	local hit = self:_selectedHit()
	if not hit then
		return
	end
	self:_pushUndo()
	hit.Hitbox.Rotation = hit.Hitbox.Rotation or vector()
	hit.Hitbox.Rotation.Z = math.clamp(tonumber(self.HitRotationInput.Text) or hit.Hitbox.Rotation.Z, -180, 180)
	hit.Hitbox.Size.Z = math.clamp(tonumber(self.HitDepthInput.Text) or hit.Hitbox.Size.Z, 0.25, 20)
	self:_updateHitboxPreview()
	self:_refreshHitFields()
end

function MotionEditorController:_insertFrame(copyCurrent: boolean)
	if #self.Motion.Frames >= MAX_MOTION_FRAMES then
		self.Status.Text = string.format("프레임은 최대 %d개입니다.", MAX_MOTION_FRAMES)
		return
	end
	local current = self.Motion.Frames[self.SelectedFrame]
	local inserted = copyCurrent and copyFrame(current)
		or {
			Time = current.Time,
			Joints = {},
			JointRotations = {},
			JointOffsets = {},
			RootOffset = vector(),
			Weapon = defaultWeapon(),
			Decorations = {},
		}
	if self.SelectedFrame < #self.Motion.Frames then
		inserted.Time = (current.Time + self.Motion.Frames[self.SelectedFrame + 1].Time) * 0.5
	else
		inserted.Time = math.min(MAX_MOTION_DURATION, current.Time + 0.2)
		if inserted.Time <= current.Time then
			self.Status.Text = string.format("최대 모션 길이 %d초에 도달했습니다.", MAX_MOTION_DURATION)
			return
		end
	end
	self:_pushUndo()
	table.insert(self.Motion.Frames, self.SelectedFrame + 1, inserted)
	for _, hit in self.Motion.Hits do
		if hit.Frame > self.SelectedFrame then
			hit.Frame += 1
		end
	end
	for _, kind in { "Effects", "Projectiles", "Teleports" } do
		for _, event in self:_eventBucket(kind) do
			local previousEndFrame = event.EndFrame or event.Frame
			if event.Frame > self.SelectedFrame then
				event.Frame += 1
			end
			if previousEndFrame > self.SelectedFrame then
				event.EndFrame = math.min(#self.Motion.Frames, previousEndFrame + 1)
			end
		end
	end
	self.SelectedFrame += 1
	self.SelectedHit = 1
	self:_refreshAll()
end

function MotionEditorController:_deleteFrame()
	if #self.Motion.Frames <= 2 then
		self.Status.Text = "모션에는 최소 2개 프레임이 필요합니다."
		return
	end
	for index = #self.Motion.Hits, 1, -1 do
		local hit = self.Motion.Hits[index]
		if hit.Frame == self.SelectedFrame then
			table.remove(self.Motion.Hits, index)
		elseif hit.Frame > self.SelectedFrame then
			hit.Frame -= 1
		end
	end
	for _, kind in { "Effects", "Projectiles", "Teleports" } do
		local bucket = self:_eventBucket(kind)
		for index = #bucket, 1, -1 do
			local event = bucket[index]
			if event.Frame == self.SelectedFrame then
				table.remove(bucket, index)
			elseif event.Frame > self.SelectedFrame then
				event.Frame -= 1
				event.EndFrame = math.max(event.Frame, (event.EndFrame or event.Frame) - 1)
			elseif (event.EndFrame or event.Frame) > self.SelectedFrame then
				event.EndFrame = math.max(event.Frame, (event.EndFrame or event.Frame) - 1)
			end
		end
	end
	table.remove(self.Motion.Frames, self.SelectedFrame)
	self.SelectedFrame = math.min(self.SelectedFrame, #self.Motion.Frames)
	self.SelectedHit = 1
	self:_refreshAll()
end

function MotionEditorController:_copyCurrentFrame()
	self.FrameClipboard = {
		Frame = copyFrame(self.Motion.Frames[self.SelectedFrame]),
		Hits = deepCopy(self:_frameHits()),
		Events = {},
	}
	for _, kind in { "Effects", "Projectiles", "Teleports" } do
		self.FrameClipboard.Events[kind] = deepCopy(self:_frameEvents(kind))
	end
	self.Status.Text = string.format(
		"  STATUS\n  프레임 %d을 복사했습니다. 다른 위치에서 붙여넣을 수 있습니다.",
		self.SelectedFrame
	)
end

function MotionEditorController:_cutCurrentFrame()
	if #self.Motion.Frames <= 2 then
		self.Status.Text = "  STATUS\n  최소 두 프레임은 남겨야 합니다."
		return
	end
	self:_copyCurrentFrame()
	self:_deleteFrame()
	self.Status.Text =
		"  STATUS\n  프레임을 잘라냈습니다. 다른 프리셋에도 붙여넣을 수 있습니다."
end

function MotionEditorController:_copyWeaponImage()
	local frame = self.Motion.Frames[self.SelectedFrame]
	self.WeaponClipboard = {
		Main = tostring(frame.Weapon and frame.Weapon.AssetId or ""),
		Dual = tostring(frame.DualWeapon and frame.DualWeapon.AssetId or ""),
	}
	self.Status.Text = "  STATUS\n  현재 프레임의 무기 이미지를 복사했습니다."
end

function MotionEditorController:_pasteWeaponImage()
	if not self.WeaponClipboard then
		self.Status.Text = "  STATUS\n  먼저 무기 이미지를 복사하세요."
		return
	end
	self:_pushUndo()
	local frame = self.Motion.Frames[self.SelectedFrame]
	frame.Weapon = frame.Weapon or defaultWeapon()
	frame.Weapon.AssetId = self.WeaponClipboard.Main
	if self.WeaponClipboard.Dual ~= "" then
		frame.DualWeapon = frame.DualWeapon or defaultWeapon()
		frame.DualWeapon.AssetId = self.WeaponClipboard.Dual
	end
	self:_refreshAll()
	self.Status.Text = "  STATUS\n  복사한 무기 이미지를 현재 프레임에 붙여넣었습니다."
end

function MotionEditorController:_pasteCurrentFrame()
	if not self.FrameClipboard then
		self.Status.Text = "  STATUS\n  먼저 복사할 프레임을 선택하세요."
		return
	end
	self:_pushUndo()
	local time = self.Motion.Frames[self.SelectedFrame].Time
	local pasted = copyFrame(self.FrameClipboard.Frame)
	pasted.Time = time
	self.Motion.Frames[self.SelectedFrame] = pasted
	for index = #self.Motion.Hits, 1, -1 do
		if self.Motion.Hits[index].Frame == self.SelectedFrame then
			table.remove(self.Motion.Hits, index)
		end
	end
	for _, hit in self.FrameClipboard.Hits do
		local copiedHit = deepCopy(hit)
		copiedHit.Frame = self.SelectedFrame
		table.insert(self.Motion.Hits, copiedHit)
	end
	for _, kind in { "Effects", "Projectiles", "Teleports" } do
		local bucket = self:_eventBucket(kind)
		for index = #bucket, 1, -1 do
			if bucket[index].Frame == self.SelectedFrame then
				table.remove(bucket, index)
			end
		end
		for _, event in self.FrameClipboard.Events[kind] do
			local copiedEvent = deepCopy(event)
			local span = math.max(0, (copiedEvent.EndFrame or copiedEvent.Frame) - copiedEvent.Frame)
			copiedEvent.Frame = self.SelectedFrame
			copiedEvent.EndFrame = math.min(#self.Motion.Frames, self.SelectedFrame + span)
			table.insert(bucket, copiedEvent)
		end
	end
	self:_refreshAll()
	self.Status.Text = string.format(
		"  STATUS\n  프레임 %d에 복사한 포즈와 무기를 붙여넣었습니다.",
		self.SelectedFrame
	)
end

function MotionEditorController:_addHit()
	self:_pushUndo()
	local hits = self:_frameHits()
	local attackIndex = #self.Motion.Hits + 1
	table.insert(self.Motion.Hits, {
		Frame = self.SelectedFrame,
		AttackId = "Attack" .. attackIndex,
		DamageRatio = 0.25,
		Hitbox = { Offset = vector(0, 0, -3), Size = vector(3, 3, 3), Rotation = vector() },
	})
	self.SelectedHit = #hits + 1
	self:_refreshAll()
end

function MotionEditorController:_deleteHit()
	local wanted = self:_selectedHit()
	if not wanted then
		return
	end
	self:_pushUndo()
	for index, hit in self.Motion.Hits do
		if hit == wanted then
			table.remove(self.Motion.Hits, index)
			break
		end
	end
	self.SelectedHit = 1
	self:_refreshAll()
end

function MotionEditorController:_duplicateHit()
	local hit = self:_selectedHit()
	if not hit then
		self.Status.Text = "  STATUS\n  복제할 판정을 먼저 선택하세요."
		return
	end
	self:_pushUndo()
	local copied = deepCopy(hit)
	copied.Frame = self.SelectedFrame
	copied.Hitbox.Offset.X = math.clamp((copied.Hitbox.Offset.X or 0) + 0.5, -20, 20)
	table.insert(self.Motion.Hits, copied)
	self.SelectedHit = #self:_frameHits()
	self:_refreshAll()
	self.Status.Text = "  STATUS\n  선택 판정을 복제했습니다."
end

function MotionEditorController:_adjustHit(kind: string, axis: string, amount: number)
	local hit = self:_selectedHit()
	if not hit then
		self.Status.Text = "먼저 현재 프레임에 판정을 추가하세요."
		return
	end
	self:_pushUndo()
	local values = hit.Hitbox[kind]
	local minimum = kind == "Size" and 0.25 or -20
	local maximum = 20
	values[axis] = math.clamp((values[axis] or 0) + amount, minimum, maximum)
	self:_updateHitboxPreview()
end

return MotionEditorController
