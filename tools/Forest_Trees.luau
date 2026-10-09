--!nocheck
--[[
	Forest_Trees.luau — 2026-10-09. 숲 나무 심기(편집 모드, StudioJobs). 자리는 tools/forest_trees.py(덩어리 손 표) → Forest_Trees_data.luau:
	  RECV=<수신 폴더> python tools/forest_trees.py && sed '/--@@DATA@@/r tools/Forest_Trees_data.luau' tools/Forest_Trees.luau > tools/swamp/_trees_run.luau && bash tools/job.sh tools/swamp/_trees_run.luau
	틀 = ServerStorage.ForestKit.<틀>(Forest_Kit.luau). Surface.R_숲2.Trees 만 지우고 새로 심는다.
	나무 하나 = Model(메시 2~3, 투명 Origin 은 안 옮긴다). 밑동은 땅(1.9)보다 0.2 묻는다. 잎 색은 나무마다 조금씩(0.9~1.08배).
	보고: /foresttrees
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")

--@@DATA@@

local BASE_Y = 1.7
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local ok, err = pcall(function()
	local kit = SS:FindFirstChild("ForestKit")
	assert(kit, "ServerStorage.ForestKit 없음 — Forest_Kit.luau 먼저")
	local root = workspace.Surface:FindFirstChild("R_숲2")
	assert(root, "Surface.R_숲2 없음 — Forest_Build 먼저")
	local old = root:FindFirstChild("Trees")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Trees"
	-- 틀마다 조각(Origin 빼고) 미리
	local pieces = {}
	for _, m in kit:GetChildren() do
		local list = {}
		for _, c in m:GetChildren() do
			if c:IsA("MeshPart") then
				list[#list + 1] = c
			end
		end
		pieces[m.Name] = list
	end
	local n, missing = 0, {}
	for i, t in TREES do
		local kind, x, z, yaw, sc = t[1], t[2], t[3], t[4], t[5]
		local list = pieces[kind]
		if not list then
			missing[kind] = true
			continue
		end
		local base = CFrame.new(x, BASE_Y, z) * CFrame.Angles(0, math.rad(yaw), 0)
		local tint = 0.9 + ((i * 7919) % 19) / 100 -- 0.90 ~ 1.08
		local model = Instance.new("Model")
		model.Name = kind
		for _, src in list do
			local p = src:Clone()
			p.Size = src.Size * sc
			p.CFrame = base * CFrame.new(src.Position * sc) * src.CFrame.Rotation
			if p.Name ~= "Wood" then
				local c = src.Color
				p.Color = Color3.new(math.min(1, c.R * tint), math.min(1, c.G * tint), math.min(1, c.B * tint))
			end
			p.Parent = model
		end
		model.Parent = folder
		n += 1
		if n % 400 == 0 then
			task.wait()
		end
	end
	folder.Parent = root
	for k in missing do
		say("틀 없음: %s", k)
	end
	say("나무 %d그루 심음 (자료 %d)", n, #TREES)
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/foresttrees", table.concat(lines, "\n"))
