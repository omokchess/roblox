--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterDefinitions = require(ReplicatedStorage.Shared.CharacterDefinitions)
local EnemyDefinitions = require(ReplicatedStorage.Shared.EnemyDefinitions)
local TowerDefinitions = require(ReplicatedStorage.Shared.TowerDefinitions)
local UpgradeDefinitions = require(ReplicatedStorage.Shared.UpgradeDefinitions)
local MotionTimeline = require(ReplicatedStorage.Shared.MotionTimeline)
local MotionValidator = require(script.Parent.MotionValidator)
local R6RigFactory = require(script.Parent.R6RigFactory)

-- 추가&수정.md에서 새로 들어온 시스템들
local StatDefinitions = require(ReplicatedStorage.Shared.StatDefinitions)
local ItemDefinitions = require(ReplicatedStorage.Shared.ItemDefinitions)
local ProgressionDefinitions = require(ReplicatedStorage.Shared.ProgressionDefinitions)
local AbilityCardDefinitions = require(ReplicatedStorage.Shared.AbilityCardDefinitions)
local Keywords = require(ReplicatedStorage.Shared.Keywords)
local TowerRewardDefinitions = require(ReplicatedStorage.Shared.TowerRewardDefinitions)
local HonorDefinitions = require(ReplicatedStorage.Shared.HonorDefinitions)
local AfterlifeDefinitions = require(ReplicatedStorage.Shared.AfterlifeDefinitions)
local RuneDefinitions = require(ReplicatedStorage.Shared.RuneDefinitions)
local PrayerDefinitions = require(ReplicatedStorage.Shared.PrayerDefinitions)
local PlayerProfile = require(ReplicatedStorage.Shared.PlayerProfile)
local TowerRun = require(ReplicatedStorage.Shared.TowerRun)
local GridBattle = require(ReplicatedStorage.Shared.GridBattle)
local BattleArena = require(ReplicatedStorage.Shared.BattleArena)
local CardArt = require(ReplicatedStorage.Shared.CardArt)
local CardArtworks = require(ReplicatedStorage.Shared.CardArtworks)
local SkyArena = require(ReplicatedStorage.Shared.SkyArena)

local PrototypeTests = {}

local function expect(condition: boolean, message: string)
	if not condition then
		error("[PorcelainTests] " .. message, 2)
	end
end

