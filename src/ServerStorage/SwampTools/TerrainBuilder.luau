--!strict
-- 지형 생성기: 바다(모래 바닥 + 물) 채우기 + 섬 높이맵을 복셀로 기록.
-- Shorelines(얕은 물+지면 공존)를 위해 WriteVoxelChannels 를 우선 사용하고, 실패 시 WriteVoxels 로 대체.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = Shared:WaitForChild("World")
local TerrainCodec = require(World:WaitForChild("TerrainCodec"))

local TerrainBuilder = {}

local RES = 4
local Y_MIN = -52 -- 바다 바닥 아래 (4의 배수)
local SEA_FLOOR = -36
local CHUNK = 64 -- 열 단위 청크

-- 레벨 재질 이름 -> (표면 재질, 하부 재질)
local LAYERS: { [string]: { top: Enum.Material, sub: Enum.Material, depth: number } } = {
	Sand = { top = Enum.Material.Sand, sub = Enum.Material.Sand, depth = 8 },
	Mud = { top = Enum.Material.Mud, sub = Enum.Material.Ground, depth = 4 },
	Ground = { top = Enum.Material.Ground, sub = Enum.Material.Ground, depth = 4 },
	LeafyGrass = { top = Enum.Material.LeafyGrass, sub = Enum.Material.Ground, depth = 3 },
	Grass = { top = Enum.Material.Grass, sub = Enum.Material.Ground, depth = 3 },
	Rock = { top = Enum.Material.Rock, sub = Enum.Material.Rock, depth = 8 },
	Slate = { top = Enum.Material.Slate, sub = Enum.Material.Rock, depth = 6 },
	Pebble = { top = Enum.Material.Pebble, sub = Enum.Material.Ground, depth = 2 },
	Limestone = { top = Enum.Material.Limestone, sub = Enum.Material.Rock, depth = 6 },
}

local useChannels: boolean? = nil -- 첫 호출에서 판정

local function writeChunk(region: Region3, solidMat: { any }, solidOcc: { any }, liquidOcc: { any }, legacyMat: { any }, legacyOcc: { any })
	local terrain = workspace.Terrain
	if useChannels ~= false then
		local ok, err = pcall(function()
			terrain:WriteVoxelChannels(region, RES, {
				SolidMaterial = solidMat,
				SolidOccupancy = solidOcc,
				LiquidOccupancy = liquidOcc,
			})
		end)
		if ok then
			useChannels = true
			return
		end
		if useChannels == nil then
			warn("[SwampTerrain] WriteVoxelChannels 사용 불가, WriteVoxels 로 대체:", err)
		end
		useChannels = false
	end
	terrain:WriteVoxels(region, RES, legacyMat, legacyOcc)
end

-- 바다: 경계 사각형 전체를 모래 바닥 + 물로 채움 (섬은 이후 덮어씀)
function TerrainBuilder.FillSea(minCorner: Vector3, maxCorner: Vector3, waterLevel: number, yielder: (() -> ())?)
	local terrain = workspace.Terrain
	local x0 = math.floor(minCorner.X / RES) * RES
	local z0 = math.floor(minCorner.Z / RES) * RES
	local x1 = math.ceil(maxCorner.X / RES) * RES
	local z1 = math.ceil(maxCorner.Z / RES) * RES
	local step = 512
	local floorTop = SEA_FLOOR + minCorner.Y
	for x = x0, x1 - 1, step do
		for z = z0, z1 - 1, step do
			local sx = math.min(step, x1 - x)
			local sz = math.min(step, z1 - z)
			local cx, cz = x + sx / 2, z + sz / 2
			local floorH = floorTop - (Y_MIN + minCorner.Y)
			terrain:FillBlock(CFrame.new(cx, Y_MIN + minCorner.Y + floorH / 2, cz), Vector3.new(sx, floorH, sz), Enum.Material.Sand)
			local waterH = waterLevel - floorTop
			terrain:FillBlock(CFrame.new(cx, floorTop + waterH / 2, cz), Vector3.new(sx, waterH, sz), Enum.Material.Water)
			if yielder then
				yielder()
			end
		end
	end
end

