--!nocheck
-- 화산섬 20 간격 높이(지반만) + 호수 바닥·물 확인. 보고: /volcano_h20 (첫 줄 머리, 다음 줄부터 z 한 줄씩 높이, 없으면 -1)
local HS = game:GetService("HttpService")
local G = workspace.Surface.World:FindFirstChild("G_화산")
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { G }
local X0, X1, Z0, Z1, ST = -2080, -440, -3730, -2030, 20
local out = { string.format("%d %d %d %d %d", X0, X1, Z0, Z1, ST) }
for z = Z0, Z1, ST do
	local row = {}
	for x = X0, X1, ST do
		local r = workspace:Raycast(Vector3.new(x + 1.3, 2000, z + 1.7), Vector3.new(0, -3000, 0), rp)
		row[#row + 1] = r and string.format("%.1f", r.Position.Y) or "-1"
	end
	out[#out + 1] = table.concat(row, ",")
	if #out % 20 == 0 then
		task.wait()
	end
end
-- 호수 바닥: 막지 않은 광선
local all = RaycastParams.new()
all.IgnoreWater = false
for _, p in ipairs({ { -1329, -3150 }, { -1250, -3000 }, { -1330, -2640 } }) do
	local r = workspace:Raycast(Vector3.new(p[1], 500, p[2]), Vector3.new(0, -2000, 0), all)
	out[#out + 1] = string.format("# 호수 %d %d → %s %s %s", p[1], p[2], r and tostring(r.Position.Y) or "없음",
		r and r.Instance:GetFullName() or "", r and r.Material.Name or "")
end
HS:PostAsync("http://127.0.0.1:34999/volcano_h20", table.concat(out, "\n"))
