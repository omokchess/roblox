local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 70
cam.CFrame = CFrame.lookAt(Vector3.new(2870, 22, -985), Vector3.new(2898, 16, -975))
local token = os.clock()
_G.CamToken = token
task.delay(10, function()
	if _G.CamToken == token then
		cam.CameraType = Enum.CameraType.Fixed
	end
end)
