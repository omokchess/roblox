--!nocheck
--[[
	Snow_Town3_MoveKeep.luau — 지하 입구(Casino_Gate) 땅 고치기. (2026-11-23, 프로그래밍 부서)
	건물 옮기기는 사용자가 Studio 에서 직접 했다. 이 스크립트가 하는 일:
	  1. Casino_Gate 를 옛 높이로 내린다(Y 만. Casino_Under 경계 상자 가운데가 OLD_UNDER_CY 가 되게. x·z·yaw 는 그대로).
	  2. 옛 자리(snow_plan4 KEEP 의 피벗)에서 '파인 칸'(눈 윗면이 59.7 보다 낮은 칸)을 1 스터드 격자로 재서,
	     옛 피벗 → 새 피벗 변환으로 새 자리에 똑같이 파고(Land 상자 빼기, 상자 하나 → 최대 6 조각 · 재질·색·이름 그대로),
	  3. 옛 자리 파인 칸은 '마을' 몸통 + 윗면 '마을_눈'(두께 2, 윗면 59.7)으로 빈 칸에만 메운다.
	  4. 겹침 검사: 새 자리 방 상자에 R_설원3_지하·R_설원3_터널 부품이 있으면 아무것도 안 하고 멈춘다.
	     Town3 바위·판·길 부품 겹침은 목록으로 보고만 한다(지우지 않음).
	  백업: ServerStorage.Snow_KeepMove_Backup (바꾼 Land 원본 복제 + 옛 피벗). 이미 있으면 멈춘다 → Undo 먼저.
	되돌리기: tools/Snow_Town3_MoveKeep_Undo.luau
	DRY_RUN = true 면 아무것도 안 바꾸고 할 일만 보고한다.
	조립 없음. 총괄이 돌릴 순서: DRY_RUN → (보고 확인) DRY_RUN=false 로 고쳐 → bash tools/job.sh tools/Snow_Town3_MoveKeep.luau → 보고 /keepmove
	순수 함수(PURE_BEGIN~END 사이)는 tools/movekeep_test.luau 가 이 파일에서 잘라 시험한다.
]]
local DRY_RUN = true

local OLD_PIVOT = { -4668, -4100, 90 } -- snow_plan4 KEEP Casino_Gate (x, z, yaw도)
local OLD_UNDER_CENTER = { -4640, 50.1, -4086 } -- 옛 Casino_Under 경계 상자 가운데
local OLD_UNDER_CY = OLD_UNDER_CENTER[2]
local GROUND = 59.7
local SNOW_T = 2

--@@PURE_BEGIN
-- 상자 = { x0, x1, y0, y1, z0, z1 } (축 정렬)
local function newBox(x0, x1, y0, y1, z0, z1)
	return { x0 = x0, x1 = x1, y0 = y0, y1 = y1, z0 = z0, z1 = z1 }
end

local function intersects(a, b)
	return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1 and a.z0 < b.z1 and b.z0 < a.z1
end

