local out = {}
local function bbox(inst)
	local ok, cf, size = pcall(function()
		if inst:IsA("Model") then return inst:GetBoundingBox() end
		if inst:IsA("BasePart") then return inst.CFrame, inst.Size end
		local m = Instance.new("Model")
		return nil
	end)
	return ok and cf, ok and size
end
for _, c in workspace:GetChildren() do
	local n = #c:GetDescendants()
	local line = c.ClassName .. " " .. c.Name .. " (" .. n .. ")"
	if c:IsA("Folder") or c:IsA("Model") then
		local minV, maxV = Vector3.new(1e9,1e9,1e9), Vector3.new(-1e9,-1e9,-1e9)
		local cnt = 0
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") and cnt < 20000 then
				cnt += 1
				local p = d.Position
				minV = minV:Min(p) maxV = maxV:Max(p)
			end
		end
		if cnt > 0 then line ..= string.format("  x %d..%d y %d..%d z %d..%d", minV.X, maxV.X, minV.Y, maxV.Y, minV.Z, maxV.Z) end
	end
	table.insert(out, line)
end
local L = game:GetService("Lighting")
table.insert(out, "--- Lighting")
for _, c in L:GetChildren() do table.insert(out, c.ClassName .. " " .. c.Name) end
table.insert(out, string.format("Clock %.1f Brightness %.2f Ambient %s Outdoor %s FogEnd %d", L.ClockTime, L.Brightness, tostring(L.Ambient), tostring(L.OutdoorAmbient), L.FogEnd))
table.insert(out, "--- scripts")
for _, s in game:GetDescendants() do
	if (s:IsA("Script") or s:IsA("LocalScript")) and (s.Name:find("Biome") or s.Name:find("Atmos") or s.Name:find("Fog") or s.Name:find("Light")) then
		table.insert(out, s:GetFullName() .. " " .. #s.Source)
	end
end
local t = workspace.Terrain
table.insert(out, "Water " .. tostring(t.WaterColor) .. " " .. t.WaterTransparency)
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/survey", table.concat(out, "\n"))
