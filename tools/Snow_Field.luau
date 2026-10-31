--!nocheck
--[[
	Snow_Field.luau — 2026-10-09(2026-10-31 얼어붙은 호수 · 설공방 폐허 · 명소). 설원 지상 마무리(편집 모드, StudioJobs): 호수·폐허·휴식처 2/8·눈 나무·큰 바위.
	호수 자리 땅(R_설원3.Land)은 LAKE_CARVE 상자로 판다(상자 빼기 — 처음 판은 ServerStorage.Snow_LakeOriginal, 몇 번 돌려도 같다).
	자료 tools/snow_field_plan.py → Snow_Field_data.luau:
	  python tools/snow_field_plan.py && sed '/--@@DATA@@/r tools/Snow_Field_data.luau' tools/Snow_Field.luau > tools/swamp/_field_run.luau && bash tools/job.sh tools/swamp/_field_run.luau
	Surface.R_설원3_장식 만 지우고 새로. 나무 = ServerStorage.ForestKit 틀의 잎을 눈 색으로(사용자 참고 사진: 하얀·푸른 잎 덩어리).
	표지: BossTrigger(태그 BossTrigger — 속성 EnemyId·Radius, 들어가면 BattleService 가 싸움을 연다) · Fog(호수 안개 입자) ·
	QuestItem(속성 QuestItem) · Campfire · Brazier(화로 불·빛) · Ember(화덕 불씨 — 작은 불·연기·빛) ·
	Sign(상자 BOXES[Index] 에 글씨) · Spot(순간이동 명소 — 태그 TeleportSpot, 속성 SpotName·Region·Order, LookX/LookZ 를 본다). 보고: /snowfield
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local RGB = Color3.fromRGB
local M = Enum.Material

--@@DATA@@

local SKIN = {
	ArenaStone = { RGB(88, 94, 102), M.Slate },
	ArenaIce = { RGB(170, 205, 230), M.Glacier },
	PillarRock = { RGB(100, 110, 106), M.Slate },
	PillarRock2 = { RGB(88, 97, 95), M.Slate },
	SnowCap = { RGB(238, 243, 247), M.Snow },
	RestStone = { RGB(120, 118, 112), M.Slate },
	FireRock = { RGB(70, 66, 62), M.Basalt },
	Timber = { RGB(90, 62, 44), M.WoodPlanks },
	Grate = { RGB(58, 60, 66), M.DiamondPlate },
	-- 얼어붙은 호수
	LakeIce = { RGB(160, 180, 196), M.Glacier },
	IceCrack = { RGB(70, 96, 118), M.Glacier, true },
	IceSnow = { RGB(236, 241, 246), M.Snow, true },
	LakeRock = { RGB(78, 80, 84), M.Slate },
	LakeRock2 = { RGB(64, 66, 70), M.Slate },
	CliffRock = { RGB(92, 98, 104), M.Slate },
	DeadWood = { RGB(196, 198, 200), M.Wood },
	DeadWood2 = { RGB(150, 146, 142), M.Wood },
	-- (옛 보스룸 2판 묶음 — 지금 자료엔 없음)
	ArenaStone2 = { RGB(104, 110, 118), M.Slate },
	ArenaIron = { RGB(60, 62, 68), M.DiamondPlate },
	ArenaEdge = { RGB(70, 74, 82), M.Slate },
	Tier = { RGB(96, 102, 110), M.Slate },
	Tier2 = { RGB(84, 90, 98), M.Slate },
	TierSnow = { RGB(238, 243, 247), M.Snow },
	Column = { RGB(140, 138, 132), M.Limestone },
	Column2 = { RGB(124, 122, 118), M.Limestone },
	Banner = { RGB(112, 30, 42), M.Fabric, true },
	Banner2 = { RGB(90, 24, 34), M.Fabric, true },
	GateTower = { RGB(100, 104, 110), M.Cobblestone },
	Iron = { RGB(52, 54, 60), M.Metal },
	Ice = { RGB(176, 218, 242), M.Glacier },
	Drift = { RGB(240, 244, 248), M.Snow },
	-- (구)설공방 폐허
	RuinStone = { RGB(128, 124, 116), M.Cobblestone },
	RuinStone2 = { RGB(112, 108, 100), M.Cobblestone },
	Plinth = { RGB(118, 116, 110), M.Slate },
	Plinth2 = { RGB(104, 102, 96), M.Slate },
	Char = { RGB(36, 30, 28), M.Wood },
	Char2 = { RGB(48, 38, 32), M.Wood },
	Plank = { RGB(44, 36, 30), M.WoodPlanks },
	Brick = { RGB(96, 58, 48), M.Brick },
	Soot = { RGB(22, 20, 20), M.Slate, true },
	Crate = { RGB(58, 44, 34), M.WoodPlanks },
	Sign = { RGB(74, 56, 40), M.WoodPlanks },
}
local LEAF = { LeafA = RGB(232, 240, 248), LeafB = RGB(196, 212, 228) }
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local ok, err = pcall(function()
	local S = workspace.Surface
	local old = S:FindFirstChild("R_설원3_장식")
	if old then
		old:Destroy()
	end
	-- 옛 폐허(Snow_City2 가 놓던 Sel_Werk_Ruin · 보일러 · 큰 톱니 — 2026-10-31 이 폐허로 바꿈)는 ServerStorage 로 옮겨 둔다
	local town = workspace:FindFirstChild("Schneereich")
	local oldRuin = town and town:FindFirstChild("마을") and town["마을"]:FindFirstChild("설공방")
	if oldRuin then
		local prevBak = SS:FindFirstChild("Snow_SelRuin_Old")
		if prevBak then
			prevBak:Destroy()
		end
		oldRuin.Name = "Snow_SelRuin_Old"
		oldRuin.Parent = SS
		say("옛 설공방 폐허 → ServerStorage.Snow_SelRuin_Old")
	end
	local root = Instance.new("Folder")
	root.Name = "R_설원3_장식"
	local fold = {}
	local function folder(n)
		if not fold[n] then
			local f = Instance.new("Folder")
			f.Name = n
			f.Parent = root
			fold[n] = f
		end
		return fold[n]
	end
	-- 호수 자리 땅 파기(상자 빼기). 처음 판은 ServerStorage.Snow_LakeOriginal 에 둔다
	do
		local function sub(lo, hi, clo, chi)
			for _, ax in ipairs({ "X", "Y", "Z" }) do
				if math.min(hi[ax], chi[ax]) - math.max(lo[ax], clo[ax]) <= 1e-3 then
					return nil
				end
			end
			local out = {}
			local l, h = { X = lo.X, Y = lo.Y, Z = lo.Z }, { X = hi.X, Y = hi.Y, Z = hi.Z }
			for _, ax in ipairs({ "X", "Y", "Z" }) do
				if clo[ax] > l[ax] + 1e-3 then
					local a, b = table.clone(l), table.clone(h)
					b[ax] = clo[ax]
					out[#out + 1] = { Vector3.new(a.X, a.Y, a.Z), Vector3.new(b.X, b.Y, b.Z) }
					l[ax] = clo[ax]
				end
				if chi[ax] < h[ax] - 1e-3 then
					local a, b = table.clone(l), table.clone(h)
					a[ax] = chi[ax]
					out[#out + 1] = { Vector3.new(a.X, a.Y, a.Z), Vector3.new(b.X, b.Y, b.Z) }
					h[ax] = chi[ax]
				end
			end
			return out
		end
		local land = S["R_설원3"].Land
		local store = SS:FindFirstChild("Snow_LakeOriginal") or Instance.new("Folder")
		store.Name = "Snow_LakeOriginal"
		store.Parent = SS
		local cut = 0
		for _, p in ipairs(land:GetChildren()) do
			if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.CFrame.XVector.X > 0.9999 and p.CFrame.YVector.Y > 0.9999 then
				local list, hit = { { p.Position - p.Size / 2, p.Position + p.Size / 2 } }, false
				for _, c in LAKE_CARVE do
					local nextList = {}
					for _, bx in ipairs(list) do
						local rest = sub(bx[1], bx[2], Vector3.new(c[1], c[3], c[5]), Vector3.new(c[2], c[4], c[6]))
						if rest then
							hit = true
							table.move(rest, 1, #rest, #nextList + 1, nextList)
						else
							nextList[#nextList + 1] = bx
						end
					end
					list = nextList
				end
				if hit then
					cut += 1
					if not store:FindFirstChild(p:GetFullName()) then
						local keep = p:Clone()
						keep.Name = p:GetFullName()
						keep.Parent = store
					end
					for i, bx in ipairs(list) do
						local q = p:Clone()
						q.Name = p.Name .. (if i > 1 then "_" .. i else "")
						q.Size = bx[2] - bx[1]
						q.CFrame = CFrame.new((bx[1] + bx[2]) / 2)
						q.Parent = land
					end
					p:Destroy()
				end
			end
		end
		say("호수 땅 파기 %d판", cut)
	end
	-- 묶음 폴더: 호수 가운데 320 · 폐허 가운데 120 안이면 그쪽(눈 윗판·쇠처럼 둘 다 쓰는 묶음 때문에 자리로 가른다)
	local bossAt, ruinAt
	for _, mk in MARKS do
		if mk[1] == "BossTrigger" then
			bossAt = Vector3.new(mk[2], 0, mk[4])
		elseif mk[1] == "Spot" and mk[5].SpotName == "설공방 폐허" then
			ruinAt = Vector3.new(mk[5].LookX, 0, mk[5].LookZ)
		end
	end
	local built = {}
	for i, b in BOXES do
		local g = b[1]
		local s = SKIN[g]
		local p = Instance.new("Part")
		p.Name = g .. i
		p.Anchored = true
		p.Size = Vector3.new(b[5], b[6], b[7])
		p.CFrame = CFrame.new(b[2], b[3], b[4]) * CFrame.Angles(0, math.rad(b[8]), 0) * CFrame.Angles(math.rad(b[9] or 0), 0, math.rad(b[10] or 0))
		p.Color, p.Material = s[1], s[2]
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if s[3] then
			p.CanCollide = false
		end
		if g == "Ice" then
			p.Transparency = 0.12
		end
		local at = Vector3.new(b[2], 0, b[4])
		p.Parent = folder(if bossAt and (at - bossAt).Magnitude < 320 then "얼어붙은 호수" elseif ruinAt and (at - ruinAt).Magnitude < 120 then "설공방 폐허" else "돌")
		built[i] = p
	end
	local kit = SS:FindFirstChild("SnowKit")
	for _, k in KITS do
		local src = kit and kit:FindFirstChild(k[1])
		if src then
			local m = src:Clone()
			m:ScaleTo(k[6])
			m:PivotTo(CFrame.new(k[2], k[3], k[4]) * CFrame.Angles(0, math.rad(k[5]), math.rad(k[7] or 12)))
			m.Parent = folder(if bossAt and (Vector3.new(k[2], 0, k[4]) - bossAt).Magnitude < 320 then "얼어붙은 호수" else "설공방 폐허")
		end
	end
	for _, mk in MARKS do
		local name, x, y, z, attrs = mk[1], mk[2], mk[3], mk[4], mk[5]
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(2, 2, 2)
		p.CFrame = CFrame.new(x, y, z)
		for k, v in attrs do
			p:SetAttribute(k, v)
		end
		if name == "Campfire" then
			p.Transparency = 1
			local f = Instance.new("Fire")
			f.Size = 6
			f.Heat = 8
			f.Parent = p
			local l = Instance.new("PointLight")
			l.Color = RGB(255, 170, 90)
			l.Range = 28
			l.Brightness = 2
			l.Parent = p
		elseif name == "Fog" then
			-- 얼어붙은 호수 위를 낮게 흐르는 안개(큰 연기 입자를 아주 옅게, 천천히)
			p.Transparency = 1
			p.CanQuery, p.CanTouch = false, false
			p.Size = Vector3.new(60, 2, 60)
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Color = ColorSequence.new(RGB(220, 232, 242))
			e.LightEmission = 0.15
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 26), NumberSequenceKeypoint.new(1, 46) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 1) })
			e.Lifetime = NumberRange.new(9, 14)
			e.Rate = 1.2
			e.Speed = NumberRange.new(1, 2.5)
			e.SpreadAngle = Vector2.new(180, 6)
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-6, 6)
			e.Parent = p
		elseif name == "BossTrigger" then
			p.Transparency = 1
			p.CanQuery, p.CanTouch = false, false
			game:GetService("CollectionService"):AddTag(p, "BossTrigger")
		elseif name == "Brazier" then
			p.Transparency = 1
			p.CanQuery = false
			local f = Instance.new("Fire")
			f.Size, f.Heat = 7, 10
			f.Parent = p
			local l = Instance.new("PointLight")
			l.Color = RGB(255, 160, 80)
			l.Range, l.Brightness = 46, 2
			l.Shadows = true
			l.Parent = p
		elseif name == "Ember" then
			-- 불탄 공방 화덕에 아직 남은 불씨: 작은 불 · 옅은 연기 · 낮은 주황 빛
			p.Transparency = 1
			p.CanQuery = false
			local f = Instance.new("Fire")
			f.Size, f.Heat = 2, 3
			f.Color, f.SecondaryColor = RGB(255, 120, 40), RGB(160, 40, 20)
			f.Parent = p
			local sm = Instance.new("Smoke")
			sm.Color = RGB(70, 66, 64)
			sm.Opacity, sm.RiseVelocity, sm.Size = 0.12, 3, 2
			sm.Parent = p
			local l = Instance.new("PointLight")
			l.Color = RGB(255, 110, 50)
			l.Range, l.Brightness = 14, 0.9
			l.Parent = p
		elseif name == "Sign" then
			p.Transparency = 1
			p.CanQuery = false
			local board = built[attrs.Index]
			if board then
				local sg = Instance.new("SurfaceGui")
				sg.Face = Enum.NormalId.Front
				sg.PixelsPerStud = 40
				sg.LightInfluence = 1
				local t = Instance.new("TextLabel")
				t.Size = UDim2.fromScale(1, 1)
				t.BackgroundTransparency = 1
				t.Text = attrs.Text
				t.TextScaled = true
				t.Font = Enum.Font.Fantasy
				t.TextColor3 = RGB(30, 22, 18)
				t.Parent = sg
				sg.Parent = board
			end
		elseif name == "Spot" then
			p.Transparency = 1
			p.CanQuery, p.CanTouch = false, false
			p.CFrame = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(attrs.LookX, y, attrs.LookZ))
			p.Name = "Spot_" .. attrs.SpotName
			game:GetService("CollectionService"):AddTag(p, "TeleportSpot")
		elseif name == "QuestItem" then
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.new(2.2, 2.2, 2.2)
			p.Material = M.Neon
			p.Color = RGB(150, 200, 255)
			local l = Instance.new("PointLight")
			l.Color = RGB(150, 200, 255)
			l.Range = 14
			l.Parent = p
		else
			p.Transparency = 1
			p.CanQuery = false
		end
		p.Parent = folder("표지")
	end
	-- 눈 나무
	local fk = SS:FindFirstChild("ForestKit")
	local pieces = {}
	for _, m in (fk and fk:GetChildren()) or {} do
		local list = {}
		for _, c in m:GetChildren() do
			if c:IsA("BasePart") and c.Name ~= "Origin" then
				list[#list + 1] = c
			end
		end
		pieces[m.Name] = list
	end
	local nt = 0
	for i, t in TREES do
		local list = pieces[t[1]]
		if not list then
			continue
		end
		local base = CFrame.new(t[2], t[3], t[4]) * CFrame.Angles(0, math.rad(t[5]), 0)
		local sc = t[6]
		local model = Instance.new("Model")
		model.Name = t[1]
		for _, src in list do
			local p = src:Clone()
			p.Size = src.Size * sc
			p.CFrame = base * CFrame.new(src.Position * sc) * src.CFrame.Rotation
			if LEAF[p.Name] then
				p.Color = LEAF[p.Name]
				p.Material = M.Snow
			end
			p.Parent = model
		end
		model.Parent = folder("나무")
		nt += 1
		if nt % 300 == 0 then
			task.wait()
		end
	end
	root.Parent = S
	say("설원 장식: 상자 %d · 키트 %d · 표지 %d · 나무 %d", #BOXES, #KITS, #MARKS, nt)
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/snowfield", table.concat(lines, "\n"))
