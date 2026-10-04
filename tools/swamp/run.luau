--!nocheck
--[[
	StudioSync.luau — tools/sync.json 목록대로 src/ 의 Luau 를 Studio 스크립트 Source 에 넣는다. (2026-09-28)
	자료는 프로젝트 뿌리를 띄운 로컬 서버(127.0.0.1:35001)에서 받는다. studio_sync.py 주석 참고.
	- 바꾸기 전 원래 Source 를 수신기(/syncbak_<경로>)로 보내 둔다(되돌릴 수 있게)
	- 없으면 만들고, 종류가 다르면(Folder 자리에 ModuleScript 등) 새로 만들어 자식을 옮긴다
	보고: /studiosync
]]
local HS = game:GetService("HttpService")
local report = {}
local ok, err = pcall(function()
	local list = HS:JSONDecode(HS:GetAsync("http://127.0.0.1:35001/tools/sync.json", true))
	local changed, created, same = 0, 0, 0
	local failed = {}
	for _, it in ipairs(list) do
		local src = HS:GetAsync("http://127.0.0.1:35001/" .. it.file, true)
		-- 부모 사슬
		local node = game:GetService(it.path[1])
		for i = 2, #it.path - 1 do
			local name = it.path[i]
			local child = node:FindFirstChild(name)
			local want = "Folder"
			if i > it.base then
				want = it.chain[i - it.base] or "Folder"
			end
			if not child then
				child = Instance.new(want)
				child.Name = name
				child.Parent = node
				created += 1
			end
			node = child
		end
		local name = it.path[#it.path]
		local target = node:FindFirstChild(name)
		if target and target.ClassName ~= it.class then
			local fresh = Instance.new(it.class)
			fresh.Name = name
			for _, c in ipairs(target:GetChildren()) do
				c.Parent = fresh
			end
			if target:IsA("LuaSourceContainer") then
				pcall(function()
					HS:PostAsync("http://127.0.0.1:34999/syncbak_" .. table.concat(it.path, "_"), target.Source)
				end)
			end
			target:Destroy()
			fresh.Parent = node
			target = fresh
			created += 1
		end
		if not target then
			target = Instance.new(it.class)
			target.Name = name
			target.Parent = node
			created += 1
		end
		if target.Source ~= src then
			if #target.Source > 0 then
				pcall(function()
					HS:PostAsync("http://127.0.0.1:34999/syncbak_" .. table.concat(it.path, "_"), target.Source)
				end)
			end
			-- 커맨드 바에서 Source 에 넣을 수 있는 건 20만 자 미만. 넘으면 ScriptEditorService 로 넣는다
			local put, why = pcall(function()
				if #src < 200000 then
					target.Source = src
				else
					game:GetService("ScriptEditorService"):UpdateSourceAsync(target, function()
						return src
					end)
				end
			end)
			if put then
				changed += 1
			else
				failed[#failed + 1] = it.file .. ": " .. tostring(why)
			end
		else
			same += 1
		end
	end
	report[#report + 1] = string.format("목록 %d: 바꿈 %d, 새로 %d, 같음 %d, 실패 %d", #list, changed, created, same, #failed)

	--[[
		지운 파일(tools/sync_remove.json)은 Studio 에서도 지운다. 지우기 전 Source 를 수신기로 보낸다.
		목록에 없는데 src 에도 없는 스크립트(Studio 에만 있는 것)는 **지우지 않고** 이름만 보고한다
		— 사용자가 Studio 에서 직접 만든 것일 수 있다.
	]]
	local okRemove, removeList = pcall(function()
		return HS:JSONDecode(HS:GetAsync("http://127.0.0.1:35001/tools/sync_remove.json", true))
	end)
	local removed = 0
	for _, path in ipairs(if okRemove then removeList else {}) do
		local node = game:GetService(path[1])
		for i = 2, #path do
			node = node and node:FindFirstChild(path[i])
		end
		if node then
			if node:IsA("LuaSourceContainer") then
				pcall(function()
					HS:PostAsync("http://127.0.0.1:34999/syncbak_removed_" .. table.concat(path, "_"), node.Source)
				end)
			end
			node:Destroy()
			removed += 1
		end
	end
	local known = {}
	for _, it in ipairs(list) do
		known[table.concat(it.path, "/")] = true
	end
	local stray = {}
	for _, root in ipairs({ { "ReplicatedStorage", "Shared" }, { "ServerScriptService", "Server" }, { "StarterPlayer", "StarterPlayerScripts", "Client" } }) do
		local node = game:GetService(root[1])
		for i = 2, #root do
			node = node and node:FindFirstChild(root[i])
		end
		for _, d in ipairs(node and node:GetDescendants() or {}) do
			if d:IsA("LuaSourceContainer") then
				local parts = {}
				local cur = d
				while cur and cur ~= game do
					table.insert(parts, 1, cur.Name)
					cur = cur.Parent
				end
				if not known[table.concat(parts, "/")] then
					stray[#stray + 1] = table.concat(parts, "/")
				end
			end
		end
	end
	report[#report + 1] = string.format("지움 %d, src 에 없는 Studio 스크립트 %d", removed, #stray)
	for _, name in ipairs(stray) do
		report[#report + 1] = "  (그대로 둠) " .. name
	end
	for _, f in ipairs(failed) do
		report[#report + 1] = "  실패 " .. f
	end
end)
if not ok then
	report[#report + 1] = "ERR " .. tostring(err)
end
HS:PostAsync("http://127.0.0.1:34999/studiosync", table.concat(report, "\n"))
