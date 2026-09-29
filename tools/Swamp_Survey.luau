--!nocheck
--[[
	Swamp_Survey.luau — 2026-09-28. 늪지대 땅 조각(Gs) 윗면 높이를 4 스터드 격자로 재서 /swamph4_<n> 으로 보낸다.
	격자: x 1384 + 4i (i 0..485), z 452 + 4j (j 0..311). 칸 가운데(+2)에서 잰다. 조각 없으면 -999.
	tools/swamp_terrain.py 가 이것을 읽어 지형(흙·물)을 만든다.
]]
local G = workspace.Surface.World["G_늪지대"]
local list = {}
for _, p in ipairs(G:GetChildren()) do
	if p:IsA("BasePart") and p.Name:match("^Gs_") then
		list[#list + 1] = p
	end
end
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = list
local HS = game:GetService("HttpService")
local X0, Z0, NX, NZ, R = 1384, 452, 486, 312, 4
local rows = {}
local part = 0
for j = 0, NZ - 1 do
	local row = table.create(NX)
	for i = 0, NX - 1 do
		local h = workspace:Raycast(Vector3.new(X0 + i * R + 2, 60, Z0 + j * R + 2), Vector3.new(0, -100, 0), rp)
		row[i + 1] = h and tostring(math.floor(h.Position.Y * 10 + 0.5)) or "x"
	end
	rows[#rows + 1] = table.concat(row, " ")
	if #rows == 52 or j == NZ - 1 then
		HS:PostAsync("http://127.0.0.1:34999/swamph4_" .. part, table.concat(rows, "\n"))
		part += 1
		rows = {}
		task.wait()
	end
end
print("swamp survey parts", part)