-- a 에서 b 를 뺀 조각들(겹치지 않으면 {a}, 겹치면 최대 6 조각). 조각끼리 안 겹친다
local function subtract(a, b)
	if not intersects(a, b) then
		return { a }
	end
	local ix0, ix1 = math.max(a.x0, b.x0), math.min(a.x1, b.x1)
	local iy0, iy1 = math.max(a.y0, b.y0), math.min(a.y1, b.y1)
	local iz0, iz1 = math.max(a.z0, b.z0), math.min(a.z1, b.z1)
	local out = {}
	if a.x0 < ix0 then
		out[#out + 1] = newBox(a.x0, ix0, a.y0, a.y1, a.z0, a.z1)
	end
	if ix1 < a.x1 then
		out[#out + 1] = newBox(ix1, a.x1, a.y0, a.y1, a.z0, a.z1)
	end
	if a.y0 < iy0 then
		out[#out + 1] = newBox(ix0, ix1, a.y0, iy0, a.z0, a.z1)
	end
	if iy1 < a.y1 then
		out[#out + 1] = newBox(ix0, ix1, iy1, a.y1, a.z0, a.z1)
	end
	if a.z0 < iz0 then
		out[#out + 1] = newBox(ix0, ix1, iy0, iy1, a.z0, iz0)
	end
	if iz1 < a.z1 then
		out[#out + 1] = newBox(ix0, ix1, iy0, iy1, iz1, a.z1)
	end
	return out
end

-- 칸 묶기. cells = { {i, j}, ... } → 직사각형 { i0, i1, j0, j1 }(끝 포함) 여럿. 합 = 칸 수, 겹침 없음
local function mergeCells(cells)
	local set = {}
	for _, c in ipairs(cells) do
		set[c[1] .. "," .. c[2]] = true
	end
	local order = {}
	for _, c in ipairs(cells) do
		order[#order + 1] = c
	end
	table.sort(order, function(p, q)
		if p[2] ~= q[2] then
			return p[2] < q[2]
		end
		return p[1] < q[1]
	end)
	local rects = {}
	for _, c in ipairs(order) do
		local i0, j0 = c[1], c[2]
		if set[i0 .. "," .. j0] then
			local i1 = i0
			while set[(i1 + 1) .. "," .. j0] do
				i1 += 1
			end
			local j1 = j0
			while true do
				local full = true
				for i = i0, i1 do
					if not set[i .. "," .. (j1 + 1)] then
						full = false
						break
					end
				end
				if not full then
					break
				end
				j1 += 1
			end
			for j = j0, j1 do
				for i = i0, i1 do
					set[i .. "," .. j] = nil
				end
			end
			rects[#rects + 1] = { i0 = i0, i1 = i1, j0 = j0, j1 = j1 }
		end
	end
	return rects
end
--@@PURE_END

local report = {}
local function say(fmt, ...)
	report[#report + 1] = string.format(fmt, ...)
end

local function rot(x, z, th) -- CFrame.Angles(0, th, 0) 를 (x,0,z) 에
	local c, s = math.cos(th), math.sin(th)
	return x * c + z * s, -x * s + z * c
end

local function boxOfPart(p)
	local c, s = p.CFrame, p.Size / 2
	local r, u, l = c.RightVector, c.UpVector, c.LookVector
	local hx = math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z
	local hy = math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z
	local hz = math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z
	local P = c.Position
	return newBox(P.X - hx, P.X + hx, P.Y - hy, P.Y + hy, P.Z - hz, P.Z + hz)
end

local function boxOf(inst)
	local b
	local function add(p)
		local q = boxOfPart(p)
		if not b then
			b = q
		else
			b.x0, b.x1 = math.min(b.x0, q.x0), math.max(b.x1, q.x1)
			b.y0, b.y1 = math.min(b.y0, q.y0), math.max(b.y1, q.y1)
			b.z0, b.z1 = math.min(b.z0, q.z0), math.max(b.z1, q.z1)
		end
	end
	if inst:IsA("BasePart") then
		add(inst)
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			add(d)
		end
	end
	return b
end

local function grow(b, m)
	return newBox(b.x0 - m, b.x1 + m, b.y0 - m, b.y1 + m, b.z0 - m, b.z1 + m)
end

local function axisAligned(p)
	local c = p.CFrame
	return math.abs(c.RightVector.X) > 0.9999 and math.abs(c.UpVector.Y) > 0.9999 and c.RightVector.X > 0 and c.UpVector.Y > 0
end

local okRun, errRun = pcall(function()
	local SS = game:GetService("ServerStorage")
	local city = assert(workspace:FindFirstChild("Schneereich"), "Workspace.Schneereich 가 없다")
	local town = assert(city:FindFirstChild("마을"), "Schneereich.마을 이 없다")
	local gate = assert(town:FindFirstChild("경매장") and town["경매장"]:FindFirstChild("Casino_Gate"), "마을.경매장.Casino_Gate 가 없다")
	local under = assert(gate:FindFirstChild("Casino_Under"), "Casino_Gate.Casino_Under 가 없다")
	local surf = assert(workspace:FindFirstChild("Surface"), "Workspace.Surface 가 없다")
	local G = assert(surf:FindFirstChild("R_설원3"), "Surface.R_설원3 이 없다")
	local land = G:FindFirstChild("Land") or G
	say("모드: %s", DRY_RUN and "DRY_RUN(아무것도 안 바꿈)" or "실제")

	if SS:FindFirstChild("Snow_KeepMove_Backup") then
		say("멈춤: ServerStorage.Snow_KeepMove_Backup 이 이미 있다 — Snow_Town3_MoveKeep_Undo 를 먼저 돌려라")
		return
	end

	--==================================================================== 1. 높이·변환
	local pivot = gate:GetPivot()
	local _, newYawRad = pivot:ToOrientation()
	local oldYawRad = math.rad(OLD_PIVOT[3])
	local dYaw = math.deg(newYawRad - oldYawRad)
	say("Casino_Gate 피벗 (%.1f, %.1f, %.1f) yaw %.1f — 옛 (%.0f, %.0f) yaw %.0f", pivot.X, pivot.Y, pivot.Z, math.deg(newYawRad), OLD_PIVOT[1], OLD_PIVOT[2], OLD_PIVOT[3])
	if math.abs(dYaw / 90 - math.floor(dYaw / 90 + 0.5)) > 0.01 then
		say("멈춤: 회전 차 %.2f 도가 90 의 배수가 아니라 1 스터드 격자가 새 자리에서 안 맞는다", dYaw)
		return
	end
	local function fwd(x, z)
		local lx, lz = rot(x - OLD_PIVOT[1], z - OLD_PIVOT[2], -oldYawRad)
		local nx, nz = rot(lx, lz, newYawRad)
		return nx + pivot.X, nz + pivot.Z
	end
	local function inv(x, z)
		local lx, lz = rot(x - pivot.X, z - pivot.Z, -newYawRad)
		local ox, oz = rot(lx, lz, oldYawRad)
		return ox + OLD_PIVOT[1], oz + OLD_PIVOT[2]
	end

	local ub = boxOf(under)
	local ucy = (ub.y0 + ub.y1) / 2
	local dy = ucy - OLD_UNDER_CY -- 내릴 양
	local gb0 = boxOf(gate)
	say("Casino_Under 경계 상자 가운데 y %.2f(옛 %.2f) → 내릴 양 %.2f. Gate 전체 가운데 y %.2f(옛 기록 55.4 → 차 %.2f)", ucy, OLD_UNDER_CY, dy, (gb0.y0 + gb0.y1) / 2, (gb0.y0 + gb0.y1) / 2 - dy - 55.4)
	local ex, ez = fwd(OLD_UNDER_CENTER[1], OLD_UNDER_CENTER[3])
	say("변환 점검: 옛 Under 가운데를 옮기면 (%.1f, %.1f), 지금 실제 (%.1f, %.1f), 차 (%.1f, %.1f)", ex, ez, (ub.x0 + ub.x1) / 2, (ub.z0 + ub.z1) / 2, ex - (ub.x0 + ub.x1) / 2, ez - (ub.z0 + ub.z1) / 2)

	local function shifted(b)
		return newBox(b.x0, b.x1, b.y0 - dy, b.y1 - dy, b.z0, b.z1)
	end
	local underNew = shifted(ub) -- 내린 뒤 방
	local gateNew = shifted(gb0)
	local cutRoom = grow(underNew, 0.5)

	--==================================================================== 4. 겹침 검사(먼저 — 걸리면 멈춤)
	local function parts(root)
		local out = {}
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("BasePart") then
					out[#out + 1] = d
				end
			end
		end
		return out
	end
	local stop = false
	for _, nm in ipairs({ "R_설원3_지하", "R_설원3_터널" }) do
		local root = surf:FindFirstChild(nm)
		if not root then
			say("%s 없음(검사 건너뜀)", nm)
		else
			local hit = {}
			local list = parts(root)
			if root:IsA("BasePart") then
				list[#list + 1] = root
			end
			for _, p in ipairs(list) do
				if intersects(boxOfPart(p), cutRoom) then
					hit[#hit + 1] = p:GetFullName()
				end
			end
			say("%s 부품 %d 중 새 방 상자와 겹침 %d", nm, #list, #hit)
			for i = 1, math.min(#hit, 10) do
				say("  겹침 %s", hit[i])
			end
			if #hit > 0 then
				stop = true
			end
		end
	end
	if stop then
		say("멈춤: 새 방이 지하·터널과 겹친다. 아무것도 바꾸지 않았다")
		return
	end
	local t3 = town:FindFirstChild("Town3")
	do
		local zone = grow(gateNew, 1)
		local hit = {}
		for _, p in ipairs(parts(t3)) do
			if intersects(boxOfPart(p), zone) then
				hit[#hit + 1] = p:GetFullName():gsub("^.*Town3%.", "")
			end
		end
		say("Town3 부품 중 새 Gate 자리(+1)와 겹침 %d (지우지 않음, 보고만)", #hit)
		for i = 1, math.min(#hit, 25) do
			say("  Town3 겹침 %s", hit[i])
		end
	end
	-- 좌표 속성·스크립트(바꾸지 않고 보고)
	do
		local n = 0
		for _, d in ipairs({ gate, table.unpack(gate:GetDescendants()) }) do
			for k, v in pairs(d:GetAttributes()) do
				if typeof(v) == "Vector3" or typeof(v) == "CFrame" then
					n += 1
					if n <= 15 then
						say("  좌표 속성(안 바꿈) %s.%s = %s", d:GetFullName():gsub("^.*경매장%.", ""), k, tostring(v))
					end
				end
			end
			if d:IsA("LuaSourceContainer") then
				say("  스크립트 %s (안 바꿈 — 하드코딩 좌표 확인)", d:GetFullName():gsub("^.*경매장%.", ""))
			end
		end
		say("Gate 안 Vector3/CFrame 속성 %d 개", n)
	end

	--==================================================================== 2. 옛 자리 파인 칸 재기(Gate 를 옮기기 전에)
	local rpG = RaycastParams.new()
	rpG.FilterType = Enum.RaycastFilterType.Include
	rpG.FilterDescendantsInstances = { G }
	local ox0, ox1, oz0, oz1 = math.huge, -math.huge, math.huge, -math.huge
	for _, c in ipairs({ { gateNew.x0, gateNew.z0 }, { gateNew.x0, gateNew.z1 }, { gateNew.x1, gateNew.z0 }, { gateNew.x1, gateNew.z1 } }) do
		local x, z = inv(c[1], c[2])
		ox0, ox1, oz0, oz1 = math.min(ox0, x), math.max(ox1, x), math.min(oz0, z), math.max(oz1, z)
	end
	ox0, ox1, oz0, oz1 = math.floor(ox0) - 1, math.ceil(ox1) + 1, math.floor(oz0) - 1, math.ceil(oz1) + 1
	local oldBox = newBox(ox0, ox1, -1e4, 1e4, oz0, oz1)
	if intersects(oldBox, newBox(gateNew.x0 - 2, gateNew.x1 + 2, -1e4, 1e4, gateNew.z0 - 2, gateNew.z1 + 2)) then
		say("멈춤: 옛 자리 재는 구역이 새 자리와 겹친다(둘이 너무 가깝다)")
		return
	end
	local ubOldBottom = ub.y0 -- 구멍이 뚫려 있을 때 메우기 시작 높이(Under 바닥)
	local groups, nDug, nCells = {}, 0, 0
	for j = 0, oz1 - oz0 - 1 do
		for i = 0, ox1 - ox0 - 1 do
			nCells += 1
			local h = workspace:Raycast(Vector3.new(ox0 + i + 0.5, 900, oz0 + j + 0.5), Vector3.new(0, -1800, 0), rpG)
			local y = h and h.Position.Y
			if (not y) or y < GROUND - 0.3 then
				nDug += 1
				local top = y and math.floor(y * 10 + 0.5) / 10 or ubOldBottom
				groups[top] = groups[top] or {}
				table.insert(groups[top], { i, j })
			end
		end
	end
	say("옛 자리 재기 구역 x %d~%d z %d~%d (%d 칸): 파인 칸 %d", ox0, ox1, oz0, oz1, nCells, nDug)
	local fills, cutters = {}, { { box = cutRoom, tag = "방" } }
	local nRect = 0
	for top, cells in pairs(groups) do
		for _, r in ipairs(mergeCells(cells)) do
			nRect += 1
			local x0, x1, z0, z1 = ox0 + r.i0, ox0 + r.i1 + 1, oz0 + r.j0, oz0 + r.j1 + 1
			fills[#fills + 1] = { x0 = x0, x1 = x1, z0 = z0, z1 = z1, top = top }
			-- 새 자리: 네 모서리를 옮겨 축 정렬 상자로
			local nx0, nx1, nz0, nz1 = math.huge, -math.huge, math.huge, -math.huge
			for _, c in ipairs({ { x0, z0 }, { x0, z1 }, { x1, z0 }, { x1, z1 } }) do
				local x, z = fwd(c[1], c[2])
				nx0, nx1, nz0, nz1 = math.min(nx0, x), math.max(nx1, x), math.min(nz0, z), math.max(nz1, z)
			end
			cutters[#cutters + 1] = { box = newBox(nx0, nx1, top, GROUND + SNOW_T + 2, nz0, nz1), tag = "파임" }
		end
	end
	say("파인 칸 → 직사각형 %d 개(옛 자리 메우기 %d 묶음, 새 자리 자르기 상자 %d 개)", nRect, #fills, #cutters)

	--==================================================================== 3. 새 자리 자를 Land 상자 찾기
	local plan, skipped = {}, {}
	for _, p in ipairs(parts(land)) do
		local pb = boxOfPart(p)
		local hitAny = false
		for _, c in ipairs(cutters) do
			if intersects(pb, c.box) then
				hitAny = true
				break
			end
		end
		if hitAny then
			if p:IsA("Part") and p.Shape == Enum.PartType.Block and axisAligned(p) then
				local pieces = { pb }
				for _, c in ipairs(cutters) do
					local nxt = {}
					for _, q in ipairs(pieces) do
						for _, r in ipairs(subtract(q, c.box)) do
							if r.x1 - r.x0 > 0.05 and r.y1 - r.y0 > 0.05 and r.z1 - r.z0 > 0.05 then
								nxt[#nxt + 1] = r
							end
						end
					end
					pieces = nxt
				end
				plan[#plan + 1] = { part = p, pieces = pieces }
			else
				skipped[#skipped + 1] = p:GetFullName():gsub("^.*R_설원3%.", "")
			end
		end
	end
	local nPieces = 0
	for _, e in ipairs(plan) do
		nPieces += #e.pieces
	end
	say("새 자리: 자를 Land 상자 %d 개 → 조각 %d 개. 회전·비상자라 건너뜀 %d 개", #plan, nPieces, #skipped)
	for i = 1, math.min(#skipped, 10) do
		say("  건너뜀 %s", skipped[i])
	end

	--==================================================================== 옛 자리 메우기 표본 색
	local bodyCol, snowCol = { Color3.fromRGB(85, 86, 92), Enum.Material.Slate }, { Color3.fromRGB(238, 243, 247), Enum.Material.Snow }
	local bodyName, snowName = "마을", "마을_눈"
	local sb, ss
	for _, p in ipairs(parts(land)) do
		if not sb and p.Name == bodyName then
			sb = p
		end
		if not ss and p.Name == snowName then
			ss = p
		end
	end
	if sb then
		bodyCol = { sb.Color, sb.Material }
	else
		say("'마을' 표본을 못 찾아 기본값")
	end
	if ss then
		snowCol = { ss.Color, ss.Material }
	else
		say("'마을_눈' 표본을 못 찾아 기본값")
	end
	local nFill = 0
	for _, f in ipairs(fills) do
		nFill += (f.top < GROUND - SNOW_T and 2 or 1)
	end
	say("옛 자리: 메울 상자 %d 개(몸통 + 눈)", nFill)

	if DRY_RUN then
		say("DRY_RUN 끝 — 바꾼 것 없음")
		return
	end

	--==================================================================== 실행(백업 먼저)
	local bk = Instance.new("Folder")
	bk.Name = "Snow_KeepMove_Backup"
	gate:SetAttribute("OrigPivot", pivot)
	local gv = Instance.new("ObjectValue")
	gv.Name = "Gate"
	gv.Value = gate
	gv.Parent = bk
	local made = Instance.new("Folder")
	made.Name = "Made" -- 새 상자 이름 목록(실제 상자에는 KeepMoveMade 속성)
	made.Parent = bk
	for n, e in ipairs(plan) do
		local f = Instance.new("Folder")
		f.Name = "B" .. n
		local c = e.part:Clone()
		c.Name = "Part"
		c:SetAttribute("OrigName", e.part.Name)
		c.Parent = f
		local pv = Instance.new("ObjectValue")
		pv.Name = "Parent"
		pv.Value = e.part.Parent
		pv.Parent = f
		f.Parent = bk
	end
	bk.Parent = SS

	if math.abs(dy) > 0.2 then
		gate:PivotTo(pivot * CFrame.new(0, 0, 0) + Vector3.new(0, -dy, 0))
	end
	local nMade = 0
	local function make(src, b, name)
		local p = src:Clone()
		p.Name = name
		p.Size = Vector3.new(b.x1 - b.x0, b.y1 - b.y0, b.z1 - b.z0)
		p.CFrame = CFrame.new((b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2, (b.z0 + b.z1) / 2)
		p:SetAttribute("KeepMoveMade", true)
		nMade += 1
		return p
	end
	for _, e in ipairs(plan) do
		local par, nm = e.part.Parent, e.part.Name
		for _, b in ipairs(e.pieces) do
			make(e.part, b, nm).Parent = par
		end
		e.part:Destroy()
	end
	local nCut = nMade
	local landFolder = land
	for _, f in ipairs(fills) do
		local bodyTop = GROUND - SNOW_T
		local snowBot = GROUND - SNOW_T
		if f.top < bodyTop then
			local p = Instance.new("Part")
			p.Name, p.Anchored, p.TopSurface, p.BottomSurface = bodyName, true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Color, p.Material = bodyCol[1], bodyCol[2]
			local b = newBox(f.x0, f.x1, f.top, bodyTop, f.z0, f.z1)
			p.Size = Vector3.new(b.x1 - b.x0, b.y1 - b.y0, b.z1 - b.z0)
			p.CFrame = CFrame.new((b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2, (b.z0 + b.z1) / 2)
			p:SetAttribute("KeepMoveMade", true)
			p.Parent = (sb and sb.Parent) or landFolder
			nMade += 1
		else
			snowBot = f.top
		end
		local s = Instance.new("Part")
		s.Name, s.Anchored, s.TopSurface, s.BottomSurface = snowName, true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		s.Color, s.Material = snowCol[1], snowCol[2]
		s.Size = Vector3.new(f.x1 - f.x0, GROUND - snowBot, f.z1 - f.z0)
		s.CFrame = CFrame.new((f.x0 + f.x1) / 2, (snowBot + GROUND) / 2, (f.z0 + f.z1) / 2)
		s:SetAttribute("KeepMoveMade", true)
		s.Parent = (ss and ss.Parent) or landFolder
		nMade += 1
	end
	say("실행: Gate 를 %.2f 내림. 새 자리 잘라낸 조각 %d · 원본 %d 개는 백업 후 Destroy · 옛 자리 메운 상자 %d", dy, nCut, #plan, nMade - nCut)
end)
if not okRun then
	say("ERR %s", tostring(errRun))
end
print(table.concat(report, "\n"))
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/keepmove", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
