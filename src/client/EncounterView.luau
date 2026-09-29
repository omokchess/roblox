--!strict
--[[
	EncounterView — 필드 만남 몹을 **그린다**. (2026-09-28)

	서버(`BattleService`)는 workspace.BattleEncounters 에 보이지 않는 자리 표시만 둔다(속성 Owner·EnemyId·Count).
	여기서 전투와 같은 슬라임 틀(Combat/Slime)로 모양을 세우고 대기 모션으로 통통 튀게 한다.
	닿았는지는 서버가 거리로 판정한다 — 여기서는 보여 주기만 한다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatAnimator = require(script.Parent.Combat.CombatAnimator)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local Slime = require(script.Parent.Combat.Slime)
local SlimeMotions = require(ReplicatedStorage.Shared.Combat.Motions.Slime)

local EncounterView = {}

type Entry = { Model: Model, Animator: any, Rig: any, Marker: BasePart }

function EncounterView.Start()
	local folder = workspace:WaitForChild("BattleEncounters", 60)
	if not folder then
		return
	end
	local holder = Instance.new("Folder")
	holder.Name = "EncounterViews"
	holder.Parent = workspace
	local entries: { [Instance]: Entry } = {}

	local function add(marker: Instance)
		if not marker:IsA("BasePart") or entries[marker] then
			return
		end
		local enemy = EnemyDefinitions.Get(marker:GetAttribute("EnemyId") or "Slime")
		local model = Slime.Build("Encounter_" .. enemy.Id, enemy.Color)
		-- 자리 표시는 몸통 가운데(높이 3), 슬라임 기준점은 바닥 가운데
		local home = marker.CFrame * CFrame.new(0, -marker.Size.Y / 2, 0)
		model:PivotTo(home)
		model.Parent = holder
		local rig = Slime.new(model)
		local animator = CombatAnimator.new(rig)
		animator:SetBase(SlimeMotions.Idle)
		animator.baseT = math.random() * 1.7

		local count = marker:GetAttribute("Count") or 1
		local sign = Instance.new("BillboardGui")
		sign.Size = UDim2.fromOffset(200, 40)
		sign.StudsOffset = Vector3.new(0, 4.6, 0)
		sign.AlwaysOnTop = true
		sign.MaxDistance = 90
		sign.Parent = model.PrimaryPart
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = string.format("%s ×%d\n<font size=\"12\" color=\"rgb(200,230,190)\">닿으면 전투</font>", enemy.Name, count)
		label.RichText = true
		label.TextColor3 = Color3.fromRGB(230, 255, 220)
		label.TextStrokeTransparency = 0.35
		label.Font = Enum.Font.GothamBold
		label.TextSize = 15
		label.Parent = sign
		entries[marker] = { Model = model, Animator = animator, Rig = rig, Marker = marker }
	end

	local function remove(marker: Instance)
		local entry = entries[marker]
		if entry then
			entries[marker] = nil
			entry.Model:Destroy()
		end
	end

	for _, marker in folder:GetChildren() do
		add(marker)
	end
	folder.ChildAdded:Connect(add)
	folder.ChildRemoved:Connect(remove)

	RunService.RenderStepped:Connect(function(dt)
		for _, entry in entries do
			entry.Animator:Update(dt)
		end
	end)
end

return EncounterView
