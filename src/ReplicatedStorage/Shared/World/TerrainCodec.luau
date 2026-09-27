--!strict
-- Blender 레벨 파이프라인이 만든 높이맵/재질맵 디코더 (blender/level/layout.py 와 짝)

local ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
local LOOKUP: { [number]: number } = {}
for i = 1, #ALPHA do
	LOOKUP[string.byte(ALPHA, i)] = i - 1
end

export type IslandData = {
	Name: string,
	OriginX: number,
	OriginZ: number,
	Cell: number,
	NX: number,
	NZ: number,
	HeightOffset: number,
	HeightScale: number,
	Heights: { string },
	Materials: { string },
}

local TerrainCodec = {}

-- 평탄 배열 (index = k * NX + i + 1), k = Z 행(북->남), i = X 열
function TerrainCodec.DecodeHeights(data: IslandData): { number }
	local out = table.create(data.NX * data.NZ)
	local off, scale = data.HeightOffset, data.HeightScale
	for k = 1, data.NZ do
		local row = data.Heights[k]
		local base = (k - 1) * data.NX
		for i = 1, data.NX do
			local hi = LOOKUP[string.byte(row, 2 * i - 1)]
			local lo = LOOKUP[string.byte(row, 2 * i)]
			out[base + i] = off + (hi * 64 + lo) * scale
		end
	end
	return out
end

function TerrainCodec.DecodeMaterials(data: IslandData): { number }
	local out = table.create(data.NX * data.NZ)
	for k = 1, data.NZ do
		local row = data.Materials[k]
		local idx = (k - 1) * data.NX
		for c = 1, #row, 2 do
			local mat = LOOKUP[string.byte(row, c)]
			local run = LOOKUP[string.byte(row, c + 1)] + 1
			for _ = 1, run do
				idx += 1
				out[idx] = mat
			end
		end
	end
	return out
end

-- 월드 좌표 (x, z) 의 높이 (쌍선형 보간). 영역 밖이면 nil
function TerrainCodec.Sample(data: IslandData, heights: { number }, x: number, z: number, offset: Vector3?): number?
	local ox = data.OriginX + (if offset then offset.X else 0)
	local oz = data.OriginZ + (if offset then offset.Z else 0)
	local fx = (x - ox) / data.Cell - 0.5
	local fz = (z - oz) / data.Cell - 0.5
	if fx < 0 or fz < 0 or fx > data.NX - 1 or fz > data.NZ - 1 then
		return nil
	end
	local i = math.clamp(math.floor(fx), 0, data.NX - 2)
	local k = math.clamp(math.floor(fz), 0, data.NZ - 2)
	local tx, tz = fx - i, fz - k
	local nx = data.NX
	local h00 = heights[k * nx + i + 1]
	local h10 = heights[k * nx + i + 2]
	local h01 = heights[(k + 1) * nx + i + 1]
	local h11 = heights[(k + 1) * nx + i + 2]
	local y = (h00 * (1 - tx) + h10 * tx) * (1 - tz) + (h01 * (1 - tx) + h11 * tx) * tz
	return y + (if offset then offset.Y else 0)
end

return TerrainCodec
