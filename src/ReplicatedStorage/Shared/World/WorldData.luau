--!strict
-- 생성된 레벨 데이터 접근 계층 (오프셋 적용, 지형 높이 조회 캐시)

local Generated = script.Parent:WaitForChild("Generated")
local WorldConfig = require(script.Parent.WorldConfig)
local TerrainCodec = require(script.Parent.TerrainCodec)

local Raw = require(Generated:WaitForChild("WorldData")) :: any

export type Zone = { Name: string, Kind: string, P: Vector3, Radius: number?, Size: Vector3?, Priority: number }
export type EnemySpawn = { Type: string, P: Vector3, Radius: number, Count: number, Boss: boolean, ArenaRadius: number? }

local WorldData = {}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

function WorldData.Offset(): Vector3
	return WorldConfig.GetOffset()
end

function WorldData.Raw(): any
	return Raw
end

function WorldData.SpawnPoints(): { { Name: string, P: Vector3 } }
	local o = WorldData.Offset()
	local out = {}
	for _, s in Raw.SpawnPoints do
		if WorldConfig.Islands[s.Name] ~= false then
			table.insert(out, { Name = s.Name, P = v3(s.P) + o })
		end
	end
	return out
end

function WorldData.EnemySpawns(): { EnemySpawn }
	local o = WorldData.Offset()
	local out: { EnemySpawn } = {}
	for _, s in Raw.EnemySpawns do
		table.insert(out, {
			Type = s.Type,
			P = v3(s.P) + o,
			Radius = s.Radius,
			Count = s.Count,
			Boss = s.Boss == true,
			ArenaRadius = s.ArenaRadius,
		})
	end
	return out
end

function WorldData.Zones(): { Zone }
	local o = WorldData.Offset()
	local out: { Zone } = {}
	for _, z in Raw.Zones do
		table.insert(out, {
			Name = z.Name,
			Kind = z.Kind,
			P = v3(z.P) + o,
			Radius = z.Radius,
			Size = if z.Size then v3(z.Size) else nil,
			Priority = z.Priority or 1,
		})
	end
	table.sort(out, function(a, b)
		return a.Priority > b.Priority
	end)
	return out
end

function WorldData.Buoys(): { Vector3 }
	local o = WorldData.Offset()
	local out = {}
	for _, b in Raw.Buoys do
		table.insert(out, v3(b.P) + o)
	end
	return out
end

function WorldData.SeaBounds(): (Vector3, Vector3)
	local b = Raw.SeaBounds
	local o = WorldData.Offset()
	return Vector3.new(b.MinX, 0, b.MinZ) + o, Vector3.new(b.MaxX, 0, b.MaxZ) + o
end

-- 섬 지형 높이 조회 (지연 디코딩 + 캐시)
local decoded: { [string]: { data: TerrainCodec.IslandData, heights: { number } } } = {}

function WorldData.IslandNames(): { string }
	local out = {}
	for _, n in Raw.TerrainModules do
		if WorldConfig.Islands[n] ~= false then
			table.insert(out, n)
		end
	end
	return out
end

function WorldData.IslandData(name: string): TerrainCodec.IslandData
	return require(Generated:WaitForChild("Terrain_" .. name)) :: any
end

function WorldData.TerrainHeight(x: number, z: number): number?
	local o = WorldData.Offset()
	for _, name in WorldData.IslandNames() do
		local entry = decoded[name]
		if not entry then
			local data = WorldData.IslandData(name)
			entry = { data = data, heights = TerrainCodec.DecodeHeights(data) }
			decoded[name] = entry
		end
		local h = TerrainCodec.Sample(entry.data, entry.heights, x, z, o)
		if h then
			return h
		end
	end
	return nil
end

-- 위치가 속한 구역 (우선순위 높은 것부터)
function WorldData.ZoneAt(pos: Vector3, zones: { Zone }?): string
	for _, z in zones or WorldData.Zones() do
		local d = pos - z.P
		if z.Kind == "Sphere" then
			if Vector3.new(d.X, 0, d.Z).Magnitude <= (z.Radius or 0) then
				return z.Name
			end
		elseif z.Kind == "Box" and z.Size then
			if math.abs(d.X) <= z.Size.X / 2 and math.abs(d.Z) <= z.Size.Z / 2 and math.abs(d.Y) <= z.Size.Y / 2 then
				return z.Name
			end
		elseif z.Kind == "Ellipse" and z.Size then
			local ex, ez = d.X / (z.Size.X / 2), d.Z / (z.Size.Z / 2)
			if ex * ex + ez * ez <= 1 then
				return z.Name
			end
		end
	end
	return "Sea"
end

return WorldData
