--!nocheck
--[[
	Snow_Town3.luau — 슈네라이히 3판 마을을 짓는다. (2026-11-14, 프로그래밍 부서)
	자료: tools/Snow_Town3_data.luau(기획 부서 손 배치표 — snow_plan4.py 가 뽑음), tools/Snow_Inside3_data.luau(아트 부서 안살림 표).
	사양: 설원마을_3판_사양.md. 옛 마을(Workspace.Schneereich.마을 의 2판 폴더들)은 지우지 않고 ServerStorage.Snow_Town2_Backup 으로 옮긴다.

	조립(프로젝트 루트, bash — 자료 끝의 `return D` 줄은 빼고 끼운다):
	  sed -e '/^return D$/d' tools/Snow_Town3_data.luau > tools/swamp/_town3_d.luau && \
	  sed -e '/--@@DATA@@/r tools/swamp/_town3_d.luau' -e '/--@@INSIDE@@/r tools/Snow_Inside3_data.luau' \
	      tools/Snow_Town3.luau > tools/swamp/_town3_run.luau && bash tools/job.sh tools/swamp/_town3_run.luau

	총괄이 Studio 에서 돌릴 순서
	  1. 아트 부서가 models/SnowTown3Kit.fbx 를 낸 뒤: 로컬 서버(35001) 띄우고 Studio 에서 Ctrl+M 으로 가져온다(Workspace.SnowTown3Kit).
	  2. bash tools/job.sh tools/Snow_Town3Kit.luau        → 보고 /snowtown3kit  (틀이 ServerStorage.SnowKit3 에 들어간다)
	  3. 위 조립 명령(job)                                   → 보고 /snowtown3     (틀이 없는 건물은 회색 상자 자리 표시)
	  건물이 더 지어지면 1~3 을 다시 돌린다(Town3 폴더만 지우고 새로 짓는다. 백업은 남은 것만 더 옮긴다).
	되돌리기: bash tools/job.sh tools/Snow_Town3_Restore.luau  (Town3 를 지우고 백업을 제자리로)

	하는 일: a 백업(옮기기만, Destroy 없음) · b Town3 폴더(단·넓은단·길·바위·판·건물·소품) · c 땅 물건은 전부 Anchored Part
	(바위 = 바위색 상자 + 윗면만 눈 판, 난수 씨앗 고정) · d 건물 놓기 + 안살림(충돌·등·NPC·불·소품) · e 소품·비행선 · f 보고.
	땅은 Surface.R_설원3 의 눈 윗면 59.7(2026-10-09 측정) 기준이라 시작에 몇 곳을 쏴서 확인한다.
]]
--@@DATA@@
--@@INSIDE@@

