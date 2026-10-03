--!nocheck
--[[
	MonsterMeshes.luau — 2026-10-03. 블렌더 models/monsters/Monsters.fbx 를 가져온 모델을 몬스터 메시 창고로 가른다.

	가져온 모델 안 MeshPart 이름 "<모델>_<부품>"(build_monsters.py)을 ReplicatedStorage.MonsterMeshes.<모델>.<부품> 으로 옮긴다.
	원점 표지 MonstersOrigin_Marker(1×1×1)로 원점(바닥 가운데 Pivot)과 스터드 배율을 되찾고,
	MeshPart 마다 속성 Offset = Pivot 기준 자리(CFrame)를 적는다 — DebugBoss.new 가 이 값을 Rest 로 쓴다.
	색·재질은 여기서 안 입힌다(코드가 부품 이름으로 입힌다). FBX 하나가 몬스터 메시 전부라 다시 가져오면 창고를 통째로 갈아 끼운다. 보고: /monstermeshes
]]
local HS = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end
local ok, err = pcall(function()
	local marker
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == "MonstersOrigin_Marker" then
			marker = d
			break
		end
	end
	assert(marker, "표지(MonstersOrigin_Marker)가 없다 — Monsters.fbx 를 먼저 가져올 것")
	local imported = marker:FindFirstAncestorWhichIsA("Model") or marker.Parent
	local k = 1 / marker.Size.X
	say("표지 크기 %.4f → 배율 %.4f", marker.Size.X, k)
	local old = RS:FindFirstChild("MonsterMeshes")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "MonsterMeshes"
	root.Parent = RS
	local n, models, turned = 0, {}, 0
	for _, mp in imported:GetDescendants() do
		if not mp:IsA("MeshPart") or mp == marker then
			continue
		end
		local mid, piece = string.match(mp.Name, "^(%w+)_(%w+)$")
		if not mid then
			say("모르는 이름 %s", mp.Name)
			continue
		end
		local holder = root:FindFirstChild(mid)
		if not holder then
			holder = Instance.new("Model")
			holder.Name = mid
			holder.Parent = root
		end
		local rel = marker.CFrame:ToObjectSpace(mp.CFrame)
		local offset = CFrame.new(rel.Position * k) * rel.Rotation
		if rel.Rotation.LookVector:Dot(Vector3.new(0, 0, -1)) < 0.9999 then
			turned += 1
		end
		mp.Size = mp.Size * k
		mp.Anchored = true
		mp.CanCollide, mp.CanQuery, mp.CanTouch = false, false, false
		mp:SetAttribute("Offset", offset)
		mp.CFrame = offset
		mp.Name = piece
		mp.Parent = holder
		n += 1
		models[mid] = (models[mid] or 0) + 1
	end
	local keys = {}
	for key, c in models do
		keys[#keys + 1] = key .. " " .. c
	end
	table.sort(keys)
	say("메시 %d개(돌아간 것 %d): %s", n, turned, table.concat(keys, ", "))
	if imported ~= workspace then
		imported:Destroy()
	end
end)
HS:PostAsync("http://127.0.0.1:34999/monstermeshes", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
