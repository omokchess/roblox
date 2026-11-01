--!nocheck
--[[
	Snow_BankDoors.luau — 2026-11-01. 은행 금고 문 · 양옆 입구를 닫는다(사용자: "나중에 관련 퀘스트로 열 수 있게 할 거니까 닫아 줘").
	  1) 은행 메시 갈아 끼우기: models/build_steam_service.py 에서 반쯤 연 금고 문짝을 뺐다 →
	     `ONLY=Svc_Bank blender -b -P models/build_steam_town.py` → models/SnowTownKit_Svc_Bank.fbx 를 Ctrl+M 으로 가져온 뒤(Workspace.SnowTownKit_Svc_Bank)
	     이 스크립트가 놓인 Svc_Bank(마을)와 틀(ServerStorage.SnowKit.Svc_Bank)의 같은 이름 MeshPart 를 새 메시로 바꾼다
	     (자리 = 바뀌지 않은 SvcBank_Stone 으로 원점을 맞춤, 색·재질·충돌 등은 옛 파트 것). 새 쪽에 없는 재질(문짝에만 있던 것)은 지운다.
	     가져온 모델이 없으면 이 단계는 건너뛴다(문만 다시 지을 때).
	  2) 놓인 Svc_Bank 의 충돌 폴더에서 열린 문짝 충돌 상자(62° 돌아간 8.8×0.9×8.8)를 지운다.
	  3) 닫힌 문을 부품으로(놓인 Svc_Bank 안 "퀘스트문" 폴더 — 다시 돌리면 지우고 새로):
	     금고 문(원판·놋쇠 테·바퀴·빗장·다이얼·이름판) / 옆문 쇠살문 둘(틀·살·자물쇠 + 안 보이는 막이).
	     모델마다 속성 QuestLocked = true · QuestDoor = 이름 · Hinge(금고 문 경첩 자리, 월드), 태그 QuestDoor — 퀘스트가 열 때 쓴다.
	  좌표: 블렌더 (x, y, z) → 모델 안 (-x, z, y). 은행 W 36 · 벽 T 1 · 바닥 FZ 0.4 · 뒷벽 안면 y 14 · 금고 문 가운데 높이 5.9 · 옆문 y -3.5 ~ 2.5 높이 9.
	Snow_City2 로 마을을 다시 지으면 이것도 다시 돌릴 것(퀘스트문은 놓인 모델 안에 있다). 보고: /bankdoors
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local RGB = Color3.fromRGB
local M = Enum.Material
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local IRON, STEEL, BRASS, PAINT = RGB(58, 60, 66), RGB(120, 124, 130), RGB(196, 160, 78), RGB(236, 232, 220)
local COPY = { "Name", "Color", "Material", "MaterialVariant", "Transparency", "Reflectance", "CanCollide", "CanQuery", "CanTouch", "CastShadow", "Anchored" }

