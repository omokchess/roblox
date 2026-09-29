--!nocheck
--[[
	Swamp_Kit.luau — 2026-09-28. SwampKit.fbx(안개늪 군도 에셋 41종)를 ServerStorage.SwampKit 틀로 가른다.

	메시 이름 "에셋__재질" 로 모델을 나누고 원점 표지(SwampOrigin_Marker)로 피벗을 되찾는다.
	재질은 참고 팔레트(Swamp_assets.luau PALETTE), 충돌은 참고와 같이: 보이는 메시는 부딪히지 않고
	명세의 단순 충돌체(블록·원통·사다리)를 보이지 않게 세운다. 불빛은 명세 자리에 점광원.
	실행: python tools/swamp_run.py 가 Swamp_assets.luau 를 넣어 Swamp_Kit_run.luau 를 만든다.
]]
local A = (function()
--@@ASSETS@@
end)()

local report = {}
local ok, err = pcall(function()
	local SS = game:GetService("ServerStorage")
	local kit = SS:FindFirstChild("SwampKit") or Instance.new("Folder")
	kit.Name = "SwampKit"
	kit.Parent = SS
	local imp = assert(workspace:FindFirstChild("SwampKit2") or workspace:FindFirstChild("SwampKit"), "Workspace.SwampKit(2) 가 없다(FBX 가져오기 먼저)")
	local marker = assert(imp:FindFirstChild("SwampOrigin_Marker", true), "원점 표지가 없다")
	local o = marker.Position
	-- 먼저 이름을 모두 검사하고 나서 옮긴다(도중에 멈추면 조각이 사라지므로)
	local groups = {}
	for _, p in ipairs(imp:GetDescendants()) do
		if p:IsA("BasePart") and p ~= marker then
			local asset, key = p.Name:match("^(.-)__(.+)$")
			assert(asset and A.ASSETS[asset], "모르는 에셋 " .. p.Name)
			if not A.PALETTE[key] then
				key = key:gsub("_%d+$", "") -- 같은 이름 메시는 가져올 때 _1 이 붙는다
			end
			assert(A.PALETTE[key], "팔레트에 없는 재질 " .. p.Name)
			groups[asset] = groups[asset] or {}
			table.insert(groups[asset], { p = p, key = key })
		end
	end
	local n, nCol, nLight = 0, 0, 0
	for asset, list in pairs(groups) do
		local old = kit:FindFirstChild(asset)
		if old then
			old:Destroy()
		end
		local m = Instance.new("Model")
		m.Name = asset
		for _, e in ipairs(list) do
			local p = e.p
			p.CFrame = p.CFrame - o
			local s = A.PALETTE[e.key]
			p.Material = Enum.Material[s[1]]
			p.Color = Color3.fromRGB(s[2], s[3], s[4])
			p.Transparency = s[5]
			p.Reflectance = s[6]
			p.CastShadow = s[7] and s[1] ~= "Neon"
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.RenderFidelity = Enum.RenderFidelity.Automatic
			p.Parent = m
		end
		local info = A.ASSETS[asset]
		for i, c in ipairs(info.colliders) do
			local shape = c[1]
			local q
			if shape == "Truss" then
				q = Instance.new("TrussPart")
			else
				q = Instance.new("Part")
				if shape == "Cylinder" then
					q.Shape = Enum.PartType.Cylinder
				end
			end
			-- { 모양, 자리 2..4, 회전 5..13, 크기 14..16, 꼬리표 17 }
			q.Name = "Collider_" .. (c[17] ~= "" and c[17] or shape)
			q.Anchored = true
			q.Transparency = 1
			q.CastShadow = false
			q.Size = Vector3.new(c[14], c[15], c[16])
			q.CFrame = CFrame.new(c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12], c[13])
			q.Parent = m
			nCol += 1
		end
		for _, l in ipairs(info.lights) do
			local a = Instance.new("Part")
			a.Name = "LightAnchor"
			a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
			a.Transparency = 1
			a.Size = Vector3.new(0.2, 0.2, 0.2)
			a.CFrame = CFrame.new(l[1], l[2], l[3])
			local pl = Instance.new("PointLight")
			pl.Color = Color3.fromRGB(l[4], l[5], l[6])
			pl.Range = l[7]
			pl.Brightness = l[8]
			pl.Shadows = false
			pl.Parent = a
			a.Parent = m
			nLight += 1
		end
		m.WorldPivot = CFrame.new()
		m.Parent = kit
		n += 1
	end
	imp:Destroy()
	report[#report + 1] = string.format("틀 %d, 충돌체 %d, 불빛 %d (표지 %.1f %.1f %.1f)", n, nCol, nLight, o.X, o.Y, o.Z)
end)
if not ok then
	report[#report + 1] = "ERR " .. tostring(err)
end
pcall(function()
	game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/swampkit", table.concat(report, "\n"))
end)
print("swampkit", table.concat(report, " / "))
