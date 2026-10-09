--!nocheck
--[[
	Forest_Kit.luau — 2026-10-09. 블렌더 숲 나무 키트(models/forest/ForestKit.fbx, 표지 ForestKitOrigin_Marker)를 가른다
	→ ServerStorage.ForestKit.<틀> (Model, 피벗 = 줄기 밑 가운데). 메시 이름 "<틀>_<묶음>"(Wood·LeafA·LeafB).
	줄기는 부딪힘(볼록 껍질), 잎은 안 부딪힘(머리 위 잎에 걸려 못 걷는 일 없게, 가볍게). 보고: /forestkit
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local RGB = Color3.fromRGB
local M = Enum.Material
local CF = Enum.CollisionFidelity

-- 묶음 → { 색, 재질, 부딪힘 }  (평원 나무 색)
local SKIN = {
	Wood = { RGB(74, 55, 40), M.Wood, true },
	LeafA = { RGB(60, 94, 50), M.Grass, false },
	LeafB = { RGB(36, 62, 38), M.Grass, false },
}

local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local ok, err = pcall(function()
	local marker
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == "ForestKitOrigin_Marker" then
			marker = d
			break
		end
	end
	assert(marker, "ForestKitOrigin_Marker 없음(가져오지 않음)")
	local imported = marker:FindFirstAncestorWhichIsA("Model") or marker.Parent
	local k = 1 / marker.Size.X
	local root = SS:FindFirstChild("ForestKit") or Instance.new("Folder")
	root.Name = "ForestKit"
	root.Parent = SS
	local models, n = {}, 0
	for _, mp in imported:GetDescendants() do
		if not mp:IsA("MeshPart") or mp == marker then
			continue
		end
		local model, group = string.match(mp.Name, "^(.+)_(%a+)$")
		local skin = group and SKIN[group]
		if not skin then
			say("모르는 이름 %s", mp.Name)
			continue
		end
		if not models[model] then
			local old = root:FindFirstChild(model)
			if old then
				old:Destroy()
			end
			local m = Instance.new("Model")
			m.Name = model
			local pivot = Instance.new("Part")
			pivot.Name = "Origin"
			pivot.Size = Vector3.new(1, 1, 1)
			pivot.Transparency = 1
			pivot.Anchored = true
			pivot.CanCollide, pivot.CanQuery, pivot.CanTouch = false, false, false
			pivot.CFrame = CFrame.new()
			pivot.Parent = m
			m.PrimaryPart = pivot
			m.Parent = root
			models[model] = m
		end
		local rel = marker.CFrame:ToObjectSpace(mp.CFrame)
		mp.Size = mp.Size * k
		mp.CFrame = CFrame.new(rel.Position * k) * rel.Rotation
		mp.Anchored = true
		mp.Color, mp.Material = skin[1], skin[2]
		mp.CollisionFidelity = CF.Hull
		mp.CanCollide = skin[3]
		mp.CanQuery = skin[3]
		mp.CanTouch = false
		mp.CastShadow = true
		mp.DoubleSided = false
		mp.Name = group
		mp.Parent = models[model]
		n += 1
	end
	for key, m in models do
		local cf, size = m:GetBoundingBox()
		say("%s: 조각 %d, 크기 %.0f×%.0f×%.0f, 가운데 %.1f,%.1f,%.1f", key, #m:GetChildren() - 1, size.X, size.Y, size.Z, cf.X, cf.Y, cf.Z)
	end
	say("메시 %d개", n)
	imported:Destroy()
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/forestkit", table.concat(lines, "\n"))
