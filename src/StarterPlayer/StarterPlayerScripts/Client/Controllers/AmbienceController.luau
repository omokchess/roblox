--!strict
-- 구역별 분위기: 대기/색보정/물빛 트윈, 반딧불·물안개 파티클, 구역 진입 타이틀, 환경음.
-- Terrain.WaterColor 는 클라이언트에서 바꾸면 로컬에만 적용 → 늪은 탁한 녹색, 바다는 청록.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.World.WorldConfig)
local WorldData = require(Shared.World.WorldData)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local AmbienceController = {}

local current = ""
local zones: { WorldData.Zone } = {}
local emitterPart: Part
local fireflies: ParticleEmitter
local mist: ParticleEmitter
local ambientSound: Sound
local titleGui: ScreenGui
local titleLabel: TextLabel
local subLabel: TextLabel

local TWEEN = TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local function makeEmitters()
	emitterPart = Instance.new("Part")
	emitterPart.Name = "AmbienceEmitter"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(90, 1, 90)
	emitterPart.Parent = camera

	fireflies = Instance.new("ParticleEmitter")
	fireflies.Name = "Fireflies"
	fireflies.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fireflies.LightEmission = 1
	fireflies.LightInfluence = 0
	fireflies.Rate = 0
	fireflies.Lifetime = NumberRange.new(4, 8)
	fireflies.Speed = NumberRange.new(0.3, 1.2)
	fireflies.SpreadAngle = Vector2.new(180, 180)
	fireflies.Acceleration = Vector3.new(0, 0.15, 0)
	fireflies.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 0) })
	fireflies.Color = ColorSequence.new(Color3.fromRGB(220, 255, 120), Color3.fromRGB(160, 255, 170))
	fireflies.EmissionDirection = Enum.NormalId.Top
	fireflies.Parent = emitterPart

	mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.LightInfluence = 1
	mist.Rate = 0
	mist.Lifetime = NumberRange.new(8, 12)
	mist.Speed = NumberRange.new(0.5, 1.5)
	mist.SpreadAngle = Vector2.new(180, 10)
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-8, 8)
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 16) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(0.7, 0.85), NumberSequenceKeypoint.new(1, 1) })
	mist.Color = ColorSequence.new(Color3.fromRGB(200, 214, 196))
	mist.Parent = emitterPart

	ambientSound = Instance.new("Sound")
	ambientSound.Name = "ZoneAmbient"
	ambientSound.Looped = true
	ambientSound.Volume = 0
	ambientSound.Parent = camera
end

local function makeTitle()
	titleGui = UIKit.ScreenGui("ZoneTitle", 3)
	titleLabel = UIKit.Label(titleGui, "", UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 0.22, 0), 44, UIKit.FontTitle)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.TextTransparency = 1
	subLabel = UIKit.Label(titleGui, "", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0.22, 58), 18, UIKit.FontRegular, UIKit.Colors.SubText)
	subLabel.TextXAlignment = Enum.TextXAlignment.Center
	subLabel.TextTransparency = 1
end

local SUBTITLES: { [string]: string } = {
	Swamp = "안개가 걷히지 않는 늪의 섬",
	Village = "수상 가옥들이 모인 늪 마을",
	Shrine = "늪의 군주가 잠든 고대 사당",
	Harbor = "모든 항로가 시작되는 항구",
	Lighthouse = "바다를 지키는 등대",
	Sea = "섬과 섬 사이의 바다",
}

local function showTitle(name: string)
	local preset = WorldConfig.Zones[name]
	if not preset or name == "Sea" then
		return
	end
	titleLabel.Text = preset.Label
	subLabel.Text = SUBTITLES[name] or ""
	for _, l in { titleLabel, subLabel } do
		l.TextTransparency = 1
		TweenService:Create(l, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
	end
	task.delay(3.2, function()
		if titleLabel.Text == preset.Label then
			for _, l in { titleLabel, subLabel } do
				TweenService:Create(l, TweenInfo.new(1.6), { TextTransparency = 1 }):Play()
			end
		end
	end)
end

local function apply(name: string)
	local preset = WorldConfig.Zones[name] or WorldConfig.Zones.Sea
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		TweenService:Create(atmo, TWEEN, preset.Atmosphere :: any):Play()
	end
	local cc = Lighting:FindFirstChild("SwampColor")
	if cc and cc:IsA("ColorCorrectionEffect") then
		TweenService:Create(cc, TWEEN, preset.Correction :: any):Play()
	end
	TweenService:Create(workspace.Terrain, TWEEN, { WaterColor = preset.WaterColor, WaterTransparency = preset.WaterTransparency }):Play()
	if preset.AmbientSound ~= "" then
		ambientSound.SoundId = preset.AmbientSound
		ambientSound:Play()
		TweenService:Create(ambientSound, TWEEN, { Volume = 0.5 }):Play()
	else
		TweenService:Create(ambientSound, TWEEN, { Volume = 0 }):Play()
	end
	showTitle(name)
end

local function isNight(): boolean
	local c = Lighting.ClockTime
	return c > 18.2 or c < 6.2
end

local function focusPosition(): Vector3
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if hrp then hrp.Position else camera.Focus.Position
end

function AmbienceController.Start()
	zones = WorldData.Zones()
	makeEmitters()
	makeTitle()
	local acc = 1
	RunService.Heartbeat:Connect(function(dt)
		local pos = focusPosition()
		emitterPart.CFrame = CFrame.new(pos.X, math.max(pos.Y - 2, 0.6), pos.Z)
		acc += dt
		if acc < 0.4 then
			return
		end
		acc = 0
		local zone = WorldData.ZoneAt(pos, zones)
		if zone ~= current then
			current = zone
			apply(zone)
		end
		local preset = WorldConfig.Zones[zone] or WorldConfig.Zones.Sea
		fireflies.Rate = if preset.Fireflies then (if isNight() then 14 else 2) else 0
		mist.Rate = if preset.Mist and pos.Y < 30 then 3 else 0
	end)
end

function AmbienceController.CurrentZone(): string
	return current
end

return AmbienceController
