--!nocheck
--[[
	Snow_TreeSwap.luau — 2026-11-17. 설원 들(Surface.R_설원3_장식.나무)의 옛 나무(ForestKit Pine_A/Pine_B/Birch_A 를 잎만 눈색으로 칠한 것)를
	3판 자연 키트(ServerStorage.SnowKit3.Sn3_Spruce_* / Sn3_Birch)로 갈아 끼운다. 자리·방향은 그대로, 크기는 옛 높이에 맞춘다.
	사용자(2026-11-17): "나무랑 지형 이런것들 지금 맵 보고 좀 다듬은 다음에 넣어줘"
	옛 나무는 지우지 않고 ServerStorage.Snow_FieldTrees_Backup 으로 옮긴다(되돌리기: 그 폴더의 모델을 원래 폴더로, 새 나무 지우기).
	짝: Pine_A(키 큼) → 34 이상 Spruce_L, 아니면 Spruce_M / Pine_B → 22 이상 Spruce_M, 아니면 Spruce_S / Birch_A → Birch.
	돌리기(총괄): sed -e '/--@@INSIDE@@/r tools/Snow_Inside3_data.luau' tools/Snow_TreeSwap.luau > tools/swamp/_treeswap_run.luau
	              bash tools/job.sh tools/swamp/_treeswap_run.luau  → 보고 /treeswap
]]
--@@INSIDE@@
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local lines = {}
local function say(fmt, ...)
	lines[#lines + 1] = string.format(fmt, ...)
end
local ok, err = pcall(function()
	local kit = assert(SS:FindFirstChild("SnowKit3"), "ServerStorage.SnowKit3 가 없다")
	local deco = assert(workspace.Surface:FindFirstChild("R_설원3_장식"), "R_설원3_장식 이 없다")
	local trees = assert(deco:FindFirstChild("나무"), "R_설원3_장식.나무 가 없다")
	local bak = SS:FindFirstChild("Snow_FieldTrees_Backup")
	if bak then
		error("Snow_FieldTrees_Backup 이 이미 있다 — 한 번 갈아 끼운 듯(다시 하려면 먼저 되돌릴 것)")
	end
	local function pick(name, h)
		if name == "Pine_A" then
			return h >= 34 and "Sn3_Spruce_L" or "Sn3_Spruce_M"
		elseif name == "Pine_B" then
			return h >= 22 and "Sn3_Spruce_M" or "Sn3_Spruce_S"
		elseif name == "Birch_A" then
			return "Sn3_Birch"
		end
	end
	local todo = {}
	for _, m in trees:GetDescendants() do
		if m:IsA("Model") and pick(m.Name, 0) then
			table.insert(todo, m)
		end
	end
	bak = Instance.new("Folder")
	bak.Name = "Snow_FieldTrees_Backup"
	bak.Parent = SS
	local made, missing, scales = {}, {}, {}
	for i, old in todo do
		local cf, sz = old:GetBoundingBox()
		local _, yaw = old:GetPivot():ToOrientation()
		local kind = pick(old.Name, sz.Y)
		local src = kit:FindFirstChild(kind)
		if not src then
			missing[kind] = true
			continue
		end
		local _, tsz = src:GetBoundingBox()
		local sc = math.clamp(sz.Y / tsz.Y, 0.6, 1.5)
		local m = src:Clone()
		m.Name = kind
		m:PivotTo(CFrame.new())
		for _, p in m:GetDescendants() do
			if p:IsA("MeshPart") then
				p.CanCollide = false
			end
		end
		local spec = INSIDE[kind]
		if spec then
			local fc = Instance.new("Folder")
			fc.Name = "충돌"
			fc.Parent = m
			for _, b in spec.coll do
				local p = Instance.new("Part")
				p.Name = "Coll"
				p.Anchored = true
				p.Transparency = 1
				p.CastShadow = false
				p.Size = Vector3.new(b[4], b[5], b[6])
				p.CFrame = CFrame.new(b[1], b[2], b[3]) * CFrame.Angles(0, math.rad(b[7]), 0)
				p.Parent = fc
			end
		end
		if math.abs(sc - 1) > 0.01 then
			m:ScaleTo(sc)
		end
		m:PivotTo(CFrame.new(cf.X, cf.Y - sz.Y / 2, cf.Z) * CFrame.Angles(0, yaw, 0))
		m:SetAttribute("OldTree", old:GetFullName())
		m.Parent = old.Parent
		-- 옛 나무는 원래 부모 경로를 속성으로 적고 백업으로
		old:SetAttribute("OldParent", old.Parent:GetFullName())
		old.Parent = bak
		made[kind] = (made[kind] or 0) + 1
		scales[#scales + 1] = sc
		if i % 50 == 0 then
			task.wait()
		end
	end
	table.sort(scales)
	for k, n in made do
		say("%s %d", k, n)
	end
	local ml = {}
	for k in missing do
		ml[#ml + 1] = k
	end
	say("갈아 끼움 %d / %d, 배율 %.2f~%.2f, 틀 없음: %s", #scales, #todo, scales[1] or 0, scales[#scales] or 0,
		#ml > 0 and table.concat(ml, ", ") or "없음")
end)
if not ok then
	say("오류: %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/treeswap", table.concat(lines, "\n"))
