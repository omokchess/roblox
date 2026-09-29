local n = 0
for _, c in workspace.MotionStudio:GetChildren() do if c.Name:find("쥐는모양") then n += 1 end end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/hcheck", "handles " .. n)
