--!nocheck
-- Plains_EdgeDump.luau — 2026-10-09 숲 땅을 평원 섬에 맞대려고 평원 땅 판·해안 조각을 뽑는다(편집 모드). 보고: /plainsedge
-- 한 줄 = 폴더|하위폴더|이름|x0|x1|z0|z1|윗면|재질
local HS = game:GetService("HttpService")
local rows = {}
local ok, err = pcall(function()
	for _, region in { "R_평원북", "R_평원동", "R_평원중", "R_평원채움", "R_평원" } do
		local f = workspace.Surface:FindFirstChild(region)
		if f then
			for _, d in f:GetDescendants() do
				if d:IsA("BasePart") and math.max(d.Size.X, d.Size.Z) >= 30 and d.Orientation.Magnitude < 1 then
					local p, s = d.Position, d.Size
					rows[#rows + 1] = string.format("%s|%s|%s|%.1f|%.1f|%.1f|%.1f|%.2f|%s", region, d.Parent.Name, d.Name,
						p.X - s.X / 2, p.X + s.X / 2, p.Z - s.Z / 2, p.Z + s.Z / 2, p.Y + s.Y / 2, d.Material.Name)
				end
			end
		end
	end
end)
if not ok then
	rows[#rows + 1] = "오류 " .. tostring(err)
end
HS:PostAsync("http://127.0.0.1:34999/plainsedge", table.concat(rows, "\n"))
