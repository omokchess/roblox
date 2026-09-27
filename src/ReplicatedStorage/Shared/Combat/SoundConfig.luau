--!strict
-- 전투 효과음. 기본값은 Roblox 클라이언트에 내장된 소리(rbxasset://)라 업로드 없이 재생된다.
-- 직접 만든 소리를 쓰려면 "rbxassetid://<ID>" 로 바꾸면 된다.

export type Sfx = { Id: string, Volume: number, Speed: number }

local SoundConfig: { [string]: Sfx } = {
	Swing = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.55, Speed = 1.1 },
	SwingHeavy = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.7, Speed = 0.85 },
	Hit = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.6, Speed = 1.7 },
	HitHeavy = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.8, Speed = 1.25 },
	Block = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Speed = 0.6 },
	Parry = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Speed = 0.9 },
	Equip = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.6, Speed = 1 },
	Dodge = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.4, Speed = 1.3 },
	Splash = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.6, Speed = 1 },
	Slam = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 1, Speed = 0.5 },
	Cast = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, Speed = 0.45 },
	Death = { Id = "rbxasset://sounds/action_falling.mp3", Volume = 0.5, Speed = 0.8 },
}

return SoundConfig
