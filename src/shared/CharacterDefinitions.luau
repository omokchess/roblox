--!strict
--[[
	직업 정의.

	출처: `유저 아이디어(직업).md`. 기준 직업은 **음악가**이고, 체력·스킬 위력은
	그 문서의 눈금(피해 18~40)을 그대로 쓴다.

	광전사만 이전 로스터에서 남았다. 나머지 9종(기사·수호자·사수·비전술사·성직자·
	연금술사·음유시인·암살자·공예가)은 문서의 직업들로 교체됐다.
]]

export type SkillDefinition = {
	Id: string,
	Name: string,
	Description: string,
	Power: number,
	CooldownTurns: number,
	Target: "Enemy" | "Self" | "Ally" | "Team",
	Effect: "Damage" | "DamageShield" | "Shield" | "Heal" | "Recoil" | "Poison" | "TeamBuff" | "Execute" | "TeamShield",
	MotionId: string,
}

export type CharacterDefinition = {
	Id: string,
	Name: string,
	Role: string,
	Description: string,
	MaxHealth: number,
	MoveSpeed: number,
	BasicPower: number,
	BasicMotionId: string,
	Skill: SkillDefinition,
	Color: Color3,
}

local definitions: { [string]: CharacterDefinition } = {
	Musician = {
		Id = "Musician",
		Name = "음악가",
		Role = "딜러 / 버퍼",
		Description = "스킬로 음표를 모아 아군에게 치명타·피해량 버프를 쌓는다.",
		MaxHealth = 92,
		MoveSpeed = 1.1,
		BasicPower = 13,
		BasicMotionId = "BasicSlash",
		Skill = {
			Id = "Brillante",
			Name = "브릴란테",
			Description = "아군 전체에게 음표 수만큼 브릴란테를 부여한다.",
			Power = 20,
			CooldownTurns = 3,
			Target = "Team",
			Effect = "TeamBuff",
			MotionId = "Guard",
		},
		Color = Color3.fromRGB(196, 130, 232),
	},
	Duelist = {
		Id = "Duelist",
		Name = "결투사",
		Role = "서브딜러 / 세미탱커",
		Description = "공격 태세와 방어 태세를 오가며 패링으로 싸운다.",
		MaxHealth = 110,
		MoveSpeed = 1.12,
		BasicPower = 17,
		BasicMotionId = "BasicSlash",
		Skill = {
			Id = "PointBlank",
			Name = "마지막까지 빛나는 점을 향해 검 끝을 쏘아라",
			Description = "32 피해를 주고 태세를 변경한다. 집중 1당 피해가 2.5% 오른다.",
			Power = 32,
			CooldownTurns = 3,
			Target = "Enemy",
			Effect = "Damage",
			MotionId = "HeavySlash",
		},
		Color = Color3.fromRGB(220, 226, 236),
	},
	Quasar = {
		Id = "Quasar",
		Name = "퀘이사",
		Role = "딜탱",
		Description = "아군의 공격을 대신 받아 질량으로 바꾸고 한 번에 되돌려준다.",
		MaxHealth = 140,
		MoveSpeed = 0.86,
		BasicPower = 15,
		BasicMotionId = "HeavySlash",
		Skill = {
			Id = "Singularity",
			Name = "특이점",
			Description = "질량을 전부 태워 내려친다. 소모한 스택 1당 피해가 5% 오른다.",
			Power = 36,
			CooldownTurns = 4,
			Target = "Enemy",
			Effect = "Damage",
			MotionId = "HeavySlash",
		},
		Color = Color3.fromRGB(150, 120, 240),
	},
	Pulsar = {
		Id = "Pulsar",
		Name = "펄서",
		Role = "서브딜러",
		Description = "자기장을 두르고 적의 공격을 반사하며 안정적으로 딜을 넣는다.",
		MaxHealth = 84,
		MoveSpeed = 1.05,
		BasicPower = 16,
		BasicMotionId = "RangedShot",
		Skill = {
			Id = "Magnetosphere",
			Name = "자기권",
			Description = "3턴 동안 받는 피해가 20% 줄고, 피격 시 반사 피해 8을 준다.",
			Power = 20,
			CooldownTurns = 5,
			Target = "Self",
			Effect = "Shield",
			MotionId = "Guard",
		},
		Color = Color3.fromRGB(96, 198, 214),
	},
	WallPilgrim = {
		Id = "WallPilgrim",
		Name = "월 필그림",
		Role = "디버퍼",
		Description = "광신을 겹겹이 쌓아 적의 방어와 화력을 깎아낸다.",
		MaxHealth = 96,
		MoveSpeed = 0.98,
		BasicPower = 14,
		BasicMotionId = "BasicSlash",
		Skill = {
			Id = "Chorale",
			Name = "합창",
			Description = "대상 행 전체에 18 피해와 광신을 부여한다.",
			Power = 18,
			CooldownTurns = 4,
			Target = "Enemy",
			Effect = "Poison",
			MotionId = "HeavySlash",
		},
		Color = Color3.fromRGB(178, 150, 110),
	},
	WallMason = {
		Id = "WallMason",
		Name = "월 메이슨",
		Role = "서브딜러",
		Description = "아군 전체에 벽을 두르고, 그 벽을 화력으로 환산한다.",
		MaxHealth = 102,
		MoveSpeed = 0.92,
		BasicPower = 15,
		BasicMotionId = "BasicSlash",
		Skill = {
			Id = "Consecrate",
			Name = "축성",
			Description = "아군 전체에게 벽 3중첩을 부여한다.",
			Power = 18,
			CooldownTurns = 4,
			Target = "Team",
			Effect = "TeamShield",
			MotionId = "Guard",
		},
		Color = Color3.fromRGB(150, 172, 196),
	},
	WallBreaker = {
		Id = "WallBreaker",
		Name = "월 브레이커",
		Role = "딜러",
		Description = "아군을 갈아 넣어 허물 벽을 쌓고 단일 화력으로 터뜨린다.",
		MaxHealth = 88,
		MoveSpeed = 1.06,
		BasicPower = 19,
		BasicMotionId = "HeavySlash",
		Skill = {
			Id = "TearDown",
			Name = "허물다",
			Description = "허물 벽을 전부 태워 꽂는다. 소모한 중첩 1당 피해가 12% 오른다.",
			Power = 41,
			CooldownTurns = 4,
			Target = "Enemy",
			Effect = "Recoil",
			MotionId = "HeavySlash",
		},
		Color = Color3.fromRGB(198, 96, 78),
	},
	Alchemist = {
		Id = "Alchemist",
		Name = "연금술사",
		Role = "딜러",
		Description = "혼자 도핑하고 혼자 딜을 넣는 유리대포다. 병을 만들어 던진다.",
		MaxHealth = 85,
		MoveSpeed = 1.02,
		BasicPower = 12,
		BasicMotionId = "RangedShot",
		Skill = {
			Id = "Throw",
			Name = "던지기",
			Description = "꽉 찬 병 하나를 던져 40 피해와 그 병의 상태이상을 부여한다.",
			Power = 40,
			CooldownTurns = 3,
			Target = "Enemy",
			Effect = "Poison",
			MotionId = "RangedShot",
		},
		Color = Color3.fromRGB(126, 206, 132),
	},
	Berserker = {
		Id = "Berserker",
		Name = "광전사",
		Role = "유리대포",
		Description = "체력을 대가로 강한 피해를 짧은 주기로 가한다.",
		MaxHealth = 100,
		MoveSpeed = 1.05,
		BasicPower = 18,
		BasicMotionId = "HeavySlash",
		Skill = {
			Id = "BloodCrash",
			Name = "핏빛 분쇄",
			Description = "40 피해를 주고 자신의 체력 10을 소모한다.",
			Power = 40,
			CooldownTurns = 2,
			Target = "Enemy",
			Effect = "Recoil",
			MotionId = "HeavySlash",
		},
		Color = Color3.fromRGB(190, 70, 65),
	},
}

local order = {
	"Musician",
	"Duelist",
	"Quasar",
	"Pulsar",
	"WallPilgrim",
	"WallMason",
	"WallBreaker",
	"Alchemist",
	"Berserker",
}

local CharacterDefinitions = {}

CharacterDefinitions.DEFAULT_ID = "Berserker"

function CharacterDefinitions.Get(id: string): CharacterDefinition
	return definitions[id] or definitions.Berserker
end

function CharacterDefinitions.All(): { CharacterDefinition }
	local result = {}
	for _, id in order do
		table.insert(result, definitions[id])
	end
	return result
end

function CharacterDefinitions.IsValid(id: string): boolean
	return definitions[id] ~= nil
end

return CharacterDefinitions
