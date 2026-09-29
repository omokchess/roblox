local HS = game:GetService("HttpService")
local out = {}
local holder = game:GetService("ServerStorage"):FindFirstChild("MaterialPacks") or Instance.new("Folder")
holder.Name = "MaterialPacks"
holder.Parent = game:GetService("ServerStorage")
for _, id in { 13591987222, 11000216412 } do
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
	if not ok then
		table.insert(out, id .. " 실패 " .. tostring(objs))
	else
		local f = Instance.new("Folder")
		f.Name = "Pack_" .. id
		f.Parent = holder
		for _, o in objs do
			o.Parent = f
			for _, d in o:GetDescendants() do
				if d:IsA("MaterialVariant") then
					table.insert(out, string.format("%d %s base=%s studs=%s", id, d.Name, d.BaseMaterial.Name, tostring(d.StudsPerTile)))
				end
			end
			if o:IsA("MaterialVariant") then
				table.insert(out, string.format("%d %s base=%s studs=%s", id, o.Name, o.BaseMaterial.Name, tostring(o.StudsPerTile)))
			end
			table.insert(out, id .. " top " .. o.ClassName .. " " .. o.Name .. " desc " .. #o:GetDescendants())
		end
	end
end
HS:PostAsync("http://127.0.0.1:34999/matimport", table.concat(out, "\n"))
