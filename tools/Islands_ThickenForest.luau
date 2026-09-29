--!nocheck
--[[
	Islands_ThickenForest.luau — 숲 나무를 더 빽빽하게 심는다.

	나무를 새로 만들지 않는다. **이미 서 있는 그루를 복제해서 옮겨 심는다.**
	기존 338그루는 하나하나 다르게 생겼고 그 생김새가 마음에 든 것이므로,
	새 생성기를 쓰면 그 결을 잃는다. 복제본마다 Y축 회전과 크기를 달리 주면
	같은 원본이라도 다른 나무로 읽힌다.

	**바위에는 안 심는다.** 발밑 판의 재질이 풀이 아니면 그 자리는 버린다.
	돌 위에서 나무가 자라는 게 어색하다는 게 이 작업의 출발점이다.
	거목이 선 바위 대지도 같은 이유로 비워 둔다.

	Islands_Ground / LiftForest / Mountains / TrimTreesInRock 뒤에 실행한다.
	되돌리려면 이름이 For_P 로 시작하는 파트만 지우면 된다.
]]

local TARGET = 780 -- 이만큼이 될 때까지 심는다
local CLEAR = 340 -- 거목 둘레 이 반경은 비운다. 바위 대지가 보여야 한다
local SPACING = 86 -- 이보다 가까운 자리에는 두 번 심지 않는다
local SCALE_LO, SCALE_HI = 0.62, 1.38

local G = workspace.Surface.World["G_숲"]
local R = workspace.Surface["R_숲"]
local ELDER = Vector2.new(-4800, 1600)

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { G }

--=== 원본 그루 모으기 ===--
-- 그루 하나는 For_<번호>_ 로 묶인다. 밑동 높이를 기준점으로 잡아야
-- 복제본을 새 지면에 앉힐 때 뿌리가 뜨거나 묻히지 않는다.
local src = {}
for _, p in ipairs(R.Flora:GetChildren()) do
	local id = p:IsA("BasePart") and p.Name:match("^For_([^_]+)_")
	if id then
		local g = src[id]
		if not g then
			g = { n = 0, sx = 0, sz = 0, mny = 1e9, list = {} }
			src[id] = g
		end
		g.n += 1
		g.sx += p.Position.X
		g.sz += p.Position.Z
		g.mny = math.min(g.mny, p.Position.Y)
		g.list[#g.list + 1] = p
	end
end

local pool, have = {}, 0
for id, g in pairs(src) do
	have += 1
	-- 거목은 원본으로 쓰지 않는다. 랜드마크가 복제되면 안 된다
	if id ~= "Elder" and g.n >= 8 and g.n <= 80 then
		pool[#pool + 1] = g
	end
end
assert(#pool > 20, "복제할 원본이 " .. #pool .. "그루뿐이다")

--=== 자리 잡기 ===--
local minx, maxx, minz, maxz = 1e9, -1e9, 1e9, -1e9
for _, p in ipairs(G:GetChildren()) do
	if p.Name:sub(1, 3) == "Gs_" then
		minx = math.min(minx, p.Position.X)
		maxx = math.max(maxx, p.Position.X)
		minz = math.min(minz, p.Position.Z)
		maxz = math.max(maxz, p.Position.Z)
	end
end

-- 이미 나무가 선 자리를 격자에 찍어 둔다. 같은 곳에 겹쳐 심지 않으려는 것이다
local taken = {}
local function key(x, z)
	return math.floor(x / SPACING) .. "_" .. math.floor(z / SPACING)
end
for _, g in pairs(src) do
	taken[key(g.sx / g.n, g.sz / g.n)] = true
end

local rng = Random.new(20260911)
local planted, tries, onRock, tooClose = 0, 0, 0, 0
local want = TARGET - have

while planted < want and tries < want * 60 do
	tries += 1
	local x = rng:NextNumber(minx, maxx)
	local z = rng:NextNumber(minz, maxz)

	if (Vector2.new(x, z) - ELDER).Magnitude < CLEAR then
		tooClose += 1
	elseif taken[key(x, z)] then
		tooClose += 1
	else
		local hit = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1400, 0), rp)
		-- 풀이 아닌 판 위에는 심지 않는다. 바위도 모래도 안 된다
		if hit and hit.Instance.Material == Enum.Material.Grass then
			taken[key(x, z)] = true
			local g = pool[rng:NextInteger(1, #pool)]
			local sc = rng:NextNumber(SCALE_LO, SCALE_HI)
			local srcCF = CFrame.new(g.sx / g.n, g.mny, g.sz / g.n)
			local dstCF = CFrame.new(x, hit.Position.Y, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)

			planted += 1
			local id = "P" .. planted
			for _, p in ipairs(g.list) do
				local rel = srcCF:ToObjectSpace(p.CFrame)
				-- 위치만 배율을 먹인다. 회전은 그대로 둬야 가지 각도가 유지된다
				local rel2 = rel - rel.Position + rel.Position * sc
				local c = p:Clone()
				c.Name = "For_" .. id .. "_" .. p.Name:gsub("^For_[^_]+_", "")
				c.Size = p.Size * sc
				c.CFrame = dstCF * rel2
				c:SetAttribute("GY", hit.Position.Y)
				c.Parent = R.Flora
			end
		elseif hit then
			onRock += 1
		end
	end
	if tries % 40 == 0 then
		task.wait()
	end
end

assert(planted > want * 0.6, "심은 것이 " .. planted .. "그루뿐이다. 자리가 모자란다")
print(
	string.format(
		"[ThickenForest] %d그루 -> %d그루 (새로 %d) / 바위라 버림 %d, 자리 겹쳐 버림 %d, 시도 %d",
		have,
		have + planted,
		planted,
		onRock,
		tooClose,
		tries
	)
)
