--!strict
-- 월드 연출 (클라이언트 로컬): 부표 흔들림, 등대 회전 빔, 등불 깜빡임 & 낮/밤 밝기, 알림 토스트.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Util.Net)
local UIKit = require(script.Parent.UIKit)

local WorldFX = {}

local buoys: { [Model]: { base: CFrame, phase: number } } = {}
local beacons: { [BasePart]: CFrame } = {}
local toastGui: ScreenGui

local function track(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

local function nightFactor(): number
	local c = Lighting.ClockTime
	-- 18~19시 점등, 5~6시 소등
	if c >= 19 or c <= 5 then
		return 1
	elseif c > 18 then
		return c - 18
	elseif c < 6 then
		return 6 - c
	end
	return 0
end

function WorldFX.Toast(text: string, color: Color3?)
	local frame = UIKit.Panel(toastGui, UDim2.fromOffset(0, 40), UDim2.new(0.5, 0, 0.72, 0), Vector2.new(0.5, 0.5))
	frame.AutomaticSize = Enum.AutomaticSize.X
	local label = UIKit.Label(frame, text, UDim2.fromOffset(0, 40), UDim2.fromOffset(0, 0), 18, nil, color)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextXAlignment = Enum.TextXAlignment.Center
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = frame
	frame.BackgroundTransparency = 1
	TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 0.2 }):Play()
	task.delay(2.6, function()
		TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.wait(0.55)
		frame:Destroy()
	end)
end

function WorldFX.Start()
	toastGui = UIKit.ScreenGui("Toasts", 20)
	track("SwampBuoy", function(inst)
		if inst:IsA("Model") then
			buoys[inst] = { base = inst:GetPivot(), phase = math.random() * 10 }
		end
	end, function(inst)
		buoys[inst :: any] = nil
	end)
	track("SwampBeacon", function(inst)
		if inst:IsA("BasePart") then
			beacons[inst] = inst.CFrame
		end
	end, function(inst)
		beacons[inst :: any] = nil
	end)

	RunService.PreRender:Connect(function()
		local t = os.clock()
		for m, info in buoys do
			local bob = CFrame.new(0, 0.35 * math.sin(t * 1.3 + info.phase), 0)
				* CFrame.Angles(math.rad(5 * math.sin(t * 0.9 + info.phase)), 0, math.rad(6 * math.sin(t * 1.1 + info.phase * 1.7)))
			m:PivotTo(info.base * bob)
		end
		for p, base in beacons do
			p.CFrame = base * CFrame.Angles(0, t * math.rad(25), 0)
		end
	end)

	-- 등불: 저녁에 켜지고 불빛이 살짝 일렁임 (15Hz)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 15 then
			return
		end
		acc = 0
		local n = nightFactor()
		local t = os.clock()
		for _, light in CollectionService:GetTagged("SwampLamp") do
			if light:IsA("Light") then
				local base = (light:GetAttribute("BaseBrightness") :: number?) or 1
				local seed: number = (light:GetAttribute("Seed") :: number?) or math.random() * 100
				light:SetAttribute("Seed", seed)
				local flick = 1 + 0.08 * math.sin(t * 11 + seed) + 0.05 * math.sin(t * 23.7 + seed * 2)
				light.Brightness = base * (0.25 + 0.75 * n) * flick
			end
		end
	end)

	Net.Event("WorldEvent").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Toast" and type(data) == "table" then
			local color = (UIKit.Colors :: any)[data.Color or ""] :: Color3?
			WorldFX.Toast(tostring(data.Text), color)
		end
	end)
end

return WorldFX