local report = {}
local function say(fmt, ...)
	report[#report + 1] = string.format(fmt, ...)
end

local RGB = Color3.fromRGB
local M = Enum.Material
local C = {
	road = { RGB(112, 106, 98), M.Cobblestone },
	plaza = { RGB(104, 99, 94), M.Cobblestone },
	found = { RGB(85, 86, 92), M.Slate },
	iron = { RGB(58, 60, 66), M.Metal },
	plate = { RGB(94, 98, 107), M.DiamondPlate },
	brass = { RGB(184, 145, 63), M.Metal },
	copper = { RGB(176, 106, 63), M.Metal },
	marble = { RGB(225, 225, 228), M.Marble },
	dark = { RGB(40, 40, 44), M.Slate },
	soot = { RGB(40, 38, 38), M.Slate },
	curb = { RGB(140, 139, 138), M.Concrete },
}
-- 틀이 아직 없을 때 세울 회색 상자의 발자국(폭 = 모델 로컬 X, 깊이 = 로컬 Z). snow_plan4.py SIZE 와 같다
local SIZE = {
	Sn3_Clock = { 20, 20 }, Sn3_Smithy = { 36, 32 }, Sn3_Enhance = { 28, 28 }, Sn3_Bank = { 36, 32 }, Sn3_Inn = { 40, 32 },
	Sn3_Potion = { 28, 28 }, Sn3_Hospital = { 40, 32 }, Sn3_General = { 28, 28 }, Sn3_Ticket = { 14, 10 }, Sn3_Mast = { 10, 10 },
	Sn3_Gate = { 26, 6 },
}
local BOTTOM = 59.2 -- 땅 눈 윗면 59.7 에 0.5 묻는다
local GROUND = 59.7

local okRun, errRun = pcall(function()
	local SS = game:GetService("ServerStorage")
	local CSi = game:GetService("CollectionService")
	local city = assert(workspace:FindFirstChild("Schneereich"), "Workspace.Schneereich 가 없다")
	local town = assert(city:FindFirstChild("마을"), "Schneereich.마을 이 없다")
	local G = assert(workspace:FindFirstChild("Surface") and workspace.Surface:FindFirstChild("R_설원3"), "Surface.R_설원3(설원 땅)이 없다")
	local kit3 = SS:FindFirstChild("SnowKit3")
	local kitOld = SS:FindFirstChild("SnowKit")
	local forestKit = SS:FindFirstChild("ForestKit")
	if not kit3 then
		say("ServerStorage.SnowKit3 가 없다 — 건물은 전부 자리 표시 상자")
	end

	--==================================================================== 0. 땅 높이 확인(백업 전)
	local rpG = RaycastParams.new()
	rpG.FilterType = Enum.RaycastFilterType.Include
	rpG.FilterDescendantsInstances = { G }
	local function groundY(x, z)
		local h = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1800, 0), rpG)
		return h and h.Position.Y
	end
	do
		local n, bad, worst, none = 0, {}, 0, 0
		local function probe(label, x, z)
			n += 1
			local y = groundY(x, z)
			if not y then
				none += 1
				bad[#bad + 1] = string.format("%s(%.0f,%.0f) 땅 없음", label, x, z)
			else
				local d = math.abs(y - GROUND)
				worst = math.max(worst, d)
				if d > 0.5 then
					bad[#bad + 1] = string.format("%s(%.0f,%.0f) y=%.2f", label, x, z, y)
				end
			end
		end
		for _, p in ipairs(D.PADS) do
			probe(p[10], p[2], p[3])
		end
		for _, t in ipairs(D.TERRACES) do
			probe(t[1], (t[2] + t[3]) / 2, (t[4] + t[5]) / 2)
			probe(t[1] .. "NW", t[2] + 1, t[4] + 1)
			probe(t[1] .. "SE", t[3] - 1, t[5] - 1)
		end
		say("땅 높이 확인 %d 곳 (기준 %.1f): 가장 큰 차 %.2f, 0.5 넘는 곳 %d, 땅 없는 곳 %d", n, GROUND, worst, #bad, none)
		for i = 1, math.min(#bad, 12) do
			say("  땅 이상 %s", bad[i])
		end
	end

	--==================================================================== 표본 색(R_설원3 의 바위·눈)
	local rockCol, snowCol = { RGB(85, 86, 92), M.Slate }, { RGB(238, 243, 247), M.Snow }
	do
		local ROCKMAT = { [M.Slate] = true, [M.Rock] = true, [M.Basalt] = true, [M.Granite] = true }
		local rockByName, rockByMat, snowByName, snowByMat
		for _, p in ipairs(G:GetDescendants()) do
			if p:IsA("BasePart") then
				if not rockByName and (p.Name:find("바위") or p.Name:lower():find("rock")) then
					rockByName = p
				end
				if not rockByMat and ROCKMAT[p.Material] then
					rockByMat = p
				end
				if not snowByName and p.Name:find("마을_눈") then
					snowByName = p
				end
				if not snowByMat and p.Material == M.Snow then
					snowByMat = p
				end
			end
		end
		local r, s = rockByName or rockByMat, snowByName or snowByMat
		if r then
			rockCol = { r.Color, r.Material }
			say("바위 표본 %s", r:GetFullName():gsub("^.*R_설원3%.", ""))
		else
			say("바위 표본을 못 찾아 기본값(Slate 회색)")
		end
		if s then
			snowCol = { s.Color, s.Material }
			say("눈 표본 %s", s:GetFullName():gsub("^.*R_설원3%.", ""))
		else
			say("눈 표본을 못 찾아 기본값(Snow 흰색)")
		end
	end

	--==================================================================== a. 백업(옮기기만 — Destroy 없음)
	local backup = SS:FindFirstChild("Snow_Town2_Backup")
	if not backup then
		backup = Instance.new("Folder")
		backup.Name = "Snow_Town2_Backup"
		backup.Parent = SS
	end
	local function freeName(parent, name)
		if not parent:FindFirstChild(name) then
			return name
		end
		local i = 2
		while parent:FindFirstChild(name .. "_" .. i) do
			i += 1
		end
		return name .. "_" .. i
	end
	local function stash(inst, dest)
		inst:SetAttribute("SnowOrigName", inst.Name)
		inst.Name = freeName(dest, inst.Name)
		inst.Parent = dest
	end
	-- 남기는 규칙: 자료 KEEP_FOLDERS 의 "폴더/이름" + 톱니 중 본부 시계 바늘(ClockHand_*, ClockPin)
	local keepChild = {}
	for _, k in ipairs(D.KEEP_FOLDERS) do
		local a, b = k:match("^([^/]+)/(.+)$")
		if a then
			keepChild[a] = keepChild[a] or {}
			keepChild[a][b] = true
		end
	end
	local function isKept(folderName, child)
		if keepChild[folderName] and keepChild[folderName][child.Name] then
			return true
		end
		if folderName == "톱니" and (child.Name:match("^ClockHand_") or child.Name == "ClockPin") then
			return true
		end
		return false
	end
	do
		local nWhole, nPart, nMiss = 0, 0, 0
		for _, entry in ipairs(D.REMOVE_FOLDERS) do
			local name = entry:match("^([^%(]+)") or entry
			local src = town:FindFirstChild(name)
			if not src then
				nMiss += 1
			elseif entry:find("%(") then
				local holder = backup:FindFirstChild(name)
				if not holder then
					holder = Instance.new("Folder")
					holder.Name = name
					holder:SetAttribute("SnowPartialOf", name)
					holder.Parent = backup
				end
				for _, c in ipairs(src:GetChildren()) do
					if not isKept(name, c) then
						stash(c, holder)
						nPart += 1
					end
				end
			else
				src:SetAttribute("SnowOrigParent", "마을")
				stash(src, backup)
				nWhole += 1
			end
		end
		say("백업 → ServerStorage.Snow_Town2_Backup: 폴더째 %d, 일부 옮김 %d 개, 이미 없음 %d", nWhole, nPart, nMiss)
	end

	--==================================================================== b. 3판 폴더
	local old3 = town:FindFirstChild("Town3")
	if old3 then
		old3:Destroy() -- 이전 3판 결과만 지운다
	end
	local T3 = Instance.new("Folder")
	T3.Name = "Town3"
	T3.Parent = town
	local function sub(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = T3
		return f
	end
	local fTer, fStep, fPath, fRock, fSlab, fBld, fProp = sub("단"), sub("넓은단"), sub("길"), sub("바위"), sub("판"), sub("건물"), sub("소품")

	local cnt, nParts = {}, 0
	local rnd = Random.new(20261113) -- 고정 씨앗: 다시 돌려도 같은 흔들기
	local function jit()
		return rnd:NextNumber(0, 0.1)
	end
	local function part(kind, name, cf, size, col, parent)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = col[1]
		p.Material = col[2]
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		cnt[kind] = (cnt[kind] or 0) + 1
		nParts += 1
		if nParts % 500 == 0 then
			task.wait()
		end
		return p
	end
	local function box(kind, name, x0, x1, y0, y1, z0, z1, col, parent)
		return part(kind, name, CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, y1 - y0, z1 - z0), col, parent)
	end
	-- 바위 + 윗면만 눈. 걷는 면(top)은 그대로, 바위 윗면은 top-0.2 아래로 묻고 눈 판(두께 0.6)이 x·z 로 0.1 넘게 덮는다.
	-- 높이 1 이하는 눈 상자 하나.
	local function rockSnow(kind, name, x0, x1, z0, z1, top, parent)
		if top - BOTTOM <= 1 then
			return box(kind, name, x0 - jit(), x1 + jit(), BOTTOM - jit(), top, z0 - jit(), z1 + jit(), snowCol, parent)
		end
		local body = box(kind, name .. "_바위", x0 - jit(), x1 + jit(), BOTTOM - jit(), top - 0.2 - jit() * 0.5, z0 - jit(), z1 + jit(), rockCol, parent)
		local e = function()
			return 0.15 + jit()
		end
		box(kind, name .. "_눈", x0 - e(), x1 + e(), top - 0.6, top, z0 - e(), z1 + e(), snowCol, parent)
		return body
	end

	for _, t in ipairs(D.TERRACES) do
		local name, x0, x1, z0, z1, top, mat = t[1], t[2], t[3], t[4], t[5], t[6], t[7]
		if mat == "돌바닥" then
			box("단", name, x0, x1, BOTTOM, top, z0, z1, C.plaza, fTer)
		else
			rockSnow("단", name, x0, x1, z0, z1, top, fTer)
		end
	end
	for _, s in ipairs(D.STEPS) do
		box("넓은단", s[1], s[2], s[3], BOTTOM, s[6], s[4], s[5], rockCol, fStep)
	end
	for _, r in ipairs(D.ROCKS) do
		rockSnow("바위", string.format("바위%s", r[6] and ("_" .. r[6]) or ""), r[1], r[2], r[3], r[4], r[5], fRock)
	end
	for _, s in ipairs(D.SLABS) do
		box("판", "눈판", s[1] - jit(), s[2] + jit(), BOTTOM - jit(), s[5], s[3] - jit(), s[4] + jit(), snowCol, fSlab)
	end
	for _, pc in ipairs(D.PATH_PIECES) do
		local name, w, x0, z0, x1, z1, top = pc[1], pc[2], pc[3], pc[4], pc[5], pc[6], pc[7]
		local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
		if len > 0.01 then
			local mid = Vector3.new((x0 + x1) / 2, top + 0.15, (z0 + z1) / 2)
			part("길", name, CFrame.lookAt(mid, mid + Vector3.new(x1 - x0, 0, z1 - z0)), Vector3.new(w, 0.2, len), C.road, fPath)
		end
	end
	task.wait()

	--==================================================================== d. 건물
	local nColl, nProp, nLamp, nFire, nNpc = 0, 0, 0, 0, 0
	local function applyInside(m, kind)
		local spec = INSIDE[kind]
		if not spec then
			return
		end
		local pv = m:GetPivot()
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("MeshPart") then
				p.CanCollide = false
			end
		end
		local fc = Instance.new("Folder")
		fc.Name = "충돌"
		fc.Parent = m
		for _, b in ipairs(spec.coll) do
			local p = part("충돌", "Coll", pv * CFrame.new(b[1], b[2], b[3]) * CFrame.Angles(0, math.rad(b[7]), 0), Vector3.new(b[4], b[5], b[6]), C.found, fc)
			p.Transparency = 1
			p.CastShadow = false
			nColl += 1
		end
		for _, pr in ipairs(spec.props or {}) do
			local src = if pr[1] == "@Press" then SS:FindFirstChild("Snow_PressTemplate")
				else ((kit3 and kit3:FindFirstChild(pr[1])) or (kitOld and kitOld:FindFirstChild(pr[1])))
			if src then
				local pm = src:Clone()
				if pr[6] ~= 1 then
					pm:ScaleTo(pr[6])
				end
				pm:PivotTo(pv * CFrame.new(pr[2], pr[3], pr[4]) * CFrame.Angles(0, math.rad(pr[5]), 0)
					* CFrame.Angles(math.rad(pr[7]), math.rad(pr[8]), math.rad(pr[9])))
				local col = pr[11] and C[string.lower(pr[11])]
				for _, p in ipairs(pm:GetDescendants()) do
					if p:IsA("BasePart") then
						p.CanCollide = false
						if col then
							p.Color, p.Material = col[1], col[2]
						end
					end
				end
				if pr[10] then
					pm:SetAttribute("Speed", pr[10])
					CSi:AddTag(pm, "SnowGear")
				end
				pm.Parent = m
				nProp += 1
			else
				say("소품 틀 없음 %s (%s)", pr[1], kind)
			end
		end
		for _, l in ipairs(spec.lamps or {}) do
			local p = part("충돌", "Lamp", pv * CFrame.new(l[1], l[2], l[3]), Vector3.new(0.2, 0.2, 0.2), C.found, fc)
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			local pl = Instance.new("PointLight")
			pl.Color = RGB(255, 190, 120)
			pl.Brightness = 1.4
			pl.Range = 16
			pl.Parent = p
			nLamp += 1
		end
		for _, n in ipairs(spec.npc or {}) do
			local p = part("충돌", "NPC자리", pv * CFrame.new(n[1], n[2] + 2.5, n[3]) * CFrame.Angles(0, math.rad(n[4]), 0), Vector3.new(4, 5, 1), C.found, fc)
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p:SetAttribute("NpcSpot", true)
			nNpc += 1
		end
		for _, fr in ipairs(spec.fires or {}) do
			local s = fr[4]
			local p = part("충돌", "Fire", pv * CFrame.new(fr[1], fr[2], fr[3]), Vector3.new(0.9 * s, 0.2, 0.6 * s), C.found, fc)
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			local fl = Instance.new("ParticleEmitter")
			fl.Name = "Flame"
			fl.Texture = "rbxasset://textures/particles/fire_main.dds"
			fl.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, RGB(255, 222, 140)),
				ColorSequenceKeypoint.new(0.45, RGB(255, 140, 45)),
				ColorSequenceKeypoint.new(1, RGB(190, 45, 20)),
			})
			fl.LightEmission = 1
			fl.LightInfluence = 0
			fl.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.0 * s),
				NumberSequenceKeypoint.new(0.5, 0.75 * s),
				NumberSequenceKeypoint.new(1, 0.1 * s),
			})
			fl.Squash = NumberSequence.new({
				NumberSequenceKeypoint.new(0, -0.3),
				NumberSequenceKeypoint.new(0.6, -1.0),
				NumberSequenceKeypoint.new(1, -1.6),
			})
			fl.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.7, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			})
			fl.Lifetime = NumberRange.new(0.35, 0.7)
			fl.Rate = 40
			fl.Speed = NumberRange.new(1.0 * s, 2.0 * s)
			fl.SpreadAngle = Vector2.new(10, 10)
			fl.Acceleration = Vector3.new(0, 1.6 * s, 0)
			fl.Rotation = NumberRange.new(-15, 15)
			fl.RotSpeed = NumberRange.new(-25, 25)
			fl.EmissionDirection = Enum.NormalId.Top
			fl.Shape = Enum.ParticleEmitterShape.Box
			fl.Parent = p
			local co = fl:Clone()
			co.Name = "Core"
			co.Color = ColorSequence.new(RGB(255, 245, 200), RGB(255, 190, 80))
			co.Size = NumberSequence.new(0.5 * s, 0.15 * s)
			co.Squash = NumberSequence.new(-0.4)
			co.Lifetime = NumberRange.new(0.2, 0.35)
			co.Rate = 25
			co.Speed = NumberRange.new(0.4 * s, 0.9 * s)
			co.Acceleration = Vector3.zero
			co.Parent = p
			local sp = Instance.new("ParticleEmitter")
			sp.Name = "Sparks"
			sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sp.Color = ColorSequence.new(RGB(255, 170, 70), RGB(255, 90, 30))
			sp.LightEmission = 1
			sp.LightInfluence = 0
			sp.Size = NumberSequence.new(0.07 * math.max(1, s), 0.02)
			sp.Lifetime = NumberRange.new(0.8, 1.6)
			sp.Rate = 4 + 3 * s
			sp.Speed = NumberRange.new(1.5 * s, 3.0 * s)
			sp.SpreadAngle = Vector2.new(25, 25)
			sp.Acceleration = Vector3.new(0, 0.8, 0)
			sp.Drag = 1.5
			sp.EmissionDirection = Enum.NormalId.Top
			sp.Parent = p
			local pl = Instance.new("PointLight")
			pl.Color = RGB(255, 150, 70)
			pl.Brightness = 1.8
			pl.Range = 8 + 8 * s
			pl.Parent = p
			CSi:AddTag(p, "SnowFire")
			nFire += 1
		end
	end

	local placedN, emptyN, missing = 0, 0, {}
	local padY = {}
	for _, pad in ipairs(D.PADS) do
		local kind, x, z, yaw, y = pad[1], pad[2], pad[3], pad[4], pad[5]
		padY[kind] = y
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)
		local src = kit3 and kit3:FindFirstChild(kind)
		if src then
			local m = src:Clone()
			m.Name = kind
			m:SetAttribute("PadName", pad[10])
			m:PivotTo(cf)
			m.Parent = fBld
			applyInside(m, kind)
			placedN += 1
		else
			local sz = SIZE[kind] or { 20, 20 }
			local h = 14
			local p = part("자리표시", kind, cf * CFrame.new(0, h / 2, 0), Vector3.new(sz[1], h, sz[2]), { RGB(150, 150, 154), M.SmoothPlastic }, fBld)
			p.Transparency = 0.5
			p.CanCollide = false
			p:SetAttribute("PadName", pad[10])
			p:SetAttribute("Placeholder", true)
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(160, 40)
			bb.StudsOffset = Vector3.new(0, h / 2 + 3, 0)
			bb.AlwaysOnTop = true
			bb.Parent = p
			local tl = Instance.new("TextLabel")
			tl.Size = UDim2.fromScale(1, 1)
			tl.BackgroundTransparency = 1
			tl.TextColor3 = RGB(255, 255, 255)
			tl.TextStrokeTransparency = 0.4
			tl.TextScaled = true
			tl.AutoLocalize = false
			tl.Text = string.format("%s %s", kind, pad[10])
			tl.Parent = bb
			emptyN += 1
			missing[#missing + 1] = kind
		end
	end
	say("건물: 놓음 %d, 자리 표시 %d — 없는 틀: %s", placedN, emptyN, #missing > 0 and table.concat(missing, ", ") or "없음")
	say("안살림: 충돌 상자 %d · 소품 %d · 등 %d · NPC 자리 %d · 불 %d", nColl, nProp, nLamp, nNpc, nFire)
	task.wait()

	--==================================================================== e. 소품
	do
		local LEAF = { LeafA = RGB(232, 240, 248), LeafB = RGB(196, 212, 228) }
		local nLamps, nTrees, lost = 0, 0, {}
		for i, pr in ipairs(D.PROPS) do
			local kind, x, z, y, yaw, sc = pr[1], pr[2], pr[3], pr[4], pr[5], pr[6]
			if kind == "Gas_Lamp" then
				local src = kitOld and kitOld:FindFirstChild("Gas_Lamp")
				if src then
					local m = src:Clone()
					m.Name = "Gas_Lamp_" .. i
					if sc ~= 1 then
						m:ScaleTo(sc)
					end
					m:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0))
					m.Parent = fProp
					nLamps += 1
				else
					lost[kind] = true
				end
			else
				local src = forestKit and forestKit:FindFirstChild(kind)
				if src then
					local base = CFrame.new(x, y - 0.3, z) * CFrame.Angles(0, math.rad(yaw), 0)
					local model = Instance.new("Model")
					model.Name = kind
					for _, s in ipairs(src:GetChildren()) do
						if s:IsA("BasePart") and s.Name ~= "Origin" then
							local p = s:Clone()
							p.Size = s.Size * sc
							p.CFrame = base * CFrame.new(s.Position * sc) * s.CFrame.Rotation
							if LEAF[p.Name] then
								p.Color = LEAF[p.Name]
								p.Material = M.Snow
							end
							p.Parent = model
						end
					end
					model.Parent = fProp
					nTrees += 1
				else
					lost[kind] = true
				end
			end
			if i % 100 == 0 then
				task.wait()
			end
		end
		local lostL = {}
		for k in pairs(lost) do
			lostL[#lostL + 1] = k
		end
		say("소품: 가스등 %d, 나무 %d, 틀 없어 못 놓은 종류: %s", nLamps, nTrees, #lostL > 0 and table.concat(lostL, ", ") or "없음")
		if D.AIRSHIP then
			local a = D.AIRSHIP
			local src = kitOld and kitOld:FindFirstChild("Airship")
			if src and padY.Sn3_Mast then
				local ship = src:Clone()
				ship.Name = "Airship"
				ship:PivotTo(CFrame.new(a[1], padY.Sn3_Mast + a[4], a[2]) * CFrame.Angles(0, math.rad(a[3]), 0))
				ship.Parent = fProp
				say("비행선: 계류탑 바닥 %.1f + %.1f", padY.Sn3_Mast, a[4])
			else
				say("비행선 못 놓음 (Airship 틀 %s, 계류탑 자리 %s)", src and "있음" or "없음", padY.Sn3_Mast and "있음" or "없음")
			end
		end
	end

	--==================================================================== 남는 건물 · 스크립트 확인(건드리지 않음)
	for _, k in ipairs(D.KEEP) do
		local m = town:FindFirstChild(k[1], true)
		if m and m:IsA("Model") then
			local p = m:GetPivot().Position
			local d = math.sqrt((p.X - k[2]) ^ 2 + (p.Z - k[3]) ^ 2)
			if d > 2 then
				say("남는 건물 %s: 자료 자리와 %.1f 다름 (Studio %.1f, %.1f)", k[1], d, p.X, p.Z)
			end
		else
			say("남는 건물 %s: 마을 안에서 못 찾음", k[1])
		end
	end
	for _, nm in ipairs({ "SnowObservatorySpin", "SnowFireFlicker" }) do
		if not town:FindFirstChild(nm) then
			say("마을 폴더에 스크립트 %s 가 없다", nm)
		end
	end

	--==================================================================== f. 보고
	local order = { "단", "넓은단", "바위", "판", "길", "충돌", "자리표시" }
	local parts = {}
	for _, k in ipairs(order) do
		parts[#parts + 1] = string.format("%s %d", k, cnt[k] or 0)
	end
	say("만든 부품 %d: %s", nParts, table.concat(parts, " · "))
	say("표 길이: 단 %d · 넓은단 %d · 바위 %d · 판 %d · 길 조각 %d · 소품 %d", #D.TERRACES, #D.STEPS, #D.ROCKS, #D.SLABS, #D.PATH_PIECES, #D.PROPS)
end)
if not okRun then
	say("ERR %s", tostring(errRun))
end
print(table.concat(report, "\n"))
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/snowtown3", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
