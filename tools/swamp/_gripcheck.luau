local out = {}
for _, rig in workspace.MotionStudio:GetChildren() do
	if rig:GetAttribute("ClassId") then
		local parts = {}
		for _, slot in { "W", "O" } do
			local g = rig:FindFirstChild("Grip" .. slot, true)
			local m = g and g:FindFirstChild("CombatGrip" .. slot)
			if m then table.insert(parts, slot .. ": " .. m:GetFullName():gsub("^Workspace%.", "")) end
		end
		table.insert(out, rig.Name .. "  " .. (#parts > 0 and table.concat(parts, " | ") or "무기 관절 없음(떠 있는 오브)"))
	end
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/gripcheck", table.concat(out, "\n"))
