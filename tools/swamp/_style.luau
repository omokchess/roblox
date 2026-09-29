local out = {}
local function show(folder, n)
	local k = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			k += 1
			if k > n then break end
			table.insert(out, string.format("%s %s size %.1f,%.1f,%.1f pos %.0f,%.1f,%.0f rot %.0f,%.0f,%.0f mat %s col %d,%d,%d", d:GetFullName(), d.ClassName, d.Size.X, d.Size.Y, d.Size.Z, d.Position.X, d.Position.Y, d.Position.Z, d.Orientation.X, d.Orientation.Y, d.Orientation.Z, d.Material.Name, d.Color.R*255, d.Color.G*255, d.Color.B*255))
		end
	end
end
local W = workspace.Surface.World
for _, g in W:GetChildren() do
	table.insert(out, "== " .. g.Name .. " parts " .. #g:GetChildren())
	local names = {}
	for _, d in g:GetChildren() do local p = d.Name:match("^(%a+)") or d.Name names[p] = (names[p] or 0) + 1 end
	for n, c in names do table.insert(out, "  " .. n .. " x" .. c) end
end
show(W["G_평원"], 12)
show(workspace.Surface.Mountains, 14)
local t = workspace.Surface:FindFirstChild("R_숲")
if t then
	local names = {}
	for _, d in t:GetChildren() do local p = d.Name:match("^([%a_]+)") or d.Name names[p] = (names[p] or 0) + 1 end
	for n, c in names do table.insert(out, "R_숲/" .. n .. " x" .. c) end
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/style", table.concat(out, "\n"))
