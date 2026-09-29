--!nocheck
--[[
	Swamp_Interiors.luau — 늪지대 집 실내: 받침벽(구멍 메움) + 인테리어. (2026-09-28)

	자료: tools/swamp/interiors.luau (tools/swamp_rooms.py 가 만든다; 로컬 서버 127.0.0.1:35000 에서 받음)
	Surface.Swamp2_늪지대 안의 집 모델(속성 Asset = Longhouse·StiltHouseA·StiltHouseB2·StiltHutC·WitchHut)마다
	자식 모델 "Interior2" 를 새로 세운다(있으면 지우고). 자리 = 집 피벗 × 에셋 좌표(틀 원점 = 피벗).
	부품은 부딪히지 않는다(집의 충돌은 원래 보이지 않는 단순 충돌체가 맡는다).
	되돌리기: 각 집의 Interior2 를 지우면 끝.
	보고: /swampinteriors
]]
local HS = game:GetService("HttpService")
local report = {}
local ok, err = pcall(function()
	local src = HS:GetAsync("http://127.0.0.1:35000/interiors.luau", true)
	local data = assert(loadstring(src))()
	local root = assert(workspace:FindFirstChild("Surface") and workspace.Surface:FindFirstChild("Swamp2_늪지대"), "Surface.Swamp2_늪지대 없음")
	local PAL = data.PALETTE
	local count = {}
	local nParts, nLights, nHouses = 0, 0, 0
	for _, m in ipairs(root:GetDescendants()) do
		local asset = m:IsA("Model") and m:GetAttribute("Asset")
		local spec = asset and data.ASSETS[asset]
		if spec then
			local old = m:FindFirstChild("Interior2")
			if old then
				old:Destroy()
			end
			local holder = Instance.new("Model")
			holder.Name = "Interior2"
			local pivot = m:GetPivot()
			local s = m:GetScale()
			for _, p in ipairs(spec.parts) do
				-- { 모양, 재질키, x,y,z, r00..r22, sx,sy,sz, 그림자 }
				local shape, key = p[1], p[2]
				local q
				if shape == "W" then
					q = Instance.new("WedgePart")
				else
					q = Instance.new("Part")
					if shape == "C" then
						q.Shape = Enum.PartType.Cylinder
					end
				end
				q.Size = Vector3.new(p[15] * s, p[16] * s, p[17] * s)
				if shape == "S" then
					-- 길쭉한 공은 Ball 모양이 못 하므로 구 메시로 크기를 따른다
					local mesh = Instance.new("SpecialMesh")
					mesh.MeshType = Enum.MeshType.Sphere
					mesh.Parent = q
				end
				q.CFrame = pivot * CFrame.new(p[3] * s, p[4] * s, p[5] * s, p[6], p[7], p[8], p[9], p[10], p[11], p[12], p[13], p[14])
				local c = PAL[key]
				local okMat = pcall(function()
					q.Material = Enum.Material[c[1]]
				end)
				if not okMat then
					q.Material = Enum.Material.SmoothPlastic
				end
				q.Color = Color3.fromRGB(c[2], c[3], c[4])
				q.Transparency = c[5]
				q.Reflectance = c[6]
				q.CastShadow = p[18] and c[7] and c[1] ~= "Neon"
				q.Anchored = true
				q.CanCollide = false
				q.CanTouch = false
				q.CanQuery = false
				q.TopSurface, q.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
				q.Name = key
				q.Parent = holder
				nParts += 1
			end
			for _, l in ipairs(spec.lights) do
				local a = Instance.new("Part")
				a.Name = "LightAnchor"
				a.Size = Vector3.new(0.2, 0.2, 0.2)
				a.Transparency = 1
				a.Anchored, a.CanCollide, a.CanTouch, a.CanQuery = true, false, false, false
				a.CastShadow = false
				a.CFrame = pivot * CFrame.new(l[1] * s, l[2] * s, l[3] * s)
				local pl = Instance.new("PointLight")
				pl.Color = Color3.fromRGB(l[4], l[5], l[6])
				pl.Range = l[7]
				pl.Brightness = l[8]
				pl.Shadows = false
				pl.Parent = a
				a.Parent = holder
				nLights += 1
			end
			holder.Parent = m
			nHouses += 1
			count[asset] = (count[asset] or 0) + 1
		end
	end
	local names = {}
	for k, v in pairs(count) do
		names[#names + 1] = string.format("%s×%d", k, v)
	end
	table.sort(names)
	report[#report + 1] = string.format("집 %d채(%s): 부품 %d, 불빛 %d", nHouses, table.concat(names, ", "), nParts, nLights)
end)
if not ok then
	report[#report + 1] = "ERR " .. tostring(err)
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/swampinteriors", table.concat(report, "\n"))
end)
print("swampinteriors", table.concat(report, " / "))
