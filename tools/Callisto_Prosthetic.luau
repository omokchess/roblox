--!nocheck
--[[
	Callisto_Prosthetic.luau — 2026-11-07. 블렌더 의수(models/build_callisto_prosthetic.py → models/CallistoProsthetic.glb)를 3D 가져오기로 넣은 뒤
	MeshPart 을 ReplicatedStorage.CallistoAssets.Prosthetic 으로 옮긴다. 클라이언트 Combat/Callisto(attachProsthetic)가 복제해 오른팔 부위에 용접한다.
	  메시 이름 CallistoProsthetic_<묶음> — Gold(금판) · Brass(황동 덩굴·고리) · BluedSteel(이음부) · Glow(별빛). 묶음 이름 그대로 Prosthetic 아래 이름이 된다.
	  원점 표지 WeaponsOrigin_Marker = 오른팔 부위 가운데 1×1×1 — 자리를 빼서 원점을, 크기로 스터드 배율(k)을 되찾는다.
	  MeshPart 마다 속성 Offset(오른팔 부위 가운데에서 본 CFrame). 색·재질은 가져오기가 붙인 SurfaceAppearance 를 걷고 코드(Callisto.luau PROSTHETIC_SKIN)가 입힌다.
	같은 의수를 다시 가져오면 그 묶음만 갈아 끼운다. 보고: /calprosthetic
	※ 가져온 직후엔 칼 날 가져오기(WeaponMeshes)와 표지 이름이 같으니, 이 스크립트를 먼저 돌려 가져온 모델을 치운 뒤 다음 GLB 를 가져올 것.
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
	assert(marker, "표지(WeaponsOrigin_Marker)가 없다 — CallistoProsthetic.glb 를 먼저 가져올 것")
	-- 가져온 묶음 = workspace 바로 아래 조상(GLB 는 조각마다 "_Node" 모델로 한 번 더 감싼다)
	local imported = marker
	while imported.Parent and imported.Parent ~= workspace do
		imported = imported.Parent
	end
	assert(imported ~= marker and imported ~= workspace, "가져온 모델 묶음을 못 찾았다")
	local k = 1 / marker.Size.X
	say("표지 크기 %.4f → 배율 %.4f", marker.Size.X, k)
	local kit = RS:FindFirstChild("CallistoAssets") or Instance.new("Folder")
	kit.Name = "CallistoAssets"
	kit.Parent = RS
	local folder = kit:FindFirstChild("Prosthetic")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Prosthetic"
		folder.Parent = kit
	end
	local n, names = 0, {}
	for _, mp in imported:GetDescendants() do
		if not mp:IsA("MeshPart") or mp == marker then
			continue
		end
		local group = string.match(mp.Name, "^CallistoProsthetic_(%w+)")
		if not group then
			say("모르는 이름 %s", mp.Name)
			continue
		end
		local old = folder:FindFirstChild(group)
		if old then
			old:Destroy()
		end
		local rel = marker.CFrame:ToObjectSpace(mp.CFrame)
		local offset = CFrame.new(rel.Position * k) * rel.Rotation
		mp.Size = mp.Size * k
		mp:ClearAllChildren() -- SurfaceAppearance 걷기
		mp.Anchored = true
		mp.CanCollide, mp.CanQuery, mp.CanTouch = false, false, false
		mp:SetAttribute("Offset", offset)
		mp.CFrame = offset
		mp.Name = group
		mp.Parent = folder
		n += 1
		table.insert(names, group)
	end
	table.sort(names)
	say("메시 %d개: %s", n, table.concat(names, ", "))
	imported:Destroy()
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/calprosthetic", table.concat(lines, "\n"))
