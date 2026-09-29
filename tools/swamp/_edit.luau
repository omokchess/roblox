local seq = game:GetService("ServerStorage").RBX_ANIMSAVES.Duelist:FindFirstChild("Idle 대기")
local n = 0
for _, d in seq:GetDescendants() do
	if d:IsA("Pose") and d.Name == "Left Arm" then
		d.CFrame = d.CFrame * CFrame.Angles(0, 0, math.rad(80))
		n += 1
	end
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/edit", "poses " .. n)
