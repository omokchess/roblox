--!nocheck
--[[
	Callisto_Outfit.luau — 2026-11-01. 블렌더 복장(models/build_callisto_outfit.py → models/CallistoOutfit.fbx)을 Ctrl+M 으로 가져온 뒤
	(Workspace.CallistoOutfit) 관절 부품별로 나눠 ReplicatedStorage.CallistoAssets.Outfit 에 둔다. 클라이언트 Combat/Callisto 가 복제해 붙인다.
	  메시 이름 = 앞머리_재질 — CalT 몸통 · CalRA 오른팔 · CalLA 왼팔(의수) · CalRL 오른다리 · CalLL 왼다리. 원점 표지 CalOrigin_Marker = 몸통 가운데.
	  부품마다 속성 Host(붙일 관절 부품 이름) · Offset(그 부품의 쉬는 자리에서 본 CFrame). 재질은 아래 SKIN.
	쉬는 자리(몸통 기준, 로블록스): 몸통 (0,0,0) · 오른팔 (1.5,0,0) · 왼팔 (-1.5,0,0) · 오른다리 (0.5,-2,0) · 왼다리 (-0.5,-2,0)
	보고: /calout
]]
local HS = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local RGB = Color3.fromRGB
local M = Enum.Material
local HOST = {
	CalT = { "Torso", CFrame.new(0, 0, 0) },
	CalRA = { "Right Arm", CFrame.new(1.5, 0, 0) },
	CalLA = { "Left Arm", CFrame.new(-1.5, 0, 0) },
	CalRL = { "Right Leg", CFrame.new(0.5, -2, 0) },
	CalLL = { "Left Leg", CFrame.new(-0.5, -2, 0) },
}
local SKIN = {
	Jacket = { RGB(110, 74, 48), M.Fabric },
	JacketDark = { RGB(74, 47, 31), M.Fabric },
	Suede = { RGB(92, 59, 39), M.Fabric },
	Shirt = { RGB(236, 231, 220), M.Fabric },
	Trouser = { RGB(28, 28, 32), M.Fabric },
	TrouserLine = { RGB(52, 52, 60), M.Fabric },
	Leather = { RGB(62, 38, 24), M.Leather },
	Shoe = { RGB(74, 44, 26), M.Leather },
	Sole = { RGB(26, 20, 18), M.SmoothPlastic },
	Brass = { RGB(184, 145, 63), M.Metal },
	Iron = { RGB(58, 60, 66), M.Metal },
	Copper = { RGB(176, 106, 63), M.Metal },
	Pearl = { RGB(244, 241, 234), M.SmoothPlastic },
	StarGlow = { RGB(156, 200, 255), M.Neon },
	Skin = { RGB(246, 228, 218), M.SmoothPlastic },
}
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end
local ok, err = pcall(function()
	local imp = assert(workspace:FindFirstChild("CallistoOutfit"), "가져온 Workspace.CallistoOutfit 이 없다(Ctrl+M 먼저)")
	local marker = assert(imp:FindFirstChild("CalOrigin_Marker", true), "원점 표지가 없다")
	local origin = marker.CFrame
	local folder = RS:FindFirstChild("CallistoAssets") or Instance.new("Folder")
	folder.Name = "CallistoAssets"
	folder.Parent = RS
	local old = folder:FindFirstChild("Outfit")
	if old then
		old:Destroy()
	end
	local outfit = Instance.new("Model")
	outfit.Name = "Outfit"
	local n, per = 0, {}
	for _, p in imp:GetDescendants() do
		if p:IsA("MeshPart") and p ~= marker then
			local pre, key = p.Name:match("^(Cal%u%u?)_(.+)$")
			local host = pre and HOST[pre]
			local skin = SKIN[key or ""]
			if host and skin then
				local rel = origin:Inverse() * p.CFrame
				p:SetAttribute("Host", host[1])
				p:SetAttribute("Offset", host[2]:Inverse() * rel)
				p.Color, p.Material = skin[1], skin[2]
				p.Anchored = false
				p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
				p.CastShadow = key ~= "StarGlow"
				p.Parent = outfit
				n += 1
				per[host[1]] = (per[host[1]] or 0) + 1
			else
				say("모르는 메시 %s", p.Name)
			end
		end
	end
	outfit.Parent = folder
	imp:Destroy()
	local list = {}
	for k, v in per do
		table.insert(list, k .. " " .. v)
	end
	table.sort(list)
	say("복장 메시 %d (%s)", n, table.concat(list, " · "))
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/calout", table.concat(lines, "\n"))
