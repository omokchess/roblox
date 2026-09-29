local m = workspace.MotionStudio.Duelist:FindFirstChild("CombatGripW", true)
if _G.GripTestRestore then
	m.C0 = _G.GripTestRestore
	_G.GripTestRestore = nil
	game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/griptest", "restored " .. tostring(m.C0))
else
	_G.GripTestRestore = m.C0
	m.C0 = m.C0 * CFrame.Angles(0, 0, math.rad(30))
	game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/griptest", "set " .. tostring(m.C0))
end
