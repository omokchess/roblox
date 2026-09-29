workspace:SetAttribute("SpectateSelf", nil)
local c = workspace.CurrentCamera c.CameraType = Enum.CameraType.Fixed
pcall(function() game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/attr", "off") end)
