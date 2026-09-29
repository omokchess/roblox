local HS = game:GetService("HttpService")
local out = {}
local function box(c)
	local minV, maxV = Vector3.new(1e9,1e9,1e9), Vector3.new(-1e9,-1e9,-1e9)
	local cnt = 0
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			cnt += 1
			minV = minV:Min(d.Position) maxV = maxV:Max(d.Position)
		end
	end
	if cnt == 0 then return "" end
	return string.format("  n%d x %d..%d y %d..%d z %d..%d", cnt, minV.X, maxV.X, minV.Y, maxV.Y, minV.Z, maxV.Z)
end
for _, top in { workspace.Surface, workspace.Jeolhwa, workspace.Schneereich } do
	table.insert(out, "== " .. top.Name)
	for _, c in top:GetChildren() do
		table.insert(out, c.ClassName .. " " .. c.Name .. box(c))
	end
end
HS:PostAsync("http://127.0.0.1:34999/survey2", table.concat(out, "\n"))
local src = game.StarterPlayer.StarterPlayerScripts.BiomeAtmosphere.Source
HS:PostAsync("http://127.0.0.1:34999/biome_src", src)
