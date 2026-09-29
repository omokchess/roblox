--!strict
--[[
	Common — 직업 묶음에 없는 것을 빌려 주는 기본 모션. (2026-09-28)
	직업마다 자기 모션을 갖는 것이 원칙이고, 이건 비상용이다.
]]
return {
	Idle = {
		Duration = 2.4,
		Loop = true,
		Keys = {
			{ t = 0, Torso = { -2, 0, 0 }, RArm = { 4, 0, 6 }, LArm = { 4, 0, -6 }, Root = { 0, 0, 0, 0, 0, 0 } },
			{ t = 1.2, Torso = { -4, 0, 0 }, RArm = { 6, 0, 8 }, LArm = { 6, 0, -8 }, Root = { 0, -0.08, 0, 0, 0, 0 } },
		},
	},
	Held = {
		Duration = 0.3,
		Hold = true,
		Keys = {
			{ t = 0, e = "backOut", Torso = { 6, 0, 0 }, RArm = { 20, 0, 30 }, LArm = { 20, 0, -30 }, RLeg = { 10, 0, 6 }, LLeg = { -6, 0, -6 } },
		},
	},
	Drop = {
		Duration = 0.4,
		Keys = {
			{ t = 0, Root = { 0, -0.5, 0, 0, 0, 0 }, Torso = { -12, 0, 0 } },
			{ t = 0.4, e = "backOut", Root = { 0, 0, 0, 0, 0, 0 }, Torso = { 0, 0, 0 } },
		},
	},
	Hit = {
		Duration = 0.5,
		Keys = {
			{ t = 0, Torso = { 0, 0, 0 } },
			{ t = 0.06, e = "expoOut", Torso = { 18, 0, 0 }, Head = { 20, 0, 0 }, Root = { 0, 0, 0.8, 0, 0, 0 } },
			{ t = 0.5, e = "sineInOut", Torso = { 0, 0, 0 }, Head = { 0, 0, 0 }, Root = { 0, 0, 0, 0, 0, 0 } },
		},
	},
	Guard = {
		Duration = 0.5,
		Keys = {
			{ t = 0 },
			{ t = 0.08, e = "expoOut", RArm = { 80, 0, -30 }, LArm = { 80, 0, 30 }, Torso = { -6, 0, 0 } },
			{ t = 0.5, RArm = { 0, 0, 0 }, LArm = { 0, 0, 0 }, Torso = { 0, 0, 0 } },
		},
	},
	Dodge = {
		Duration = 0.5,
		Keys = {
			{ t = 0 },
			{ t = 0.12, e = "expoOut", Root = { 1.6, 0, 0.6, 0, 0, -18 }, Torso = { -10, 0, 0 } },
			{ t = 0.5, e = "sineInOut", Root = { 0, 0, 0, 0, 0, 0 }, Torso = { 0, 0, 0 } },
		},
	},
	Skills = {
		Default = {
			Duration = 0.8,
			Keys = {
				{ t = 0 },
				{ t = 0.2, e = "quadOut", RArm = { 130, 0, 10 }, Torso = { 6, 20, 0 } },
				{ t = 0.34, e = "expoOut", RArm = { 40, 0, -20 }, Torso = { -14, -25, 0 } },
				{ t = 0.8, RArm = { 0, 0, 0 }, Torso = { 0, 0, 0 } },
			},
			Events = { { t = 0.3, k = "Hit", i = 1 } },
		},
	},
}
