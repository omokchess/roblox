--!nocheck
--[[
	Field_Remove.luau — Field_Build 로 지은 들판을 걷고 치웠던 옛 판을 제자리로 되돌린다. (2026-09-29)
	_G.FieldRemoveName 에 이름(예: "평원_북쪽들녘")을 넣고 돌린다. 없으면 F_ 로 시작하는 들판을 모두 걷는다.
]]
local SS = game:GetService("ServerStorage")
local out = {}
local function pathTo(path)
	local node = workspace
	for seg in string.gmatch(path, "[^/]+") do
		node = node and node:FindFirstChild(seg)
	end
	return node
end
local want = _G.FieldRemoveName
for _, f in workspace.Surface:GetChildren() do
	if string.sub(f.Name, 1, 2) == "F_" and (not want or f.Name == "F_" .. want) then
		local name = string.sub(f.Name, 3)
		f:Destroy()
		local back = 0
		local store = SS:FindFirstChild("FieldRemoved") and SS.FieldRemoved:FindFirstChild(name)
		for _, p in (store and store:GetChildren()) or {} do
			local home = pathTo(p:GetAttribute("From") or "")
			if home then
				p:SetAttribute("From", nil)
				p.Parent = home
				back += 1
			end
		end
		if store then
			store:Destroy()
		end
		table.insert(out, string.format("%s 걷음, 옛 판 %d 되돌림", name, back))
	end
end
pcall(function()
	game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/field_remove", #out > 0 and table.concat(out, "\n") or "걷을 들판 없음")
end)
