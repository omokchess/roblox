local out = {}
local params = RaycastParams.new()
for _, p in { {5000, 0}, {4500, -500}, {-1000, 4000}, {0, -5000}, {-6000, -1000}, {-2500, -1200}, {800, -3200}, {1500, -500}, {3000, 3000} } do
	local r = workspace:Raycast(Vector3.new(p[1], 2000, p[2]), Vector3.new(0, -4000, 0), params)
	if r then
		table.insert(out, string.format("(%d,%d) hit %s %s y=%.1f mat=%s", p[1], p[2], r.Instance.ClassName, r.Instance:GetFullName(), r.Position.Y, tostring(r.Material)))
	else
		table.insert(out, string.format("(%d,%d) nothing", p[1], p[2]))
	end
end
-- 지형 물 여부: 한 점 읽기
local t = workspace.Terrain
local region = Region3.new(Vector3.new(4996, -8, -4), Vector3.new(5004, 0, 4)):ExpandToGrid(4)
local mats, occ = t:ReadVoxels(region, 4)
table.insert(out, "voxel at 5000,-4,0: " .. tostring(mats[1][1][1]) .. " " .. occ[1][1][1])
-- World 폴더 아래 이름 종류
local names = {}
for _, c in workspace.Surface.World:GetChildren() do names[c.Name] = (names[c.Name] or 0) + 1 end
for n, k in names do table.insert(out, "World/" .. n .. " x" .. k) end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/probe2", table.concat(out, "\n"))
