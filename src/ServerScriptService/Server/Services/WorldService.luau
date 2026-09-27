--!strict
-- 월드 서비스: 서버 시작 시 월드가 없으면 생성, 낮/밤 순환.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.World.WorldConfig)
local WorldBuilder = require(ServerStorage:WaitForChild("SwampTools"):WaitForChild("WorldBuilder"))

local WorldService = {}

local ready = false

function WorldService.IsReady(): boolean
	return ready
end

local function buildIfNeeded()
	if not WorldConfig.BuildOnServerStart then
		ready = true
		return
	end
	if WorldBuilder.IsBuilt() then
		print("[SwampWorld] 저장된 월드 사용 (재생성 생략)")
		WorldBuilder.ApplyLighting()
		ready = true
		return
	end
	-- 지형/배치가 끝날 때까지 캐릭터 스폰 보류
	local autoLoad = Players.CharacterAutoLoads
	Players.CharacterAutoLoads = false
	local ok, err = pcall(function()
		WorldBuilder.Build({ Clear = false })
	end)
	if not ok then
		warn("[SwampWorld] 월드 생성 실패:", err)
	end
	ready = true
	Players.CharacterAutoLoads = autoLoad
	for _, p in Players:GetPlayers() do
		if not p.Character then
			task.spawn(function()
				p:LoadCharacter()
			end)
		end
	end
end

local function dayNight()
	local cfg = WorldConfig.DayNight
	if not cfg.Enabled then
		return
	end
	Lighting.ClockTime = cfg.StartClock
	local hoursPerSecond = 24 / (cfg.DayLengthMinutes * 60)
	RunService.Heartbeat:Connect(function(dt: number)
		Lighting.ClockTime = (Lighting.ClockTime + dt * hoursPerSecond) % 24
	end)
end

function WorldService.Start()
	workspace:SetAttribute("SwampWorldReady", false)
	buildIfNeeded()
	workspace:SetAttribute("SwampWorldReady", true)
	dayNight()
end

return WorldService