local ok, err = pcall(function()
	local town = assert(workspace:FindFirstChild("Schneereich"), "Schneereich 가 없다")
	local placed = {}
	for _, d in town:GetDescendants() do
		if d:IsA("Model") and d.Name == "Svc_Bank" then
			table.insert(placed, d)
		end
	end
	assert(#placed > 0, "놓인 Svc_Bank 가 없다")
	local kit = SS:FindFirstChild("SnowKit")
	local template = kit and kit:FindFirstChild("Svc_Bank")

	-- 1) 메시 갈아 끼우기
	local imported = workspace:FindFirstChild("SnowTownKit_Svc_Bank")
	local newParts = {}
	local origins = {} -- 모델 → 블렌더 원점(바뀌지 않은 Stone 으로 맞춘 것)
	if imported then
		local marker = imported:FindFirstChild("SnowTownOrigin_Marker", true)
		local markerCF = if marker then marker.CFrame else imported:GetPivot()
		for _, p in imported:GetDescendants() do
			if p:IsA("MeshPart") and p ~= marker then
				newParts[p.Name] = p
			end
		end
		local targets = table.clone(placed)
		if template then
			table.insert(targets, template)
		end
		for _, target in targets do
			local ref = target:FindFirstChild("SvcBank_Stone")
			local newRef = newParts.SvcBank_Stone
			assert(ref and newRef, "SvcBank_Stone 이 없다")
			-- 원점: 옛 Stone = 원점 * (표지 → 새 Stone)
			local origin = ref.CFrame * (markerCF:Inverse() * newRef.CFrame):Inverse()
			origins[target] = origin
			local swapped, removed, worst = 0, 0, 0
			for _, old in target:GetChildren() do
				if old:IsA("MeshPart") and old.Name:sub(1, 8) == "SvcBank_" then
					local src = newParts[old.Name]
					if not src then
						old:Destroy()
						removed += 1
						continue
					end
					local q = src:Clone()
					q.CFrame = origin * (markerCF:Inverse() * src.CFrame)
					for _, k in COPY do
						q[k] = old[k]
					end
					pcall(function()
						q.CollisionFidelity = old.CollisionFidelity
					end)
					for k, v in old:GetAttributes() do
						q:SetAttribute(k, v)
					end
					for _, c in old:GetChildren() do
						c.Parent = q
					end
					-- 문짝과 상관없는 재질은 자리가 그대로여야 한다(맞춤 점검)
					if math.abs(q.Size.Magnitude - old.Size.Magnitude) < 0.05 then
						worst = math.max(worst, (q.Position - old.Position).Magnitude)
					end
					q.Parent = target
					old:Destroy()
					swapped += 1
				end
			end
			say("%s: 메시 %d 바꿈 · %d 지움 · 그대로인 재질 자리 어긋남 최대 %.3f", target:GetFullName(), swapped, removed, worst)
		end
		imported:Destroy()
	else
		say("가져온 SnowTownKit_Svc_Bank 없음 — 메시는 그대로, 문만 다시")
	end

	for _, bank in placed do
		-- 모델 원점(블렌더 원점): 메시를 갈았으면 Stone 으로 맞춘 원점, 아니면 피벗(바닥 가운데 — 마을 짓기가 틀 피벗 그대로 놓는다)
		local O = origins[bank] or bank:GetPivot()
		say("%s: 원점 − 피벗 %.3f", bank.Name, (O.Position - bank:GetPivot().Position).Magnitude)
		local function at(bx, by, bz)
			return O * CFrame.new(-bx, bz, by)
		end
		-- 2) 열린 문짝 충돌 상자(블렌더 (-2.3, 9.17, 5.9) 둘레, 8.8 × 0.9 × 8.8)
		local coll = bank:FindFirstChild("충돌")
		local cut = 0
		for _, c in (coll and coll:GetChildren()) or {} do
			if c:IsA("BasePart") then
				local lp = O:PointToObjectSpace(c.Position)
				local sz = { c.Size.X, c.Size.Y, c.Size.Z }
				table.sort(sz)
				if (lp - Vector3.new(2.3, 5.9, 9.17)).Magnitude < 1.5 and math.abs(sz[3] - 8.8) < 0.3 and math.abs(sz[1] - 0.9) < 0.3 then
					c:Destroy()
					cut += 1
				end
			end
		end
		say("%s: 열린 문짝 충돌 상자 %d 지움", bank:GetFullName(), cut)

		-- 3) 닫힌 문
		local old = bank:FindFirstChild("퀘스트문")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "퀘스트문"
		local function part(parent, name, size, cf, color, mat, shape)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.Size = size
			p.CFrame = cf
			p.Color, p.Material = color, mat
			if shape then
				p.Shape = shape
			end
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Parent = parent
			return p
		end
		local function door(name)
			local m = Instance.new("Model")
			m.Name = name
			m:SetAttribute("QuestLocked", true)
			m:SetAttribute("QuestDoor", name)
			CS:AddTag(m, "QuestDoor")
			m.Parent = folder
			return m
		end
		-- 금고 문: 원판(블렌더 y 13.15 ~ 13.85, 반지름 4.4)이 구멍(반지름 4.1)을 덮는다. 앞 = 홀 쪽(블렌더 -y)
		local vault = door("은행 금고 문")
		local Z = CFrame.Angles(0, math.rad(90), 0) -- 원기둥 축(X)을 모델 Z(문에 수직)로
		local face = function(bx, by, bz)
			return at(bx, by, bz) * Z
		end
		local disc = part(vault, "문판", Vector3.new(0.7, 8.8, 8.8), face(0, 13.5, 5.9), IRON, M.Metal, Enum.PartType.Cylinder)
		part(vault, "놋쇠테", Vector3.new(0.12, 9.0, 9.0), face(0, 13.1, 5.9), BRASS, M.Metal, Enum.PartType.Cylinder)
		part(vault, "안판", Vector3.new(0.08, 8.2, 8.2), face(0, 13.03, 5.9), IRON, M.DiamondPlate, Enum.PartType.Cylinder)
		part(vault, "바퀴통", Vector3.new(0.3, 1.0, 1.0), face(0, 12.85, 5.9), BRASS, M.Metal, Enum.PartType.Cylinder)
		for k = 0, 5 do
			local a = k * math.pi / 3
			local cx, cz = 0.9 * math.cos(a), 5.9 + 0.9 * math.sin(a)
			part(vault, "바퀴살", Vector3.new(1.8, 0.14, 0.12), at(cx, 12.8, cz) * CFrame.Angles(0, 0, -a), BRASS, M.Metal)
			part(vault, "손잡이", Vector3.new(0.34, 0.34, 0.34), at(1.8 * math.cos(a), 12.72, 5.9 + 1.8 * math.sin(a)), BRASS, M.Metal, Enum.PartType.Ball)
		end
		for k = 0, 7 do
			local a = k * math.pi / 4
			part(vault, "볼트", Vector3.new(0.2, 0.44, 0.44), face(3.6 * math.cos(a), 13.0, 5.9 + 3.6 * math.sin(a)), STEEL, M.Metal, Enum.PartType.Cylinder)
		end
		for _, dz in { -1.2, 0, 1.2 } do
			part(vault, "빗장", Vector3.new(2.8, 0.16, 0.1), at(2.6, 12.98, 5.9 + dz), STEEL, M.Metal)
		end
		part(vault, "다이얼", Vector3.new(0.06, 0.9, 0.9), face(2.3, 12.95, 8.2), PAINT, M.SmoothPlastic, Enum.PartType.Cylinder)
		part(vault, "다이얼테", Vector3.new(0.04, 1.04, 1.04), face(2.3, 12.97, 8.2), BRASS, M.Metal, Enum.PartType.Cylinder)
		part(vault, "이름판", Vector3.new(1.4, 0.4, 0.04), at(-2.4, 12.96, 2.9), BRASS, M.Metal)
		vault.PrimaryPart = disc
		vault:SetAttribute("Hinge", at(-4.75, 13.25, 5.9).Position)
		-- 옆문 쇠살문 둘(벽 두께 가운데 x = ±17.5, y -3.5 ~ 2.5, 높이 0.4 ~ 9.4)
		for i, s in { -1, 1 } do
			local gate = door("은행 옆문 " .. i)
			local x = s * 17.5
			local block = part(gate, "막이", Vector3.new(0.4, 9.0, 6.0), at(x, -0.5, 4.9), IRON, M.Metal)
			block.Transparency = 1
			for _, y in { -3.35, 2.35 } do
				local post = part(gate, "기둥", Vector3.new(0.3, 9.0, 0.3), at(x, y, 4.9), IRON, M.Metal)
				post.CanCollide = false
			end
			for _, z in { 0.6, 4.9, 9.2 } do
				local rail = part(gate, "가로대", Vector3.new(0.3, 0.3, 6.0), at(x, -0.5, z), IRON, M.Metal)
				rail.CanCollide = false
			end
			for k = 0, 9 do
				local bar = part(gate, "살", Vector3.new(0.14, 8.6, 0.14), at(x, -3.0 + k * 0.55, 4.9), STEEL, M.Metal)
				bar.CanCollide = false
			end
			for _, dx in { -0.25, 0.25 } do
				local lock = part(gate, "자물쇠", Vector3.new(0.2, 0.8, 0.5), at(x + dx, -0.5, 4.9), BRASS, M.Metal)
				lock.CanCollide = false
			end
			gate.PrimaryPart = block
		end
		folder.Parent = bank
		say("%s: 퀘스트문 3(금고 문 · 옆문 둘) — 금고 문 가운데 %s", bank:GetFullName(), tostring(disc.Position))
	end
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/bankdoors", table.concat(lines, "\n"))
