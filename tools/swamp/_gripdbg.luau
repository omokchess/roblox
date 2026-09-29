local out = {}
local rig = workspace.MotionStudio.Duelist
table.insert(out, "ClassId " .. tostring(rig:GetAttribute("ClassId")))
local grip = rig:FindFirstChild("GripW", true)
table.insert(out, "grip " .. tostring(grip and grip:GetFullName()))
local motor = grip and grip:FindFirstChild("CombatGripW")
table.insert(out, "motor " .. tostring(motor and motor.ClassName))
local f = Instance.new("Folder")
local ok, err = pcall(function() f:SetAttribute("GripW", motor.C0) end)
table.insert(out, "set " .. tostring(ok) .. " " .. tostring(err) .. " -> " .. tostring(f:GetAttribute("GripW")))
local src = game.ServerScriptService.Server.MotionStudioService.Source
table.insert(out, "server has grip code: " .. tostring(string.find(src, "CombatGrip", 1, true) ~= nil))
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/gripdbg", table.concat(out, "\n"))
