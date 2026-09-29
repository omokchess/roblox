local out = {}
local function dump(inst, depth, maxd)
	if depth > maxd then return end
	table.insert(out, string.rep("  ", depth) .. inst.ClassName .. " " .. inst.Name .. (inst:IsA("ObjectValue") and (" -> " .. tostring(inst.Value and inst.Value:GetFullName())) or "") .. (inst:GetAttribute("Sig") and " [Sig]" or ""))
	local n = 0
	for _, c in inst:GetChildren() do
		n += 1
		if n > 6 then table.insert(out, string.rep("  ", depth + 1) .. "...") break end
		dump(c, depth + 1, maxd)
	end
end
local ss = game:GetService("ServerStorage")
for _, c in ss:GetChildren() do dump(c, 0, 3) end
local rig = workspace.MotionStudio:FindFirstChild("Duelist")
dump(rig:FindFirstChild("AnimSaves") or Instance.new("Folder"), 0, 2)
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/probe", table.concat(out, "\n"))
