--!strict

export type UpgradeDefinition = {
	Id: string,
	Name: string,
	Description: string,
	Kind: "Basic" | "Skill" | "Vitality" | "Haste" | "Shield" | "Heal" | "Cleanse" | "Buff",
	Amount: number,
}

local upgrades: { UpgradeDefinition } = {
	{
		Id = "TemperedEdge",
		Name = "담금질",
		Description = "파티의 기본 공격력이 5 오른다.",
		Kind = "Basic",
		Amount = 5,
	},
	{
		Id = "FocusedGlaze",
		Name = "집중 유약",
		Description = "파티의 고유 기술 위력이 8 오른다.",
		Kind = "Skill",
		Amount = 8,
	},
	{
		Id = "ThickClay",
		Name = "두꺼운 점토",
		Description = "파티의 최대 체력과 현재 체력이 22 오른다.",
		Kind = "Vitality",
		Amount = 22,
	},
	{
		Id = "QuickFiring",
		Name = "급속 소성",
		Description = "고유 기술의 재사용 대기가 1턴 줄어든다.",
		Kind = "Haste",
		Amount = 1,
	},
	{
		Id = "ProtectiveCoat",
		Name = "보호 코팅",
		Description = "파티 전원이 보호막 18을 얻는다.",
		Kind = "Shield",
		Amount = 18,
	},
	{
		Id = "RestorationGlaze",
		Name = "복원 유약",
		Description = "파티 전원의 체력을 최대 체력의 35%만큼 회복한다.",
		Kind = "Heal",
		Amount = 35,
	},
	{
		Id = "PurifyingFlame",
		Name = "정화 소성",
		Description = "파티의 상태이상과 기절을 모두 제거한다.",
		Kind = "Cleanse",
		Amount = 0,
	},
	{
		Id = "WarGlaze",
		Name = "전투 유약",
		Description = "다음 3번의 행동 동안 모든 피해량이 20% 오른다.",
		Kind = "Buff",
		Amount = 20,
	},
}

local UpgradeDefinitions = {}

function UpgradeDefinitions.Get(id: string): UpgradeDefinition?
	for _, upgrade in upgrades do
		if upgrade.Id == id then
			return upgrade
		end
	end
	return nil
end

function UpgradeDefinitions.PickThree(seed: number): { UpgradeDefinition }
	local pool = table.clone(upgrades)
	local random = Random.new(seed)
	for index = #pool, 2, -1 do
		local swap = random:NextInteger(1, index)
		pool[index], pool[swap] = pool[swap], pool[index]
	end
	return { pool[1], pool[2], pool[3] }
end

return UpgradeDefinitions
