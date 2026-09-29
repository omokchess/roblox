--!nocheck
--[[
	Jeolhwa_City3.luau — 평원의 도성 절화 3판. (2026-09-26)

	2판은 담 두른 필지 네 종류를 길 양쪽에 같은 간격으로 늘어놓아, 위에서 보면 바둑판이고
	길에 서면 어디나 같은 장면이었다. 궁은 넓은 빈 박석 마당에 건물 다섯 채뿐이었다.
	3판은
	  * 궁을 정문(광화문형) → 금천과 다리 → 중문과 행각으로 두른 정전 마당 → 북문 → 침전
	    축으로 세우고, 서쪽에 경회루 연못과 궐내각사, 동쪽에 동궁과 후원을 둔다
	  * 도성은 구역마다 성격과 밀도를 달리한다. 북촌은 골목 담을 맞댄 기와집,
	    저자는 운종가 행랑과 종루 선 저잣마당, 남촌은 초가 무리와 논밭
	  * 길은 광장에서 방사로 나가고 바깥 순환길이 끝을 이어 막다른 길이 없다

	**배치는 tools/jeolhwa_plan.py 표에 손으로 적었다.** 그 파일이 겹침을 검사하고
	평면도를 그리고 이 스크립트가 읽는 표(Jeolhwa_City3_data.luau)를 뽑는다.
	붙여 넣는 파일은 --@@DATA@@ 자리에 그 표를 끼운 Jeolhwa_City3_run.luau 다.

	틀은 ServerStorage.JeolhwaKit 에 이미 색과 충돌을 입혀 두었다(Jeolhwa_City, Jeolhwa_Kit2).
	다시 돌리면 Workspace.Jeolhwa 만 새로 짓는다. 걸린 원래 나무는 그루째
	ServerStorage.Jeolhwa_ClearedFlora 로 옮기고, 다시 돌릴 때 먼저 제자리로 돌린다.
]]
-- jeolhwa_plan.py 가 적은 표. 손으로 고치지 말고 jeolhwa_plan.py 를 고쳐 다시 뽑는다
local D = {}
D.PALACE = {
	{"Gate_Palace", 225, 640, 0, "궁/정문"},
	{"Gate_Main", 20, 680, 90, "궁/정문"},
	{"Gate_Main", 430, 680, -90, "궁/정문"},
	{"Gate_Hall", 225, 712, 0, "궁/정전"},
	{"Palace_Main", 225, 805, 0, "궁/정전"},
	{"Gate_Main", 225, 870, 0, "궁/정전"},
	{"Corridor_Corner", 140, 712, -90, "궁/행각"},
	{"Corridor_Corner", 310, 712, 180, "궁/행각"},
	{"Corridor_Corner", 310, 870, 90, "궁/행각"},
	{"Corridor_Corner", 140, 870, 0, "궁/행각"},
	{"Palace_Chimjeon", 225, 925, 0, "궁/침전"},
	{"Annex_Tile", 168, 912, 8, "궁/침전"},
	{"Building_House", 282, 912, -6, "궁/침전"},
	{"Prop_Jangdok", 300, 940, 0, "궁/침전"},
	{"Prop_Well", 268, 944, 0, "궁/침전"},
	{"Building_House", 58, 735, 0, "궁/각사"},
	{"Granary", 110, 742, -90, "궁/각사"},
	{"Annex_Tile", 42, 772, 90, "궁/각사"},
	{"Prop_Well", 90, 718, 0, "궁/각사"},
	{"Pavilion_Nugak", 79, 862, 90, "궁/경회루"},
	{"Gate_Main", 376, 705, 0, "궁/동궁"},
	{"Building_Hall", 376, 782, 0, "궁/동궁"},
	{"Annex_Tile", 345, 742, -90, "궁/동궁"},
	{"Annex_Tile", 407, 742, 90, "궁/동궁"},
	{"Prop_Jangdok", 408, 800, 0, "궁/동궁"},
	{"Pavilion_Jeongja", 377, 882, 0, "궁/후원"},
}
D.TOWN = {
	{"Building_HouseL", -30, 652, 0, "북촌"},
	{"Annex_Tile", -60, 636, -90, "북촌"},
	{"Prop_Jangdok", -50, 670, 0, "북촌"},
	{"Building_House", -100, 650, 6, "북촌"},
	{"Prop_Garden", -82, 674, 6, "북촌"},
	{"Building_HouseLM", -150, 676, 12, "북촌"},
	{"Prop_Jangdok", -176, 684, 12, "북촌"},
	{"Building_House", -32, 758, -4, "북촌"},
	{"Annex_Tile", -62, 742, -90, "북촌"},
	{"Building_HouseL", -104, 770, -8, "북촌"},
	{"Prop_Jangdok", -80, 785, 0, "북촌"},
	{"Prop_Well", -18, 781, 0, "북촌"},
	{"Building_House", -146, 778, 14, "북촌"},
	{"Building_HouseLM", -40, 868, 2, "북촌"},
	{"Building_House", -82, 874, 10, "북촌"},
	{"Annex_Tile", -104, 908, 100, "북촌"},
	{"Building_House", -142, 914, 22, "북촌"},
	{"Pavilion_Jeongja", -48, 944, 0, "북촌"},
	{"Building_House", 138, 590, 0, "서촌길가"},
	{"Shop_Row3", 92, 598, 4, "서촌길가"},
	{"Annex_Tile", 55, 612, -4, "서촌길가"},
	{"Prop_Well", 28, 614, 0, "서촌길가"},
	{"Building_HouseLM", 112, 508, 180, "주막"},
	{"Prop_Jangdok", 135, 492, 0, "주막"},
	{"Building_Cottage", 62, 520, 172, "주막"},
	{"Building_Cottage", -236, 618, 15, "서촌"},
	{"Annex_Thatch", -262, 640, 75, "서촌"},
	{"Prop_Haystack", -214, 640, 0, "서촌"},
	{"Building_House", -252, 568, -10, "서촌"},
	{"Building_HouseL", -204, 796, 70, "서촌"},
	{"Annex_Thatch", -200, 842, 40, "서촌"},
	{"Prop_Garden", -178, 820, 20, "서촌"},
	{"Building_Cottage", -178, 520, 8, "서촌"},
	{"Prop_Garden", -150, 530, 8, "서촌"},
	{"Shop_Row5", 318, 572, 0, "저자"},
	{"Shop_Row3", 367, 575, -2, "저자"},
	{"Shop_Row5", 424, 587, -8, "저자"},
	{"Granary", 330, 614, 180, "저자"},
	{"Building_House", 405, 620, 176, "저자"},
	{"Shop_Row5", 374, 516, 180, "저자"},
	{"Shop_Row3", 422, 520, 184, "저자"},
	{"Building_House", 458, 503, 175, "저자"},
	{"Building_House", 372, 474, 184, "저자"},
	{"Granary", 414, 478, 176, "저자"},
	{"Tower_Bell", 504, 580, 0, "저잣마당"},
	{"Prop_Well", 478, 604, 0, "저잣마당"},
	{"Shop_Row3", 505, 628, 0, "저잣마당"},
	{"Shop_Row5", 500, 530, 180, "저잣마당"},
	{"Building_HouseL", 574, 562, 90, "저잣마당"},
	{"Prop_Jangdok", 566, 590, 0, "저잣마당"},
	{"Building_HouseL", 492, 738, 4, "동촌"},
	{"Annex_Tile", 522, 760, -95, "동촌"},
	{"Building_Cottage", 562, 748, -8, "동촌"},
	{"Building_Cottage", 470, 806, 20, "동촌"},
	{"Annex_Thatch", 505, 826, 60, "동촌"},
	{"Building_House", 560, 832, -25, "동촌"},
	{"Prop_Garden", 598, 750, -8, "동촌"},
	{"Prop_Haystack", 486, 848, 0, "동촌"},
	{"Building_Hall", 628, 858, -80, "척수관"},
	{"Granary", 596, 902, 190, "척수관"},
	{"Annex_Tile", 648, 800, -95, "척수관"},
	{"Granary", 200, 318, 0, "관아"},
	{"Annex_Tile", 254, 322, 90, "관아"},
	{"Building_Cottage", -210, 318, 10, "남촌"},
	{"Building_Cottage", -170, 298, -15, "남촌"},
	{"Annex_Thatch", -236, 294, 80, "남촌"},
	{"Prop_Haystack", -190, 336, 0, "남촌"},
	{"Building_Cottage", -60, 312, 5, "남촌"},
	{"Building_Cottage", -22, 290, -20, "남촌"},
	{"Annex_Thatch", -84, 290, 70, "남촌"},
	{"Prop_Haystack", -40, 332, 0, "남촌"},
	{"Building_Cottage", 72, 330, 0, "남촌"},
	{"Annex_Thatch", 100, 316, -80, "남촌"},
	{"Building_Cottage", 96, 284, 25, "남촌"},
	{"Building_Cottage", 456, 322, 5, "남촌"},
	{"Building_Cottage", 496, 302, -15, "남촌"},
	{"Building_House", 428, 290, 10, "남촌"},
	{"Annex_Thatch", 482, 268, 90, "남촌"},
	{"Building_Cottage", 590, 336, 20, "남촌"},
	{"Building_Cottage", 566, 300, -5, "남촌"},
	{"Prop_Haystack", 612, 312, 0, "남촌"},
	{"Pavilion_Jeongja", 285, 30, 180, "산정자"},
	{"Pavilion_Jeongja", 705, 250, 90, "산정자"},
}
D.CORRIDORS = {
	{145, 712, 206.5, 712, 180, 3},
	{243.5, 712, 305, 712, 180, 3},
	{145, 870, 210, 870, 0, 3},
	{240, 870, 305, 870, 0, 3},
	{140, 717, 140, 865, -90, 7},
	{310, 717, 310, 865, 90, 7},
}
D.WALLS = {
	{"Wall_Segment", 21, 640, 194.5, 640, "궁/담"},
	{"Wall_Segment", 255.5, 640, 429, 640, "궁/담"},
	{"Wall_Segment", 20, 640, 20, 665, "궁/담"},
	{"Wall_Segment", 20, 695, 20, 957, "궁/담"},
	{"Wall_Segment", 430, 640, 430, 665, "궁/담"},
	{"Wall_Segment", 430, 695, 430, 957, "궁/담"},
	{"Wall_Segment", 21, 957, 429, 957, "궁/담"},
	{"Wall_Segment", 327, 705, 361, 705, "궁/동궁"},
	{"Wall_Segment", 391, 705, 429, 705, "궁/동궁"},
	{"Wall_Segment", 327, 706, 327, 815, "궁/동궁"},
	{"Wall_Segment", 328, 815, 429, 815, "궁/동궁"},
	{"Wall_Segment", -71, 614, -31, 614, "북촌"},
	{"Wall_Segment", -11, 614, -7, 614, "북촌"},
	{"Wall_Segment", -7, 615, -7, 668, "북촌"},
	{"Wall_Segment", -72, 615, -72, 660, "북촌"},
	{"Wall_Stone", -124, 624, -106, 621, "북촌"},
	{"Wall_Stone", -90, 619, -74, 618, "북촌"},
	{"Wall_Segment", -6, 711, -20, 712, "북촌"},
	{"Wall_Segment", -40, 713, -86, 706, "북촌"},
	{"Wall_Segment", -86, 706, -94, 707, "북촌"},
	{"Wall_Segment", -114, 710, -130, 717, "북촌"},
	{"Wall_Segment", -130, 717, -162, 742, "북촌"},
	{"Wall_Segment", -8, 790, -38, 794, "북촌"},
	{"Wall_Segment", -58, 800, -120, 832, "북촌"},
	{"Wall_Stone", 592, 536, 592, 588, "저잣마당"},
	{"Wall_Segment", 180, 300, 270, 300, "관아"},
	{"Wall_Segment", 180, 301, 180, 398, "관아"},
	{"Wall_Segment", 270, 301, 270, 398, "관아"},
	{"Wall_Segment", 181, 398, 215, 398, "관아"},
	{"Wall_Segment", 235, 398, 269, 398, "관아"},
	{"Fence_Brush", 598, 812, 598, 880, "척수관"},
	{"Fence_Brush", 598, 812, 640, 780, "척수관"},
	{"Fence_Brush", -226, 344, -186, 350, "남촌"},
	{"Fence_Brush", -76, 336, -46, 344, "남촌"},
	{"Fence_Brush", 58, 350, 90, 352, "남촌"},
	{"Fence_Brush", 440, 344, 478, 340, "남촌"},
}
D.GATES = {
	{-21, 614, 0, "북촌"},
	{-30, 712.5, 0, "북촌"},
	{-104, 708.5, 5, "북촌"},
	{-48, 797, 17, "북촌"},
	{225, 398, 180, "관아"},
}
D.ROADS = {
	{"운종가", 28, "dirt", {{285, 545}, {340, 545}, {374, 545}, {422, 551}, {470, 566}}},
	{"운종가동", 14, "dirt", {{540, 604}, {590, 606}, {638, 601}, {668, 600}}},
	{"서촌길", 14, "dirt", {{165, 545}, {120, 550}, {72, 561}, {30, 576}, {0, 592}, {-50, 597}, {-105, 606}, {-158, 626}, {-205, 656}, {-245, 698}, {-272, 750}}},
	{"북촌길", 12, "dirt", {{0, 592}, {4, 640}, {2, 690}, {-1, 742}, {3, 795}, {-2, 850}, {-18, 902}, {-37, 922}}},
	{"북촌골목1", 9, "dirt", {{2, 690}, {-40, 699}, {-85, 692}, {-128, 704}, {-168, 732}}},
	{"북촌골목2", 9, "dirt", {{3, 795}, {-38, 805}, {-80, 820}, {-120, 847}, {-152, 880}}},
	{"남서길", 12, "dirt", {{170, 430}, {130, 408}, {82, 392}, {22, 378}, {-45, 370}, {-115, 368}, {-185, 378}, {-240, 402}, {-282, 440}}},
	{"남동길", 12, "dirt", {{280, 430}, {320, 410}, {372, 394}, {430, 382}, {495, 372}, {560, 374}, {618, 390}, {660, 425}}},
	{"남산길", 8, "dirt", {{372, 394}, {366, 320}, {346, 232}, {318, 140}, {298, 72}}},
	{"동산길", 8, "dirt", {{618, 390}, {650, 345}, {678, 298}, {690, 274}}},
	{"서순환", 10, "dirt", {{-282, 440}, {-298, 520}, {-300, 600}, {-290, 680}, {-272, 750}, {-250, 815}, {-215, 868}}},
	{"동순환", 10, "dirt", {{660, 425}, {672, 500}, {668, 600}, {655, 690}, {625, 780}, {585, 850}, {548, 895}}},
	{"동문길", 12, "dirt", {{445, 680}, {500, 688}, {560, 698}, {618, 706}, {655, 690}}},
	{"관아앞", 16, "stone", {{225, 425}, {225, 402}}},
	{"어도", 24, "stone", {{225, 598}, {225, 631}}},
	{"북문길", 10, "stone", {{225, 882}, {225, 891}}},
}
D.POOLS = {
	{"서촌못", -96, 488, -44, 526},
	{"경회루못", 34, 800, 118, 925},
	{"후원못", 342, 842, 412, 922},
	{"금천", 70, 669, 380, 677},
}
D.ISLANDS = {
	{362, 867, 392, 897},
}
D.BRIDGES = {
	{225, 673, 0, 16, 26},
	{120, 673, 0, 14, 8},
	{330, 673, 0, 14, 8},
	{108, 862, 90, 22, 9},
	{377, 855, 0, 26, 6},
}
D.PAVES = {
	{"바깥마당", 25, 650, 425, 700, "ground"},
	{"정문길", 195, 631, 255, 650, "ground"},
	{"정전마당", 131, 700, 319, 882, "ring"},
	{"저잣마당", 468, 548, 540, 612, "ground"},
}
D.FIELDS = {
	{-140, 420, -60, 480},
	{-40, 410, 40, 470},
	{-250, 460, -170, 500},
	{-120, 250, -60, 280},
	{10, 230, 70, 270},
	{-230, 240, -180, 280},
	{400, 230, 470, 260},
	{520, 250, 600, 290},
	{120, 250, 170, 300},
	{-296, 318, -256, 352},
	{-132, 318, -98, 348},
	{18, 318, 52, 350},
	{130, 322, 170, 360},
	{378, 272, 408, 306},
	{-300, 390, -260, 420},
}
D.TREES = {
	{64, 788},
	{100, 786},
	{36, 935},
	{124, 940},
	{80, 945},
	{335, 830},
	{420, 835},
	{335, 935},
	{420, 940},
	{420, 772},
	{48, 705},
	{412, 655},
	{40, 655},
	{142, 890},
	{312, 888},
	{22, 604},
	{-120, 684},
	{-190, 700},
	{-60, 820},
	{-160, 850},
	{-10, 930},
	{-110, 940},
	{150, 612},
	{8, 560},
	{148, 520},
	{40, 490},
	{-100, 500},
	{-230, 480},
	{-40, 440},
	{300, 600},
	{452, 612},
	{552, 622},
	{556, 528},
	{300, 450},
	{300, 500},
	{322, 522},
	{296, 474},
	{338, 488},
	{520, 700},
	{600, 790},
	{450, 860},
	{530, 930},
	{680, 560},
	{640, 470},
	{-150, 340},
	{0, 320},
	{40, 280},
	{130, 340},
	{400, 330},
	{540, 330},
	{620, 270},
	{-280, 360},
	{-260, 700},
	{-230, 900},
	{360, 250},
	{240, 260},
	{180, 260},
	{-300, 262},
	{-278, 252},
	{-120, 226},
	{-98, 212},
	{30, 214},
	{205, 230},
	{470, 225},
	{500, 236},
	{660, 330},
	{-40, 250},
}


