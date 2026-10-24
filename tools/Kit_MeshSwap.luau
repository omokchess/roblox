--!nocheck
--[[
	Kit_MeshSwap.luau — 2026-10-24. 키트를 다시 내보낸 뒤(반짝임 고침, models/zfight_scan.py) 이미 놓인 모델의 MeshPart 를
	새 틀 것으로 갈아 끼운다. 지역을 다시 짓지 않는다(사용자 손이 섞였을 수 있다).

	1) FBX 가져오기 전에 한 번: ServerStorage.ZFight_OldKits 가 없으면 KITS 를 통째로 복사해 두고 끝난다(옛 틀 = 되돌릴 곳).
	2) 가져오기 → 가르기(Jeolhwa_Kit2 · Jeolhwa_Props · Roman_Kit · Ruins_Kit) 뒤에 다시 돌리면:
	   옛 틀과 새 틀에서 이름이 같은데 MeshId 가 바뀐 파트를 짝짓고, Workspace(사용자 것 USER 빼고)와 ServerStorage.JeolhwaKit
	   (Jeolhwa_Refresh 가 소품을 복사해 둔 Prop_* 틀)에서 옛 MeshId 를 쓰는 MeshPart 를 새 것 복제본으로 바꾼다.
	   자리 = 옛 파트 CFrame + 옛→새 틀 안 어긋남(면을 밀어 상자 가운데가 0.01 쯤 움직인다), 크기 = 새 틀 크기 × (옛 파트 / 옛 틀).
	   이름·색·재질·투명·충돌·속성·자식(불빛 등)은 옛 파트 것. 모델·피벗은 그대로. 다시 돌려도 된다(바꿀 것이 없으면 0).
	   틀(ServerStorage 키트)도 같은 식으로 = 옛 틀 복제본에 메시만 새것(속성 ZFightSwapped = 보관 Token). 가르기 스크립트가 새로 만든 틀에는
	   나중에 붙인 고침이 없어서다 — 곳간 Collider_Wall(Jeolhwa_GranaryWalls), 문간 충돌 끔(Jeolhwa_GateFix), 칼로도르 등불 표지 넷.
	되돌리기: 같은 세션의 _G.KitSwapUndo({새, 옛} 목록). 보고 /kitswap
	다음에 키트를 또 다시 낼 때는 ServerStorage.ZFight_OldKits 를 먼저 지우고 1) 부터(지난 보관은 이미 쓸모없다).
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local KITS = { "JeolhwaKit", "JeolhwaProps", "RomanKit", "RuinsKit", "SnowKit", "SwampKit" }
local USER = { Rig = true, Building_Hall = true, Fetra = true, MotionStudio = true }
local COPY = { "Name", "Color", "Material", "MaterialVariant", "Transparency", "Reflectance", "CanCollide", "CanQuery",
	"CanTouch", "CastShadow", "Anchored", "Locked", "Massless", "CollisionGroup" }

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local ok, err = pcall(function()
	local bak = SS:FindFirstChild("ZFight_OldKits")
	if not bak then
		bak = Instance.new("Folder")
		bak.Name = "ZFight_OldKits"
		bak:SetAttribute("Token", HS:GenerateGUID(false)) -- 이 보관 차례에 다시 만든 틀 표시(다음 차례엔 또 만든다)
		for _, n in ipairs(KITS) do
			local k = assert(SS:FindFirstChild(n), "ServerStorage." .. n .. " 이 없다")
			k:Clone().Parent = bak
			say("옛 틀 보관 %s %d", n, #k:GetChildren())
		end
		bak.Parent = SS
		return
	end

	-- 옛 MeshId → { 옛 틀 파트, 새 틀 파트 }
	local map, nPair = {}, 0
	for _, n in ipairs(KITS) do
		local old, new = bak:FindFirstChild(n), SS:FindFirstChild(n)
		for _, om in ipairs(old:GetChildren()) do
			local nm = new:FindFirstChild(om.Name)
			for _, op in ipairs(nm and om:GetChildren() or {}) do
				local np = op:IsA("MeshPart") and nm:FindFirstChild(op.Name)
				if np and np:IsA("MeshPart") and np.MeshId ~= op.MeshId and not map[op.MeshId] then
					map[op.MeshId] = { op, np }
					nPair += 1
				end
			end
		end
	end
	say("바뀐 틀 파트 %d", nPair)

	-- 담 틀은 Jeolhwa_WallHeight 가 바닥선 기준으로 세로만 늘려 두었다(속성 HeightScaled). 새 틀 파트도 같이 늘려 놓고 잰다.
	-- 바닥선은 HeightBase 속성이 있으면 그것(Wall_Corner 는 Jeolhwa_WallCorner 가 원점 y 0 기준으로 늘렸다), 없으면 가장 낮은 파트 밑면
	local bases = {}
	local function scaled(op, np)
		local f = op.Parent:GetAttribute("HeightScaled")
		if not f then
			return np.CFrame, np.Size
		end
		local m = np.Parent
		if not bases[m] then
			local b = math.huge
			for _, q in ipairs(m:GetChildren()) do
				if q:IsA("BasePart") and q.Name ~= "Foundation" then
					b = math.min(b, q.Position.Y - q.Size.Y / 2) -- 틀 파트는 돌지 않았다
				end
			end
			bases[m] = b
		end
		local b, pos = op.Parent:GetAttribute("HeightBase") or bases[m], np.Position
		return CFrame.new(pos.X, b + (pos.Y - b) * f, pos.Z) * np.CFrame.Rotation, np.Size * Vector3.new(1, f, 1)
	end

	local far, maxMove = 0, 0
	local function swap(p, e)
		local op, np = e[1], e[2]
		local ncf, nsize = scaled(op, np)
		local d = op.CFrame:ToObjectSpace(ncf)
		if d.Position.Magnitude > 0.5 then
			far += 1 -- 옛 틀이 원점에서 옮겨져 있었다 — 건드리지 않는다
			return nil
		end
		local s = p.Size / op.Size
		local c = np:Clone()
		c:ClearAllChildren()
		c.Size = nsize * s
		c.CFrame = p.CFrame * CFrame.new(d.Position * s) * d.Rotation
		for _, k in ipairs(COPY) do
			c[k] = p[k]
		end
		if c.CollisionFidelity ~= p.CollisionFidelity then
			c.CollisionFidelity = p.CollisionFidelity
		end
		if c.RenderFidelity ~= p.RenderFidelity then
			c.RenderFidelity = p.RenderFidelity
		end
		for k, v in pairs(p:GetAttributes()) do
			if not k:match("^RBX_") then
				c:SetAttribute(k, v)
			end
		end
		for _, ch in ipairs(p:GetChildren()) do
			ch.Parent = c
		end
		c.Parent = p.Parent
		p.Parent = nil
		maxMove = math.max(maxMove, (c.Position - p.Position).Magnitude)
		return c
	end

	-- 틀: 옛 틀 복제본에 메시만 새것. 갈아 끼울 새 틀 파트(np)를 아래에서도 복제하므로 갈아 넣기는 맨 끝에
	local fresh = {}
	for _, n in ipairs(KITS) do
		local live = SS:FindFirstChild(n)
		for _, om in ipairs(bak:FindFirstChild(n):GetChildren()) do
			local nm = live:FindFirstChild(om.Name)
			if nm and nm:GetAttribute("ZFightSwapped") ~= bak:GetAttribute("Token") then
				local t = om:Clone()
				local k = 0
				for _, p in ipairs(t:GetDescendants()) do
					local e = p:IsA("MeshPart") and map[p.MeshId]
					if e and swap(p, e) then
						k += 1
					end
				end
				if k > 0 then
					t:SetAttribute("ZFightSwapped", bak:GetAttribute("Token"))
					fresh[#fresh + 1] = { live, nm, t }
				else
					t:Destroy()
				end
			end
		end
	end

	local undo, per, userHit = {}, {}, 0
	for _, r in ipairs(workspace:GetChildren()) do
		for _, p in ipairs(r:GetDescendants()) do
			local e = p:IsA("MeshPart") and map[p.MeshId]
			if e and USER[r.Name] then
				userHit += 1
			elseif e then
				local c = swap(p, e)
				if c then
					undo[#undo + 1] = { c, p }
					local q = c
					while q.Parent ~= r do
						q = q.Parent
					end
					local key = r.Name .. "." .. q.Name
					per[key] = (per[key] or 0) + 1
				end
			end
		end
	end
	for _, f in ipairs(fresh) do
		f[2]:Destroy()
		f[3].Parent = f[1]
	end
	say("틀 다시 만듦(옛 틀 + 새 메시) %d", #fresh)
	_G.KitSwapUndo = undo
	local keys = {}
	for k in pairs(per) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		say("  %s %d", k, per[k])
	end
	say("갈아 끼움 %d, 가장 크게 움직인 가운데 %.3f, 옛 틀이 옮겨져 건너뜀 %d, 사용자 것(안 건드림) %d", #undo, maxMove, far, userHit)
end)
if not ok then
	say("ERR %s", tostring(err))
end
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/kitswap", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
print("kitswap", #report, ok)
