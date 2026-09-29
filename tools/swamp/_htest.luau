local st = workspace.MotionStudio
local h = st:FindFirstChild("Duelist_쥐는모양_W")
local m = st.Duelist:FindFirstChild("CombatGripW", true)
local before = m.C0
h.CFrame = h.CFrame * CFrame.Angles(0, 0, math.rad(40)) + Vector3.new(0, 0.5, 0)
task.wait(0.2)
local changed = m.C0 ~= before
local follows = (m.Part1.Position - h.Position).Magnitude
m.C0 = before
task.wait(0.2)
local back = (h.CFrame.Position - (m.Part0.CFrame * m.C0 * m.C1:Inverse()).Position).Magnitude
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/htest", string.format("C0 바뀜 %s, 무기-손잡이 거리 %.3f, 되돌린 뒤 손잡이 따라옴 %.3f", tostring(changed), follows, back))
