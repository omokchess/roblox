--!nocheck
-- 신맵 전량 철거 — Studio 커맨드 바에 붙여넣어 실행.
-- 설계 근거는 「신맵 구조도.md」 §0.
--
-- 하는 일:
--   1. workspace.Tree 안의 `Taiga Tree` 70그루 중 설원 셀 중심에 가장 가까운 한 그루만 살린다.
--   2. 그 한 그루를 Surface/R_설원/Flora 로 옮기고, 설원 셀 중심 (-1600, -1600), 밑동 Y=0 에 앉힌다.
--   3. 나머지 최상위 인스턴스 전부 삭제 + 지형 초기화.
--
-- 실행 전 백업: 파일 > 사본 다운로드
-- DRY_RUN = true 면 무엇을 지울지만 출력한다.

local DRY_RUN = false

local SNOW_X, SNOW_Z = -1600, -1600 -- 설원 셀 (-1,-1) 중심
local GROUND_Y = 0 -- 지상 기준면. 나무 밑동을 여기 맞춘다

local KEEP = { Terrain = true, Camera = true }

-- 자기 자신 + 자손의 BasePart 경계 상자
local function bounds(inst)
	local n, lo, hi = 0, nil, nil
	local function add(p)
		local c, h = p.Position, p.Size / 2
		lo = lo and lo:Min(c - h) or (c - h)
		hi = hi and hi:Max(c + h) or (c + h)
		n += 1
	end
	if inst:IsA("BasePart") then
		add(inst)
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			add(d)
		end
	end
	return n, lo, hi
end

-- 1. 살릴 나무 고르기 — 설원 셀 중심에 가장 가까운 그루
local treeRoot = workspace:FindFirstChild("Tree")
local keeper, keeperDist
if treeRoot then
	for _, t in ipairs(treeRoot:GetChildren()) do
		local n, lo, hi = bounds(t)
		if n > 0 then
			local c = (lo + hi) / 2
			local d = (Vector2.new(c.X, c.Z) - Vector2.new(SNOW_X, SNOW_Z)).Magnitude
			if not keeperDist or d < keeperDist then
				keeper, keeperDist = t, d
			end
		end
	end
end

if not keeper then
	warn("[WipeMap] 살릴 나무를 찾지 못했다. workspace.Tree 확인 필요. 중단.")
	return
end

local kn, klo, khi = bounds(keeper)
print(
	string.format(
		"살릴 나무: %s (%s) 파트 %d / 현재 중심(%d,%d,%d) 크기(%d,%d,%d) / 설원중심까지 %d",
		keeper.Name,
		keeper.ClassName,
		kn,
		(klo.X + khi.X) / 2,
		(klo.Y + khi.Y) / 2,
		(klo.Z + khi.Z) / 2,
		khi.X - klo.X,
		khi.Y - klo.Y,
		khi.Z - klo.Z,
		keeperDist
	)
)

-- 2. 삭제 대상 집계
local targets, groups, order, total = {}, {}, {}, 0
for _, child in ipairs(workspace:GetChildren()) do
	if not KEEP[child.Name] and not child:IsA("SpawnLocation") then
		local n = bounds(child)
		table.insert(targets, child)
		total += n
		local key = child.Name .. "  (" .. child.ClassName .. ")"
		local g = groups[key]
		if not g then
			g = { n = 0, parts = 0 }
			groups[key] = g
			table.insert(order, key)
		end
		g.n += 1
		g.parts += n
	end
end
table.sort(order, function(a, b)
	return groups[a].parts > groups[b].parts
end)
for _, key in ipairs(order) do
	print(string.format("  삭제 %-30s ×%-4d 파트 %d", key, groups[key].n, groups[key].parts))
end

if DRY_RUN then
	print(
		string.format(
			"[WipeMap] DRY_RUN — 최상위 %d개 / 파트 %d개 삭제 대상 (나무 1그루 제외)",
			#targets,
			total
		)
	)
	return
end

-- 3. 나무를 설원으로 이관. Union·Script 등 내부는 건드리지 않고 평행이동만 한다
local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local flora = folder(folder(folder(workspace, "Surface"), "R_설원"), "Flora")
keeper.Name = "Snw_TaigaTree"
keeper.Parent = flora

local offset = Vector3.new(SNOW_X - (klo.X + khi.X) / 2, GROUND_Y - klo.Y, SNOW_Z - (klo.Z + khi.Z) / 2)
if keeper:IsA("Model") then
	keeper:PivotTo(keeper:GetPivot() + offset)
else
	for _, d in ipairs(keeper:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Position += offset
		end
	end
end

-- 4. 나머지 철거
for _, inst in ipairs(targets) do
	inst:Destroy()
end
workspace.Terrain:Clear()

local _, nlo, nhi = bounds(keeper)
print(
	string.format(
		"[WipeMap] 철거 완료 — 최상위 %d개 / 파트 %d개 삭제 + 지형 초기화. "
			.. "남긴 나무 Surface.R_설원.Flora.Snw_TaigaTree 중심(%d,%d,%d) 밑동 Y=%d. 다음: BuildRegionSkeleton",
		#targets,
		total,
		(nlo.X + nhi.X) / 2,
		(nlo.Y + nhi.Y) / 2,
		(nlo.Z + nhi.Z) / 2,
		nlo.Y
	)
)
