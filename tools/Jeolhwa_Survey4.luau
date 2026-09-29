--!nocheck
-- 궁궐 안에 남은 물체가 무엇인지
local out = {}
pcall(function()
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { workspace.Jeolhwa, workspace.Surface.World }
	local seen = {}
	for _, p in ipairs(workspace:GetPartBoundsInBox(CFrame.new(225, 40, 775), Vector3.new(250, 80, 260), op)) do
		local k = p:GetFullName()
		if not seen[k] then
			seen[k] = true
			out[#out + 1] = string.format("%s (%.0f,%.0f,%.0f)", k, p.Position.X, p.Position.Y, p.Position.Z)
		end
	end
end)
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function() HS:PostAsync("http://127.0.0.1:34999/survey4", table.concat(out, "\n")) end)
HS.HttpEnabled = was
