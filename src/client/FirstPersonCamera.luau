--!strict
-- 필드 1인칭 고정 + ALT 로 커서 풀기 + 회전 관성. PC(마우스 있는 기기)만.
-- 전투·컷신 등이 카메라를 Scriptable 로 잡는 동안(CameraType ~= Custom)은 손대지 않고, 끝나 Custom 으로 돌아오면 다시 이어받는다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FirstPersonMath = require(game:GetService("ReplicatedStorage").Shared.FirstPersonMath)

local ALT_MODE: "hold" | "toggle" = "hold"
local HALF_LIFE = 0.07 -- 초. 작을수록 즉각적
local SENSITIVITY = 0.003 -- 마우스 1픽셀당 라디안
local PITCH_LIMIT = math.rad(80)

local FirstPersonCamera = {}

function FirstPersonCamera.Start()
	-- 모바일·패드 전용 기기는 기본 동작 유지
	if not UserInputService.MouseEnabled or UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return
	end
	local player = Players.LocalPlayer
	local free = false
	local active = false
	local targetYaw, targetPitch, yaw, pitch = 0, 0, 0, 0

	local function isAlt(input: InputObject)
		return input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt
	end
	UserInputService.InputBegan:Connect(function(input)
		if isAlt(input) and not UserInputService:GetFocusedTextBox() then
			free = if ALT_MODE == "toggle" then not free else true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if ALT_MODE == "hold" and isAlt(input) then
			free = false
		end
	end)

	RunService:BindToRenderStep("FirstPersonCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera or camera.CameraType ~= Enum.CameraType.Custom then
			active, free = false, false
			return
		end
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		local pitchNow, yawNow = camera.CFrame:ToOrientation()
		if not active then -- 막 이어받음: 지금 보는 각에서 시작
			active = true
			targetYaw, targetPitch, yaw, pitch = yawNow, pitchNow, yawNow, pitchNow
			UserInputService:GetMouseDelta() -- 쌓인 이동량 버림
		end
		if free or UserInputService:GetFocusedTextBox() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			UserInputService:GetMouseDelta() -- 풀린 동안 이동량은 회전에 쓰지 않는다
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
			local d = UserInputService:GetMouseDelta()
			targetYaw -= d.X * SENSITIVITY
			targetPitch = FirstPersonMath.ClampPitch(targetPitch - d.Y * SENSITIVITY, PITCH_LIMIT)
		end
		yaw = FirstPersonMath.Smooth(yaw, targetYaw, dt, HALF_LIFE)
		pitch = FirstPersonMath.Smooth(pitch, targetPitch, dt, HALF_LIFE)
		camera.CFrame = CFrame.new(camera.CFrame.Position) * CFrame.fromOrientation(pitch, yaw, 0)

		-- 몸은 카메라 yaw 를 따라감(탈것에 앉은 동안은 건드리지 않음)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if humanoid and root and not humanoid.Sit then
			humanoid.AutoRotate = false
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
		end
	end)
end

return FirstPersonCamera
