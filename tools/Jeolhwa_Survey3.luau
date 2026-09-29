--!nocheck
-- 나무 폴더 짜임 조사
local out = {}
pcall(function()
	local fl = workspace.Surface["R_평원"].Flora
	local kinds = {}
	for i, c in ipairs(fl:GetChildren()) do
		kinds[c.ClassName] = (kinds[c.ClassName] or 0) + 1
		if i <= 12 then
			local s = c.Name .. " [" .. c.ClassName .. "]"
			if c:IsA("BasePart") then
				s = s .. string.format(" pos(%.0f,%.1f,%.0f) size(%.1f,%.1f,%.1f)", c.Position.X, c.Position.Y, c.Position.Z, c.Size.X, c.Size.Y, c.Size.Z)
			else
				s = s .. " children " .. #c:GetChildren()
			end
			out[#out + 1] = s
		end
	end
	for k, n in pairs(kinds) do out[#out + 1] = k .. " " .. n end
	local cl = game.ServerStorage.Jeolhwa_ClearedFlora
	for i, c in ipairs(cl:GetChildren()) do
		if i <= 12 then
			out[#out + 1] = "CLEARED " .. c.Name .. " [" .. c.ClassName .. "] " .. tostring(c:GetAttribute("OriginalParent"))
				.. (c:IsA("BasePart") and string.format(" (%.0f,%.1f,%.0f) %.1fx%.1fx%.1f", c.Position.X, c.Position.Y, c.Position.Z, c.Size.X, c.Size.Y, c.Size.Z) or "")
		end
	end
end)
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function() HS:PostAsync("http://127.0.0.1:34999/survey3", table.concat(out, "\n")) end)
HS.HttpEnabled = was