local report = {}
local function say(fmt, ...)
	report[#report + 1] = string.format(fmt, ...)
end

local RGB = Color3.fromRGB
local M = Enum.Material
local C = {
	pave = RGB(176, 172, 158), -- 박석
	rim = RGB(193, 190, 176), -- 갓돌. 틀의 Stylobate 와 같다
	masonry = RGB(157, 153, 139),
	bed = RGB(54, 62, 56),
	water = RGB(72, 112, 116),
	dirt = RGB(150, 128, 96),
	soil = RGB(122, 100, 73),
	crop = RGB(108, 132, 66),
}

--==================================================================== 도구
local function halfExtents(part, frame)
	local r = frame:ToObjectSpace(part.CFrame)
	local s = part.Size / 2
	local R, U, L = r.RightVector, r.UpVector, r.LookVector
	return Vector3.new(
		math.abs(R.X) * s.X + math.abs(U.X) * s.Y + math.abs(L.X) * s.Z,
		math.abs(R.Y) * s.X + math.abs(U.Y) * s.Y + math.abs(L.Y) * s.Z,
		math.abs(R.Z) * s.X + math.abs(U.Z) * s.Y + math.abs(L.Z) * s.Z
	), r.Position
end

-- 모델을 피벗 x 축으로만 늘인다. 담과 행각 토막 길이를 두 끝에 맞추려는 것이다
local function stretchX(model, f)
	local frame = model:GetPivot()
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local r = frame:ToObjectSpace(p.CFrame)
			local R, U, L = r.RightVector, r.UpVector, r.LookVector
			local ax = { math.abs(R.X), math.abs(U.X), math.abs(L.X) }
			local s = p.Size
			if ax[1] >= ax[2] and ax[1] >= ax[3] then
				s = Vector3.new(s.X * f, s.Y, s.Z)
			elseif ax[2] >= ax[3] then
				s = Vector3.new(s.X, s.Y * f, s.Z)
			else
				s = Vector3.new(s.X, s.Y, s.Z * f)
			end
			p.Size = s
			p.CFrame = frame * CFrame.new(r.X * f, r.Y, r.Z) * r.Rotation
		end
	end
end

local okRun, errRun = pcall(function()
	local SS = game:GetService("ServerStorage")
	local kit = assert(SS:FindFirstChild("JeolhwaKit"), "ServerStorage.JeolhwaKit 이 없다")
	for _, list in ipairs({ D.PALACE, D.TOWN }) do
		for _, e in ipairs(list) do
			assert(kit:FindFirstChild(e[1]), e[1] .. " 틀이 없다. Jeolhwa_Kit2 를 먼저 돌려라")
		end
	end

	--==================================================================== 판
	-- 2판은 지우지 않고 ServerStorage 로 치워 둔다. 3판을 다시 돌릴 때는 3판만 새로 짓는다
	local old = workspace:FindFirstChild("Jeolhwa")
	if old then
		if old:GetAttribute("Version") ~= 3 and not SS:FindFirstChild("Jeolhwa_v2_backup") then
			old.Name = "Jeolhwa_v2_backup"
			old.Parent = SS
			say("2판을 ServerStorage.Jeolhwa_v2_backup 으로 옮겼다")
		else
			old:Destroy()
		end
	end
	local city = Instance.new("Folder")
	city.Name = "Jeolhwa"
	city:SetAttribute("Version", 3)
	city.Parent = workspace
	local function folder(path)
		local f = city
		for name in string.gmatch(path, "[^/]+") do
			local c = f:FindFirstChild(name)
			if not c then
				c = Instance.new("Folder")
				c.Name = name
				c.Parent = f
			end
			f = c
		end
		return f
	end
	local FStone, FWater, FRoads, FTrees = folder("돌"), folder("물"), folder("길"), folder("나무")

	local G = workspace.Surface.World["G_평원"]
	local rpG = RaycastParams.new()
	rpG.FilterType = Enum.RaycastFilterType.Include
	rpG.FilterDescendantsInstances = { G }
	local rpAll = RaycastParams.new()
	rpAll.FilterType = Enum.RaycastFilterType.Include
	rpAll.FilterDescendantsInstances = { G, FStone }
	local function groundY(x, z, rp)
		local h = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), rp or rpAll)
		return h and h.Position.Y
	end
	-- 사각형 위를 16 간격으로 재어 가장 낮은 곳과 높은 곳
	local function span(x0, z0, x1, z1, rp)
		local lo, hi = math.huge, -math.huge
		local nx, nz = math.max(2, math.ceil((x1 - x0) / 16)), math.max(2, math.ceil((z1 - z0) / 16))
		for i = 0, nx do
			for j = 0, nz do
				local gy = groundY(x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz, rp)
				assert(gy, string.format("(%.0f,%.0f) 아래에 땅이 없다", x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		return lo, hi
	end

	local nParts = 0
	local function part(name, cf, size, color, mat, parent)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		nParts += 1
		return p
	end
	-- 윗면이 top 인 판. 밑은 판 아래 가장 낮은 땅보다 0.9 깊게 묻는다
	local function slab(name, x0, z0, x1, z1, top, color, mat, parent)
		local lo = span(x0, z0, x1, z1, rpG)
		local bot = math.min(lo, top - 0.4) - 0.9
		return part(name, CFrame.new((x0 + x1) / 2, (top + bot) / 2, (z0 + z1) / 2),
			Vector3.new(x1 - x0, top - bot, z1 - z0), color, mat, parent)
	end
	-- 넓은 자리는 48 이하 조각으로 나눈다. 윗면은 모두 같은 높이다
	local function tiled(name, x0, z0, x1, z1, top, color, mat, parent)
		local nx, nz = math.ceil((x1 - x0) / 48), math.ceil((z1 - z0) / 48)
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				slab(string.format("%s_%d_%d", name, i, j),
					x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz,
					x0 + (x1 - x0) * (i + 1) / nx, z0 + (z1 - z0) * (j + 1) / nz, top, color, mat, parent)
			end
		end
	end
	-- 윗면 top 에서 바깥(dx, dz) 쪽으로 아래 바닥까지 내려가는 계단. (x, z) 는 가장자리 가운데
	local function stepsDown(name, x, z, dx, dz, width, top, parent, belowFn)
		local below = belowFn and belowFn(x + dx * 6, z + dz * 6, top) or groundY(x + dx * 6, z + dz * 6)
		assert(below, name .. " 계단 아래에 바닥이 없다")
		local drop = top - below
		if drop < 0.5 then
			return 0
		end
		local n = math.ceil(drop / 0.9)
		local rot = (dx ~= 0) and CFrame.Angles(0, math.rad(90), 0) or CFrame.new()
		for k = 1, n do
			local stTop = top - drop * k / (n + 1)
			local off = 2.2 * (k - 0.5)
			local bot = below - 1
			part(string.format("%s_Step%d", name, k),
				CFrame.new(x + dx * off, (stTop + bot) / 2, z + dz * off) * rot,
				Vector3.new(width, stTop - bot, 2.3), C.rim, M.Limestone, parent)
		end
		return n
	end

	--==================================================================== 1. 돌 바닥
	local ringTop
	for _, p in ipairs(D.PAVES) do
		local name, x0, z0, x1, z1, kind = p[1], p[2], p[3], p[4], p[5], p[6]
		local _, hi = span(x0, z0, x1, z1, rpG)
		local f = folder("돌/" .. name)
		if kind == "ring" then
			-- 행각 마당 기단. 한 높이로 평평해야 행각 토막 지붕이 층지지 않는다
			ringTop = hi + 0.8
			tiled("Base", x0, z0, x1, z1, ringTop, C.masonry, M.Slate, f)
			local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
			part("Rim_S", CFrame.new(cx, ringTop - 0.3, z0 + 1), Vector3.new(x1 - x0 + 0.6, 0.8, 2.2), C.rim, M.Limestone, f)
			part("Rim_N", CFrame.new(cx, ringTop - 0.3, z1 - 1), Vector3.new(x1 - x0 + 0.6, 0.8, 2.2), C.rim, M.Limestone, f)
			part("Rim_W", CFrame.new(x0 + 1, ringTop - 0.3, cz), Vector3.new(2.2, 0.8, z1 - z0 - 4.6), C.rim, M.Limestone, f)
			part("Rim_E", CFrame.new(x1 - 1, ringTop - 0.3, cz), Vector3.new(2.2, 0.8, z1 - z0 - 4.6), C.rim, M.Limestone, f)
			-- 가운데 어도. 중문에서 정전 계단까지 한 켜 높인 돌길
			part("Eodo", CFrame.new(225, ringTop + 0.15, 745.5), Vector3.new(12, 0.3, 33), C.rim, M.Limestone, f)
			-- 품계석. 어도 양옆에 여섯씩
			for k = 0, 5 do
				for _, sx in ipairs({ -1, 1 }) do
					part(string.format("Pumgye_%d_%d", k, sx), CFrame.new(225 + sx * 13, ringTop + 1.1, 734 + k * 5),
						Vector3.new(1.4, 2.2, 1.0), C.rim, M.Limestone, f)
				end
			end
			say("행각 기단 윗면 %.2f", ringTop)
		else
			tiled("Pave", x0, z0, x1, z1, hi + 0.3, C.pave, M.Limestone, f)
		end
	end
	assert(ringTop, "행각 기단(ring) 자리가 표에 없다")

	--==================================================================== 2. 물
	local pools = {}
	for _, p in ipairs(D.POOLS) do
		local name, x0, z0, x1, z1 = p[1], p[2], p[3], p[4], p[5]
		local lo, hi = span(x0 - 2, z0 - 2, x1 + 2, z1 + 2)
		local canal = (z1 - z0) < 12 or (x1 - x0) < 12
		local rimTop = hi + (canal and 1.0 or 1.6)
		local waterTop = rimTop - 0.5
		local bedTop = hi + 0.05
		local f = folder("물/" .. name)
		local sf = folder("돌/" .. name)
		local bot = lo - 1
		local T = 1.5
		part("Rim_S", CFrame.new((x0 + x1) / 2, (rimTop + bot) / 2, z0 - T / 2), Vector3.new(x1 - x0 + 2 * T, rimTop - bot, T), C.rim, M.Limestone, sf)
		part("Rim_N", CFrame.new((x0 + x1) / 2, (rimTop + bot) / 2, z1 + T / 2), Vector3.new(x1 - x0 + 2 * T, rimTop - bot, T), C.rim, M.Limestone, sf)
		part("Rim_W", CFrame.new(x0 - T / 2, (rimTop + bot) / 2, (z0 + z1) / 2), Vector3.new(T, rimTop - bot, z1 - z0), C.rim, M.Limestone, sf)
		part("Rim_E", CFrame.new(x1 + T / 2, (rimTop + bot) / 2, (z0 + z1) / 2), Vector3.new(T, rimTop - bot, z1 - z0), C.rim, M.Limestone, sf)
		part("Bed", CFrame.new((x0 + x1) / 2, (bedTop + bot) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, bedTop - bot, z1 - z0), C.bed, M.Slate, sf)
		local w = part("Water", CFrame.new((x0 + x1) / 2, (waterTop + bedTop) / 2, (z0 + z1) / 2),
			Vector3.new(x1 - x0, waterTop - bedTop, z1 - z0), C.water, M.Glass, f)
		w.Transparency = 0.25
		w.Reflectance = 0.08
		w.CanCollide = false
		w.CastShadow = false
		pools[#pools + 1] = { name = name, x0 = x0, z0 = z0, x1 = x1, z1 = z1, rimTop = rimTop }
		say("못 %s 둘레 %.2f 물 %.2f", name, rimTop, waterTop)
	end
	local function poolAt(x, z)
		for _, p in ipairs(pools) do
			if x >= p.x0 - 2 and x <= p.x1 + 2 and z >= p.z0 - 2 and z <= p.z1 + 2 then
				return p
			end
		end
	end
	for i, s in ipairs(D.ISLANDS) do
		local p = assert(poolAt((s[1] + s[3]) / 2, (s[2] + s[4]) / 2), "섬이 못 밖에 있다")
		slab("Island_" .. i, s[1], s[2], s[3], s[4], p.rimTop + 0.2, C.rim, M.Limestone, folder("돌/" .. p.name))
	end
	task.wait()

	--==================================================================== 3. 건물
	local placed = {}
	local foundations, maxGap = 0, 0
	local function place(kind, x, z, yaw, parent, stretch)
		local m = kit[kind]:Clone()
		if stretch and math.abs(stretch - 1) > 0.001 then
			stretchX(m, stretch)
		end
		m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0))
		m.Parent = parent
		local frame = m:GetPivot()
		local minY = math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				local e, c = halfExtents(p, frame)
				minY = math.min(minY, c.Y - e.Y)
			end
		end
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				local e, c = halfExtents(p, frame)
				if c.Y - e.Y < minY + 0.3 then
					x0, x1 = math.min(x0, c.X - e.X), math.max(x1, c.X + e.X)
					z0, z1 = math.min(z0, c.Z - e.Z), math.max(z1, c.Z + e.Z)
				end
			end
		end
		local lo, hi = math.huge, -math.huge
		for _, u in ipairs({ 0.02, 0.5, 0.98 }) do
			for _, v in ipairs({ 0.02, 0.5, 0.98 }) do
				local wp = frame:PointToWorldSpace(Vector3.new(x0 + (x1 - x0) * u, 0, z0 + (z1 - z0) * v))
				local gy = groundY(wp.X, wp.Z)
				assert(gy, string.format("%s (%.0f,%.0f) 발자국 (%.0f,%.0f) 아래에 땅이 없다", kind, x, z, wp.X, wp.Z))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		m:PivotTo(m:GetPivot() + Vector3.new(0, hi - (frame.Y + minY), 0))
		if hi - lo > 0.25 then
			local f = Instance.new("Part")
			f.Name = "Foundation"
			f.Anchored = true
			f.Size = Vector3.new(x1 - x0 + 1.0, hi - lo + 1.0, z1 - z0 + 1.0)
			f.CFrame = CFrame.new(frame:PointToWorldSpace(Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2))) * frame.Rotation
				+ Vector3.new(0, (lo - 1.0 + hi) / 2 - frame.Y, 0)
			f.Color = C.masonry
			f.Material = M.Slate
			f.TopSurface = Enum.SurfaceType.Smooth
			f.BottomSurface = Enum.SurfaceType.Smooth
			f.Parent = m
			foundations += 1
			maxGap = math.max(maxGap, hi - lo)
		end
		placed[#placed + 1] = { m = m, kind = kind }
		return m
	end

	local count = 0
	for _, list in ipairs({ D.PALACE, D.TOWN }) do
		for _, e in ipairs(list) do
			local m = place(e[1], e[2], e[3], e[4], folder(e[5]))
			m.Name = e[1]
			count += 1
			if count % 6 == 0 then
				task.wait()
			end
		end
	end
	for ci, c in ipairs(D.CORRIDORS) do
		local ax, az, bx, bz, yaw, n = c[1], c[2], c[3], c[4], c[5], c[6]
		local L = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		for k = 1, n do
			local t = (k - 0.5) / n
			local m = place("Corridor", ax + (bx - ax) * t, az + (bz - az) * t, yaw, folder("궁/행각"), L / n / 20)
			m.Name = string.format("Corridor_%d_%d", ci, k)
		end
	end
	for _, g in ipairs(D.GATES) do
		local m = place("Wall_GateTile", g[1], g[2], g[3], folder(g[4]))
		m.Name = "Wall_GateTile"
	end
	task.wait()

	-- 담. 두 끝 사이를 20 에 가까운 토막으로 고르게 나눠 늘여 붙인다
	local nWalls = 0
	for wi, w in ipairs(D.WALLS) do
		local kind, ax, az, bx, bz, grp = w[1], w[2], w[3], w[4], w[5], w[6]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local n = math.max(1, math.floor(len / 20 + 0.5))
		local yaw = math.deg(math.atan2(-(bz - az), bx - ax))
		local f = folder(grp .. "/담")
		for k = 1, n do
			local t = (k - 0.5) / n
			local m = place(kind, ax + (bx - ax) * t, az + (bz - az) * t, yaw, f, len / n / 20)
			m.Name = string.format("%s_%d_%d", kind, wi, k)
			nWalls += 1
		end
		if wi % 8 == 0 then
			task.wait()
		end
	end

	-- 다리. 건물을 다 앉힌 뒤에 놓는다. 끝이 누각 기단이나 섬에 닿는지 알아야 계단을 붙일지 정한다
	local rpBelow = RaycastParams.new()
	rpBelow.FilterType = Enum.RaycastFilterType.Exclude
	rpBelow.FilterDescendantsInstances = { FWater, FTrees, FRoads }
	local function belowAt(x, z, from)
		local h = workspace:Raycast(Vector3.new(x, from + 1, z), Vector3.new(0, -80, 0), rpBelow)
		return h and h.Position.Y
	end
	for i, b in ipairs(D.BRIDGES) do
		local x, z, yaw, L, w = b[1], b[2], b[3], b[4], b[5]
		local p = assert(poolAt(x, z), string.format("다리 %d 가 물 위에 있지 않다", i))
		local top = p.rimTop + 0.4
		local f = folder("돌/다리_" .. i)
		local along = (yaw == 0) and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
		local size = (yaw == 0) and Vector3.new(w, 1.4, L) or Vector3.new(L, 1.4, w)
		part("Deck", CFrame.new(x, top - 0.7, z), size, C.rim, M.Limestone, f)
		-- 난간돌. 긴 두 변에 낮게
		local side = (yaw == 0) and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
		local rs = (yaw == 0) and Vector3.new(0.9, 1.0, L - 1) or Vector3.new(L - 1, 1.0, 0.9)
		for _, s in ipairs({ -1, 1 }) do
			part("Rail_" .. s, CFrame.new(Vector3.new(x, top + 0.5, z) + side * s * (w / 2 - 0.45)), rs, C.masonry, M.Slate, f)
		end
		-- 두 끝 계단. 아래 바닥(둘레돌 밖 땅, 섬, 누각 기단)까지
		for _, s in ipairs({ -1, 1 }) do
			local e = Vector3.new(x, 0, z) + along * s * (L / 2)
			stepsDown("End" .. s, e.X, e.Z, along.X * s, along.Z * s, w - 2, top, f, belowAt)
		end
	end
	task.wait()

	--==================================================================== 4. 길
	local FLOOR = { stone = { C.rim, M.Limestone }, dirt = { C.dirt, M.Ground } }
	local function floorPiece(name, cx, cz, len, width, yaw, kind, parent)
		local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, math.rad(yaw), 0)
		local lo, hi = math.huge, -math.huge
		for _, u in ipairs({ -0.5, 0, 0.5 }) do
			for _, v in ipairs({ -0.5, 0.5 }) do
				local wp = cf:PointToWorldSpace(Vector3.new(len * u, 0, width * v))
				local gy = groundY(wp.X, wp.Z, rpG)
				assert(gy, string.format("%s 자리 (%.0f,%.0f) 에 땅이 없다", name, wp.X, wp.Z))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		local top, bot = hi + 0.3, lo - 0.9
		return part(name, CFrame.new(cx, (top + bot) / 2, cz) * CFrame.Angles(0, math.rad(yaw), 0),
			Vector3.new(len, top - bot, width), FLOOR[kind][1], FLOOR[kind][2], parent)
	end
	for _, lane in ipairs(D.ROADS) do
		local name, width, kind, pts = lane[1], lane[2], lane[3], lane[4]
		local f = folder("길/" .. name)
		for i = 1, #pts - 1 do
			local ax, az = pts[i][1], pts[i][2]
			local bx, bz = pts[i + 1][1], pts[i + 1][2]
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local yaw = math.deg(math.atan2(-(bz - az), bx - ax))
			local n = math.max(1, math.ceil(len / 40))
			for k = 1, n do
				local t = (k - 0.5) / n
				floorPiece(string.format("Road_%d_%d", i, k), ax + (bx - ax) * t, az + (bz - az) * t, len / n + 1, width, yaw, kind, f)
			end
			if i > 1 then
				-- 굽이 이음. 꺾인 자리의 빈 삼각형을 둥근 판으로 메운다. 길보다 0.02 낮춰 깜빡이지 않게
				local gy = groundY(ax, az, rpG)
				local c = part("Joint_" .. i, CFrame.new(ax, gy + 0.28 - 0.6, az) * CFrame.Angles(0, 0, math.rad(90)),
					Vector3.new(1.2, width, width), FLOOR[kind][1], FLOOR[kind][2], f)
				c.Shape = Enum.PartType.Cylinder
			end
		end
	end
	task.wait()

	--==================================================================== 5. 논밭
	for i, fd in ipairs(D.FIELDS) do
		local x0, z0, x1, z1 = fd[1], fd[2], fd[3], fd[4]
		local _, hi = span(x0, z0, x1, z1, rpG)
		local f = folder("논밭/" .. i)
		local top = hi + 0.25
		slab("Soil", x0, z0, x1, z1, top, C.soil, M.Ground, f)
		local k = 0
		for fx = x0 + 2, x1 - 2, 4 do
			k += 1
			part("Row_" .. k, CFrame.new(fx, top + 0.45, (z0 + z1) / 2), Vector3.new(1.4, 0.9, z1 - z0 - 2), C.crop, M.Grass, f)
		end
	end
	task.wait()

	--==================================================================== 6. 나무
	local cleared = SS:FindFirstChild("Jeolhwa_ClearedFlora")
	if not cleared then
		cleared = Instance.new("Folder")
		cleared.Name = "Jeolhwa_ClearedFlora"
		cleared.Parent = SS
	end
	local floraRoots = {}
	for _, r in ipairs({ "R_평원", "R_숲" }) do
		local f = workspace.Surface:FindFirstChild(r)
		if f and f:FindFirstChild("Flora") then
			floraRoots[#floraRoots + 1] = f.Flora
		end
	end
	-- 앞서 옮긴 것을 먼저 제자리로 돌린다
	-- 원래 자리는 Flora 밑 하위 폴더일 수도 있다. 2판은 뿌리 폴더만 찾아서 하위 폴더 나무가 창고에 남았다
	local byPath = {}
	for _, r in ipairs(floraRoots) do
		byPath[r:GetFullName()] = r
		for _, d in ipairs(r:GetDescendants()) do
			if d:IsA("Folder") or d:IsA("Model") then
				byPath[d:GetFullName()] = d
			end
		end
	end
	local restored = 0
	for _, c in ipairs(cleared:GetChildren()) do
		local home = byPath[c:GetAttribute("OriginalParent") or ""]
		if home then
			c.Parent = home
			restored += 1
		end
	end
	-- 나무 한 그루는 이름 앞머리로 묶인다. Pln_Tree_9_B1t_L2 처럼 파트가 낱개로 들어 있다
	local function treeKey(p)
		return p.Parent:GetFullName() .. "/" .. (p.Name:match("^(.-_%d+)_") or p.Name)
	end
	local trees, plainKeys = {}, {}
	for _, r in ipairs(floraRoots) do
		for _, p in ipairs(r:GetDescendants()) do
			if p:IsA("BasePart") then
				local k = treeKey(p)
				if not trees[k] then
					trees[k] = {}
					if r.Parent.Name == "R_평원" then
						plainKeys[#plainKeys + 1] = k
					end
				end
				table.insert(trees[k], p)
			end
		end
	end
	-- 평원 식생에는 그루터기와 덤불도 섞여 있다. 파트 넷 이상, 키 14 이상인 나무만 옮겨 심는다
	local tall = {}
	for _, k in ipairs(plainKeys) do
		local lo, hi = math.huge, -math.huge
		for _, p in ipairs(trees[k]) do
			lo = math.min(lo, p.Position.Y - p.Size.Y / 2)
			hi = math.max(hi, p.Position.Y + p.Size.Y / 2)
		end
		if #trees[k] >= 4 and hi - lo >= 14 then
			tall[#tall + 1] = k
		end
	end
	plainKeys = tall
	table.sort(plainKeys)
	assert(#plainKeys > 0, "옮겨 심을 평원 나무가 없다")
	say("옮겨 심을 나무 후보 %d 그루", #plainKeys)
	for i, t in ipairs(D.TREES) do
		local src = trees[plainKeys[((i * 7) % #plainKeys) + 1]]
		local model = Instance.new("Model")
		model.Name = "Tree_" .. i
		local minY, rx, rz = math.huge, nil, nil
		for _, p in ipairs(src) do
			local c = p:Clone()
			c.Parent = model
			minY = math.min(minY, c.Position.Y - c.Size.Y / 2)
			if c.Name:match("_Root$") then
				rx, rz = c.Position.X, c.Position.Z
			end
		end
		if not rx then
			local cf0 = model:GetBoundingBox()
			rx, rz = cf0.X, cf0.Z
		end
		-- 뿌리 밑을 피벗으로 삼아 한 그루씩 조금씩 돌려 심는다. 같은 방향이면 복사본으로 보인다
		model.WorldPivot = CFrame.new(rx, minY, rz)
		model.Parent = FTrees
		local gy = assert(groundY(t[1], t[2]), "나무 자리에 땅이 없다")
		model:PivotTo(CFrame.new(t[1], gy - 0.5, t[2]) * CFrame.Angles(0, math.rad((i * 67) % 360), 0))
	end

	-- 원래 나무 비키기. 새로 앉힌 것에 걸린 나무를 그루째 옮긴다
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = floraRoots
	local movedTrees = 0
	local function clearArea(cf, size)
		for _, p in ipairs(workspace:GetPartBoundsInBox(cf, size, op)) do
			if p.Parent ~= cleared then
				for _, q in ipairs(trees[treeKey(p)] or { p }) do
					if q.Parent ~= cleared then
						q:SetAttribute("OriginalParent", q.Parent:GetFullName())
						q.Parent = cleared
					end
				end
				movedTrees += 1
			end
		end
	end
	for _, e in ipairs(placed) do
		local cf, size = e.m:GetBoundingBox()
		clearArea(cf, size + Vector3.new(6, 60, 6))
	end
	for _, d in ipairs(city:GetDescendants()) do
		if d:IsA("BasePart") and not d:IsDescendantOf(FTrees) and d.Parent and not d.Parent:IsA("Model") then
			clearArea(d.CFrame, d.Size + Vector3.new(4, 60, 4))
		end
	end

	--==================================================================== 7. 검사
	local counts = {}
	for _, e in ipairs(placed) do
		counts[e.kind] = (counts[e.kind] or 0) + 1
	end
	local keys = {}
	for k in pairs(counts) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	local line = {}
	for _, k in ipairs(keys) do
		line[#line + 1] = k .. " " .. counts[k]
	end
	say("%s", table.concat(line, ", "))
	say("모델 %d (담 토막 %d), 받침돌 %d 개, 가장 큰 땅 높이차 %.2f", #placed, nWalls, foundations, maxGap)
	say("나무 되돌림 %d, 새로 비킨 나무 %d 그루, 창고 파트 %d", restored, movedTrees, #cleared:GetChildren())

	-- 광장은 비워 둔다. 새로 지은 것이 스폰 광장에 들어가면 멈춘다
	local keepCF, keepSize = CFrame.new(225, 30, 510), Vector3.new(118, 60, 178)
	local kp = OverlapParams.new()
	kp.FilterType = Enum.RaycastFilterType.Include
	kp.FilterDescendantsInstances = { city }
	local intruders = {}
	for _, p in ipairs(workspace:GetPartBoundsInBox(keepCF, keepSize, kp)) do
		if not p:IsDescendantOf(FRoads) and not p:IsDescendantOf(FTrees) then
			intruders[#intruders + 1] = p:GetFullName()
		end
	end
	assert(#intruders == 0, "스폰 광장에 들어간 것: " .. table.concat(intruders, ", ", 1, math.min(5, #intruders)))

	-- 행각은 한 높이여야 한다. 토막 밑이 기단 윗면과 어긋나면 지붕이 층진다
	local worst = 0
	for _, e in ipairs(placed) do
		if e.kind == "Corridor" or e.kind == "Corridor_Corner" then
			local cf, size = e.m:GetBoundingBox()
			worst = math.max(worst, math.abs((cf.Y - size.Y / 2) - ringTop))
		end
	end
	assert(worst < 0.05, string.format("행각 토막 높이가 %.2f 어긋난다", worst))

	local n = 0
	for _, d in ipairs(city:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	say("파트 합계 %d", n)
end)
if not okRun then
	say("ERR %s", tostring(errRun))
end
print(table.concat(report, "\n"))
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/city3", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
