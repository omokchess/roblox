--!strict

export type FloorDefinition = {
	Floor: number,
	Name: string,
	Kind: "Normal" | "Elite" | "Boss",
	Enemies: { string },
	HealthScale: number,
	PowerScale: number,
	Gimmick: string,
	GimmickName: string,
	GimmickDescription: string,
}

-- 적은 지금 슬라임 한 종뿐이다(EnemyDefinitions 주석). 마릿수는 예전 구성(2·3·3·3·3)을 그대로 따른다.
local normalPools = {
	{ "Slime", "Slime" },
	{ "Slime", "Slime", "Slime" },
	{ "Slime", "Slime", "Slime" },
	{ "Slime", "Slime", "Slime" },
	{ "Slime", "Slime", "Slime" },
}

local gimmicks = {
	{ Id = "None", Name = "고요한 층", Description = "추가 규칙이 없습니다." },
	{
		Id = "EnemyShield",
		Name = "두꺼운 유약",
		Description = "적이 층 수에 비례한 보호막을 얻습니다.",
	},
	{
		Id = "OpeningBurn",
		Name = "과열 가마",
		Description = "전투 시작 시 파티에 약한 화상이 부여됩니다.",
	},
	{ Id = "EnemyPower", Name = "불안정 소성", Description = "적 공격력이 추가로 15% 증가합니다." },
	{
		Id = "PlayerShield",
		Name = "보호 코팅",
		Description = "파티가 전투 시작 시 보호막을 얻습니다.",
	},
	{ Id = "SkillHaste", Name = "빠른 회전판", Description = "파티 기술 쿨타임이 1턴 감소합니다." },
}

local floors: { FloorDefinition } = {}
for floor = 1, 30 do
	local boss = floor % 10 == 0
	local elite = not boss and floor % 5 == 0
	local enemies
	if boss then
		enemies = { "Slime" }
	elseif elite then
		enemies = { "Slime", "Slime" }
	else
		enemies = table.clone(normalPools[math.min(#normalPools, math.floor((floor - 1) / 6) + 1)])
	end
	local gimmick = gimmicks[(floor - 1) % #gimmicks + 1]
	table.insert(floors, {
		Floor = floor,
		Name = floor == 30 and "탑의 정상"
			or (boss and "수호자의 방" or (elite and "정예 공방" or "소성 계단")),
		Kind = boss and "Boss" or (elite and "Elite" or "Normal"),
		Enemies = enemies,
		HealthScale = 1 + (floor - 1) * 0.055 + (elite and 0.12 or 0),
		PowerScale = 1 + (floor - 1) * 0.032 + (boss and 0.12 or 0),
		Gimmick = gimmick.Id,
		GimmickName = gimmick.Name,
		GimmickDescription = gimmick.Description,
	})
end

local TowerDefinitions = {}

function TowerDefinitions.Get(floor: number): FloorDefinition
	return floors[math.clamp(math.floor(floor), 1, #floors)]
end

function TowerDefinitions.All(): { FloorDefinition }
	return table.clone(floors)
end

function TowerDefinitions.Count(): number
	return #floors
end

return TowerDefinitions
