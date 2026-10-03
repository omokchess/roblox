--!nocheck
--[[
	Plains_Kit.luau — 2026-10-03. 블렌더 평원 키트·평원 북쪽 해안 띠를 가져온 모델을 가른다.

	models/plains/PlainsKit.fbx        (표지 PlainsKitOrigin_Marker)  → ServerStorage.PlainsKit.<틀>  (Model, 피벗 = 블렌더 원점 = 바닥 가운데)
	(해안 띠 PlainsNorthShore 는 2026-10-03 곡선 해안을 버리며 없앴다 — 표지가 없으면 건너뛴다)
	메시 이름 "<틀>_<묶음>". 묶음으로 색·재질·충돌을 입힌다(SKIN). 가져온 것만 갈아 끼운다. 보고: /plainskit
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local RGB = Color3.fromRGB
local M = Enum.Material
local CF = Enum.CollisionFidelity

-- 묶음 → { 색, 재질, 충돌 }
local SKIN = {
	Grass = { RGB(117, 151, 83), M.Grass, CF.PreciseConvexDecomposition },
	Rock = { RGB(120, 116, 106), M.Slate, CF.PreciseConvexDecomposition },
	Sand = { RGB(219, 200, 155), M.Sand, CF.PreciseConvexDecomposition },
	Stone = { RGB(157, 153, 139), M.Limestone, CF.PreciseConvexDecomposition },
	StoneDark = { RGB(126, 122, 110), M.Limestone, CF.PreciseConvexDecomposition },
}
-- 작은 바위는 볼록 껍질로 충분(가볍다)
local HULL = { Boulder_A = true, Boulder_B = true, Boulder_C = true, Rock_Spire = true }

local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local function split(markerName, holderName, world)
	local marker
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == markerName then
			marker = d
			break
		end
	end
	if not marker then
		say("%s 없음(가져오지 않음)", markerName)
		return
	end
	local imported = marker:FindFirstAncestorWhichIsA("Model") or marker.Parent
	local k = 1 / marker.Size.X
	local root = SS:FindFirstChild("PlainsKit")
	if not root then
		root = Instance.new("Folder")
		root.Name = "PlainsKit"
		root.Parent = SS
	end
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
		local key = if world then holderName else model
		if not models[key] then
			local old = root:FindFirstChild(key)
			if old then
				old:Destroy()
			end
			local m = Instance.new("Model")
			m.Name = key
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
			models[key] = m
		end
		local rel = marker.CFrame:ToObjectSpace(mp.CFrame)
		mp.Size = mp.Size * k
		mp.CFrame = CFrame.new(rel.Position * k) * rel.Rotation
		mp.Anchored = true
		mp.Color, mp.Material = skin[1], skin[2]
		mp.CollisionFidelity = if HULL[model] then CF.Hull else skin[3]
		mp.CanCollide = true
		mp.CanTouch = false
		mp.CastShadow = true
		mp.DoubleSided = false
		mp.Name = if world then mp.Name else group
		mp.Parent = models[key]
		n += 1
	end
	for key, m in models do
		local cf, size = m:GetBoundingBox()
		say("%s: 조각 %d, 크기 %.0f×%.0f×%.0f, 가운데 %.0f,%.0f,%.0f", key, #m:GetChildren() - 1, size.X, size.Y, size.Z, cf.X, cf.Y, cf.Z)
	end
	say("%s → 메시 %d개", markerName, n)
	if imported ~= workspace then
		imported:Destroy()
	end
end

local ok, err = pcall(function()
	split("PlainsKitOrigin_Marker", nil, false)
	split("PlainsNorthOrigin_Marker", "_Shore", true)
end)
HS:PostAsync("http://127.0.0.1:34999/plainskit", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
