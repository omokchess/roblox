local out = {}
local f = workspace.Jeolhwa:FindFirstChild("나무")
local n, kinds = 0, {}
for _, m in f:GetChildren() do
	if m:IsA("Model") then
		n += 1
		local mats = {}
		for _, d in m:GetDescendants() do if d:IsA("BasePart") then mats[d.Material.Name .. "/" .. d.ClassName .. (d:IsA("Part") and d.Shape.Name or "")] = true end end
		local keys = {} for k in mats do table.insert(keys, k) end
		table.sort(keys)
		local key = table.concat(keys, ",")
		kinds[key] = (kinds[key] or 0) + 1
	end
end
table.insert(out, "Jeolhwa 나무 모델 " .. n)
for k, c in kinds do table.insert(out, c .. "  " .. k) end
local ss = game:GetService("ServerStorage")
for _, fname in { "Pln_PreviousGeneratedTrees", "BeforeBlockWorldGeneratedFlora" } do
	local g = ss:FindFirstChild(fname)
	local shapes = {}
	for _, d in (g and g:GetDescendants()) or {} do if d:IsA("Part") then shapes[d.Shape.Name] = (shapes[d.Shape.Name] or 0) + 1 end end
	local s = {} for k, c in shapes do table.insert(s, k .. "=" .. c) end
	table.insert(out, fname .. " " .. table.concat(s, " "))
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/treeprobe", table.concat(out, "\n"))
