local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 70
cam.CFrame = CFrame.lookAt(Vector3.new(9, 1202, -12), Vector3.new(9, 1199, 0))
local token = os.clock()
_G.CamToken = token
task.delay(10, function()
	if _G.CamToken == token then
		cam.CameraType = Enum.CameraType.Fixed
	end
end)
