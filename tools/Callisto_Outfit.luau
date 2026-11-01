--!nocheck
--[[
	Callisto_Outfit.luau — 2026-11-01 4판. 블렌더 복장·가면(models/build_callisto_outfit.py → models/CallistoOutfit.glb)을 3D 가져오기로 넣은 뒤
	관절 부품별로 나눠 ReplicatedStorage.CallistoAssets.Outfit 에 둔다. 클라이언트 Combat/Callisto 가 복제해 붙인다.
	  메시 이름 = 앞머리_재질 — CalT 몸통 · CalRA 오른팔 · CalLA 왼팔 · CalRL 오른다리 · CalLL 왼다리 · CalH 머리(가면).
	  원점 표지 CalOrigin_Marker = 몸통 가운데 1×1×1 — 자리를 빼서 원점을, 크기로 스터드 배율(k)을 되찾는다.
	  부품마다 속성 Host(붙일 관절 부품 이름) · Offset(그 부품의 쉬는 자리에서 본 CFrame).
	  재질은 가져오기가 만든 SurfaceAppearance(색·법선·거칠기·금속 — 텍스처 models/callisto_tex)를 그대로 쓴다.
	  없으면 아래 SKIN 색·재질로 대신하고, Glow(별빛)는 늘 Neon.
	쉬는 자리(몸통 기준, 로블록스): 몸통 (0,0,0) · 오른팔 (1.5,0,0) · 왼팔 (-1.5,0,0) · 오른다리 (0.5,-2,0) · 왼다리 (-0.5,-2,0) · 머리 (0,1.5,0)
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
	CalH = { "Head", CFrame.new(0, 1.5, 0) },
}
local SKIN = {
	Tweed = { RGB(110, 74, 48), M.Fabric },
	Silk = { RGB(30, 40, 92), M.Fabric },
	Suede = { RGB(86, 55, 36), M.Fabric },
	Poplin = { RGB(240, 237, 230), M.Fabric },
	Twill = { RGB(30, 30, 35), M.Fabric },
	Leather = { RGB(94, 56, 33), M.Leather },
	GloveLeather = { RGB(32, 27, 27), M.Leather },
	SoleLeather = { RGB(46, 31, 24), M.Leather },
	Brass = { RGB(206, 164, 80), M.Metal },
	Gold = { RGB(228, 186, 100), M.Metal },
	Pearl = { RGB(244, 240, 233), M.SmoothPlastic },
	Porcelain = { RGB(245, 241, 232), M.SmoothPlastic },
	Velvet = { RGB(22, 24, 46), M.Fabric },
	Glow = { RGB(156, 200, 255), M.Neon },
}
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end
local ok, err = pcall(function()
	local marker
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "CalOrigin_Marker" then
			marker = d
			break
		end
	end
	assert(marker, "원점 표지 CalOrigin_Marker 가 없다(CallistoOutfit.glb 를 먼저 가져올 것)")
	local imp = marker:FindFirstAncestorWhichIsA("Model") or marker.Parent
	local k = 1 / marker.Size.X
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
	local n, withSa, per, leftX = 0, 0, {}, nil
	for _, p in imp:GetDescendants() do
		if p:IsA("MeshPart") and p ~= marker then
			local pre, key = p.Name:match("^(Cal%u%u?)_(%a+)$")
			local host = pre and HOST[pre]
			local skin = SKIN[key or ""]
			if not host or not skin then
				say("모르는 메시 %s", p.Name)
				continue
			end
			local rel = origin:ToObjectSpace(p.CFrame)
			local offset = host[2]:Inverse() * (CFrame.new(rel.Position * k) * rel.Rotation)
			p.Size = p.Size * k
			local sa = p:FindFirstChildOfClass("SurfaceAppearance")
			if key == "Glow" then
				if sa then
					sa:Destroy()
				end
				p.Color, p.Material = skin[1], skin[2]
			elseif sa then
				p.Material = skin[2]
				withSa += 1
			else
				p.Color, p.Material = skin[1], skin[2]
			end
			p.TextureID = ""
			p.Anchored = true
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
			p.CastShadow = key ~= "Glow"
			p:SetAttribute("Host", host[1])
			p:SetAttribute("Offset", offset)
			p.CFrame = host[2] * offset
			p.Parent = outfit
			n += 1
			per[pre] = (per[pre] or 0) + 1
			if pre == "CalLA" then
				leftX = rel.Position.X * k
			end
		end
	end
	outfit.Parent = folder
	imp:Destroy()
	local keys = {}
	for pre, c in per do
		keys[#keys + 1] = pre .. " " .. c
	end
	table.sort(keys)
	say("배율 k %.4f · 메시 %d (%s) · SurfaceAppearance %d", k, n, table.concat(keys, ", "), withSa)
	say("왼팔 조각 X %.2f (음수면 축이 맞다)", leftX or 0)
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/calout", table.concat(lines, "\n"))
