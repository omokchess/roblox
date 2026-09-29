--!nocheck
--[[
	Swamp_Terrain.luau — 2026-09-28. 늪지대를 안개늪처럼 매끈한 지형(흙·풀·진흙) + 물로 덮는다.

	자료: tools/swamp_plan.py 가 만든 tools/swamp/terrain.txt 를 로컬 서버에서 받는다
	      (tools/swamp 에서  python -m http.server 35000 --bind 127.0.0.1)
	- 4 스터드 칸마다 높이(2 글자) + 재질(줄마다 RLE). 높이 부호 0 은 섬 밖(공기).
	- y -12..16 을 통째로 다시 쓴다(이 범위 안의 옛 지형은 지워짐; 원래 이 자리엔 지형이 없었다).
	- 수면 y = 0: 지형이 물보다 낮은 칸은 WriteVoxelChannels 의 LiquidOccupancy 로 물을 채운다.
	- 잰 규칙(2026-09-28, 맵 밖 시험판): 맨 위 흙 칸(바닥 b)의 차지율 o 이면 흙 표면 = b + 2 + 4o (2 만큼 위로 뜬다),
	  물 표면 = b + 4·물 차지율(그대로). 한 칸에 흙 o 와 물 1 을 같이 넣어도 된다(흙이 수면 아래면 물이 0 까지 찬다).
	  그래서 흙은 원하는 높이에서 2 를 빼고 차지율을 매기고, 물 아래 칸은 흙이 덜 찬 칸마다 물 1 을 넣는다.
	- 흙 판(Gs_늪지대)은 숨긴다: 투명·충돌·광선 끔. 원래 값은 속성 SwampOld* 로 남겨 Swamp_Revert 가 되돌린다.
	결과는 /swampterrain 로 보고.
]]
local HS = game:GetService("HttpService")
local T = workspace.Terrain
local report = {}
local ok, err = pcall(function()
	local txt = HS:GetAsync("http://127.0.0.1:35000/terrain.txt", true)
	local lines = string.split(txt, "\n")
	local hdr = string.split(lines[1], " ")
	local X0, Z0, R, NX, NZ, WATER =
		tonumber(hdr[1]), tonumber(hdr[2]), tonumber(hdr[3]), tonumber(hdr[4]), tonumber(hdr[5]), tonumber(hdr[6])
	assert(R == 4 and X0 % 4 == 0 and Z0 % 4 == 0, "격자가 4 에 맞지 않다")
	local ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
	local IDX = {}
	for i = 1, 64 do
		IDX[string.byte(ALPHA, i)] = i - 1
	end
	local E = Enum.Material
	local MATS = { E.Mud, E.Ground, E.LeafyGrass, E.Grass, E.Rock, E.Pebble, E.Slate, E.Cobblestone, E.Sand }
	-- 겉 재질 → 속 재질(겉에서 4 아래부터)
	local SUB = { [E.Mud] = E.Mud, [E.Rock] = E.Rock, [E.Slate] = E.Rock }
	local H, MT = table.create(NZ), table.create(NZ)
	for j = 1, NZ do
		local s = lines[1 + j]
		assert(#s == NX * 2, "높이 줄 길이 " .. j)
		local row = table.create(NX)
		for i = 1, NX do
			local v = IDX[s:byte(2 * i - 1)] * 64 + IDX[s:byte(2 * i)]
			row[i] = v == 0 and false or (v / 10 - 64)
		end
		H[j] = row
		local m = lines[1 + NZ + j]
		local mrow = table.create(NX)
		for k = 1, #m, 2 do
			local mat = MATS[IDX[m:byte(k)] + 1]
			for _ = 1, IDX[m:byte(k + 1)] + 1 do
				mrow[#mrow + 1] = mat
			end
		end
		assert(#mrow == NX, "재질 줄 길이 " .. j)
		MT[j] = mrow
	end

	local YMIN, NY, CH = -12, 7, 64
	local nChunk, nSolid, nWater = 0, 0, 0
	for cz0 = 0, NZ - 1, CH do
		for cx0 = 0, NX - 1, CH do
			local cw, cd = math.min(CH, NX - cx0), math.min(CH, NZ - cz0)
			local SM, SO, LO = table.create(cw), table.create(cw), table.create(cw)
			for ix = 1, cw do
				local a, b, c = table.create(NY), table.create(NY), table.create(NY)
				for iy = 1, NY do
					a[iy], b[iy], c[iy] = table.create(cd, E.Air), table.create(cd, 0), table.create(cd, 0)
				end
				SM[ix], SO[ix], LO[ix] = a, b, c
			end
			for iz = 1, cd do
				local hrow, mrow = H[cz0 + iz], MT[cz0 + iz]
				for ix = 1, cw do
					local h = hrow[cx0 + ix]
					if h then
						local top = mrow[cx0 + ix]
						local sub = SUB[top] or E.Ground
						local hs = h - 2 -- 흙 표면이 차지율보다 2 위에 그려지므로
						for iy = 1, NY do
							local bottom = YMIN + (iy - 1) * 4
							local vtop = bottom + 4
							local so, sm = 0, E.Air
							if hs >= vtop then
								so = 1
								sm = (hs - vtop < 4) and top or sub
							elseif hs > bottom then
								so = (hs - bottom) / 4
								sm = top
								if so < 0.04 then
									so, sm = 0, E.Air
								end
							end
							local lo = 0
							if h < WATER and bottom < WATER and so < 1 then
								lo = math.clamp((WATER - bottom) / 4, 0, 1)
							end
							SM[ix][iy][iz], SO[ix][iy][iz], LO[ix][iy][iz] = sm, so, lo
							if so > 0 then
								nSolid += 1
							end
							if lo > 0 then
								nWater += 1
							end
						end
					end
				end
			end
			local mn = Vector3.new(X0 + cx0 * 4, YMIN, Z0 + cz0 * 4)
			local region = Region3.new(mn, mn + Vector3.new(cw * 4, NY * 4, cd * 4))
			T:WriteVoxelChannels(region, 4, { SolidMaterial = SM, SolidOccupancy = SO, LiquidOccupancy = LO })
			nChunk += 1
			task.wait()
		end
	end
	-- 물빛: 탁한 늪 녹색(안개늪 Swamp 구역 값). 지형 물은 이 섬에만 있다
	T.WaterColor = Color3.fromRGB(46, 62, 40)
	T.WaterTransparency = 0.28
	T.WaterReflectance = 0.3
	T.WaterWaveSize = 0.12
	T.WaterWaveSpeed = 6
	-- 흙 판 숨기기
	local nHide = 0
	for _, p in ipairs(workspace.Surface.World["G_늪지대"]:GetChildren()) do
		if p:IsA("BasePart") and p.Name:match("^Gs_") then
			if p:GetAttribute("SwampOldTransparency") == nil then
				p:SetAttribute("SwampOldTransparency", p.Transparency)
				p:SetAttribute("SwampOldCollide", p.CanCollide)
				p:SetAttribute("SwampOldQuery", p.CanQuery)
				p:SetAttribute("SwampOldShadow", p.CastShadow)
			end
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			nHide += 1
		end
	end
	report[#report + 1] = string.format("덩이 %d, 흙 복셀 %d, 물 복셀 %d, 숨긴 판 %d", nChunk, nSolid, nWater, nHide)
end)
if not ok then
	report[#report + 1] = "ERR " .. tostring(err)
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/swampterrain", table.concat(report, "\n"))
end)
print("swampterrain", table.concat(report, " / "))
