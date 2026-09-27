--!nocheck
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

return function(H)
	local W = "src/ReplicatedStorage/Shared/World"
	local TerrainCodec = H.require(W .. "/TerrainCodec.luau")
	local WorldData = H.require(W .. "/WorldData.luau")
	local Placements = H.require(W .. "/Generated/Placements.luau")
	local AssetManifest = H.require("src/ServerStorage/SwampTools/AssetManifest.luau")

	for _, name in WorldData.IslandNames() do
		local data = WorldData.IslandData(name)
		H.check(name .. ": 원점 4 stud 정렬", data.OriginX % 4 == 0 and data.OriginZ % 4 == 0, data.OriginX .. "," .. data.OriginZ)
		local hs = TerrainCodec.DecodeHeights(data)
		local ms = TerrainCodec.DecodeMaterials(data)
		H.check(name .. ": 높이 개수", #hs == data.NX * data.NZ, #hs)
		H.check(name .. ": 재질 개수", #ms == data.NX * data.NZ, #ms)
		local maxMat = 0
		for _, m in ms do
			if m > maxMat then maxMat = m end
		end
		H.check(name .. ": 재질 인덱스 범위", maxMat < #WorldData.Raw().MaterialNames, maxMat)
	end
	-- 알려진 지점 높이 (레이아웃 스탬프)
	local plaza = WorldData.TerrainHeight(-705, 0)
	H.check("항구 광장 높이 ≈ 3", plaza and math.abs(plaza - 3) < 0.4, plaza)
	local beach = WorldData.TerrainHeight(260, 0)
	H.check("늪 선착장 해변 높이 ≈ 1.25", beach and math.abs(beach - 1.25) < 0.4, beach)
	local moor = WorldData.TerrainHeight(143, 0)
	H.check("정박 지점 수심 충분 (< -9)", moor == nil or moor < -9, moor)
	-- 배치된 모든 에셋이 매니페스트에 존재
	local missing = {}
	for _, pl in Placements do
		if not AssetManifest[pl.a] then
			missing[pl.a] = true
		end
	end
	local list = {}
	for k in missing do table.insert(list, k) end
	H.check("배치 에셋 ⊂ 매니페스트 (" .. #Placements .. "개)", #list == 0, table.concat(list, ", "))
	-- 구역 판정
	H.check("구역: 마을", WorldData.ZoneAt(Vector3.new(460, 10, 0)) == "Village")
	H.check("구역: 사당", WorldData.ZoneAt(Vector3.new(900, 5, 200)) == "Shrine")
	H.check("구역: 바다", WorldData.ZoneAt(Vector3.new(-100, 0, 0)) == "Sea")
end
