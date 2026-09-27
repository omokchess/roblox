--!strict
-- 플레이어 무기 정의

export type WeaponDef = {
	Id: string,
	DisplayName: string,
	Icon: string,
	Model: string, -- 에셋 이름 (AssetLibrary)
	Kind: string, -- 들기 자세 (cleaver/spear/maul)
	Light: { string },
	Heavy: string,
	HeavyCharge: string,
	Skills: { [string]: string }, -- E / R
	Block: string,
	BlockReduction: number,
	SpeedScale: number,
	Description: string,
}

local WeaponDefs: { [string]: WeaponDef } = {
	Bogcleaver = {
		Id = "Bogcleaver",
		DisplayName = "늪지기 식칼",
		Icon = "🗡",
		Model = "W_Bogcleaver",
		Kind = "cleaver",
		Light = { "Cleaver_L1", "Cleaver_L2", "Cleaver_L3", "Cleaver_L4" },
		Heavy = "Cleaver_Heavy",
		HeavyCharge = "Cleaver_HeavyCharge",
		Skills = { E = "Cleaver_VenomRend", R = "Cleaver_Whirl" },
		Block = "Block_Cleaver",
		BlockReduction = 0.8,
		SpeedScale = 1,
		Description = "빠르고 균형 잡힌 한손 식칼. 4연격과 독날 기술.",
	},
	Harpoon = {
		Id = "Harpoon",
		DisplayName = "작살창",
		Icon = "🔱",
		Model = "W_Harpoon",
		Kind = "spear",
		Light = { "Spear_L1", "Spear_L2", "Spear_L3" },
		Heavy = "Spear_Heavy",
		HeavyCharge = "Spear_HeavyCharge",
		Skills = { E = "Spear_Throw", R = "Spear_Leap" },
		Block = "Block_Spear",
		BlockReduction = 0.7,
		SpeedScale = 1,
		Description = "긴 사거리의 창. 작살 투척으로 적을 끌어당긴다.",
	},
	Mossmaul = {
		Id = "Mossmaul",
		DisplayName = "이끼 망치",
		Icon = "🔨",
		Model = "W_Mossmaul",
		Kind = "maul",
		Light = { "Maul_L1", "Maul_L2", "Maul_L3" },
		Heavy = "Maul_Heavy",
		HeavyCharge = "Maul_HeavyCharge",
		Skills = { E = "Maul_GroundSlam", R = "Maul_Charge" },
		Block = "Block_Maul",
		BlockReduction = 0.9,
		SpeedScale = 0.9,
		Description = "느리지만 강인도를 크게 깎는 양손 망치.",
	},
}

-- 기본 소지 무기 (단축키 1, 2, 3)
local Loadout = { "Bogcleaver", "Harpoon", "Mossmaul" }

-- 손에 쥐는 위치: 손(R15 RightHand / R6 Right Arm) 기준. 무기 +Y(날) → 손 앞(-Z)
local GripR15 = CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(-90), 0, 0)
local GripR6 = CFrame.new(0, -1.05, 0) * CFrame.Angles(math.rad(-90), 0, 0)

return { Weapons = WeaponDefs, Loadout = Loadout, GripR15 = GripR15, GripR6 = GripR6 }
