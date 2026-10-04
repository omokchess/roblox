--!nocheck
--[[
	Desert_Bones.luau — 2026-10-04. 블렌더 거대 생물 뼈(models/desert/build_bones.py → DesertBones.fbx)를 틀로 만들고 사막에 손으로 놓는다.
	사용자: "엄청 커다란 생물 뼈도 몇개 놔줘. 블렌더로 작업해서 놔줘."
	  1. Ctrl+M 으로 가져온 Workspace.DesertBones 가 있으면 조각(Bone_*)마다 ServerStorage.DesertKit.<이름> 틀로(밑면 가운데 = 피벗,
	     뼈 색·석회암 재질). 없으면 이미 만든 틀을 쓴다.
	  2. PLACE 표대로 Surface.R_사막.Bones(히든 분지 것은 R_사막.Hidden)에 놓는다 — 땅을 재서 sink 만큼 묻는다.
	돌림: 0 이면 머리(앞)가 -Z(북), 90 = 서, 180 = 남, 270 = 동. 다시 돌려도 된다(놓은 것만 새로). 보고: /desertbones
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local BONE = Color3.fromRGB(226, 214, 188)

-- { 틀, x, z, 돌림, 배율, 묻기, "Hidden"? }
local PLACE = {
	{ "Bone_Ribcage", 2735, -720, 30, 1.7, 4 }, -- 가운데 사구 위 거대 갈비뼈 우리
	{ "Bone_Tusk", 2420, -690, 200, 1.5, 3 }, -- 가운데사구 엄니 한 쌍
	{ "Bone_Tusk", 2447, -660, 160, 1.2, 3 },
	{ "Bone_Femur", 2262, -545, 35, 1.8, 2 }, -- 남쪽 사구 넓적다리뼈
	{ "Bone_Tail", 2680, -1235, 70, 1.6, 1 }, -- 북쪽 사구 꼬리
	{ "Bone_Skull", 2765, -862, 220, 0.9, 2 }, -- 모래첨탑 서쪽 두개골
	-- 히든 분지(협곡 끝 곶 안): 통째로 누운 짐승 — 머리는 어귀(서쪽)를 본다
	{ "Bone_Skull", 3505, -1062, 90, 1.5, 2, "Hidden" },
	{ "Bone_Ribcage", 3548, -1095, 90, 1.35, 5, "Hidden" },
	{ "Bone_Tail", 3555, -1150, 120, 1.3, 1, "Hidden" },
	{ "Bone_Femur", 3480, -1150, 70, 1.4, 2, "Hidden" },
}

local lines = {}
local ok, err = pcall(function()
	local kit = SS:FindFirstChild("DesertKit") or Instance.new("Folder")
	kit.Name = "DesertKit"
	kit.Parent = SS
	-- 1. 가져온 FBX → 틀
	local fresh = workspace:FindFirstChild("DesertBones")
	if fresh then
		for _, p in fresh:GetDescendants() do
			if p:IsA("MeshPart") and p.Name:match("^Bone_") then
				local m = Instance.new("Model")
				m.Name = p.Name
				p.Color, p.Material = BONE, Enum.Material.Limestone
				p.Anchored = true
				p.RenderFidelity = Enum.RenderFidelity.Precise
				p.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
				p.Parent = m
				local cf, size = p.CFrame, p.Size
				-- 밑면 가운데를 원점으로(돌림은 FBX 그대로 — 블렌더 -y 앞 = -Z)
				local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
				p.CFrame = cf - bottom
				m.WorldPivot = CFrame.new()
				local old = kit:FindFirstChild(m.Name)
				if old then
					old:Destroy()
				end
				m.Parent = kit
				table.insert(lines, "틀 " .. m.Name)
			end
		end
		fresh:Destroy()
	end
	-- 2. 놓기
	local desert = workspace.Surface:FindFirstChild("R_사막")
	assert(desert, "Surface.R_사막 이 없다 — Desert_Build 먼저")
	local bones = desert:FindFirstChild("Bones")
	if bones then
		bones:Destroy()
	end
	bones = Instance.new("Folder")
	bones.Name = "Bones"
	bones.Parent = desert
	local hidden = desert:FindFirstChild("Hidden")
	for _, c in hidden and hidden:GetChildren() or {} do
		if c.Name:match("^Bone_") then
			c:Destroy()
		end
	end
	local ground = {}
	for _, n in { "Land", "Dunes", "Mesas", "Canyon", "Shore", "TopPatches", "Bridges", "Ramps" } do
		local f = desert:FindFirstChild(n)
		if f then
			table.insert(ground, f)
		end
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = ground
	for i, e in PLACE do
		local tmpl = kit:FindFirstChild(e[1])
		assert(tmpl, "틀 없음 " .. e[1] .. " — FBX 를 먼저 가져올 것")
		local m = tmpl:Clone()
		m.Name = string.format("%s_%d", e[1], i)
		if e[5] ~= 1 then
			m:ScaleTo(e[5])
		end
		local hit = workspace:Raycast(Vector3.new(e[2], 400, e[3]), Vector3.new(0, -500, 0), ray)
		local y = if hit then hit.Position.Y else 4
		m:PivotTo(CFrame.new(e[2], y - e[6], e[3]) * CFrame.Angles(0, math.rad(e[4]), 0))
		m.Parent = if e[7] == "Hidden" and hidden then hidden else bones
	end
	table.insert(lines, string.format("놓음 %d(히든 %d)", #PLACE, 4))
end)
HS:PostAsync("http://127.0.0.1:34999/desertbones", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
