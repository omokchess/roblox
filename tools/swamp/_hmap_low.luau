local HS = game:GetService("HttpService")
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { workspace:FindFirstChild("MotionStudio") }
local X0, X1, Z0, Z1, S = -5600, 3900, -4000, 1900, 40
local rows = {}
local mats = {}
local matId = {}
local nextId = 0
for z = Z1, Z0, -S do
	local line = table.create(0)
	for x = X0, X1, S do
		local r = workspace:Raycast(Vector3.new(x + 1.3, -400, z + 1.3), Vector3.new(0, 1300, 0), params)
		if r then
			local m = r.Instance:IsA("Terrain") and ("T:" .. r.Material.Name) or r.Material.Name
			if not matId[m] then nextId += 1 matId[m] = nextId end
			table.insert(line, string.format("%d:%d", math.floor(r.Position.Y + 0.5), matId[m]))
		else
			table.insert(line, "_")
		end
	end
	table.insert(rows, table.concat(line, " "))
end
local legend = {}
for m, id in matId do table.insert(legend, id .. "=" .. m) end
HS:PostAsync("http://127.0.0.1:34999/hmap_low", string.format("%d %d %d %d %d\n%s\n", X0, X1, Z0, Z1, S, table.concat(legend, ",")) .. table.concat(rows, "\n"))
