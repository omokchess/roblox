local n = 0
for _, c in workspace.MotionStudio:GetChildren() do
	if c.Name:find("쥐는모양") then
		c.Size = Vector3.new(1.3, 1.3, 1.3)
		c.Transparency = 0.35
		n += 1
	end
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/hresize", "resized " .. n)
