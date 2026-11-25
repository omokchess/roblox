--!strict
--[[
	MastLiftService — 계류탑 승강기(1층 ↔ 승강장). 계단도 있으니 편의용.
	Studio 에서 tools/Snow_Town3.luau 가 지은 모델(태그 SnowMastLift):
	  Sn3_MastLift   승강기 칸(1층 자리에 놓여 있음)
	  Call_Bottom / Call_Top   1층·승강장 문 옆 ProximityPrompt 자리(고정, 보이지 않는 파트)
	  속성 Rise = 올라가는 높이(스터드, 48)
	탄 사람은 칸 안 서 있기 → 칸을 비고정 한 몸으로 풀어 서버가 끄므로 같이 실려 간다(RigidMover).
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local RigidMover = require(script.Parent.RigidMover)

local MastLiftService = {}

local SPEED = 9 -- 스터드/초

local function setup(holder: Model)
	local cab = holder:FindFirstChild("Sn3_MastLift")
	local callBottom = holder:FindFirstChild("Call_Bottom")
	local callTop = holder:FindFirstChild("Call_Top")
	if
		not (
			cab
			and cab:IsA("Model")
			and callBottom
			and callBottom:IsA("BasePart")
			and callTop
			and callTop:IsA("BasePart")
		)
	then
		warn("MastLiftService: 승강기 칸 또는 Call_Bottom/Call_Top 없음")
		return
	end
	local rise = (holder:GetAttribute("Rise") :: number?) or 48

	local root = Instance.new("Part")
	root.Name = "LiftRoot"
	root.Size = Vector3.one
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.CFrame = cab:GetPivot()
	root.Parent = cab

	local inside = Instance.new("Part") -- 칸 안 버튼 자리
	inside.Name = "CabPad"
	inside.Size = Vector3.one
	inside.Transparency = 1
	inside.CanCollide = false
	inside.CanQuery = false
	inside.CanTouch = false
	inside.Massless = true
	inside.CFrame = root.CFrame * CFrame.new(0, 3, 0)
	inside.Parent = cab

	local parts: { BasePart } = {}
	for _, d in cab:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local mover = RigidMover.new(root, parts)
	local bottomCF = root.CFrame
	local topCF = bottomCF + Vector3.new(0, rise, 0)

	local function newPrompt(parent: Instance): ProximityPrompt
		local p = Instance.new("ProximityPrompt")
		p.ObjectText = "승강기"
		p.HoldDuration = 0.2
		p.MaxActivationDistance = 10
		p.RequiresLineOfSight = false
		p.Parent = parent
		return p
	end
	local pCab, pBottom, pTop = newPrompt(inside), newPrompt(callBottom), newPrompt(callTop)

	local at = "bottom"
	local moving = false
	local function refresh()
		pCab.ActionText = if at == "bottom" then "올라가기" else "내려가기"
		pBottom.ActionText = if at == "bottom" then "올라가기" else "승강기 부르기"
		pTop.ActionText = if at == "top" then "내려가기" else "승강기 부르기"
		for _, p in { pCab, pBottom, pTop } do
			p.Enabled = not moving
		end
	end
	refresh()

	local function go(target: string)
		if moving or target == at then
			return
		end
		moving = true
		refresh()
		local from, to = if target == "top" then bottomCF else topCF, if target == "top" then topCF else bottomCF
		local duration = rise / SPEED
		mover:Begin()
		local started = os.clock()
		while true do
			local f = math.min((os.clock() - started) / duration, 1)
			local e = f * f * (3 - 2 * f)
			mover:Move(from:Lerp(to, e))
			if f >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		mover:End(to)
		at = target
		moving = false
		refresh()
	end

	local function other(): string
		return if at == "bottom" then "top" else "bottom"
	end
	pCab.Triggered:Connect(function()
		task.spawn(go, other())
	end)
	pBottom.Triggered:Connect(function()
		task.spawn(go, if at == "bottom" then "top" else "bottom")
	end)
	pTop.Triggered:Connect(function()
		task.spawn(go, if at == "top" then "bottom" else "top")
	end)
end

function MastLiftService.Start()
	local function hook(holder: Instance)
		if holder:IsA("Model") then
			task.defer(setup, holder)
		end
	end
	for _, holder in CollectionService:GetTagged("SnowMastLift") do
		hook(holder)
	end
	CollectionService:GetInstanceAddedSignal("SnowMastLift"):Connect(hook)
end

return MastLiftService
