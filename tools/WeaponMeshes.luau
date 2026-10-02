--!nocheck
--[[
	WeaponMeshes.luau — 2026-10-02. 블렌더 models/weapons/Weapons.fbx 를 가져온 모델을 무기 메시 창고로 가른다.

	가져온 모델 안 MeshPart 이름 "<무기Id>_<Main|Off>_<묶음>"(build_weapons.py)을
	ReplicatedStorage.WeaponMeshes.<무기Id>.<Main|Off>.<묶음> 으로 옮긴다.
	원점 표지 WeaponsOrigin_Marker(무기 공간 1×1×1)로 원점(쥐는 점)과 스터드 배율을 되찾고,
	MeshPart 마다 속성 Offset = 쥐는 점 기준 자리(CFrame)를 적는다 — CombatWeapons 가 이 값으로 Grip 에 용접한다.
	색·재질은 여기서 안 입힌다(WeaponDefinitions 의 Skins 를 CombatWeapons 가 입힌다).
	같은 무기를 다시 가져오면 그 묶음만 갈아 끼운다. 보고: /weaponmeshes
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
		if d:IsA("MeshPart") and d.Name == "WeaponsOrigin_Marker" then
			marker = d
			break
		end
	end
	assert(marker, "표지(WeaponsOrigin_Marker)가 없다 — Weapons.fbx 를 먼저 가져올 것")
	local imported = marker:FindFirstAncestorWhichIsA("Model") or marker.Parent
	local k = 1 / marker.Size.X
	say("표지 크기 %.4f → 배율 %.4f", marker.Size.X, k)
	local root = RS:FindFirstChild("WeaponMeshes")
	if not root then
		root = Instance.new("Folder")
		root.Name = "WeaponMeshes"
		root.Parent = RS
	end
	local function child(parent, name, class)
		local c = parent:FindFirstChild(name)
		if not c then
			c = Instance.new(class)
			c.Name = name
			c.Parent = parent
		end
		return c
	end
	local n, pieces = 0, {}
	for _, mp in imported:GetDescendants() do
		if not mp:IsA("MeshPart") or mp == marker then
			continue
		end
		local wid, piece, group = string.match(mp.Name, "^(%w+)_(%a+)_(%w+)")
		if not wid or (piece ~= "Main" and piece ~= "Off") then
			say("모르는 이름 %s", mp.Name)
			continue
		end
		local holder = child(child(root, wid, "Folder"), piece, "Model")
		local old = holder:FindFirstChild(group)
		if old then
			old:Destroy()
		end
		local rel = marker.CFrame:ToObjectSpace(mp.CFrame)
		local offset = CFrame.new(rel.Position * k) * rel.Rotation
		mp.Size = mp.Size * k
		mp.Anchored = true
		mp.CanCollide, mp.CanQuery, mp.CanTouch = false, false, false
		mp:SetAttribute("Offset", offset)
		mp.CFrame = offset
		mp.Name = group
		mp.Parent = holder
		n += 1
		pieces[wid .. "." .. piece] = (pieces[wid .. "." .. piece] or 0) + 1
	end
	local keys = {}
	for key, c in pieces do
		keys[#keys + 1] = key .. " " .. c
	end
	table.sort(keys)
	say("메시 %d개: %s", n, table.concat(keys, ", "))
	if imported ~= workspace then
		imported:Destroy()
	end
end)
HS:PostAsync("http://127.0.0.1:34999/weaponmeshes", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
