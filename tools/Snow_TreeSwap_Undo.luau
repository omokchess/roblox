--!nocheck
-- Snow_TreeSwap_Undo.luau — 2026-11-18. Snow_TreeSwap 되돌리기: 백업(ServerStorage.Snow_FieldTrees_Backup)의 옛 나무를 원래 부모로,
-- 새 나무(속성 OldTree 가 있는 모델)는 지운다. 사용자: "기존 나무 복구 해줘" → /treeundo
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local out = {}
local ok, err = pcall(function()
	local bak = assert(SS:FindFirstChild("Snow_FieldTrees_Backup"), "백업 폴더가 없다")
	local function resolve(path)
		local node = game
		for name in string.gmatch(path, "[^%.]+") do
			node = node:FindFirstChild(name)
			if not node then
				return nil
			end
		end
		return node
	end
	local back, lost = 0, 0
	for _, m in bak:GetChildren() do
		local p = resolve(m:GetAttribute("OldParent") or "")
		if p then
			m:SetAttribute("OldParent", nil)
			m.Parent = p
			back += 1
		else
			lost += 1
		end
	end
	local removed = 0
	for _, m in workspace.Surface["R_설원3_장식"]:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("OldTree") then
			m:Destroy()
			removed += 1
		end
	end
	if #bak:GetChildren() == 0 then
		bak:Destroy()
	end
	table.insert(out, string.format("옛 나무 되돌림 %d, 부모 못 찾음 %d(백업에 남김), 새 나무 지움 %d", back, lost, removed))
end)
if not ok then
	table.insert(out, "오류: " .. tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/treeundo", table.concat(out, "\n"))