-- 섬 하나를 복셀로 기록
function TerrainBuilder.BuildIsland(data: TerrainCodec.IslandData, materialNames: { string }, offset: Vector3, waterLevel: number, yielder: (() -> ())?)
	local heights = TerrainCodec.DecodeHeights(data)
	local mats = TerrainCodec.DecodeMaterials(data)
	local nx, nz = data.NX, data.NZ
	local ox, oz = data.OriginX + offset.X, data.OriginZ + offset.Z
	local oy = offset.Y
	local layerList: { { top: Enum.Material, sub: Enum.Material, depth: number } } = {}
	for i, name in materialNames do
		layerList[i] = LAYERS[name] or LAYERS.Ground
	end
	local maxH = -math.huge
	for _, h in heights do
		if h > maxH then
			maxH = h
		end
	end
	local yMin = Y_MIN + oy
	local yMax = math.ceil((math.max(maxH, waterLevel - oy) + oy + RES) / RES) * RES
	local ny = math.floor((yMax - yMin) / RES)
	local wl = waterLevel

	for cz0 = 0, nz - 1, CHUNK do
		for cx0 = 0, nx - 1, CHUNK do
			local cw = math.min(CHUNK, nx - cx0)
			local cd = math.min(CHUNK, nz - cz0)
			local solidMat, solidOcc, liquidOcc = table.create(cw), table.create(cw), table.create(cw)
			local legacyMat, legacyOcc = table.create(cw), table.create(cw)
			for ix = 1, cw do
				local smx, sox, lox, gmx, gox = table.create(ny), table.create(ny), table.create(ny), table.create(ny), table.create(ny)
				for iy = 1, ny do
					smx[iy] = table.create(cd)
					sox[iy] = table.create(cd)
					lox[iy] = table.create(cd)
					gmx[iy] = table.create(cd)
					gox[iy] = table.create(cd)
				end
				solidMat[ix], solidOcc[ix], liquidOcc[ix] = smx, sox, lox
				legacyMat[ix], legacyOcc[ix] = gmx, gox
			end
			for iz = 1, cd do
				for ix = 1, cw do
					local idx = (cz0 + iz - 1) * nx + (cx0 + ix)
					local h = heights[idx] + oy
					local layer = layerList[mats[idx] + 1] or LAYERS.Ground
					for iy = 1, ny do
						local bottom = yMin + (iy - 1) * RES
						local top = bottom + RES
						local sm: Enum.Material = Enum.Material.Air
						local so, lo = 0, 0
						if h >= top then
							so = 1
							sm = if h - top < layer.depth then layer.top else layer.sub
						elseif h > bottom then
							so = (h - bottom) / RES
							sm = layer.top
							if so < 0.04 then
								so = 0
								sm = Enum.Material.Air
							end
						end
						-- 물: 이 복셀에서 수면 아래이면서 고체가 차지하지 않은 부분
						if bottom < wl then
							local waterFrac = math.clamp((wl - bottom) / RES, 0, 1)
							lo = math.clamp(waterFrac - so, 0, 1)
						end
						solidMat[ix][iy][iz] = sm
						solidOcc[ix][iy][iz] = so
						liquidOcc[ix][iy][iz] = lo
						-- 레거시(단일 재질) 규칙: 얕은 부분 고체가 절반 미만이면 물로
						if so >= 0.55 or (so > 0 and bottom >= wl) then
							legacyMat[ix][iy][iz] = sm
							legacyOcc[ix][iy][iz] = so
						elseif lo > 0 then
							legacyMat[ix][iy][iz] = Enum.Material.Water
							legacyOcc[ix][iy][iz] = 1
						else
							legacyMat[ix][iy][iz] = sm
							legacyOcc[ix][iy][iz] = so
						end
					end
				end
			end
			local minV = Vector3.new(ox + cx0 * RES, yMin, oz + cz0 * RES)
			local maxV = minV + Vector3.new(cw * RES, ny * RES, cd * RES)
			writeChunk(Region3.new(minV, maxV), solidMat, solidOcc, liquidOcc, legacyMat, legacyOcc)
			if yielder then
				yielder()
			end
		end
	end
end

function TerrainBuilder.Clear()
	workspace.Terrain:Clear()
end

return TerrainBuilder