function PrototypeTests.Run()
	local testRig = R6RigFactory.Create("ClassicHeadTest", Color3.new(1, 1, 1), CFrame.new())
	local testHead = testRig:FindFirstChild("Head")
	local testHeadMesh = testHead and testHead:FindFirstChild("ClassicHeadMesh")
	expect(
		testHeadMesh ~= nil and testHeadMesh:IsA("SpecialMesh") and testHeadMesh.MeshType == Enum.MeshType.Head,
		"battle rig must use the classic Roblox head mesh"
	)
	testRig:Destroy()
	local characters = CharacterDefinitions.All()
	-- 직업은 9개다(카드 파일 9개와 같은 로스터 — `AbilityCards` 머리 주석)
	expect(#characters == 9, "fixed character roster must contain 9 classes")
	local characterIds: { [string]: boolean } = {}
	for _, character in characters do
		expect(not characterIds[character.Id], "character ids must be unique")
		characterIds[character.Id] = true
		expect(character.MaxHealth > 0 and character.MoveSpeed > 0, "character base stats must be positive")
		expect(character.BasicPower > 0 and character.Skill.Power >= 0, "character combat stats must be fixed")
		expect(
			character.Skill.Name ~= "" and character.Skill.MotionId ~= "",
			"character skill definition is incomplete"
		)
	end
	expect(CharacterDefinitions.IsValid("Musician"), "support character definition missing")
	expect(CharacterDefinitions.IsValid("Berserker"), "berserker character definition missing")
	-- 적은 지금 슬라임 한 종뿐이다(2026-09-28 요청). 보스 층도 슬라임.
	expect(#EnemyDefinitions.FirstEncounter() == 1, "first encounter must be the slime")
	expect(EnemyDefinitions.Boss().Id == "Slime", "boss floors must fall back to the slime")
	expect(TowerDefinitions.Count() == 30, "tower must contain exactly 30 floors")
	expect(TowerDefinitions.Get(10).Kind == "Boss", "floor 10 must be a boss floor")
	expect(TowerDefinitions.Get(20).Enemies[1] == "Slime", "floor 20 must spawn the slime")
	expect(TowerDefinitions.Get(30).Enemies[1] == "Slime", "floor 30 must spawn the slime")
	for expectedFloor, floor in TowerDefinitions.All() do
		expect(floor.Floor == expectedFloor, "tower floor numbers must be contiguous")
		expect(floor.HealthScale > 0 and floor.PowerScale > 0, "tower scaling must be positive")
		expect(floor.GimmickName ~= "" and floor.GimmickDescription ~= "", "tower floor rule is incomplete")
		for _, enemyId in floor.Enemies do
			expect(EnemyDefinitions.IsValid(enemyId), "tower references an unknown enemy")
		end
	end
	expect(
		TowerDefinitions.Get(30).HealthScale > TowerDefinitions.Get(1).HealthScale,
		"tower health scaling must increase across the run"
	)
	local choices = UpgradeDefinitions.PickThree(77)
	expect(#choices == 3, "upgrade draft must contain 3 choices")
	expect(choices[1].Id ~= choices[2].Id and choices[2].Id ~= choices[3].Id, "upgrade choices must be unique")

	local validMotion = {
		Id = "Basic",
		Duration = 0.6,
		DualWield = true,
		Frames = {
			{
				Time = 0,
				Joints = {},
				JointRotations = { ["Right Shoulder"] = { X = 0.1, Y = 0.2, Z = 0.3, W = 0.9 } },
				JointOffsets = { ["Right Shoulder"] = { X = 0.5, Y = -0.25, Z = 0.75 } },
				RootOffset = { X = 1, Y = 0, Z = 0 },
				Weapon = {
					AssetId = "rbxassetid://12345",
					Size = { X = 2, Y = 4, Z = 0.2 },
				},
				DualWeapon = {
					AssetId = "54321",
					Size = { X = 1, Y = 3, Z = 0.2 },
				},
				Decorations = {
					{
						Name = "왕관",
						AssetId = "98765",
						Attach = "Head",
						Offset = { X = 0, Y = 1, Z = 0 },
						Size = { X = 2, Y = 1, Z = 0.1 },
					},
				},
				LayerOrder = { "Weapon", "Player", "Decoration:1", "DualWeapon" },
			},
			{
				Time = 0.6,
				Joints = {},
				LayerOrder = { "Player", "Weapon", "DualWeapon" },
			},
		},
		Hits = {
			{
				Frame = 2,
				AttackId = "SharedSwing",
				DamageRatio = 0.5,
				Hitbox = {
					Offset = { X = 0, Y = 0, Z = -3 },
					Size = { X = 3, Y = 3, Z = 3 },
					Rotation = { X = 0, Y = 0, Z = 30 },
				},
			},
			{
				Frame = 2,
				AttackId = "SharedSwing",
				DamageRatio = 0.5,
				Hitbox = { Offset = { X = 2, Y = 0, Z = -3 }, Size = { X = 2, Y = 2, Z = 2 } },
			},
		},
		Events = {
			Effects = {
				{
					Frame = 1,
					AssetId = "123456",
					Offset = { X = 2, Y = 1, Z = 0 },
					Size = { X = 3, Y = 2, Z = 0.1 },
					ColorHex = "#FF3366",
					Opacity = 0.7,
					FlipX = true,
					EffectPreset = "ring",
				},
			},
		},
		Combat = {
			Damage = 20,
			CooldownTurns = 0,
			TargetCount = 2,
			CastDirection = "target",
			UltimateGain = 10,
			Statuses = { { Type = "bleed", ApplyFrame = 2, Power = 2, Stacks = 2 } },
			Buffs = {},
		},
	}
	local sanitized, validError = MotionValidator.Sanitize(validMotion)
	expect(sanitized ~= nil and validError == nil, "same AttackId must support multiple hitboxes")
	expect(sanitized and #sanitized.Hits == 2, "valid hitboxes were not preserved")
	expect(sanitized and sanitized.Frames[1].RootOffset.X == 1, "frame root movement was not preserved")
	expect(
		sanitized and sanitized.Frames[1].JointOffsets["Right Shoulder"].Z == 0.75,
		"per-joint movement was not preserved"
	)
	expect(
		sanitized and math.abs(sanitized.Frames[1].JointRotations["Right Shoulder"].W - 0.9) < 0.001,
		"quaternion joint rotation was not preserved"
	)
	expect(sanitized and sanitized.Frames[1].Weapon.AssetId == "rbxassetid://12345", "weapon image was not preserved")
	expect(sanitized and sanitized.Hits[1].Hitbox.Rotation.Z == 30, "hitbox rotation was not preserved")
	expect(sanitized and #sanitized.Events.Effects == 1, "frame effect was not preserved")
	expect(sanitized and sanitized.Events.Effects[1].ColorHex == "#FF3366", "effect color was not preserved")
	expect(sanitized and sanitized.Events.Effects[1].Opacity == 0.7, "effect opacity was not preserved")
	expect(sanitized and sanitized.Events.Effects[1].FlipX == true, "effect flip was not preserved")
	expect(sanitized and sanitized.Events.Effects[1].EffectPreset == "ring", "built-in effect was not preserved")
	expect(sanitized and sanitized.DualWield == true, "dual wield setting was not preserved")
	expect(
		sanitized and sanitized.Frames[1].DualWeapon.AssetId == "rbxassetid://54321",
		"dual weapon was not preserved"
	)
	expect(sanitized and #sanitized.Frames[1].Decorations == 1, "frame decoration was not preserved")
	expect(sanitized and sanitized.Frames[1].LayerOrder[1] == "Weapon", "frame layer order was not preserved")
	expect(sanitized and sanitized.Combat.TargetCount == 2, "combat targeting was not preserved")
	expect(sanitized and sanitized.Combat.Statuses[1].Type == "bleed", "combat status was not preserved")
	expect(sanitized and sanitized.Combat.UltimateGain == 10, "ultimate gain was not preserved")
	local pack, packError = MotionValidator.SanitizePack({
		Name = "도자기 검",
		Description = "검증용 무기",
		BodyColorHex = "#33AA77",
		AuthorCharacterId = "Musician",
		BaseStats = { MaxHealth = 9999, MoveSpeed = 99 },
		ActivePreset = "Basic",
		Presets = { Basic = validMotion },
	})
	expect(pack ~= nil and packError == nil and pack.Presets.Basic ~= nil, "motion preset pack was not preserved")
	expect(pack and pack.Name == "도자기 검", "weapon name was not preserved")
	expect(pack and pack.BodyColorHex == "#33AA77", "body color was not preserved")
	expect(pack and pack.AuthorCharacterId == "Musician", "author character was not preserved")
	expect(pack and pack.BaseStats == nil, "legacy weapon base stats must be removed")
	local damageEvents = MotionTimeline.DamageEvents(sanitized)
	expect(#damageEvents == 1, "same AttackId hitboxes must resolve as one damage event")
	expect(damageEvents[1].Time == 0.6, "damage event must use its authored frame time")
	expect(damageEvents[1].Ratio == 0.5, "authored frame damage ratio was not preserved")
	local automaticEvents = MotionTimeline.DamageEvents({
		Duration = 1,
		Frames = { { Time = 0 }, { Time = 0.25 }, { Time = 0.75 }, { Time = 1 } },
		Hits = {
			{ Frame = 2, AttackId = "First", DamageRatio = 0 },
			{ Frame = 3, AttackId = "Second", DamageRatio = 0 },
		},
	})
	expect(#automaticEvents == 2, "separate AttackIds must create separate damage events")
	expect(automaticEvents[1].Ratio == 0.5 and automaticEvents[2].Ratio == 0.5, "automatic damage split failed")
	expect(automaticEvents[1].Time == 0.25 and automaticEvents[2].Time == 0.75, "multi-hit timing was flattened")

	local invalidMotion = table.clone(validMotion)
	invalidMotion.Hits = {
		{ Frame = 1, AttackId = "First", DamageRatio = 0.7 },
		{ Frame = 2, AttackId = "Second", DamageRatio = 0.5 },
	}
	local rejected = MotionValidator.Sanitize(invalidMotion)
	expect(rejected == nil, "total unique AttackId damage ratio over 100% must be rejected")
	local expensiveDraft = {
		Id = "Basic",
		Duration = 0.5,
		Complete = false,
		Frames = { { Time = 0, Joints = {} }, { Time = 0.5, Joints = {} } },
		Hits = { { Frame = 2, AttackId = "Hit", DamageRatio = 1 } },
		Combat = { Damage = 60, TargetCount = 3, Knockback = 200, Statuses = {}, Buffs = {} },
	}
	local draftPack = MotionValidator.SanitizePack({ Presets = { Basic = expensiveDraft } })
	expect(draftPack ~= nil, "incomplete over-budget preset must remain saveable as a draft")
	expensiveDraft.Complete = true
	local rejectedComplete = MotionValidator.SanitizePack({ Presets = { Basic = expensiveDraft } })
	expect(rejectedComplete == nil, "completed over-budget preset must be rejected")
	local ultimate = MotionValidator.Sanitize({
		Id = "Ultimate",
		Duration = 0.5,
		Frames = { { Time = 0, Joints = {} }, { Time = 0.5, Joints = {} } },
		Hits = {},
		Combat = { Damage = 40, CooldownTurns = 9, Statuses = {}, Buffs = {} },
	})
	expect(ultimate and ultimate.Combat.CooldownTurns == 0, "ultimate cooldown must always be zero")
	print("[PorcelainTests] PASS roster, tower, upgrade draft, motion validation")

	PrototypeTests.RunSystems()
end

--[[
	상태이상 시스템과 직업 스킬 효과 검증.

	`RunSystems`에서 갈라 냈다 — 한 함수에 지역 변수가 200개를 넘으면 Luau가
	"Out of local registers"로 아예 컴파일을 거부한다. 실제로 그 한계를 넘겼다.
]]
--[[
	능력 카드가 **실제로 전투를 바꾸는지** 검증.

	카드는 오래도록 텍스트일 뿐이어서, 보상 화면에서 골라도 전투는 아무것도 몰랐다.
	`CardEffects`가 그걸 붙였으므로 훅 네 개가 전부 도는지 여기서 못박는다.
]]
--[[
	키워드 검사.

	`RunSystems`에서 갈라 냈다 — 한 함수에 지역 변수가 200개를 넘으면 Luau가
	"Out of local registers"로 컴파일을 거부한다. 이 파일에서 두 번째로 밟았다.
]]
local function runKeywords()
	--[[
		**모든 키워드에 서로 다른 색이 있어야 한다** (요청).

		글에서 `[낱말]`을 색으로 가르는 것이 목적이라, 두 낱말이 같은 색이면 그
		목적이 그 자리에서 무너진다.
	]]
	local usedColor: { [string]: string } = {}
	for _, keyword in Keywords.All() do
		expect(
			keyword.Color:match("^#%x%x%x%x%x%x$") ~= nil,
			string.format("keyword '%s' needs a #rrggbb colour, got '%s'", keyword.Id, keyword.Color)
		)
		expect(
			usedColor[keyword.Color] == nil,
			string.format(
				"keywords '%s' and '%s' share colour %s",
				tostring(usedColor[keyword.Color]),
				keyword.Id,
				keyword.Color
			)
		)
		usedColor[keyword.Color] = keyword.Id
	end

	--[[
		`[키워드]`가 글에서 그 레벨의 값과 함께 나와야 한다.

		편집기에서 낱말 옆 `%` 칸에 넣은 값이 게임 글에 그대로 뜨는지를 본다 —
		둘이 어긋나면 편집기가 거짓말을 하는 셈이다.
	]]
	local sample = {
		Id = "KeywordProbe",
		Name = "검사용",
		Description = "체력이 30% 이하일 때 [가하는 피해량] 증가.",
		Levels = { { 8, 11, 14, 17, 20, 23 } },
		LevelKeywords = { "DamageDealt" },
		Grade = "Common" :: any,
		ClassId = "Alchemist",
		Tags = { "Brink" },
	}
	expect(
		AbilityCardDefinitions.Describe(sample, 1) == "체력이 30% 이하일 때 가하는 피해량 8% 증가.",
		"a bracketed keyword must render with its level value"
	)
	expect(
		AbilityCardDefinitions.Describe(sample, 6) == "체력이 30% 이하일 때 가하는 피해량 23% 증가.",
		"the keyword value must follow the card level"
	)

	--[[
		한 슬롯에 낱말을 **여럿** 이을 수 있다(요청). 쉼표로 이은 문자열 하나에
		둘 다 담기고, 두 낱말 모두 같은 레벨 값을 받아야 한다.
	]]
	local multi = {
		Id = "KeywordMulti",
		Name = "검사용3",
		Description = "[가하는 피해량] 증가와 [받는 피해량] 감소가 각각 {5}% 오른다.",
		Levels = { { 5, 7, 9, 11, 13, 15 } },
		LevelKeywords = { "DamageDealt,DamageTaken" },
		Grade = "Common" :: any,
		ClassId = "Alchemist",
		Tags = { "Brink" },
	}
	expect(
		AbilityCardDefinitions.Describe(multi, 1)
			== "가하는 피해량 5% 증가와 받는 피해량 5% 감소가 각각 5% 오른다.",
		"a slot with two linked keywords must give both the same level value"
	)
	expect(
		AbilityCardDefinitions.Describe(multi, 3)
			== "가하는 피해량 9% 증가와 받는 피해량 9% 감소가 각각 9% 오른다.",
		"both linked keywords must track the same ladder across levels"
	)

	--[[
		사다리가 없는 낱말은 대괄호만 벗는다. 화면에서는 색으로 구분되므로
		대괄호가 없어도 낱말인 것이 읽힌다.
	]]
	local plain = {
		Id = "KeywordPlain",
		Name = "검사용2",
		Description = "[꽉 찬 병] 1개당 {3}% 오른다.",
		Levels = { { 3, 4, 5, 6, 7, 8 } },
		LevelKeywords = { "DamageDealt" },
		Grade = "Common" :: any,
		ClassId = "Alchemist",
		Tags = { "Brew" },
	}
	expect(
		AbilityCardDefinitions.Describe(plain, 2) == "꽉 찬 병 1개당 4% 오른다.",
		"a keyword without a ladder must simply lose its brackets"
	)
end

local function runCardEffects()
	--[[
		카드 엔진 2판(CardEffects/<직업>.luau). 수치는 카드의 `Levels` 사다리에서 읽는다 —
		그래서 여기 기대값도 사다리 1레벨·최대 레벨 값 그대로다.
	]]
	local CardEffects = require(ReplicatedStorage.Shared.CardEffects)
	local ClassResources = require(ReplicatedStorage.Shared.ClassResources)
	local BattleStatus = require(ReplicatedStorage.Shared.BattleStatus)
	local GroggyGauge = require(ReplicatedStorage.Shared.GroggyGauge)

	local function battleWith(classId: string, cards: { any })
		return GridBattle.New(1, "테스터", 200, 30, classId, 20, 60, cards)
	end
	local function rage(state): number
		return BattleStatus.Stack(GridBattle.Ally(state).Status, ClassResources.RAGE)
	end

	-- 카드가 없으면 아무 일도 없어야 한다. 기준선이다.
	local bare = battleWith("Berserker", {})
	expect(rage(bare) == 0, "a card-less battle must not hand out class resources")

	-- 범위 미리보기 = 판정: 광속 붕괴는 질량이 없어도 특이점을 끝 단계(2)로 키운다. 스냅샷 스킬 목록이
	-- 그 값(Grow)을 실어 보내야 클라이언트 빨간 칸이 실제로 맞는 칸과 같다
	do
		local function singularityGrow(state): number?
			for _, entry in GridBattle.Snapshot(state).AllySkills do
				if entry.Id == "Singularity" then
					return entry.Grow
				end
			end
			return nil
		end
		local plain = battleWith("Quasar", {})
		local collapse = battleWith("Quasar", { { CardId = "Quasar_E_LightspeedCollapse", Level = 1 } })
		expect(singularityGrow(plain) == 0, "특이점 without mass must not grow")
		expect(singularityGrow(collapse) == 2, "광속 붕괴 must report the full-size singularity to the preview")
	end

	--=== 전투 시작 · 사다리 ===--

	expect(rage(battleWith("Berserker", { { CardId = "Berserker_C_Ember", Level = 1 } })) == 1, "불씨 Lv1 must start with 1 rage")
	expect(rage(battleWith("Berserker", { { CardId = "Berserker_C_Ember", Level = 3 } })) == 3, "불씨 Lv3 must follow its ladder (3)")

	-- 외피: 최대 체력 5%(Lv1) → 10%(Lv6)
	local hull1 = battleWith("Quasar", { { CardId = "Quasar_C_Hull", Level = 1 } })
	local hull6 = battleWith("Quasar", { { CardId = "Quasar_C_Hull", Level = 6 } })
	expect(GridBattle.Ally(hull1).Status.Shield == 10, "외피 Lv1 must open with a 5% shield")
	expect(GridBattle.Ally(hull6).Status.Shield == 20, "외피 Lv6 must open with a 10% shield")

	--=== 규칙 질의 ===--

	-- 피의 맹약: 최대 체력 −20%, 분노 상한 8 → 13
	local pact = battleWith("Berserker", { { CardId = "Berserker_C_BloodPact", Level = 1 } })
	expect(GridBattle.Ally(pact).MaxHealth == 160, "피의 맹약 must cut max health by 20%")
	GridBattle.GainResource(pact, GridBattle.Ally(pact), ClassResources.RAGE, 99)
	expect(rage(pact) == 13, "피의 맹약 must raise the rage cap to 13")

	-- 흡혈: 분노 상한 0 (둘 다 들면 흡혈이 이긴다)
	local vamp = battleWith("Berserker", {
		{ CardId = "Berserker_E_Vampire", Level = 1 },
		{ CardId = "Berserker_C_BloodPact", Level = 1 },
	})
	GridBattle.GainResource(vamp, GridBattle.Ally(vamp), ClassResources.RAGE, 5)
	expect(rage(vamp) == 0, "흡혈 must block rage even with 피의 맹약")

	--=== 치명상 직전(Lethal) · 회복 훅 ===--

	local undying = battleWith("Berserker", { { CardId = "Berserker_E_Undying", Level = 1 } })
	local undyingAlly = GridBattle.Ally(undying)
	undyingAlly.Health = 1
	local foe = GridBattle.AliveEnemies(undying)[1]
	GridBattle.ResolveDodge(undying, foe.Id, "Fail")
	expect(undyingAlly.Alive and undyingAlly.Health == 1, "불굴 must hold the ally at 1 health once")
	GridBattle.ResolveDodge(undying, foe.Id, "Fail")
	expect(not undyingAlly.Alive, "불굴 must work only once per battle")

	--=== 피격 → 분노(다혈질 + 격노) ===--

	local plain = battleWith("Berserker", {})
	local wrath = battleWith("Berserker", { { CardId = "Berserker_R_Wrath", Level = 1 } })
	GridBattle.ResolveDodge(plain, GridBattle.AliveEnemies(plain)[1].Id, "Fail")
	GridBattle.ResolveDodge(wrath, GridBattle.AliveEnemies(wrath)[1].Id, "Fail")
	expect(rage(plain) >= 1, "다혈질 must turn lost health into rage")
	expect(rage(wrath) == rage(plain) + 1, "격노 must add one more rage per direct hit")

	--=== 아군 그로기 ===--

	local groggy = battleWith("Berserker", {})
	local numb = battleWith("Berserker", { { CardId = "Berserker_C_Numb", Level = 1 } })
	for _ = 1, 4 do
		for _, state in { groggy, numb } do
			local ally = GridBattle.Ally(state)
			ally.Health = ally.MaxHealth
			GridBattle.ResolveDodge(state, GridBattle.AliveEnemies(state)[1].Id, "Fail")
		end
	end
	expect(GroggyGauge.IsStunned(GridBattle.Ally(groggy).Groggy), "four missed dodges must stun the ally")
	GridBattle.EndTurn(groggy)
	expect(GroggyGauge.IsStunned(GridBattle.Ally(groggy).Groggy), "the stun must last through the ally's next turn")
	expect(not GroggyGauge.IsStunned(GridBattle.Ally(numb).Groggy), "무감각 must stop groggy")

	--=== 직업 키트 ===--

	-- 퀘이사 질량: 1당 주는 피해 +1%
	local quasar = battleWith("Quasar", {})
	local quasarAlly = GridBattle.Ally(quasar)
	GridBattle.GainResource(quasar, quasarAlly, ClassResources.MASS, 10)
	GridBattle.EndTurn(quasar) -- 키트가 턴 시작에 질량 보정을 다시 건다
	expect(BattleStatus.Total(quasarAlly.Status, "DamageDealt") >= 0.1 - 1e-6, "mass must raise damage dealt")

	-- 결투사 태세: 턴당 한 번, 행동 없이
	local duel = battleWith("Duelist", {})
	expect(GridBattle.ToggleStance(duel), "a duelist must be able to switch stance")
	expect(not GridBattle.ToggleStance(duel), "stance can switch only once per turn")

	--=== 데이터 정합 ===--

	for _, cardId in CardEffects.WiredIds() do
		expect(
			AbilityCardDefinitions.Get(cardId) ~= nil
				or string.find(cardId, "_Kit$") ~= nil
				or string.find(cardId, "^%a+_%u%a+$") ~= nil, -- 직업 패시브(Berserker_Fury 처럼 등급 글자가 없다)
			string.format("CardEffects lists '%s' but no card, kit or passive has that id", cardId)
		)
	end
	local total, wired = 0, 0
	for _, character in CharacterDefinitions.All() do
		local classId = character.Id
		for _, grade in { "Essential", "Rare", "Common" } do
			for _, card in AbilityCardDefinitions.GetPool(classId, grade :: any) do
				total += 1
				if CardEffects.IsWired(card.Id) then
					wired += 1
				end
				-- 전직 배타: 서로를 가리켜야 한다
				for _, other in (card :: any).Excludes or {} do
					local target = AbilityCardDefinitions.Get(other)
					expect(target ~= nil, string.format("%s excludes unknown card %s", card.Id, other))
					expect(
						target ~= nil and table.find((target :: any).Excludes or {}, card.Id) ~= nil,
						string.format("%s excludes %s but not the other way round", card.Id, other)
					)
				end
			end
		end
	end
	expect(wired == total, string.format("every card must be wired (%d / %d)", wired, total))

	--=== 뽑기가 빌드를 읽는다 ===--

	-- 철벽을 들었으면 광검·양날(전직 배타)은 필수 화면에 나오지 않는다
	local ironWall = { { CardId = "Duelist_E_IronWall", Level = 1 } }
	for seed = 1, 20 do
		for _, card in AbilityCardDefinitions.DrawForFloor("Duelist", 10, seed, nil, 0, ironWall) do
			expect(
				card.Id ~= "Duelist_E_LightBlade" and card.Id ~= "Duelist_E_DoubleEdge",
				"an excluded essential must never be offered (" .. card.Id .. ")"
			)
		end
	end
	-- 갈림길: 일반 화면에는 가진 축 밖의 카드가 적어도 한 장 있다
	local oneAxis = { { CardId = "Berserker_C_Bite", Level = 1 } } -- 피(Blood)
	for seed = 1, 20 do
		local fresh = false
		for _, card in AbilityCardDefinitions.DrawForFloor("Berserker", 7, seed, nil, 0, oneAxis) do
			for _, tag in card.Tags do
				if card.Grade == "Common" and tag ~= "Blood" then
					fresh = true
				end
			end
		end
		expect(fresh, "a common screen must keep at least one card outside the build's axes")
	end
	print(string.format("[PorcelainTests] card effects wired: %d / %d", wired, total))
end

local function runStatusAndSkillEffects()
	--=== 상태이상 (상태이상.md) ===--

	local BattleStatus = require(ReplicatedStorage.Shared.BattleStatus)

	-- 보호막은 추가 HP다. 피해를 먼저 먹는다.
	local shieldStatus = BattleStatus.New()
	BattleStatus.AddShield(shieldStatus, 30)
	local absorbed, leftover = BattleStatus.Absorb(shieldStatus, 20)
	expect(absorbed == 20 and leftover == 0, "a shield must absorb damage before health")
	expect(shieldStatus.Shield == 10, "a shield must keep what it did not spend")
	local absorbed2, leftover2 = BattleStatus.Absorb(shieldStatus, 25)
	expect(absorbed2 == 10 and leftover2 == 15, "damage past the shield must carry through")

	--[[
		지속 피해 감소 규칙. `상태이상.md`가 종류마다 다르게 못박았다.
		  출혈 −1 / 독 −3 / 화상 −1
	]]
	local dotStatus = BattleStatus.New()
	BattleStatus.AddBleed(dotStatus, 3)
	BattleStatus.AddPoison(dotStatus, 10)
	BattleStatus.AddBurn(dotStatus, 10)
	local tick = BattleStatus.TickDots(dotStatus, 200)
	-- 출혈은 최대 체력의 5% → 200의 5% = 10
	expect(tick.Physical == 10, "bleed must deal 5% of max health")
	expect(tick.True == 10, "poison must deal its own value as true damage")
	-- 화상은 수치%만큼 → 200의 10% = 20
	expect(tick.Fire == 20, "burn must deal (value)% of max health as fire")
	expect(dotStatus.Bleed == 2, "bleed must decay by 1")
	expect(dotStatus.Poison == 7, "poison must decay by 3")
	expect(dotStatus.Burn == 9, "burn must decay by 1")

	-- 기름은 화염 피해만 50% 키운다. 물리와 고정에는 손대지 않는다.
	local oilStatus = BattleStatus.New()
	BattleStatus.AddOil(oilStatus, 5)
	expect(BattleStatus.IncomingDamage(oilStatus, 100, "Fire") == 150, "oil must raise fire damage by 50%")
	expect(BattleStatus.IncomingDamage(oilStatus, 100, "Physical") == 100, "oil must not touch physical damage")

	-- True 속성은 어떤 보정도 받지 않는다.
	local wardStatus = BattleStatus.New()
	BattleStatus.AddModifier(wardStatus, "DamageTaken", -0.5, 2, "테스트")
	expect(BattleStatus.IncomingDamage(wardStatus, 100, "Physical") == 50, "damage-taken must scale physical damage")
	expect(BattleStatus.IncomingDamage(wardStatus, 100, "True") == 100, "true damage must ignore modifiers")

	-- 기한이 다 되면 사라진다. -1은 전투 내내 남는다.
	BattleStatus.AddModifier(wardStatus, "DamageDealt", 0.2, -1, "영구")
	BattleStatus.TickModifiers(wardStatus)
	expect(BattleStatus.Total(wardStatus, "DamageTaken") == -0.5, "a 2-turn modifier must survive one tick")
	BattleStatus.TickModifiers(wardStatus)
	expect(BattleStatus.Total(wardStatus, "DamageTaken") == 0, "a modifier must expire when its turns run out")
	expect(BattleStatus.Total(wardStatus, "DamageDealt") == 0.2, "a -1 modifier must never expire")

	-- 스택은 상한에서 멈추고, 실제로 쓴 만큼만 빠진다.
	local stackStatus = BattleStatus.New()
	BattleStatus.AddStack(stackStatus, "Focus", 99, 10)
	expect(BattleStatus.Stack(stackStatus, "Focus") == 10, "stacks must clamp to their cap")
	expect(BattleStatus.SpendStack(stackStatus, "Focus", 99) == 10, "spending must report what was actually spent")
	expect(BattleStatus.Stack(stackStatus, "Focus") == 0, "spending must empty the stack")

	--=== 지속 피해로는 죽지 않는다 ===--

	--[[
		`상태이상.md`: 출혈·독·화상 모두 "이 효과로 사망할 수 없다."
		체력 1에서 멈춰야 한다.
	]]
	local dotBattle = GridBattle.New(1, "출혈", 40, 1, "Duelist")
	local dotAlly = GridBattle.Ally(dotBattle)
	dotAlly.Health = 3
	BattleStatus.AddBleed(dotAlly.Status, 5)
	BattleStatus.AddPoison(dotAlly.Status, 99)
	for _ = 1, 5 do
		GridBattle.EndTurn(dotBattle)
	end
	expect(dotAlly.Alive, "damage over time must never kill")
	expect(dotAlly.Health == 1, "damage over time must stop at 1 health")

	--=== 직업 스킬 효과 ===--

	local BattleSkillEffects = require(ReplicatedStorage.Shared.BattleSkillEffects)
	local BattleSkills = require(ReplicatedStorage.Shared.BattleSkills)
	local ClassResources = require(ReplicatedStorage.Shared.ClassResources)

	--[[
		피해 0이던 스킬 여섯 개가 **실제로 무언가를 하는지**. 이게 이 작업의 핵심이라
		직업마다 관측 가능한 결과를 하나씩 못박는다.
	]]

	-- 음악가 브릴란테: 음표 수만큼 치명타 버프가 걸린다.
	local musicBattle = GridBattle.New(1, "음악가", 100, 10, "Musician")
	local musicAlly = GridBattle.Ally(musicBattle)
	expect(
		BattleStatus.Stack(musicAlly.Status, ClassResources.METER) == 1,
		"the musician must start with 1 meter (passive)"
	)
	GridBattle.MoveAlly(musicBattle, 1, 2)
	GridBattle.ResolveSkill(musicBattle, 1, "Success") -- 벨로체 → 4분음표 2 + 보호막
	expect(BattleStatus.Stack(musicAlly.Status, ClassResources.QUARTER) == 2, "veloce must grant 2 quarter notes")
	expect(musicAlly.Status.Shield > 0, "veloce must grant a shield")
	GridBattle.ResolveSkill(musicBattle, 2, "Success") -- 브릴란테
	expect(BattleStatus.Total(musicAlly.Status, "CritChance") > 0, "brillante must grant a crit buff")
	expect(BattleStatus.Stack(musicAlly.Status, ClassResources.EIGHTH) == 2, "brillante must grant 2 eighth notes")

	-- 펄서 자기권: 받는 피해 감소 + 반사가 걸린다.
	local pulsarBattle = GridBattle.New(1, "펄서", 100, 10, "Pulsar")
	local pulsarAlly = GridBattle.Ally(pulsarBattle)
	GridBattle.MoveAlly(pulsarBattle, 1, 2)
	GridBattle.ResolveSkill(pulsarBattle, 1, "Success") -- 자기권
	expect(BattleStatus.Total(pulsarAlly.Status, "DamageTaken") < 0, "magnetosphere must reduce damage taken")
	expect(BattleStatus.Total(pulsarAlly.Status, "Reflect") > 0, "magnetosphere must grant reflect")

	--[[
		그 반사가 실제로 적을 때리는지. 회피 실패(Fail)로 맞아야 반사가 나간다.
	]]
	local reflectFoe = GridBattle.AliveEnemies(pulsarBattle)[1]
	local foeHealthBefore = reflectFoe.Health
	GridBattle.ResolveDodge(pulsarBattle, reflectFoe.Id, "Fail")
	expect(reflectFoe.Health < foeHealthBefore, "reflect must damage the attacker")
	expect(
		BattleStatus.Stack(reflectFoe.Status, ClassResources.DEPOLAR) > 0,
		"magnetosphere must also apply depolarisation"
	)

	-- 월 메이슨 축성: 벽 3중첩 + 받는 피해 감소.
	local masonBattle = GridBattle.New(1, "메이슨", 100, 10, "WallMason")
	local masonAlly = GridBattle.Ally(masonBattle)
	GridBattle.MoveAlly(masonBattle, 1, 2)
	GridBattle.ResolveSkill(masonBattle, 3, "Success") -- 축성
	expect(BattleStatus.Stack(masonAlly.Status, ClassResources.WALL) == 3, "consecrate must grant 3 wall stacks")
	expect(BattleStatus.Total(masonAlly.Status, "DamageTaken") < 0, "wall must reduce damage taken")

	-- 연금술사 다지기/섞기: 약재 → 원액 → 병.
	local alchBattle = GridBattle.New(1, "연금술사", 100, 10, "Alchemist")
	local alchAlly = GridBattle.Ally(alchBattle)
	expect(BattleStatus.Stack(alchAlly.Status, ClassResources.HERB) == 3, "the alchemist must start with 3 herbs")
	expect(
		BattleStatus.Stack(alchAlly.Status, ClassResources.EMPTY_BOTTLE) == 5,
		"the alchemist must start with 5 empty bottles"
	)
	GridBattle.MoveAlly(alchBattle, 1, 2)
	GridBattle.ResolveSkill(alchBattle, 1, "Success") -- 다지기: 약재를 무조건 최대치로 쓴다
	expect(BattleStatus.Stack(alchAlly.Status, ClassResources.HERB) == 0, "grind must spend every herb it can")
	expect(BattleStatus.Stack(alchAlly.Status, ClassResources.EXTRACT) == 3, "grind must convert herbs into extract")
	expect(BattleStatus.Total(alchAlly.Status, "DamageDealt") > 0, "grind must grant its damage buff")
	expect(BattleStatus.Total(alchAlly.Status, "DamageTaken") > 0, "grind must also carry its drawback")

	GridBattle.ResolveSkill(alchBattle, 2, "Success", function()
		return 0.1 -- 항상 첫 종류(독 병)가 나오게 고정한다
	end)
	expect(BattleStatus.Stack(alchAlly.Status, ClassResources.EXTRACT) == 0, "mix must spend every extract")
	expect(BattleStatus.Stack(alchAlly.Status, ClassResources.POISON_BOTTLE) == 3, "mix must produce filled bottles")

	-- 던지기: 병 하나를 써서 그 상태이상을 건다.
	local alchFoe = GridBattle.AliveEnemies(alchBattle)[1]
	local alchCell = GridBattle.CellOf(alchBattle, alchFoe.Id)
	if alchCell then
		GridBattle.MoveAlly(alchBattle, 1, alchCell.Y)
	end
	--[[
		강화 `중독`은 **3번 오른쪽(4번)에 따로 열린다**(요청). 3번은 평범한 던지기로
		남는다 — 예전에는 3번이 조건에 따라 중독으로 바뀌어 던지기를 쓸 수 없었다.
	]]
	expect(
		BattleSkillEffects.UpgradeFor("Alchemist", alchAlly.Status) == "Poisoning",
		"three bottles must open the poisoning upgrade"
	)
	expect(GridBattle.SkillList(alchBattle)[4].Id == "Poisoning", "the upgrade must sit right after the third slot")

	-- 중독: 병 3개를 전부 태우고 절반(1개)을 돌려받는다.
	GridBattle.ResolveSkill(alchBattle, 4, "Success", nil, "Poisoning")
	expect(BattleStatus.Stack(alchAlly.Status, ClassResources.POISON_BOTTLE) == 1, "poisoning must refund half")
	expect(alchAlly.Health < alchAlly.MaxHealth, "poisoning must cost the alchemist health")

	--[[
		병이 1개로 줄었으니 강화는 닫히고, 4번은 다시 공용 스킬(가드)이 된다.
		이래서 클라이언트가 번호와 함께 Id를 보내야 한다.
	]]
	expect(
		BattleSkillEffects.UpgradeFor("Alchemist", alchAlly.Status) == nil,
		"the upgrade must close once bottles run low"
	)
	expect(GridBattle.SkillList(alchBattle)[4].Id == "Guard", "slot 4 must fall back to guard")

	-- 평범한 던지기는 병 하나만 쓴다.
	-- 한 턴에 스킬을 여럿 쓰는 시험이라 스테미나를 채워 둔다(스테미나 규칙은 따로 시험한다)
	alchAlly.Stamina = alchAlly.MaxStamina
	local thrown, why = GridBattle.ResolveSkill(alchBattle, 3, "Success", nil, "Throw")
	expect(
		BattleStatus.Stack(alchAlly.Status, ClassResources.POISON_BOTTLE) == 0,
		"throw must spend one bottle (" .. tostring(thrown) .. " " .. tostring(why) .. ")"
	)

	-- 결투사 3번은 준비 자세다. 연계는 그다음 턴에 4번으로 열린다.
	local duelBattle = GridBattle.New(1, "결투사", 200, 10, "Duelist")
	local duelAlly = GridBattle.Ally(duelBattle)
	local duelSkills = BattleSkills.ForClass("Duelist")
	expect(duelSkills[3].Id == "DeepBreath", "the duelist's third slot must be the ready stance")
	expect(
		BattleSkillEffects.UpgradeFor("Duelist", duelAlly.Status) == nil,
		"the follow-up must not be available before the stance"
	)
	--[[
		준비 자세 전에는 4번이 **가드**여야 한다. 강화가 없을 때 공용 스킬이 그
		자리로 올라온다.
	]]
	expect(GridBattle.SkillList(duelBattle)[4].Id == "Guard", "guard must fill slot 4 when no upgrade is open")

	GridBattle.MoveAlly(duelBattle, 1, 2)
	GridBattle.ResolveSkill(duelBattle, 3, "Success") -- 준비 자세
	expect(BattleStatus.Stack(duelAlly.Status, ClassResources.FOCUS) >= 3, "the ready stance must grant 3 focus")
	expect(
		BattleSkillEffects.UpgradeFor("Duelist", duelAlly.Status) == "PointBlank",
		"the follow-up must open after the ready stance"
	)
	expect(GridBattle.SkillList(duelBattle)[4].Id == "PointBlank", "the follow-up must take slot 4 once open")

	--=== 가드 / 명상 (모든 직업 공용) ===--

	local commonBattle = GridBattle.New(1, "공용", 200, 10, "Berserker")
	local commonAlly = GridBattle.Ally(commonBattle)
	local commonList = GridBattle.SkillList(commonBattle)
	expect(commonList[#commonList - 1].Id == "Guard", "guard must always be available")
	expect(commonList[#commonList].Id == "Meditate", "meditate must always be available")

	-- 가드: 이번 턴 받는 피해 70% 감소.
	GridBattle.MoveAlly(commonBattle, 1, 2)
	GridBattle.ResolveSkill(commonBattle, #commonList - 1, "Success", nil, "Guard")
	expect(
		math.abs(BattleStatus.Total(commonAlly.Status, "DamageTaken") + 0.7) < 1e-9,
		"guard must cut damage taken by 70%"
	)
	-- "이번 턴"이므로 턴이 끝나면 사라진다.
	GridBattle.EndTurn(commonBattle)
	expect(BattleStatus.Total(commonAlly.Status, "DamageTaken") == 0, "guard must last only one turn")

	-- 명상: 받는 피해 25% 증가 + 스테미나 30 즉시 회복.
	commonAlly.Stamina = 10
	GridBattle.ResolveSkill(commonBattle, #commonList, "Success", nil, "Meditate")
	expect(commonAlly.Stamina == 40, "meditate must restore 30 stamina")
	expect(
		math.abs(BattleStatus.Total(commonAlly.Status, "DamageTaken") - 0.25) < 1e-9,
		"meditate must raise damage taken by 25%"
	)

	--=== 근거리 / 원거리 태그 ===--

	--[[
		모든 스킬에 사거리 태그가 있어야 한다. 새 스킬을 넣고 빠뜨리면 UI에 빈
		칸이 뜨고, 카드가 "원거리 스킬" 조건을 볼 수 없게 된다.
	]]
	for _, list in { BattleSkills.Enemy(), BattleSkills.Upgrades(), BattleSkills.Common() } do
		for _, skill in list do
			expect(
				skill.Range == "Melee" or skill.Range == "Ranged",
				"every skill needs a melee/ranged tag: " .. skill.Id
			)
		end
	end

	-- 퀘이사 붕괴는 첫 사용이 차징이고, 두 번째 사용에 발동한다.
	local quasarBattle = GridBattle.New(1, "퀘이사", 200, 10, "Quasar")
	local quasarAlly = GridBattle.Ally(quasarBattle)
	local quasarFoe = GridBattle.AliveEnemies(quasarBattle)[1]
	local quasarCell = GridBattle.CellOf(quasarBattle, quasarFoe.Id)
	if quasarCell then
		GridBattle.MoveAlly(quasarBattle, 1, quasarCell.Y)
	end
	local quasarFoeHealth = quasarFoe.Health
	GridBattle.ResolveSkill(quasarBattle, 1, "Success") -- 차징만
	expect(BattleStatus.Stack(quasarAlly.Status, ClassResources.CHARGE) == 1, "collapse must start charging")
	expect(quasarFoe.Health == quasarFoeHealth, "charging must not deal damage")
	GridBattle.ResolveSkill(quasarBattle, 1, "Success") -- 발동
	expect(BattleStatus.Stack(quasarAlly.Status, ClassResources.CHARGE) == 0, "releasing must clear the charge")

	-- 월 브레이커: 제 살 깎기는 항상 4번에 열려 있다(허물 벽을 마련하는 유일한 수단).
	local breakerBattle = GridBattle.New(1, "브레이커", 200, 10, "WallBreaker")
	local breakerAlly = GridBattle.Ally(breakerBattle)
	GridBattle.MoveAlly(breakerBattle, 1, 2)
	expect(GridBattle.SkillList(breakerBattle)[4].Id == "SelfCarve", "self-carve must always occupy slot 4")
	GridBattle.ResolveSkill(breakerBattle, 4, "Success")
	expect(BattleStatus.Stack(breakerAlly.Status, ClassResources.RUIN) == 3, "self-carve must grant 3 ruin stacks")
	expect(breakerAlly.Health < breakerAlly.MaxHealth, "self-carve must cost health")
	expect(BattleStatus.Total(breakerAlly.Status, "DamageDealt") > 0, "ruin must raise damage dealt")

	-- 월 필그림 광신: 적의 주는 피해가 줄고 받는 피해가 오른다.
	local pilgrimBattle = GridBattle.New(1, "필그림", 100, 10, "WallPilgrim")
	local pilgrimFoe = GridBattle.AliveEnemies(pilgrimBattle)[1]
	local pilgrimCell = GridBattle.CellOf(pilgrimBattle, pilgrimFoe.Id)
	if pilgrimCell then
		GridBattle.MoveAlly(pilgrimBattle, 1, pilgrimCell.Y)
	end
	GridBattle.ResolveSkill(pilgrimBattle, 1, "Success") -- 못질
	expect(BattleStatus.Stack(pilgrimFoe.Status, ClassResources.ZEAL) == 2, "nailing must apply 2 zeal")
	expect(BattleStatus.Total(pilgrimFoe.Status, "DamageDealt") < 0, "zeal must weaken the enemy's damage")
end

--[[
	추가&수정.md에서 새로 들어온 시스템들(육성·아이템·명예·사망·탑 보상·능력 카드·룬·기도)의
	수치가 사양대로인지 검사한다. 사양의 숫자를 그대로 박아 두었으므로,
	사양이 바뀌면 이 테스트부터 고쳐야 한다.
]]
function PrototypeTests.RunSystems()
	--=== 스탯 ===--
	local block = StatDefinitions.NewBlock()
	block.Main.Strength = 49
	block.Sub.Strength = 23
	expect(StatDefinitions.MainValue(block, "Strength") == 49, "stat requirement check must use main stat only")
	expect(StatDefinitions.TotalValue(block, "Strength") == 72, "total stat must be main + sub")
	expect(
		StatDefinitions.Format(block, "Strength") == "[힘: 49(+23) = 72]",
		"stat display must follow [main(+sub) = total]"
	)

	local derived = StatDefinitions.Derive(block)
	-- 힘 72점 → 물리 대미지 +360%, 체력 +72
	expect(math.abs(derived.PhysicalDamage - 3.6) < 1e-9, "strength must give 5% physical damage per point")
	expect(derived.MaxHealth == 72, "strength must give 1 max health per point")

	--=== 레벨 · 체력 · 스테미나 ===--
	expect(ProgressionDefinitions.MaxHealth(1) == 60, "level 1 base health must be 60")
	expect(ProgressionDefinitions.MaxHealth(6) == 70, "max health must grow 10 per 5 levels")
	expect(ProgressionDefinitions.MaxHealth(11) == 80, "max health must grow 10 per 5 levels")
	expect(ProgressionDefinitions.HealthRegen(60) == 3, "health regen must be 5% of max per turn")
	expect(ProgressionDefinitions.MaxStamina(1) == 60, "level 1 base stamina must be 60")
	expect(ProgressionDefinitions.StaminaRegen(nil) == 8, "stamina regen must be flat 8 per turn")
	expect(ProgressionDefinitions.StaminaRegen(0.5) == 12, "buff efficiency must raise stamina regen")
	-- 층마다 1레벨, 5층마다 2레벨 추가. 30층 완주 → 1 + 30 + 12 = 43
	expect(ProgressionDefinitions.LevelForFloors(5) == 8, "5 floors must give level 8")
	expect(ProgressionDefinitions.LevelForFloors(30) == 43, "30 floors must give level 43")
	expect(ProgressionDefinitions.LevelGainForFloor(5) == 3, "every 5th floor must give 3 levels")
	expect(ProgressionDefinitions.LevelGainForFloor(4) == 1, "normal floor must give 1 level")
	expect(ProgressionDefinitions.TotalStatPoints(43) == 126, "each level must give 3 stat points")

	--=== 아이템 등급 · 착용 제한 ===--
	expect(#ItemDefinitions.AllRarities() == 8, "there must be 8 item rarities")
	expect(ItemDefinitions.IsTowerObtainable("Epic"), "tower must drop up to epic")
	expect(not ItemDefinitions.IsTowerObtainable("Unique"), "unique and above must be field-only")
	expect(ItemDefinitions.IsCraftable("Supreme", false), "forge must craft up to supreme")
	expect(not ItemDefinitions.IsCraftable("Legendary", false), "legendary needs the material quest")
	expect(ItemDefinitions.IsCraftable("Legendary", true), "material quest must unlock legendary craft")
	expect(not ItemDefinitions.IsCraftable("Abyss", true), "abyss must never be craftable")
	expect(ItemDefinitions.ClampRequirement("Abyss", 250) == 100, "stat requirement must cap at 100")

	local greatsword = {
		Id = "TestGreatsword",
		Name = "시험용 대검",
		Rarity = "Rare" :: any,
		PrimaryStat = "Strength" :: any,
		StatRequirement = 40,
		BaseDamage = 100,
	}
	-- 메인 49 >= 40 이므로 제한 충족
	expect(ItemDefinitions.EffectiveDamage(greatsword, block) == 100, "meeting requirement must give full damage")

	-- 서브스탯으로는 제한을 뚫을 수 없어야 한다
	local subOnly = StatDefinitions.NewBlock()
	subOnly.Sub.Strength = 80
	expect(not ItemDefinitions.MeetsRequirement(greatsword, subOnly), "sub stats must not satisfy requirements")
	expect(ItemDefinitions.EffectiveDamage(greatsword, subOnly) == 50, "under requirement must halve damage")

	--=== 명예 · 거래 ===--
	expect(HonorDefinitions.DEFAULT_HONOR == 150, "default honor must be 150")
	expect(HonorDefinitions.Clamp(400) == 300, "honor must cap at 300")
	expect(HonorDefinitions.MaxTradableRarity(50) == "Common", "honor 50 trades commons only")
	expect(HonorDefinitions.MaxTradableRarity(150) == "Rare", "honor 150 trades up to rare")
	expect(HonorDefinitions.MaxTradableRarity(300) == "Abyss", "honor 300 trades everything")
	expect(HonorDefinitions.CanTrade(200, "Epic"), "honor 200 must allow epic")
	expect(not HonorDefinitions.CanTrade(200, "Unique"), "honor 200 must not allow unique")
	-- 나뭇가지 반복 거래로 명예를 올릴 수 없어야 한다
	expect(not HonorDefinitions.QualifiesForHonorGain(1, 1), "cheap repeat trades must not raise honor")
	expect(HonorDefinitions.QualifiesForHonorGain(120, 100), "giving equal or more must raise honor")

	--=== 사망 -> 차원 분기 ===--
	expect(AfterlifeDefinitions.ResolveRealm(120, 10) == "Heaven", "good deeds 100+ must go to heaven")
	expect(AfterlifeDefinitions.ResolveRealm(10, 120) == "Hell", "evil deeds 100+ must go to hell")
	expect(AfterlifeDefinitions.ResolveRealm(120, 120) == "AstralNexus", "both 100+ must go to astral nexus")
	expect(AfterlifeDefinitions.ResolveRealm(99, 99) == "SpiritWorld", "neither 100 must go to spirit world")

	--=== 탑 보상 · 리롤 ===--
	expect(TowerRewardDefinitions.COST_PER_FLOOR == 30, "each floor must give 30 cost")
	expect(TowerRewardDefinitions.RerollCost(0) == 10, "first reroll must cost 10")
	expect(TowerRewardDefinitions.RerollCost(1) == 15, "second reroll must cost 15")
	-- 22.5는 반올림해서 23으로 차감한다
	expect(math.abs(TowerRewardDefinitions.RawRerollCost(2) - 22.5) < 1e-9, "third reroll raw cost must be 22.5")
	expect(TowerRewardDefinitions.RerollCost(2) == 23, "third reroll must round to 23")
	expect(TowerRewardDefinitions.ResetRerollCount() == 0, "changing floors must reset reroll price")
	expect(TowerRewardDefinitions.PresetSlotPrice(2) == 0, "first 3 preset slots must be free")
	expect(TowerRewardDefinitions.PresetSlotPrice(3) == 100, "4th preset slot must cost 100 robux")

	--=== 능력 카드 ===--
	expect(AbilityCardDefinitions.MaxLevel("Essential") == 2, "essential cards cap at level 2")
	expect(AbilityCardDefinitions.MaxLevel("Rare") == 6, "rare cards cap at level 6")
	expect(AbilityCardDefinitions.MaxLevel("Common") == 6, "common cards cap at level 6")
	-- 카드별 최대 레벨(편집기 "최대 레벨" 칸): 없으면 등급표, 있으면 그 값을 따른다.
	expect(
		AbilityCardDefinitions.MaxLevelFor({ Grade = "Rare" } :: any) == 6,
		"a card without its own MaxLevel must fall back to the grade cap"
	)
	expect(
		AbilityCardDefinitions.MaxLevelFor({ Grade = "Rare", MaxLevel = 9 } :: any) == 9,
		"a card with its own MaxLevel must override the grade cap"
	)
	expect(AbilityCardDefinitions.Rules.Essential.PoolSizePerClass == 4, "4 essential cards per class")
	expect(AbilityCardDefinitions.Rules.Rare.PoolSizePerClass == 10, "10 rare cards per class")
	expect(AbilityCardDefinitions.Rules.Common.PoolSizePerClass == 20, "20 common cards per class")
	--[[
		필수 카드는 요청대로 **5 · 10 · 20 · 25층에서 한 번씩만** 나온다.
		15층과 30층은 빠져 있어서 주기 계산으로는 표현되지 않는다.
	]]
	for _, floor in { 5, 10, 20, 25 } do
		expect(AbilityCardDefinitions.IsEssentialFloor(floor), "essential cards must appear on floor " .. floor)
	end
	for _, floor in { 1, 4, 11, 15, 19, 30 } do
		expect(not AbilityCardDefinitions.IsEssentialFloor(floor), "essential cards must not appear on floor " .. floor)
	end
	expect(AbilityCardDefinitions.AcquireSlotsForFloor(1) == 1, "one card per floor at the start")

	--=== 직업 카드 데이터 ===--
	local AbilityCards = require(ReplicatedStorage.Shared.AbilityCards)
	local registeredClasses = AbilityCards.Register()
	expect(registeredClasses >= 2, "at least the two reference classes must be registered")

	-- 등록한 모든 직업이 사양의 종류 수를 지켜야 한다.
	local seenCardIds: { [string]: boolean } = {}
	for _, module in AbilityCards.Modules do
		local classId = module.ClassId
		expect(#module.Cards == 34, classId .. " must define 34 cards (4 + 10 + 20)")
		expect(#AbilityCardDefinitions.GetPool(classId, "Essential") == 4, classId .. " needs 4 essential cards")
		expect(#AbilityCardDefinitions.GetPool(classId, "Rare") == 10, classId .. " needs 10 rare cards")
		expect(#AbilityCardDefinitions.GetPool(classId, "Common") == 20, classId .. " needs 20 common cards")

		for _, card in module.Cards do
			-- Id는 직업을 넘어 전역으로 유일해야 한다. 뽑기·업그레이드가 Id로 추적하기 때문이다.
			expect(not seenCardIds[card.Id], "card ids must be globally unique: " .. card.Id)
			seenCardIds[card.Id] = true
			expect(card.ClassId == classId, "card ClassId must match its module: " .. card.Id)
			expect(card.Name ~= "" and card.Description ~= "", "card text must not be empty: " .. card.Id)
			expect(#card.Tags > 0, "every card needs at least one deck-building tag: " .. card.Id)
		end
	end

	-- 카드 데이터가 있는 직업은 실제 로스터에 있어야 한다.
	local hasCards: { [string]: boolean } = {}
	for _, classId in AbilityCards.RegisteredClassIds() do
		expect(CharacterDefinitions.IsValid(classId), "card data references an unknown class: " .. classId)
		hasCards[classId] = true
	end

	-- 반대 방향도 본다. 로스터의 모든 직업이 카드를 가져야 한다.
	-- 직업을 새로 추가하고 카드를 빠뜨리면 여기서 걸린다.
	for _, character in CharacterDefinitions.All() do
		expect(hasCards[character.Id], "class has no ability cards: " .. character.Id)
	end

	--[[
		사양이 버퍼 직업(음악가)에 요구한 요구한 분기를 검사한다.
		  "필수 카드 중 대미지 카드 조합 → 딜러 / 서포팅 조합 → 서포터 / 하이브리드 조합 → 둘 다"
		이것이 성립하려면 필수 4장이 딜러축과 서포터축으로 갈려 있어야 한다.
		여기서는 태그로 그 갈림을 확인한다. Solo = 딜러축, Chorus = 서포터축.
	]]
	local damageLeaning, supportLeaning = 0, 0
	for _, card in AbilityCardDefinitions.GetPool("Musician", "Essential") do
		local isDamage, isSupport = false, false
		for _, tag in card.Tags do
			if tag == "Solo" then
				isDamage = true
			elseif tag == "Chorus" then
				isSupport = true
			end
		end
		if isDamage then
			damageLeaning += 1
		end
		if isSupport then
			supportLeaning += 1
		end
	end
	expect(damageLeaning >= 2, "musician needs at least 2 damage-leaning essential cards (spec example)")
	expect(supportLeaning >= 2, "musician needs at least 2 support-leaning essential cards (spec example)")

	-- 서로 다른 직업의 카드가 섞여 나오면 안 된다.
	for _, card in AbilityCardDefinitions.DrawForFloor("Musician", 10, 99) do
		expect(card.ClassId == "Musician", "draws must only return the requested class's cards")
	end

	-- 일반 층: 희귀 2 + 일반 4 = 6종.
	local floor7 = AbilityCardDefinitions.DrawForFloor("Berserker", 7, 1234)
	expect(#floor7 == 6, "a normal floor must offer 2 rare + 4 common")
	for _, card in floor7 do
		expect(card.Grade ~= "Essential", "a normal floor must never show essential cards")
	end

	--[[
		필수 층은 **두 화면**이다
		(요청: "필수 카드 먼저 나오고 일반 희귀 카드가 나오도록").

		  아직 안 골랐을 때(0) → 필수 3종
		  한 장 고른 뒤(1)     → 희귀 2 + 일반 4

		예전에는 셋이 한 줄에 섞여 9장이 깔렸다.
	]]
	for _, essentialFloor in { 5, 10, 20, 25 } do
		local firstScreen = AbilityCardDefinitions.DrawForFloor("Berserker", essentialFloor, 1234, nil, 0)
		expect(#firstScreen == 3, "an essential floor must open with exactly 3 cards")
		for _, card in firstScreen do
			expect(card.Grade == "Essential", "the first essential-floor screen must be essential only")
		end

		local secondScreen = AbilityCardDefinitions.DrawForFloor("Berserker", essentialFloor, 1234, nil, 1)
		expect(#secondScreen == 6, "the second essential-floor screen must offer 2 rare + 4 common")
		for _, card in secondScreen do
			expect(card.Grade ~= "Essential", "the second screen must not repeat essential cards")
		end
	end

	--[[
		5의 배수지만 필수 층이 아닌 15·30층은 처음부터 희귀·일반이다.
		두 장을 고를 수 있다는 것과 필수가 나온다는 것은 별개다.
	]]
	for _, plainFive in { 15, 30 } do
		local drawn = AbilityCardDefinitions.DrawForFloor("Berserker", plainFive, 1234, nil, 0)
		expect(#drawn == 6, "floors 15 and 30 give two picks but no essential screen")
	end

	-- 최대 레벨에 도달한 카드는 후보에서 빠져야 한다.
	local maxed: { [string]: boolean } = {}
	for _, card in AbilityCardDefinitions.GetPool("Berserker", "Rare") do
		maxed[card.Id] = true
	end
	local noRare = AbilityCardDefinitions.DrawForFloor("Berserker", 7, 1234, maxed)
	expect(#noRare == 4, "maxed cards must be excluded from the draw")

	--=== 층별 보상 흐름 (뽑기 → 리롤 → 업그레이드 → 마무리) ===--
	local CardDraft = require(ReplicatedStorage.Shared.CardDraft)

	local runProfile = PlayerProfile.New()
	runProfile.TowerRun = PlayerProfile.NewTowerRun()
	runProfile.TowerRun.Active = true
	local run = runProfile.TowerRun :: any

	-- 1층 클리어: 코스트 30, 리롤 초기화, 카드 6종
	local first = CardDraft.BeginFloor(run, "Berserker", 1, 42)
	expect(first.Ok, "beginning a floor must succeed")
	expect(run.Cost == 30, "clearing a floor must grant 30 cost")
	expect(#first.Cards == 6, "a normal floor offers 2 rare + 4 common")
	expect(first.NextRerollCost == 10, "the first reroll must cost 10")
	expect(run.PendingLevel == 1, "a normal floor must bank 1 level")

	-- 리롤 두 번: 10 차감 → 15 차감. 남은 코스트 5.
	local r1 = CardDraft.Reroll(run, "Berserker", 42)
	expect(r1.Ok and run.Cost == 20, "first reroll must charge 10")
	expect(r1.NextRerollCost == 15, "second reroll must cost 15")
	local r2 = CardDraft.Reroll(run, "Berserker", 42)
	expect(r2.Ok and run.Cost == 5, "second reroll must charge 15")
	expect(r2.NextRerollCost == 23, "third reroll must cost 23 (22.5 rounded)")

	-- 코스트가 모자라면 실패하고 상태가 그대로여야 한다.
	local costBefore, rerollBefore = run.Cost, run.RerollCount
	local r3 = CardDraft.Reroll(run, "Berserker", 42)
	expect(not r3.Ok, "a reroll must fail when cost is short")
	expect(run.Cost == costBefore, "a failed reroll must not spend cost")
	expect(run.RerollCount == rerollBefore, "a failed reroll must not advance the price")

	-- 획득: 1층에는 1장만 얻을 수 있다
	local pick = first.Cards[1]
	local upOk = CardDraft.Acquire(run, pick, 0)
	expect(upOk, "the first acquisition of a floor must succeed")
	expect(CardDraft.CardLevel(run, pick.Id) == 1, "a newly acquired card must be level 1")
	local upBlocked = CardDraft.Acquire(run, pick, 1)
	expect(not upBlocked, "floor 1 only grants one card")

	-- 사양 핵심: **같은 카드를 다시 얻으면 강화된다** (별도 업그레이드 행동이 없다)
	expect(CardDraft.Acquire(run, pick, 0), "acquiring a duplicate must be allowed")
	expect(CardDraft.CardLevel(run, pick.Id) == 2, "a duplicate acquisition must level the card up")

	-- 층을 넘기면 리롤 가격이 초기화된다 (사양)
	local second = CardDraft.BeginFloor(run, "Berserker", 2, 43)
	expect(run.RerollCount == 0, "changing floors must reset the reroll price")
	expect(second.NextRerollCost == 10, "reroll price must be back to 10")
	expect(run.Cost == costBefore + 30, "the new floor must add another 30 cost")

	-- 5층은 3레벨을 준다 (1 + 2)
	local before5 = run.PendingLevel
	CardDraft.BeginFloor(run, "Berserker", 5, 44)
	expect(run.PendingLevel == before5 + 3, "every 5th floor must bank 3 levels")
	--[[
		요청: "5층 단위로 1개씩 늘어나는 게 아니라, 5층마다 2개씩 선택."
		→ 5의 배수 층에서만 2장이고, 그 밖에는 계속 1장이다.
	]]
	expect(AbilityCardDefinitions.AcquireSlotsForFloor(5) == 2, "floor 5 must grant 2 card acquisitions")
	expect(AbilityCardDefinitions.AcquireSlotsForFloor(1) == 1, "floor 1 grants a single card")
	expect(AbilityCardDefinitions.AcquireSlotsForFloor(10) == 2, "every fifth floor grants exactly 2")
	expect(AbilityCardDefinitions.AcquireSlotsForFloor(25) == 2, "picks must not keep growing with depth")
	expect(AbilityCardDefinitions.AcquireSlotsForFloor(24) == 1, "non-multiples of five grant a single card")

	-- 필수 카드는 레벨 2가 상한. 획득이 곧 강화이므로 세 번째 획득은 막혀야 한다.
	local essential = AbilityCardDefinitions.GetPool("Berserker", "Essential")[1]
	expect(CardDraft.Acquire(run, essential, 0), "essential card acquisition 1 must work")
	expect(CardDraft.Acquire(run, essential, 0), "essential card acquisition 2 must work (levels to 2)")
	expect(CardDraft.CardLevel(run, essential.Id) == 2, "two acquisitions must put an essential at level 2")
	local overCap = CardDraft.Acquire(run, essential, 0)
	expect(not overCap, "essential cards must cap at level 2")
	expect(CardDraft.MaxedCardIds(run)[essential.Id] == true, "a capped card must be marked maxed")

	-- 최대 레벨 카드는 이후 뽑기에서 빠진다
	for _, card in AbilityCardDefinitions.DrawForFloor("Berserker", 10, 7, CardDraft.MaxedCardIds(run)) do
		expect(card.Id ~= essential.Id, "maxed cards must not be offered again")
	end

	-- 도중 이탈: 장비는 돌려주되 레벨은 확정되지 않는다
	local bailProfile = PlayerProfile.New()
	bailProfile.TowerRun = PlayerProfile.NewTowerRun()
	bailProfile.TowerRun.Active = true
	(bailProfile.TowerRun :: any).PendingLevel = 9
	(bailProfile.TowerRun :: any).Floor = 12
	table.insert((bailProfile.TowerRun :: any).StoredItems, { Id = "x", Name = "보관 장비" })
	local levelBefore = PlayerProfile.ActiveSlot(bailProfile).Level
	local returned, gained = CardDraft.FinishRun(bailProfile, false)
	expect(returned == 1, "stored gear must always come back")
	expect(gained == 0, "leaving early must not bank levels")
	expect(PlayerProfile.ActiveSlot(bailProfile).Level == levelBefore, "level must not change on an early exit")
	expect(bailProfile.Account.HighestFloor == 12, "highest floor must still be recorded")
	expect(bailProfile.TowerRun == nil, "finishing must clear the run")

	-- 완주: 레벨과 스탯 포인트가 확정된다
	local doneProfile = PlayerProfile.New()
	doneProfile.TowerRun = PlayerProfile.NewTowerRun()
	doneProfile.TowerRun.Active = true
	(doneProfile.TowerRun :: any).PendingLevel = 9
	(doneProfile.TowerRun :: any).Floor = 30
	local _, gainedDone = CardDraft.FinishRun(doneProfile, true)
	expect(gainedDone == 9, "completing the tower must bank the pending levels")
	expect(PlayerProfile.ActiveSlot(doneProfile).Level == 10, "levels must apply on completion")
	expect(PlayerProfile.ActiveSlot(doneProfile).UnspentPoints == 27, "each level must grant 3 stat points")

	--=== 전투: 6×3 배치 격자 ===--
	local BattleGrid = require(ReplicatedStorage.Shared.BattleGrid)
	local BattleSkills = require(ReplicatedStorage.Shared.BattleSkills)

	local grid = BattleGrid.New()
	expect(grid.Width == 6 and grid.Height == 3, "the battle grid must be 6 wide and 3 tall")

	-- 진영이 다르면 같은 좌표라도 다른 칸이다.
	expect(BattleGrid.Place(grid, "ally1", "Ally", 3, 2), "placing on an empty cell must work")
	expect(BattleGrid.Place(grid, "foe1", "Enemy", 3, 2), "the same coords on the other side is a different cell")
	expect(BattleGrid.Occupant(grid, "Ally", 3, 2) == "ally1", "the cell must report its occupant")

	-- 한 칸에 둘은 못 선다.
	local cellTaken = BattleGrid.Place(grid, "ally2", "Ally", 3, 2)
	expect(not cellTaken, "two units must not share a cell")

	-- 격자 밖은 거부한다.
	expect(not BattleGrid.Place(grid, "ally2", "Ally", 7, 1), "x must stay within 1..6")
	expect(not BattleGrid.Place(grid, "ally2", "Ally", 1, 4), "y must stay within 1..3")

	-- 보스 기믹으로 칸을 막을 수 있어야 한다 (사양: "칸을 제한하는 기믹")
	BattleGrid.SetEnabled(grid, "Ally", 1, 1, false)
	expect(not BattleGrid.IsEnabled(grid, "Ally", 1, 1), "a disabled cell must report as disabled")
	expect(not BattleGrid.Place(grid, "ally2", "Ally", 1, 1), "units must not enter a disabled cell")
	BattleGrid.SetEnabled(grid, "Ally", 1, 1, true)
	expect(BattleGrid.Place(grid, "ally2", "Ally", 1, 1), "re-enabling a cell must allow placement")

	-- 이동하면 원래 칸이 비어야 한다.
	expect(BattleGrid.Move(grid, "ally1", 5, 3), "moving within your own side must work")
	expect(BattleGrid.Occupant(grid, "Ally", 3, 2) == nil, "the old cell must be freed on move")
	expect(BattleGrid.Occupant(grid, "Ally", 5, 3) == "ally1", "the new cell must hold the unit")

	-- 스킬 범위: 미리보기와 실제 타격이 같은 함수를 쓴다
	local row = BattleGrid.CellsInShape(grid, "Enemy", 3, 2, { Kind = "Row" })
	expect(#row == 6, "a row shape must cover the full width")
	local column = BattleGrid.CellsInShape(grid, "Enemy", 3, 2, { Kind = "Column" })
	expect(#column == 3, "a column shape must cover the full height")
	local all = BattleGrid.CellsInShape(grid, "Enemy", 1, 1, { Kind = "All" })
	expect(#all == 18, "an all shape must cover 6x3 = 18 cells")
	local single = BattleGrid.CellsInShape(grid, "Enemy", 3, 2, { Kind = "Single" })
	expect(#single == 1, "a single shape must cover one cell")

	-- 막힌 칸은 미리보기에서도 빠져야 한다 (붉게 칠하면 안 된다)
	BattleGrid.SetEnabled(grid, "Enemy", 1, 2, false)
	local rowMasked = BattleGrid.CellsInShape(grid, "Enemy", 3, 2, { Kind = "Row" })
	expect(#rowMasked == 5, "disabled cells must be excluded from skill range")

	-- 범위 안에 실제로 선 유닛만 대미지 대상이 된다
	local hitUnits = BattleGrid.UnitsInShape(grid, "Enemy", 3, 2, { Kind = "Row" })
	expect(#hitUnits == 1 and hitUnits[1] == "foe1", "only occupied cells produce targets")

	--[[
		조건부로 늘어나는 범위, 단계별 색깔 지정 (요청: "그 색깔에 따라서
		단계별 범위지정"). 각 단계는 그 단계에서 새로 켜지는 칸만 적고,
		이전 단계 칸과 합쳐 누적으로 켜진다.

		`do...end`로 가둔다 — 이 함수 하나가 이미 로컬 변수 200개 한도에
		바짝 붙어 있어서(빌드가 "Out of local registers"로 실제로 터졌다),
		여기서 쓰는 변수들이 함수 끝까지 슬롯을 붙들지 않게 한다.
	]]
	do
		local growShape: BattleGrid.Shape = {
			Kind = "Cross",
			Cells = { { X = 3, Y = 0 }, { X = 3, Y = 1 }, { X = 3, Y = -1 } },
			Stages = {
				{ { X = 4, Y = 0 }, { X = 3, Y = 2 }, { X = 3, Y = -2 } },
				{ { X = 5, Y = 0 }, { X = 3, Y = 3 }, { X = 3, Y = -3 } },
			},
		}
		-- 실제 격자(3칸 높이)는 세로로 자랄 자리가 모자라니, 여유 있는 격자로 단계를 다 확인한다.
		local growGrid = BattleGrid.New(6, 7)
		local ungrown = BattleGrid.CellsInShape(growGrid, "Enemy", 1, 4, growShape, 0)
		expect(#ungrown == 3, "with no growth, only the base cells count")
		local oneStage = BattleGrid.CellsInShape(growGrid, "Enemy", 1, 4, growShape, 1)
		expect(#oneStage == 6, "growCount 1 must add exactly stage 1's cells on top of the base")
		local bothStages = BattleGrid.CellsInShape(growGrid, "Enemy", 1, 4, growShape, 2)
		expect(#bothStages == 9, "growCount 2 must add both stages, cumulatively")
		local capped = BattleGrid.CellsInShape(growGrid, "Enemy", 1, 4, growShape, 99)
		expect(#capped == 9, "growCount beyond the number of stages must not error or add more cells")
		local hasForward = false
		for _, cell in bothStages do
			if cell.X == 6 and cell.Y == 4 then
				hasForward = true
			end
		end
		expect(hasForward, "each stage's cells are relative to the origin, same as the base Cells")

		-- 진짜 3칸 격자에서는 위·아래가 곧바로 벽에 막혀 앞으로만 자란다.
		local clipped = BattleGrid.CellsInShape(grid, "Enemy", 1, 2, growShape, 2)
		expect(#clipped == 5, "on the real 3-row grid, up/down growth is clipped by the board edge")

		-- 자원을 나눠서 세는 규칙(예: 16분음표 3개당 1칸)도 여기서 정한다
		local growSkill: BattleSkills.Skill = {
			Id = "TestGrow",
			Name = "test",
			Damage = 0,
			Range = "Ranged",
			Shape = growShape,
			GrowResource = "Sixteenth",
			GrowDivisor = 3,
		}
		expect(BattleSkills.GrowCount(growSkill, 0) == 0, "no stacks means no growth")
		expect(BattleSkills.GrowCount(growSkill, 5) == 1, "5 stacks at a divisor of 3 must floor to 1 step")
		expect(BattleSkills.GrowCount(growSkill, 6) == 2, "6 stacks at a divisor of 3 must give exactly 2 steps")

		--[[
			아군 진형에 스킬 사용 (요청: "격자에서 찍기에 '아군 진형에 스킬
			사용' 누르면 아군 진형에 범위 지정"). 기준점이 상대가 아니라
			캐스터 자신이어야 하고, 맞는 진영도 자기 진영이어야 한다.
		]]
		local allyShape: BattleGrid.Shape = {
			Kind = "Single",
			Cells = { { X = 0, Y = 0 } },
			TargetSide = "Ally",
		}
		local supportGrid = BattleGrid.New()
		expect(BattleGrid.Place(supportGrid, "caster", "Ally", 2, 2), "place the caster on their own side")
		expect(BattleGrid.Place(supportGrid, "buddy", "Ally", 2, 2) == false, "sanity: cell already taken")
		BattleGrid.Move(supportGrid, "caster", 2, 2)
		expect(BattleGrid.Place(supportGrid, "buddy", "Ally", 4, 1), "place an ally elsewhere on the same side")
		local allyCells = BattleSkills.Cells(supportGrid, "Ally", 2, allyShape, 0, 2)
		expect(
			#allyCells == 1 and allyCells[1].Side == "Ally" and allyCells[1].X == 2 and allyCells[1].Y == 2,
			"an Ally-targeted shape must anchor on the caster's own cell, on the caster's own side"
		)
		local allyTargets = BattleSkills.Targets(supportGrid, "Ally", 2, allyShape, 0, 2)
		expect(
			#allyTargets == 1 and allyTargets[1] == "caster",
			"an Ally-targeted skill must be able to hit the caster's own side, including itself"
		)
	end

	--[[
		모션 단계 (요청: "모션상 단계... 결투사의 앞뒤관통의 경우에 써야됨").
		`Shape`가 첫 모션이고 `Motions`가 그 뒤를 잇는다 — `AllShapes`가 순서대로
		하나의 목록으로 돌려줘야 한다.
	]]
	do
		local motionSkill: BattleSkills.Skill = {
			Id = "TestMotion",
			Name = "test",
			Damage = 9,
			Range = "Melee",
			Shape = { Kind = "Single", Cells = { { X = 2, Y = 0 } } },
			Motions = {
				{ Kind = "Single", Cells = { { X = -3, Y = 0 } } },
			},
		}
		local allShapes = BattleSkills.AllShapes(motionSkill)
		expect(#allShapes == 2, "AllShapes must return the primary Shape plus every Motion, in order")
		expect(allShapes[1] == motionSkill.Shape, "the first shape must be the primary Shape")
		expect(allShapes[2] == motionSkill.Motions[1], "the second shape must be the first Motion")

		local noMotionSkill: BattleSkills.Skill = {
			Id = "TestNoMotion",
			Name = "test",
			Damage = 5,
			Range = "Melee",
			Shape = { Kind = "Single" },
		}
		expect(#BattleSkills.AllShapes(noMotionSkill) == 1, "a skill with no Motions must yield just its own Shape")
	end

	--[[
		앞뒤관통 실제 데이터 (사양: "피해량: 9 × 2(합 18)"). 실수로 바뀌면 여기서
		바로 걸리게, 지어낸 스킬이 아니라 진짜 스킬 정의를 직접 읽어 대조한다.
		좌표는 md를 문자 그대로 옮기지 않고, 예전부터 맞던 범위(적이 선 칸과
		그다음 칸)를 두 모션으로 나눈 것이다 — 자세한 이유는 정의 옆 주석 참고.
	]]
	do
		local frontBackPierce = BattleSkills.ById("FrontBackPierce")
		expect(frontBackPierce ~= nil, "FrontBackPierce must exist")
		if frontBackPierce then
			expect(frontBackPierce.Damage == 9, "each motion of FrontBackPierce deals 9, for a total of 9x2=18")
			local shapes = BattleSkills.AllShapes(frontBackPierce)
			expect(#shapes == 2, "FrontBackPierce must have exactly two motions: forward, then backward")
			local forward, backward = shapes[1], shapes[2]
			--[[
				2026-09-28 편집기 수정본(카드들.json)으로 범위가 바뀌었다: 앞 모션 (0..2,0), 뒤 모션 (−6..0,0).
				좌표는 그 수정본이 기준이다. 여기서는 **겨냥한 칸(0,0)을 두 모션 모두 치는지**만 본다 —
				그래야 전열에 홀로 선 적을 빗맞히지 않는다.
			]]
			local function hasOrigin(shape: any): boolean
				for _, cell in shape.Cells or {} do
					if cell.X == 0 and cell.Y == 0 then
						return true
					end
				end
				return false
			end
			expect(hasOrigin(forward), "the first motion must strike the aimed cell, so a lone front enemy is never missed")
			expect(hasOrigin(backward), "the second motion must also cover the aimed cell")
		end
	end

	--[[
		쿨타임 (요청: "직업 능력 탭에서 액티브 스킬 쿨타임 쓰는 칸이 없어").
		쓰면 채워지고, 채워진 동안은 다시 못 쓰고, 턴이 지날 때마다 하나씩 줄어든다.

		실제 스킬 중 아직 `Cooldown`이 채워진 게 없어서(값을 채우는 건 이번
		요청이 아니라 기능만 만드는 것), 진짜 스킬(`Veloce`)의 값을 시험이 끝난
		뒤 되돌리는 조건으로 잠깐 빌려 쓴다.
	]]
	do
		local skill = BattleSkills.ById("Veloce")
		expect(skill ~= nil, "Veloce must exist")
		if skill then
			local originalCooldown = skill.Cooldown
			skill.Cooldown = 2
			local cdBattle = GridBattle.New(1, "테스터", 100, 10, "Musician")
			local cdAlly = GridBattle.Ally(cdBattle)
			expect(cdAlly.Cooldowns["Veloce"] == nil, "a fresh unit must start with no cooldown recorded")

			local ok1 = GridBattle.ResolveSkill(cdBattle, 1, "Success")
			expect(ok1, "the first use must succeed with no prior cooldown")
			expect(cdAlly.Cooldowns["Veloce"] == 2, "using the skill must fill its cooldown")

			local ok2, err2 = GridBattle.ResolveSkill(cdBattle, 1, "Success")
			expect(not ok2, "using it again immediately must be refused")
			expect(err2 ~= nil and err2:find("재사용") ~= nil, "the refusal must explain why")

			GridBattle.EndTurn(cdBattle)
			expect(cdAlly.Cooldowns["Veloce"] == 1, "ending a turn must count the cooldown down by one")
			local ok3 = GridBattle.ResolveSkill(cdBattle, 1, "Success")
			expect(not ok3, "one turn is not enough yet with a 2-turn cooldown")

			GridBattle.EndTurn(cdBattle)
			expect(cdAlly.Cooldowns["Veloce"] == 0, "a second turn must bring it to zero")
			local ok4 = GridBattle.ResolveSkill(cdBattle, 1, "Success")
			expect(ok4, "once cooldown reaches zero the skill must be usable again")

			skill.Cooldown = originalCooldown
		end
	end

	-- 멀티 배치 충돌: 3인 이상은 투표, 듀오는 가위바위보 (사양)
	expect(BattleGrid.ConflictResolution(4) == "Vote", "a full team resolves conflicts by vote")
	expect(BattleGrid.ConflictResolution(3) == "Vote", "three players can still vote")
	expect(BattleGrid.ConflictResolution(2) == "RockPaperScissors", "a duo cannot vote, so RPS")

	local conflicts = BattleGrid.FindConflicts({
		{ UnitId = "p1", Side = "Ally", X = 2, Y = 2 },
		{ UnitId = "p2", Side = "Ally", X = 2, Y = 2 },
		{ UnitId = "p3", Side = "Ally", X = 4, Y = 1 },
	})
	local conflictCells = 0
	for _, contenders in conflicts do
		conflictCells += 1
		expect(#contenders == 2, "the contested cell must list both claimants")
	end
	expect(conflictCells == 1, "only the contested cell counts as a conflict")

	--=== 전투: QTE ===--
	local QteDefinitions = require(ReplicatedStorage.Shared.QteDefinitions)

	-- 사양의 배율. 스킬 실패는 1/2, 회피는 성공 0 / 방어 1/2 / 실패 그대로.
	expect(QteDefinitions.Multiplier("Skill", "Fail") == 0.5, "a failed skill QTE must halve damage")
	expect(QteDefinitions.Multiplier("Skill", "Success") == 1.2, "a perfect skill QTE must boost damage")
	expect(QteDefinitions.Multiplier("Dodge", "Success") == 0, "a successful dodge/parry must negate damage")
	expect(QteDefinitions.Multiplier("Dodge", "Partial") == 0.5, "guarding must halve incoming damage")
	expect(QteDefinitions.Multiplier("Dodge", "Fail") == 1, "a failed dodge must take full damage")

	-- 고정 시드로 만들면 결정적이어야 한다 (서버 판정과 리플레이가 어긋나면 안 된다)
	local function seededRng(seed: number): () -> number
		local random = Random.new(seed)
		return function()
			return random:NextNumber()
		end
	end

	local skillQte = QteDefinitions.Create("Skill", seededRng(1), 0, "q1", true)
	expect(skillQte.Role == "Skill", "a skill QTE must carry the skill role")
	-- 2026-09-29 스튜디오에서 QTE 를 어렵게 조정(5초 → 3.5초, 링·스윕 빠르게, 명령 8개)했다. 시험도 그 값을 따른다
	expect(skillQte.DurationMs == 3500, "QTE duration must match QteDefinitions (3.5s)")

	local dodgeQte = QteDefinitions.Create("Dodge", seededRng(2), 0, "q2", true)
	expect(dodgeQte.Role == "Dodge", "a dodge QTE must carry the dodge role")
	expect(dodgeQte.Type == "Parry" or dodgeQte.Type == "Directional", "dodge QTEs come from the dodge registry")

	-- 시각 상태와 판정이 같은 수식을 쓰는지 (미리보기와 결과가 어긋나면 안 된다)
	local state0 = QteDefinitions.VisualState(skillQte, 0)
	expect(state0.progress == 0, "progress starts at 0")
	local stateEnd = QteDefinitions.VisualState(skillQte, skillQte.DurationMs)
	expect(stateEnd.progress == 1, "progress reaches 1 at the deadline")

	-- Mash 판정: 목표치 근처만 성공
	local mash = QteDefinitions.Create("Skill", seededRng(3), 0, "q3", true)
	mash.Type = "Mash"
	mash.Goal = 8
	mash.InputCount = 8
	expect(QteDefinitions.Judge(mash, 100) == "Success", "hitting the mash goal exactly must succeed")
	mash.InputCount = 6
	expect(QteDefinitions.Judge(mash, 100) == "Partial", "being slightly off must be partial")
	mash.InputCount = 1
	expect(QteDefinitions.Judge(mash, 100) == "Fail", "being far off must fail")

	-- Sweep 최종 등급은 실수 횟수로 정해진다
	expect(QteDefinitions.SweepFinalGrade(0) == "Success", "a clean sweep is a success")
	expect(QteDefinitions.SweepFinalGrade(1) == "Partial", "one miss is partial")
	expect(QteDefinitions.SweepFinalGrade(2) == "Fail", "two misses fail")

	-- 방향 QTE: 끝까지 입력하지 못하면 실패
	local directional = QteDefinitions.Create("Dodge", seededRng(4), 0, "q4", true)
	directional.Type = "Directional"
	directional.ExpectedDirections = { "Up", "Down", "Left" }
	directional.SequenceIndex = 2
	directional.Mistakes = 0
	expect(QteDefinitions.Judge(directional, 100) == "Fail", "an unfinished sequence must fail")
	directional.SequenceIndex = 3
	expect(QteDefinitions.Judge(directional, 100) == "Success", "a flawless full sequence must succeed")
	-- 명령이 8개로 늘며 실수 1번은 봐준다(COMMAND_DODGE_MISTAKES), 2번은 막기(Partial), 3번부터 실패
	directional.Mistakes = QteDefinitions.COMMAND_DODGE_MISTAKES
	expect(QteDefinitions.Judge(directional, 100) == "Success", "forgiven mistakes must still succeed")
	directional.Mistakes = QteDefinitions.COMMAND_DODGE_MISTAKES + 1
	expect(QteDefinitions.Judge(directional, 100) == "Partial", "one more mistake must downgrade to guard")
	directional.Mistakes = QteDefinitions.COMMAND_GUARD_MISTAKES + 1
	expect(QteDefinitions.Judge(directional, 100) == "Fail", "too many mistakes must fail")

	-- 입력 유효성
	expect(QteDefinitions.IsValidInput("Directional", "Up"), "directional QTEs accept directions")
	expect(not QteDefinitions.IsValidInput("Directional", "Tap"), "directional QTEs reject taps")
	expect(QteDefinitions.IsValidInput("Forge", "Tap"), "ring QTEs accept taps")

	--=== 전투: 그로기 게이지 ===--
	local GroggyGauge = require(ReplicatedStorage.Shared.GroggyGauge)

	expect(GroggyGauge.MAX == 100, "the groggy gauge must cap at 100")
	expect(GroggyGauge.Gain.Parry == 15, "a parry must add 15 groggy (spec)")

	local groggy = GroggyGauge.New()
	expect(not GroggyGauge.IsStunned(groggy), "a fresh gauge is not stunned")

	-- 패리 6회 = 90, 아직 스턴 아님
	for _ = 1, 6 do
		GroggyGauge.AddFrom(groggy, "Parry")
	end
	expect(groggy.Value == 90, "six parries must total 90")
	expect(not GroggyGauge.IsStunned(groggy), "90 is below the stun threshold")

	-- 7회째에 100에 닿아 스턴
	local becameStunned = GroggyGauge.AddFrom(groggy, "Parry")
	expect(becameStunned, "reaching 100 must trigger the stun")
	expect(GroggyGauge.IsStunned(groggy), "the unit must now be stunned")
	expect(groggy.Value == 100, "the gauge must clamp at 100")

	-- 스턴 중에는 더 쌓이지 않는다 (연속 스턴 방지)
	local again = GroggyGauge.AddFrom(groggy, "Parry")
	expect(not again, "a stunned unit must not accumulate more groggy")

	-- 한 턴 쉬고 나면 풀리고 게이지가 비워진다
	local skipped = GroggyGauge.TickTurn(groggy)
	expect(skipped, "the stunned turn must be skipped")
	expect(not GroggyGauge.IsStunned(groggy), "the stun must last exactly one turn")
	expect(groggy.Value == 0, "the gauge must reset after the stun ends")
	expect(not GroggyGauge.TickTurn(groggy), "a recovered unit acts normally")

	-- QTE와 그로기의 연결: 패리 성공만 그로기를 준다
	local parryQte = QteDefinitions.Create("Dodge", seededRng(5), 0, "q5", true)
	parryQte.Type = "Parry"
	expect(QteDefinitions.GroggyGain(parryQte, "Success") == 15, "a successful parry must feed 15 groggy")
	expect(QteDefinitions.GroggyGain(parryQte, "Partial") == 0, "a guard must not feed groggy")
	expect(QteDefinitions.GroggyGain(parryQte, "Fail") == 0, "a failed parry must not feed groggy")
	local forgeQte = QteDefinitions.Create("Skill", seededRng(6), 0, "q6", true)
	forgeQte.Type = "Forge"
	expect(QteDefinitions.GroggyGain(forgeQte, "Success") == 0, "only parries feed the groggy gauge")

	--=== 룬 · 수식어 ===--
	local canInscribe = RuneDefinitions.CanInscribe(nil)
	expect(canInscribe, "a blank item must accept a rune")
	local blocked = RuneDefinitions.CanInscribe("Keen")
	expect(not blocked, "affixes must never stack on one item")
	local fixedRune = { Id = "R1", Name = "예리한 룬", Kind = "Fixed" :: any, AffixId = "Keen" }
	local okFixed, affix = RuneDefinitions.Inscribe(nil, fixedRune, 1)
	expect(okFixed and affix ~= nil and affix.Id == "Keen", "fixed rune must apply its own affix")
	local randomRune = { Id = "R2", Name = "무작위 룬", Kind = "Random" :: any }
	local okRandom, randomAffix = RuneDefinitions.Inscribe(nil, randomRune, 7)
	expect(okRandom and randomAffix ~= nil, "random rune must resolve to some affix")

	--=== 기도 ===--
	local frost = {
		Id = "Frost",
		Name = "서리의 기도",
		Verse = "차가운 숨이여, 내 앞의 물을 붙들라",
		ChantTurns = 2,
		BaseDamage = 80,
		RequiredMedium = { "Water" },
		Penalty = "Exhaustion" :: any,
		IsOffensive = true,
	}
	-- 규칙 2: 어구를 줄이면 성립하지 않는다
	local shortened = PrayerDefinitions.CanInvoke(frost, "차가운 숨이여", { Water = true }, false)
	expect(not shortened, "shortened verses must fail")
	-- 규칙 3: 매질이 없으면 성립하지 않는다
	local noMedium = PrayerDefinitions.CanInvoke(frost, frost.Verse, {}, false)
	expect(not noMedium, "prayers cannot create something from nothing")
	-- 규칙 6: 기계는 기도할 수 없다
	local machine = PrayerDefinitions.CanInvoke(frost, frost.Verse, { Water = true }, true)
	expect(not machine, "machines can never pray")
	local valid = PrayerDefinitions.CanInvoke(frost, frost.Verse, { Water = true }, false)
	expect(valid, "a complete verse with its medium must succeed")
	-- 규칙 5: 사람을 겨눈 공격 기도는 금기
	expect(PrayerDefinitions.IsTaboo(frost, true), "offensive prayers on people are taboo")
	expect(not PrayerDefinitions.IsTaboo(frost, false), "beasts are not covered by the taboo")
	-- 대가는 반드시 남는다
	expect(PrayerDefinitions.PenaltyScale(-10) > 0, "a prayer must always cost something")

	--=== 저장 프로필 ===--
	local fresh = PlayerProfile.New()
	expect(fresh.Version == 3, "profile schema must be version 3")
	expect(fresh.Account.Honor == 150, "new accounts must start at 150 honor")
	expect(fresh.Account.PresetSlots == 3, "new accounts must start with 3 free preset slots")
	expect(#fresh.Slots == 1, "a new profile must have one slot")
	expect(fresh.TowerRun == nil, "a new profile must not be mid-run")

	-- v2(모션 전용) 저장본이 v3로 넘어오는지. 모션 데이터는 살아남아야 한다.
	local legacy = {
		Version = 2,
		Packs = { legacy = { some = "motion" } },
		Equipped = { Berserker = "legacy" },
		SelectedCharacterId = "Musician",
		HighestFloor = 12,
	}
	local migrated = PlayerProfile.Migrate(legacy)
	expect(migrated.Version == 3, "migration must produce a v3 profile")
	expect(migrated.Account.Packs.legacy ~= nil, "migration must keep motion packs")
	expect(migrated.Account.Equipped.Berserker == "legacy", "migration must keep equipped motions")
	expect(migrated.Account.SelectedCharacterId == "Musician", "migration must keep the selected character")
	expect(migrated.Account.HighestFloor == 12, "migration must keep the highest floor")
	expect(migrated.Account.Honor == 150, "migrated accounts must get the default honor")

	-- 조작·손상된 저장본을 범위 안으로 조여야 한다.
	local hostile = {
		Version = 3,
		Account = { Honor = 9999, PresetSlots = -5, HighestFloor = 999 },
		Slots = { { Name = "x", Level = -3, Gold = -100, GoodDeeds = -1 } },
		ActiveSlot = 42,
	}
	local cleaned = PlayerProfile.Sanitize(hostile)
	expect(cleaned.Account.Honor == 300, "honor must be clamped to 300 on load")
	expect(cleaned.Account.PresetSlots >= 3, "preset slots must never drop below the free 3")
	expect(cleaned.Account.HighestFloor == 30, "highest floor must be clamped to the tower height")
	expect(cleaned.Slots[1].Level >= 1, "level must never load below 1")
	expect(cleaned.Slots[1].Gold == 0, "negative gold must be clamped")
	expect(cleaned.Slots[1].GoodDeeds == 0, "negative deed counters must be clamped")
	expect(cleaned.ActiveSlot == 1, "active slot must stay within the slot list")

	-- 끝난 등반은 이어받지 않고, 진행 중인 등반만 복구한다.
	local finished = PlayerProfile.Sanitize({
		Version = 3,
		Account = {},
		Slots = {},
		TowerRun = { Active = false, Floor = 7 },
	})
	expect(finished.TowerRun == nil, "an inactive tower run must not be restored")

	local ongoing = PlayerProfile.Sanitize({
		Version = 3,
		Account = {},
		Slots = {},
		TowerRun = { Active = true, Floor = 7, Cost = 90, RerollCount = 2, PendingLevel = 9 },
	})
	expect(ongoing.TowerRun ~= nil, "an active tower run must be restored")
	expect(ongoing.TowerRun and ongoing.TowerRun.Floor == 7, "restored run must keep its floor")
	expect(ongoing.TowerRun and ongoing.TowerRun.PendingLevel == 9, "pending level must survive a rejoin")

	-- 무료 3개까지는 그냥, 4개째부터 100로벅스
	local slotProfile = PlayerProfile.New()
	local canAdd, price = PlayerProfile.CanAddSlot(slotProfile)
	expect(canAdd and price == 0, "the 2nd preset must be free")
	table.insert(slotProfile.Slots, PlayerProfile.NewSlot("2", "Berserker", "Human"))
	table.insert(slotProfile.Slots, PlayerProfile.NewSlot("3", "Berserker", "Human"))
	local blockedAdd, blockedPrice = PlayerProfile.CanAddSlot(slotProfile)
	expect(not blockedAdd, "the 4th preset must not be free")
	expect(blockedPrice == 100, "the 4th preset must cost 100 robux")

	--=== 탑 등반 생명주기 (추가&수정.md `#### 탑 시스템`) ===--

	local towerProfile = PlayerProfile.New()
	local towerSlot = PlayerProfile.ActiveSlot(towerProfile)
	towerSlot.Level = 12
	towerSlot.UnspentPoints = 7
	towerSlot.Stats.Main.Strength = 5
	towerSlot.Items = {
		{
			Id = "OwnedSword",
			Name = "가져온 검",
			Rarity = "Rare" :: any,
			PrimaryStat = "Strength" :: any,
			StatRequirement = 4,
			BaseDamage = 40,
		},
		{
			Id = "OwnedArmor",
			Name = "가져온 갑옷",
			Rarity = "Epic" :: any,
			PrimaryStat = "Vitality" :: any,
			StatRequirement = 6,
			BaseDamage = 0,
		},
	}

	local started, startReason = TowerRun.Start(towerProfile)
	expect(started and startReason == nil, "starting a tower run must succeed on a fresh profile")
	expect(towerProfile.TowerRun ~= nil, "starting a run must open the run state")

	-- 사양: 방어구는 모두 벗고, 직업 기본 무기만 자동 장착된다.
	expect(#towerSlot.Items == 1, "entering the tower must strip gear down to the class weapon")
	expect(
		towerSlot.Items[1].BaseDamage == CharacterDefinitions.Get(towerSlot.ClassId).BasicPower,
		"the auto-equipped weapon must use the class basic power"
	)
	expect(
		towerProfile.TowerRun ~= nil and #towerProfile.TowerRun.StoredItems == 2,
		"stripped gear must be stored for return"
	)

	-- 사양: 스탯은 직업 베이스만 남기고 초기화된다.
	expect(towerSlot.Level == 1, "entering the tower must reset the slot level")
	expect(towerSlot.UnspentPoints == 0, "entering the tower must clear unspent points")
	expect(towerSlot.Stats.Main.Strength == 0, "entering the tower must reset spent stats")

	-- 두 번 시작할 수 없다.
	local restarted = TowerRun.Start(towerProfile)
	expect(not restarted, "a second run must not start while one is active")

	-- 1층 클리어: 코스트 30, 리롤 가격 초기화, 카드 제시
	local firstDraft = TowerRun.ClearFloor(towerProfile, 1234)
	expect(firstDraft.Ok, "clearing a floor must produce a draft")
	expect(firstDraft.Cost == TowerRewardDefinitions.COST_PER_FLOOR, "each cleared floor must grant 30 cost")
	expect(
		firstDraft.NextRerollCost == TowerRewardDefinitions.REROLL_BASE_COST,
		"reroll price must reset when entering a floor"
	)
	expect(#firstDraft.Cards > 0, "a floor draft must offer cards")

	-- 리롤 가격이 10 → 15로 오른다(사양: 50%씩 증가, 반올림).
	local rerolled = TowerRun.Reroll(towerProfile, 1234)
	expect(rerolled.Ok, "a reroll must succeed while cost remains")
	expect(rerolled.Cost == TowerRewardDefinitions.COST_PER_FLOOR - 10, "the first reroll must cost 10")
	expect(rerolled.NextRerollCost == 15, "the second reroll must cost 15")

	-- 1층은 카드 1장만 고를 수 있다.
	local towerState = towerProfile.TowerRun :: PlayerProfile.TowerRun
	expect(
		TowerRun.RemainingPicks(towerState) == AbilityCardDefinitions.AcquireSlotsForFloor(1),
		"remaining picks must start at the floor's slot count"
	)
	local pickedOk = TowerRun.Acquire(towerProfile, rerolled.Cards[1])
	expect(pickedOk, "picking an offered card must succeed")
	local overPick = TowerRun.Acquire(towerProfile, rerolled.Cards[1])
	expect(not overPick, "picking more cards than the floor allows must fail")

	-- 같은 카드를 또 얻으면 강화된다(획득 = 강화).
	local sameCard = rerolled.Cards[1]
	local cardLevelBefore = CardDraft.CardLevel(towerState, sameCard.Id)
	TowerRun.ClearFloor(towerProfile, 555)
	local upgraded = TowerRun.Acquire(towerProfile, sameCard)
	expect(upgraded, "re-picking a card on a later floor must succeed")
	expect(
		CardDraft.CardLevel(towerState, sameCard.Id) == cardLevelBefore + 1,
		"re-acquiring the same card must raise its level"
	)

	-- 도중 이탈: 장비는 돌려받지만 레벨은 확정되지 않는다(사양).
	local pendingBefore = towerState.PendingLevel
	expect(pendingBefore > 0, "clearing floors must bank pending levels")
	local exitSummary = TowerRun.Exit(towerProfile)
	expect(exitSummary.ReturnedItems == 2, "leaving the tower must return every stored item")
	expect(exitSummary.GainedLevels == 0, "leaving early must not confirm banked levels")
	expect(towerSlot.Level == 1, "leaving early must leave the slot level untouched")
	expect(towerProfile.TowerRun == nil, "leaving must close the run")
	expect(towerProfile.Account.HighestFloor == 2, "the highest reached floor must persist on the account")

	-- 완주: 30층까지 오르면 레벨이 확정된다.
	local clearProfile = PlayerProfile.New()
	local clearSlot = PlayerProfile.ActiveSlot(clearProfile)
	expect(TowerRun.Start(clearProfile), "a second profile must be able to start a run")
	for _ = 1, TowerRewardDefinitions.MAX_FLOOR do
		TowerRun.ClearFloor(clearProfile, 42)
	end
	local clearState = clearProfile.TowerRun :: PlayerProfile.TowerRun
	expect(clearState.Floor == TowerRewardDefinitions.MAX_FLOOR, "thirty clears must reach the final floor")
	expect(TowerRun.IsCleared(clearState), "reaching floor 30 must count as cleared")
	local bankedLevels = clearState.PendingLevel
	local completedOk, completeSummary = TowerRun.Complete(clearProfile)
	expect(completedOk and completeSummary ~= nil, "completing at the final floor must succeed")
	expect(
		completeSummary ~= nil and completeSummary.GainedLevels == bankedLevels,
		"completing must confirm every banked level"
	)
	expect(clearSlot.Level == 1 + bankedLevels, "completing must apply banked levels to the slot")
	expect(
		clearSlot.UnspentPoints == bankedLevels * StatDefinitions.POINTS_PER_LEVEL,
		"completing must grant 3 stat points per level"
	)

	--=== 격자 전투 (추가&수정.md `#### 전투 시스템`) ===--

	local battle = GridBattle.New(1, "테스터", 100, 10)
	expect(battle.Outcome == "Ongoing", "a new battle must start ongoing")
	expect(GridBattle.Ally(battle).Health == 100, "the ally must enter at full health")
	expect(
		#GridBattle.AliveEnemies(battle) == #TowerDefinitions.Get(1).Enemies,
		"floor 1 must spawn its defined enemies"
	)

	-- 아군은 자기 진영 안에서만 움직인다.
	expect(GridBattle.MoveAlly(battle, 3, 1), "moving inside the ally grid must succeed")
	local allyCell = GridBattle.CellOf(battle, GridBattle.ALLY_ID)
	expect(
		allyCell ~= nil and allyCell.Side == "Ally" and allyCell.X == 3 and allyCell.Y == 1,
		"the ally must land on the requested ally cell"
	)
	expect(not GridBattle.MoveAlly(battle, 99, 1), "moving outside the grid must fail")

	-- 라인이 다르면 아무도 맞지 않는다(사양: 공격 라인 = 선 라인).
	local emptyLane = GridBattle.New(1, "테스터", 100, 10)
	local firstEnemy = GridBattle.AliveEnemies(emptyLane)[1]
	local enemyCell = GridBattle.CellOf(emptyLane, firstEnemy.Id)
	local otherLane = (enemyCell.Y % emptyLane.Grid.Height) + 1
	GridBattle.MoveAlly(emptyLane, 1, otherLane)
	local beforeHealth = firstEnemy.Health
	GridBattle.ResolveSkill(emptyLane, 1, "Success")
	expect(firstEnemy.Health == beforeHealth, "attacking an empty lane must not damage anyone")

	-- 같은 라인이면 맞고, QTE 등급이 배율로 들어간다.
	local hitBattle = GridBattle.New(1, "테스터", 100, 10)
	local target = GridBattle.AliveEnemies(hitBattle)[1]
	local targetCell = GridBattle.CellOf(hitBattle, target.Id)
	GridBattle.MoveAlly(hitBattle, 1, targetCell.Y)
	local fullHealth = target.Health
	GridBattle.ResolveSkill(hitBattle, 1, "Success")
	expect(target.Health < fullHealth, "attacking along the enemy lane must deal damage")

	local failBattle = GridBattle.New(1, "테스터", 100, 10)
	local failTarget = GridBattle.AliveEnemies(failBattle)[1]
	local failCell = GridBattle.CellOf(failBattle, failTarget.Id)
	GridBattle.MoveAlly(failBattle, 1, failCell.Y)
	local failBefore = failTarget.Health
	GridBattle.ResolveSkill(failBattle, 1, "Fail")
	local failDealt = failBefore - failTarget.Health
	expect(failDealt > 0, "a failed QTE must still land a weakened hit")

	local successBattle = GridBattle.New(1, "테스터", 100, 10)
	local successTarget = GridBattle.AliveEnemies(successBattle)[1]
	local successCell = GridBattle.CellOf(successBattle, successTarget.Id)
	GridBattle.MoveAlly(successBattle, 1, successCell.Y)
	local successBefore = successTarget.Health
	GridBattle.ResolveSkill(successBattle, 1, "Success")
	expect(successBefore - successTarget.Health > failDealt, "a successful QTE must beat a failed one")

	-- 회피 성공은 피해 0. 적 그로기는 결투사의 패리만 채운다(2026-09-29 스튜디오에서 바꾼 규칙: 나머지 직업은 회피일 뿐).
	do -- 함수 지역 변수 200개 한도 때문에 블록으로 묶는다
		local evadeBattle = GridBattle.New(1, "테스터", 100, 10)
		local evaded = GridBattle.AliveEnemies(evadeBattle)[1]
		local evadeBefore = GridBattle.Ally(evadeBattle).Health
		GridBattle.ResolveDodge(evadeBattle, evaded.Id, "Success")
		expect(GridBattle.Ally(evadeBattle).Health == evadeBefore, "a perfect dodge must take no damage")
		expect(evaded.Groggy.Value == 0, "a non-duelist dodge must not build groggy")
	end

	local dodgeBattle = GridBattle.New(1, "테스터", 100, 10, "Duelist")
	local attacker = GridBattle.AliveEnemies(dodgeBattle)[1]
	local allyBefore = GridBattle.Ally(dodgeBattle).Health
	GridBattle.ResolveDodge(dodgeBattle, attacker.Id, "Success")
	expect(GridBattle.Ally(dodgeBattle).Health == allyBefore, "a perfect parry must take no damage")
	expect(
		attacker.Groggy.Value == QteDefinitions.PARRY_GROGGY_GAIN,
		"a duelist parry must build the attacker's groggy gauge"
	)

	GridBattle.ResolveDodge(dodgeBattle, attacker.Id, "Fail")
	expect(GridBattle.Ally(dodgeBattle).Health < allyBefore, "a failed dodge must take full damage")

	--[[
		연출용 사건 기록. 클라이언트 연출(CombatDirector)이 피해 숫자·쓰러짐을 이걸로 그린다.
		맞은 대상·피해가 실제 체력 변화와 같아야 하고, Seq 는 늘기만 해야 한다.
	]]
	do
	local attackEvent = dodgeBattle.Events[#dodgeBattle.Events]
	expect(attackEvent and attackEvent.Kind == "EnemyAttack", "an enemy attack must leave an event")
	expect(attackEvent.Hits[1][1].Id == "player" and attackEvent.Hits[1][1].Damage == allyBefore - GridBattle.Ally(dodgeBattle).Health, "the attack event must carry the real damage")
	local skillEvent = successBattle.Events[#successBattle.Events]
	expect(skillEvent and skillEvent.Kind == "Skill" and skillEvent.Actor == "player", "a skill must leave an event")
	local eventTotal = 0
	for _, group in skillEvent.Hits do
		for _, hit in group do
			expect(hit.Id == successTarget.Id, "the skill event must name the unit that was hit")
			eventTotal += hit.Damage
		end
	end
	-- 넘친 피해(과잉 처치)는 체력보다 클 수 있다. 죽였으면 Killed 가 붙어야 한다.
	expect(eventTotal >= successBefore - successTarget.Health and eventTotal > 0, "the skill event must carry the real damage")
	expect(successTarget.Alive or skillEvent.Hits[1][1].Killed == true, "a lethal hit must be marked as a kill")
	expect(skillEvent.Seq > 0 and GridBattle.Snapshot(successBattle).Events[1].Seq == skillEvent.Seq, "the snapshot must carry the events")
	end

	-- 적을 전부 쓰러뜨리면 승리한다.
	local winBattle = GridBattle.New(1, "테스터", 100, 999)
	for _ = 1, 40 do
		if winBattle.Outcome ~= "Ongoing" then
			break
		end
		local remaining = GridBattle.AliveEnemies(winBattle)[1]
		if not remaining then
			break
		end
		local cell = GridBattle.CellOf(winBattle, remaining.Id)
		GridBattle.MoveAlly(winBattle, 1, cell.Y)
		GridBattle.ResolveSkill(winBattle, 1, "Success")
	end
	expect(winBattle.Outcome == "Victory", "clearing every enemy must end in victory")

	-- 아군이 쓰러지면 패배한다.
	local loseBattle = GridBattle.New(1, "테스터", 1, 1)
	local killer = GridBattle.AliveEnemies(loseBattle)[1]
	GridBattle.ResolveDodge(loseBattle, killer.Id, "Fail")
	expect(loseBattle.Outcome == "Defeat", "losing all health must end in defeat")

	-- 같은 씨앗이면 적 턴이 그대로 재현된다(서버 권위 검증용).
	local function seeded(seed: number): () -> number
		local generator = Random.new(seed)
		return function()
			return generator:NextNumber()
		end
	end
	local runA = GridBattle.New(3, "테스터", 100, 10)
	local runB = GridBattle.New(3, "테스터", 100, 10)
	GridBattle.EnemyPlan(runA, seeded(99))
	GridBattle.EnemyPlan(runB, seeded(99))
	for id, unitA in runA.Units do
		local cellA = GridBattle.CellOf(runA, id)
		local cellB = GridBattle.CellOf(runB, id)
		expect((cellA == nil) == (cellB == nil), "same seed must place the same units")
		if cellA and cellB then
			expect(cellA.X == cellB.X and cellA.Y == cellB.Y, "same seed must reproduce enemy movement")
		end
		expect(unitA.SkillIndex == runB.Units[id].SkillIndex, "same seed must reproduce enemy skill choice")
	end

	-- 스냅샷은 좌표와 상태를 담아 나간다.
	local snapshot = GridBattle.Snapshot(runA)
	expect(snapshot.Floor == 3 and snapshot.Outcome == "Ongoing", "a snapshot must carry floor and outcome")
	expect(snapshot.Units[GridBattle.ALLY_ID] ~= nil, "a snapshot must include the ally")

	--=== 회피/그로기 경로 (사양: 라인 규칙 · 패리 시 그로기) ===--

	--[[
		적이 아군과 **같은 라인**에 있어야 위협이 잡힌다. 이 경로는 실기로 상황을
		만들기 어려워(적이 매 턴 무작위로 옮긴다) 순수 로직으로 직접 세워 확인한다.
	]]
	local dodgeState = GridBattle.New(1, "테스터", 100, 10)
	local foe = GridBattle.AliveEnemies(dodgeState)[1]
	local foeCell = GridBattle.CellOf(dodgeState, foe.Id)

	-- 같은 라인 + 전열이면 노려진다.
	GridBattle.MoveAlly(dodgeState, 1, foeCell.Y)
	foe.SkillIndex = 1
	expect(GridBattle.EnemyThreatensAlly(dodgeState, foe), "an enemy sharing the ally lane must threaten")

	-- 라인을 옮기면 위협이 사라진다(사양의 핵심 회피 수단).
	local dodgeOtherLane = (foeCell.Y % dodgeState.Grid.Height) + 1
	GridBattle.MoveAlly(dodgeState, 1, dodgeOtherLane)
	expect(not GridBattle.EnemyThreatensAlly(dodgeState, foe), "changing lanes must break the threat")

	-- 라인 관통(Row)은 x를 쓰지 않으므로 라인만 맞으면 뒤에 있어도 노려진다.
	GridBattle.MoveAlly(dodgeState, 6, foeCell.Y)
	for index, skill in BattleSkills.All() do
		if skill.Shape.Kind == "Row" then
			foe.SkillIndex = index
		end
	end
	expect(GridBattle.EnemyThreatensAlly(dodgeState, foe), "a full-lane skill must reach the back row")

	-- 패리(결투사의 회피 Success)는 피해 0 + 상대 그로기 상승.
	local parryState = GridBattle.New(1, "테스터", 100, 10, "Duelist")
	local parryFoe = GridBattle.AliveEnemies(parryState)[1]
	local hpBefore = GridBattle.Ally(parryState).Health
	GridBattle.ResolveDodge(parryState, parryFoe.Id, "Success")
	expect(GridBattle.Ally(parryState).Health == hpBefore, "a parry must take no damage")
	expect(parryFoe.Groggy.Value == QteDefinitions.PARRY_GROGGY_GAIN, "a parry must add groggy")

	-- 보통(Partial)은 절반, 실패는 전부 맞는다.
	local halfState = GridBattle.New(1, "테스터", 100, 10)
	local halfFoe = GridBattle.AliveEnemies(halfState)[1]
	GridBattle.ResolveDodge(halfState, halfFoe.Id, "Partial")
	local halfTaken = 100 - GridBattle.Ally(halfState).Health
	local fullState = GridBattle.New(1, "테스터", 100, 10)
	local fullFoe = GridBattle.AliveEnemies(fullState)[1]
	GridBattle.ResolveDodge(fullState, fullFoe.Id, "Fail")
	local fullTaken = 100 - GridBattle.Ally(fullState).Health
	expect(halfTaken > 0 and fullTaken > halfTaken, "a partial dodge must hurt less than a failed one")

	-- 그로기가 가득 차면 스턴 → 그 적은 적 턴에 행동하지 못한다.
	local stunState = GridBattle.New(1, "테스터", 100, 10)
	local stunFoe = GridBattle.AliveEnemies(stunState)[1]
	for _ = 1, 20 do
		if GroggyGauge.IsStunned(stunFoe.Groggy) then
			break
		end
		GroggyGauge.Add(stunFoe.Groggy, QteDefinitions.PARRY_GROGGY_GAIN)
	end
	expect(GroggyGauge.IsStunned(stunFoe.Groggy), "filling the gauge must stun")
	local actedWhileStunned = false
	for _, acted in
		GridBattle.EnemyPlan(stunState, function()
			return 0.5
		end)
	do
		if acted.Id == stunFoe.Id then
			actedWhileStunned = true
		end
	end
	expect(not actedWhileStunned, "a stunned enemy must not act")

	-- 스턴은 STUN_TURNS만큼만 간다. 턴을 넘기면 풀린다.
	for _ = 1, GroggyGauge.STUN_TURNS + 1 do
		GridBattle.EndTurn(stunState)
	end
	expect(not GroggyGauge.IsStunned(stunFoe.Groggy), "a stun must wear off after its duration")
	expect(stunFoe.Groggy.Value == 0, "the gauge must reset once the stun ends")

	--=== 적 공격 예고 (한 템포 앞서 보여야 한다) ===--

	--[[
		적은 **예고한 다음 턴에** 때린다.

		예전에는 플레이어가 스킬을 쓴 직후 적이 움직이고 그대로 때렸다. 그래서
		"예고된 라인을 보고 비켜선다"는 선택이 성립하지 않았고, 회피가 QTE 하나로만
		갈렸다("적 공격이 한 템포 빠르다"). 여기서 그 순서를 못 박는다.
	]]
	local planState = GridBattle.New(1, "예고", 300, 10, "Berserker")
	expect(#planState.Planned == 0, "no attack must be telegraphed before the enemy plans")

	local planned = GridBattle.EnemyPlan(planState, seeded(7))
	expect(#planned > 0, "planning must telegraph at least one enemy")
	expect(#planState.Planned == #planned, "the state must remember who telegraphed")

	--[[
		예고된 라인에 서면 위협이 잡히고, 비켜서면 사라진다.
		이것이 "위치로 피한다"는 뜻이다.
	]]
	local planFoe = planned[1]
	local planCell = GridBattle.CellOf(planState, planFoe.Id)
	expect(planCell ~= nil, "a telegraphed enemy must be on the grid")
	if planCell then
		GridBattle.MoveAlly(planState, 1, planCell.Y)
		local onLine = GridBattle.PlannedThreats(planState)
		local found = false
		for _, threat in onLine do
			if threat.Id == planFoe.Id then
				found = true
			end
		end
		expect(found, "standing on the telegraphed lane must be threatened")

		-- 다른 라인으로 비켜선다. 3칸이라 반드시 다른 라인이 있다.
		local away = if planCell.Y == 1 then 2 else 1
		GridBattle.MoveAlly(planState, 1, away)
		local dodgedByMoving = true
		for _, threat in GridBattle.PlannedThreats(planState) do
			if threat.Id == planFoe.Id then
				-- 그 적의 스킬이 라인 전체를 덮으면 비켜도 닿는다. 그건 정상이다.
				local foeSkill = BattleSkills.ByIndex(BattleSkills.Enemy(), planFoe.SkillIndex)
				if foeSkill.Shape.Kind ~= "Row" then
					dodgedByMoving = false
				end
			end
		end
		expect(dodgedByMoving, "stepping off the telegraphed lane must avoid the attack")
	end

	-- 턴이 끝나면 예고가 비워진다. 안 그러면 같은 공격이 두 번 나간다.
	GridBattle.EndTurn(planState)
	expect(#planState.Planned == 0, "ending the turn must clear the telegraph")

	-- 스냅샷도 예고를 실어 보내야 클라이언트가 위협 칸을 칠할 수 있다.
	GridBattle.EnemyPlan(planState, seeded(11))
	local planSnapshot = GridBattle.Snapshot(planState)
	expect(planSnapshot.Planned ~= nil, "the snapshot must carry the telegraph")
	expect(#planSnapshot.Planned == #planState.Planned, "the snapshot telegraph must match the state")

	-- 상태이상·스킬 효과 검증은 함수를 갈라 두었다(아래 runStatusAndSkillEffects).
	runKeywords()
	runCardEffects()
	runStatusAndSkillEffects()

	--=== 직업별 스킬 ===--

	--[[
		직업마다 **자기 스킬**을 가져야 한다.

		예전에는 `BattleSkills`에 목록이 하나뿐이라 어떤 직업을 골라도 같은 5개를 썼다
		— 직업 선택이 전투에 아무 영향을 주지 않았다. 화면만 봐서는 "왜 다 광전사
		스킬이지?" 정도로만 보이므로 여기서 못 박는다.
	]]
	local skillClassIds = {
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
	local seenSkillSets: { [string]: string } = {}
	for _, classId in skillClassIds do
		local list = BattleSkills.ForClass(classId)
		expect(#list == 3, "every class must have exactly 3 skills: " .. classId)

		local names = {}
		for _, skill in list do
			table.insert(names, skill.Id)
			--[[
				눈금은 0~40(유저 아이디어(직업).md). 단, 재사용 대기가 긴(6턴 이상) 한 방 스킬은 50까지 —
				2026-09-28 편집기에서 광전사 `종베기`(대기 8턴, 분노 전부 소모·자해)를 50으로 올렸다.
			]]
			local cap = if (skill.Cooldown or 0) >= 6 then 50 else 40
			expect(skill.Damage >= 0 and skill.Damage <= cap, "skill damage must stay on the 0~40 scale (50 for long-cooldown finishers): " .. skill.Id)
		end
		local signature = table.concat(names, "/")
		expect(
			seenSkillSets[signature] == nil,
			string.format("%s shares a skill set with %s", classId, seenSkillSets[signature] or "?")
		)
		seenSkillSets[signature] = classId
	end

	-- 적은 직업이 없으므로 공용 목록을 그대로 쓴다.
	expect(#BattleSkills.Enemy() == 2, "enemies must keep their own skill list (slime tackle/spit)")

	--[[
		**피해 0인 스킬에는 반드시 효과가 붙어 있어야 한다.**

		피해가 있는 스킬은 효과가 없어도 제 역할을 한다. 문제는 피해 0인 쪽이다 —
		효과를 빠뜨리면 눌러도 아무 일이 없고, 화면으로는 알아채기 어렵다.
		(이 검사가 없던 동안 여섯 개가 그 상태로 남아 있었다)
	]]
	local SkillEffects = require(ReplicatedStorage.Shared.BattleSkillEffects)
	local noEffect: { string } = {}
	for _, classId in skillClassIds do
		for _, skill in BattleSkills.ForClass(classId) do
			if skill.Damage == 0 and not SkillEffects.Get(skill.Id) then
				table.insert(noEffect, string.format("%s/%s", classId, skill.Id))
			end
		end
	end
	expect(#noEffect == 0, "zero-damage skills must have an effect: " .. table.concat(noEffect, ", "))

	-- 강화 스킬도 효과가 있어야 한다. 조건만 차고 아무 일도 없으면 버그다.
	for _, upgrade in BattleSkills.Upgrades() do
		expect(SkillEffects.Get(upgrade.Id) ~= nil, "upgrade skills must have an effect: " .. upgrade.Id)
	end

	--[[
		전투가 실제로 그 직업의 스킬을 쓰는지. `GridBattle.New`에 직업을 넘기지 않으면
		조용히 기본값으로 떨어지므로 스냅샷에 실린 목록으로 확인한다.
	]]
	local skillBattle = GridBattle.New(1, "결투사", 200, 10, "Duelist")
	local skillSnapshot = GridBattle.Snapshot(skillBattle)
	expect(skillSnapshot.AllyClassId == "Duelist", "the snapshot must carry the ally class")
	--[[
		직업 3개 + 공용 2개(가드·명상). 강화는 조건이 안 찼으므로 아직 없다.
	]]
	expect(#skillSnapshot.AllySkills == 5, "the snapshot must carry class skills plus guard and meditate")
	expect(skillSnapshot.AllySkills[1].Name == "앞뒤관통", "the snapshot must carry the duelist's own skill names")
	expect(skillSnapshot.AllySkills[1].RangeLabel == "근거리", "the snapshot must carry the melee/ranged label")
	expect(skillSnapshot.AllySkills[4].Kind == "Common", "guard and meditate must be tagged as common")

	--=== 등반 직업 선택 ===--

	--[[
		고른 직업이 등반 내내 실제로 반영되는지 본다.

		`TowerService.Enter`가 하는 일은 `slot.ClassId`를 쓰는 것뿐이고, 그 한 줄이
		기본 무기와 카드 풀을 동시에 결정한다. 그 연결이 끊기면 결투사를 골라도
		광전사 카드가 나오는데, 화면만 봐서는 알아채기 어렵다.
	]]
	local pickProfile = PlayerProfile.New()
	local pickSlot = PlayerProfile.ActiveSlot(pickProfile)
	pickSlot.ClassId = "Duelist"

	local pickOk = TowerRun.Start(pickProfile)
	expect(pickOk, "starting a run with a chosen class must succeed")
	expect(#pickSlot.Items == 1, "a run must start with exactly the class basic weapon")
	expect(
		pickSlot.Items[1].Id == "TowerBasic_Duelist",
		"the basic weapon must come from the chosen class, not the previous one"
	)

	local pickDraft = TowerRun.ClearFloor(pickProfile, 4242)
	expect(#pickDraft.Cards > 0, "clearing a floor must offer cards")
	for _, card in pickDraft.Cards do
		expect(card.ClassId == "Duelist", "offered cards must belong to the chosen class")
	end

	-- 고른 직업의 능력치로 실제 전투가 서고, 스킬이 통해야 한다.
	local pickHealth = ProgressionDefinitions.MaxHealthWithStats(pickSlot.Level, pickSlot.Stats)
	local pickBattle = GridBattle.New(1, "결투사", pickHealth, pickSlot.Items[1].BaseDamage)
	expect(GridBattle.Ally(pickBattle).MaxHealth == pickHealth, "the battle must use the chosen class's health")
	expect(#GridBattle.AliveEnemies(pickBattle) > 0, "floor 1 must spawn enemies")

	--[[
		OP 개발 캐릭터가 실제로 한 방에 정리하는지. 이게 통하지 않으면 시험용으로
		쓸 수 없다(1층에서 막혀 전투 흐름을 못 본다).
	]]
	local opBattle = GridBattle.New(1, "OP 결투사", 9999, 400)
	GridBattle.MoveAlly(opBattle, 1, 2)
	for _, opFoe in GridBattle.AliveEnemies(opBattle) do
		local opFoeCell = GridBattle.CellOf(opBattle, opFoe.Id)
		if opFoeCell then
			GridBattle.MoveAlly(opBattle, 1, opFoeCell.Y)
			GridBattle.ResolveSkill(opBattle, 1, "Success")
		end
	end
	expect(opBattle.Outcome == "Victory", "the dev OP build must be able to clear floor 1")

	--=== 도발 ===--

	local tauntState = GridBattle.New(3, "도발", 120, 10)
	expect(GridBattle.Ally(tauntState).Taunt == 0, "taunt must start empty")

	-- 상한을 넘겨 쌓아도 상한에서 멈춰야 한다(규격: 스택은 반드시 상한이 있을 것).
	GridBattle.AddTaunt(tauntState, GridBattle.ALLY_ID, 999)
	expect(GridBattle.Ally(tauntState).Taunt == GridBattle.TAUNT_MAX, "taunt must clamp to its cap")
	expect(GridBattle.TauntChance(tauntState, GridBattle.ALLY_ID) == 1, "a full stack must intercept everything")

	--[[
		도발은 **대상만** 바꾼다. 라인 선택에는 개입하지 않는다.
		탑은 솔로라 아군이 하나뿐이므로, 파티 상황을 흉내내려고 둘째 아군을 끼워 넣는다.
	]]
	local mate = table.clone(GridBattle.Ally(tauntState))
	mate.Id = "mate"
	mate.Name = "동료"
	mate.Taunt = 0
	tauntState.Units.mate = mate

	local always = function()
		return 0
	end
	local never = function()
		return 0.999
	end
	expect(
		GridBattle.RedirectTarget(tauntState, "mate", always) == GridBattle.ALLY_ID,
		"a full taunt must pull an ally's incoming attack onto the taunter"
	)
	expect(
		GridBattle.RedirectTarget(tauntState, GridBattle.ALLY_ID, always) == GridBattle.ALLY_ID,
		"taunt must not redirect an attack already aimed at the taunter"
	)

	-- 절반만 쌓였으면 확률이므로 실패할 수 있어야 한다. 확정 가로채기는 상한에서만이다.
	GridBattle.Ally(tauntState).Taunt = GridBattle.TAUNT_MAX // 2
	expect(
		GridBattle.RedirectTarget(tauntState, "mate", never) == "mate",
		"a partial stack must be able to fail its roll"
	)
	expect(
		GridBattle.RedirectTarget(tauntState, "mate", always) == GridBattle.ALLY_ID,
		"a partial stack must still redirect when the roll passes"
	)
	tauntState.Units.mate = nil
	GridBattle.Ally(tauntState).Taunt = GridBattle.TAUNT_MAX

	-- 턴이 끝나면 빠진다. 유지하려면 계속 쌓아야 한다.
	GridBattle.EndTurn(tauntState)
	expect(
		GridBattle.Ally(tauntState).Taunt == GridBattle.TAUNT_MAX - GridBattle.TAUNT_DECAY,
		"taunt must decay every turn"
	)

	--=== 등반실 (겹침 방지) ===--

	--[[
		방마다 좌표가 달라야 한다. 하나라도 겹치면 두 사람이 같은 전장에 서게 된다.
	]]
	local seenSlots: { [string]: boolean } = {}
	for index = 1, SkyArena.SLOT_COUNT do
		local origin = SkyArena.SlotOrigin(index)
		local key = string.format("%d/%d/%d", origin.X, origin.Y, origin.Z)
		expect(not seenSlots[key], "every tower chamber must sit at its own spot")
		seenSlots[key] = true
	end

	--[[
		간격이 격자보다 넓어야 한다.

		격자 가로폭 = Midline + Width * (CellSize + Gap) * 2.
		나중에 칸을 키우면서 SLOT_SPACING을 그대로 두면 옆방과 물리적으로 겹치는데,
		그 실수를 여기서 잡는다. (ArenaExtents는 Vector2를 쓰므로 상수로 직접 센다)
		]]
	local arenaAcross = BattleArena.DEFAULT_MIDLINE + 6 * (BattleArena.DEFAULT_CELL_SIZE + BattleArena.DEFAULT_GAP) * 2
	expect(SkyArena.SLOT_SPACING > arenaAcross, "chambers must be spaced wider than the grid itself")
	expect(SkyArena.FLOOR_LENGTH >= arenaAcross, "the chamber floor must cover the whole grid")
	expect(SkyArena.SlotGap() > 0, "chamber floors must not touch each other")

	-- 인접한 두 방의 실제 거리도 바닥판 폭보다 커야 한다.
	local slotOne = SkyArena.SlotOrigin(1)
	local slotTwo = SkyArena.SlotOrigin(2)
	expect(math.abs(slotTwo.X - slotOne.X) >= SkyArena.FLOOR_LENGTH, "neighbouring chamber floors must not overlap")

	-- 서 있는 자리는 바닥판 안이어야 한다. 밖이면 입장하자마자 떨어진다.
	local stand = SkyArena.SlotStand(3)
	local slotThree = SkyArena.SlotOrigin(3)
	expect(
		math.abs(stand.X - slotThree.X) < SkyArena.FLOOR_LENGTH / 2,
		"the standing spot must be inside its chamber floor"
	)

	--=== 카드 그림 ===--

	--[[
		모든 카드가 그림을 갖는지 확인한다.

		태그를 새로 만들고 `CardArt`의 문양 표에 넣는 것을 잊으면, 그 카드는 조용히
		기본 문양으로 떨어진다. 눈으로는 알아채기 어려우니 여기서 막는다.
	]]
	local artChecked = 0
	local artSignatures: { [string]: string } = {}
	local artClassIds = {
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
	for _, classId in artClassIds do
		for _, grade in { "Essential", "Rare", "Common" } do
			for _, card in AbilityCardDefinitions.GetPool(classId, grade :: any) do
				for _, tag in card.Tags do
					expect(CardArt.HasFamily(tag), string.format("card tag '%s' has no art family (%s)", tag, card.Id))
				end

				local art = CardArt.For(card)
				expect(#art.Shapes > 0, "every card must produce at least one shape: " .. card.Id)

				--[[
					도형이 그림 영역을 크게 벗어나면 잘려서 문양이 무너진다.
					배경 띠와 광채는 일부러 넘치므로(ZIndex 1) 문양만 본다.
				]]
				for _, item in art.Shapes do
					if item.ZIndex > 1 then
						expect(
							item.X >= -0.1 and item.X <= 1.1 and item.Y >= -0.1 and item.Y <= 1.1,
							"card art glyphs must stay inside the frame: " .. card.Id
						)
					end
				end

				artChecked += 1
				artSignatures[card.Id] = string.format("%d/%s", #art.Shapes, tostring(art.Accent.R))
			end
		end
	end
	expect(artChecked == 306, "every one of the 306 cards must have art")

	--[[
		**태그마다 그림이 달라야 한다** (요청: "다 나누고").

		같은 Id로 그리므로 변주값이 같다 — 그림이 겹치면 문양 자체가 같다는 뜻이다.
		예전에는 40개 태그가 14개 문양을 나눠 써서 `Brink`와 `Sacrifice`가 똑같은
		물약병으로 나왔다. 태그를 새로 만들고 문양 붙이기를 잊으면 여기서 걸린다.
	]]
	local glyphSeen: { [string]: string } = {}
	local tagList = CardArt.Tags()
	for _, tag in tagList do
		local art = CardArt.For({ Id = "ArtUniqueness", Grade = "Common", Tags = { tag } })
		local parts: { string } = {}
		for _, item in art.Shapes do
			table.insert(
				parts,
				string.format("%.3f,%.3f,%.3f,%.3f,%.1f", item.X, item.Y, item.W, item.H, item.Rotation)
			)
		end
		local signature = table.concat(parts, "|")
		expect(
			glyphSeen[signature] == nil,
			string.format("tags '%s' and '%s' draw the same glyph", tostring(glyphSeen[signature]), tag)
		)
		glyphSeen[signature] = tag
	end
	expect(#tagList == 32, "the 32 card tags must each have their own glyph, got " .. #tagList)

	--[[
		**카드 이름은 전 직업에서 유일해야 한다** (요청: "해당 카드 이름에 맞게 짜줘").

		예전에는 세 월 필그림스 직업이 `기도`·`서약`·`봉헌`·`검약`을 글자 그대로 나눠
		썼다. 이름이 곧 기믹이어야 하는데 이름이 겹치면 직업마다 뭐가 다른지 읽히지
		않는다. 직업별 어휘를 갈랐고, 되돌아가지 않게 여기서 막는다.

		**한 축은 최소 다섯 장을 가진다.** 태그가 넷인데 한쪽이 한두 장이면 그건
		덱 빌딩 축이 아니라 장식이다.
	]]
	--[[
		**레벨별 수치**(요청: "(레벨당 +n) 표현을 없앰 / 매 레벨마다 수치를 다르게").

		  · 사다리 길이는 등급 상한과 같아야 한다. 짧으면 상위 레벨이 조용히
		    마지막 값에 물려 카드가 안 자란다.
		  · `Levels`를 가진 카드는 설명에 `{n}` 자리표시자가 있어야 하고,
		    그 번호마다 사다리가 있어야 한다.
		  · 사다리를 가진 카드는 "(레벨당" 같은 옛 표기를 쓰지 않는다.
	]]
	for _, classId in artClassIds do
		for _, grade in { "Essential", "Rare", "Common" } do
			for _, card in AbilityCardDefinitions.GetPool(classId, grade :: any) do
				if not AbilityCardDefinitions.HasScaling(card) then
					continue
				end
				local cap = AbilityCardDefinitions.MaxLevelFor(card)
				for slot, ladder in card.Levels :: any do
					expect(
						#ladder == cap,
						string.format("%s ladder {%d} has %d rungs, needs %d", card.Id, slot, #ladder, cap)
					)
				end
				--[[
					중괄호는 **나온 순서**가 곧 사다리 번호다. 그러니 글의 중괄호 개수와
					사다리 개수가 같아야 한다. 하나라도 어긋나면 글에 값이 안 박히거나
					쓰이지 않는 사다리가 남는다.
				]]
				local marks = 0
				for _ in card.Description:gmatch("{[%d%.%-]+}") do
					marks += 1
				end
				expect(
					marks == #(card.Levels :: any),
					string.format("%s has %d braces but %d ladders", card.Id, marks, #(card.Levels :: any))
				)
				expect(
					not string.find(card.Description, "(레벨당", 1, true),
					"a card with level values must not also spell out '(레벨당': " .. card.Id
				)
				--[[
					사다리에 붙인 키워드는 사전에 실재해야 한다. 오타가 나면 편집기가
					그 사다리를 어디에도 못 묶고 조용히 이름 없는 칸으로 남는다.
				]]
				for slot, keywordIds in card.LevelKeywords or {} do
					-- 한 슬롯에 쉼표로 여럿 이어질 수 있다("Id1,Id2"). 하나씩 갈라 검사한다.
					for keywordId in keywordIds:gmatch("[^,]+") do
						expect(
							Keywords.Get(keywordId) ~= nil,
							string.format("%s ladder {%d} names unknown keyword '%s'", card.Id, slot, keywordId)
						)
					end
				end
				-- 레벨을 올리면 글의 숫자가 실제로 달라져야 한다.
				expect(
					AbilityCardDefinitions.Describe(card, 1) ~= card.Description,
					"Describe must substitute the placeholders: " .. card.Id
				)
			end
		end
	end

	for _, classId in artClassIds do
		for _, grade in { "Essential", "Rare", "Common" } do
			for _, card in AbilityCardDefinitions.GetPool(classId, grade :: any) do
				--[[
					글에 적힌 `[낱말]`은 사전에 있어야 한다. 오타면 게임에서 색도
					설명도 붙지 않고 대괄호만 남는다.
				]]
				for _, name in Keywords.Mentioned(card.Description) do
					expect(
						Keywords.ByName(name) ~= nil,
						string.format("card %s mentions unknown keyword '[%s]'", card.Id, name)
					)
				end
			end
		end
	end

	local nameOwner: { [string]: string } = {}
	for _, classId in artClassIds do
		local tagCount: { [string]: number } = {}
		for _, grade in { "Essential", "Rare", "Common" } do
			for _, card in AbilityCardDefinitions.GetPool(classId, grade :: any) do
				expect(
					nameOwner[card.Name] == nil,
					string.format(
						"card name '%s' is shared by %s and %s",
						card.Name,
						tostring(nameOwner[card.Name]),
						classId
					)
				)
				nameOwner[card.Name] = classId
				for _, tag in card.Tags do
					tagCount[tag] = (tagCount[tag] or 0) + 1
				end
			end
		end

		local axes = 0
		for tag, count in tagCount do
			axes += 1
			expect(count >= 5, string.format("%s axis '%s' only has %d cards", classId, tag, count))
		end
		expect(axes == 4, string.format("%s must have exactly 4 deck-building axes, got %d", classId, axes))
	end

	--[[
		카드 조건에 **층 이동과 이동속도를 쓰지 않는다** (요청).

		  층 이동  보상은 층마다 한 번뿐이라 "층에 진입할 때"는 사실상 상시 효과다.
		           같은 조건을 `전투 시작 시` / `매 턴`으로 옮겼다.
		  이동속도 턴제라서 의미가 없다. 피해·받는 피해 같은 값으로 바꿨다.

		새 카드를 쓸 때 무심코 되살리기 쉬운 표현이라 검사로 막는다.
	]]
	for _, phrase in { "층에 진입할 때", "층을 넘길 때", "이동속도" } do
		for _, classId in artClassIds do
			for _, grade in { "Essential", "Rare", "Common" } do
				for _, card in AbilityCardDefinitions.GetPool(classId, grade :: any) do
					expect(
						not string.find(card.Description, phrase, 1, true),
						string.format("card must not use '%s': %s", phrase, card.Id)
					)
				end
			end
		end
	end

	-- 같은 카드는 몇 번을 그려도 같은 그림이어야 한다(보상 화면을 다시 열어도 안 바뀐다).
	for cardId, signature in artSignatures do
		local card = AbilityCardDefinitions.Get(cardId)
		if card then
			local redrawn = CardArt.For(card)
			expect(
				string.format("%d/%s", #redrawn.Shapes, tostring(redrawn.Accent.R)) == signature,
				"card art must be deterministic: " .. cardId
			)
		end
	end

	--[[
		손으로 그린 그림.

		`Art`가 가리키는 그림이 없으면 조용히 태그 문양으로 돌아가야 한다 — 편집기에서
		그림을 지웠다고 카드가 빈칸이 되면 안 된다.
	]]
	do
		local sample = AbilityCardDefinitions.GetPool(artClassIds[1], "Common" :: any)[1]
		expect(sample ~= nil, "artwork test needs a card")

		local ghost = table.clone(sample)
		ghost.Art = "그런그림없음"
		-- 견줄 대상은 **그림을 안 가리키는** 같은 카드다(표본 카드가 이미 그림을 가리킬 수 있다)
		local plain = table.clone(sample)
		plain.Art = nil
		expect(#CardArt.For(ghost).Shapes == #CardArt.For(plain).Shapes, "missing artwork must fall back to the glyph")

		for _, grade in { "Essential", "Rare", "Common" } do
			local template = CardArtworks.Template(grade)
			expect(#template > 0, "grade template must not be empty: " .. grade)
			template[1].X = 99
			expect(CardArtworks.Template(grade)[1].X ~= 99, "template must hand out copies: " .. grade)
		end

		for _, artwork in CardArtworks.All() do
			local drawn = table.clone(sample)
			drawn.Art = artwork.Id
			expect(#CardArt.For(drawn).Shapes >= #artwork.Shapes, "saved artwork must reach the card: " .. artwork.Id)
		end
	end

	print(
		"[PorcelainTests] PASS stats, progression, items, honor, afterlife, tower rewards, cards, runes, prayer, profile, tower run, grid battle, dodge, groggy, chambers, card art, artworks, card effects, status effects, class skills and enemy telegraph"
	)
end

return PrototypeTests
