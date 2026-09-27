--!strict
-- 카메라 흔들림 & FOV 펀치 (기본 카메라 위에 덧씌움)

local RunService = game:GetService("RunService")

local CameraController = {}

local trauma = 0
local fovKick = 0
local baseFov = 70
local seed = math.random() * 1000

function CameraController.Shake(amount: number)
	trauma = math.clamp(trauma + amount, 0, 1.5)
end

function CameraController.Punch(fov: number)
	fovKick = math.max(fovKick, fov)
end

local lastShake: CFrame? = nil

function CameraController.Start()
	local cam = workspace.CurrentCamera
	baseFov = cam.FieldOfView
	-- 기본 카메라는 현재 CFrame 을 기준으로 다음 프레임을 계산하므로,
	-- 카메라 갱신 직전에 지난 프레임의 흔들림을 되돌려 누적(표류)을 막는다.
	RunService:BindToRenderStep("SwampCameraUnshake", Enum.RenderPriority.Camera.Value - 1, function()
		if lastShake then
			local c = workspace.CurrentCamera
			c.CFrame = c.CFrame * lastShake:Inverse()
			lastShake = nil
		end
	end)
	RunService:BindToRenderStep("SwampCameraFX", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		cam = workspace.CurrentCamera
		if trauma > 0.001 then
			local s = trauma * trauma
			local t = os.clock() * 28
			local rx = math.noise(seed, t) * 0.9 * s
			local ry = math.noise(seed + 10, t) * 0.9 * s
			local rz = math.noise(seed + 20, t) * 0.6 * s
			local shake = CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
			cam.CFrame = cam.CFrame * shake
			lastShake = shake
			trauma = math.max(0, trauma - dt * 1.8)
		end
		if fovKick > 0.01 then
			cam.FieldOfView = baseFov + fovKick
			fovKick = math.max(0, fovKick - dt * 30)
		elseif math.abs(cam.FieldOfView - baseFov) > 0.01 then
			cam.FieldOfView = baseFov
		end
	end)
end

return CameraController
