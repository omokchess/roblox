--!strict
--[[
	CombatMotions — 직업별 전투 모션 묶음을 모아 두는 곳. (2026-09-28)

	한 직업의 묶음(Motions/<직업>.luau)은 이 이름들을 가진다:
	  Idle   대기(되풀이)            Held  마우스로 들려 옮겨지는 동안(붙듦)
	  Drop   칸에 내려놓일 때        Hit   피격(QTE 실패)
	  Guard  방어(QTE 절반 성공)     Dodge 회피·받아넘김(QTE 성공)
	  Skills = { [스킬 Id] = 모션 }  직업 스킬·강화 스킬·가드·명상
	  Fidgets = { 모션, … }  대기 중 불규칙한 간격으로 가끔 하는 버릇(키에 적은 관절만 덮는다 — CombatAnimator:Fidget)
	없는 것은 Common 묶음에서 빌린다.

	**무기 호환**: 묶음은 그 직업 기본 무기 종류(WeaponDefinitions.ClassType)에 맞춰 만든다.
	다른 종류 무기를 들면 `ByType[종류]` 가 있으면 그것을, 없으면 직업 묶음을 그대로 쓴다.
]]

local CombatMotions = {}

local Motions = script.Parent.Motions

CombatMotions.Sets = {
	Common = require(Motions.Common),
	Test = require(Motions.Test),
	Duelist = require(Motions.Duelist),
	Musician = require(Motions.Musician),
	Quasar = require(Motions.Quasar),
	Pulsar = require(Motions.Pulsar),
	WallPilgrim = require(Motions.WallPilgrim),
	WallMason = require(Motions.WallMason),
	WallBreaker = require(Motions.WallBreaker),
	Alchemist = require(Motions.Alchemist),
	Berserker = require(Motions.Berserker),
}
-- 무기 종류별 묶음(직업과 다른 종류의 무기를 들었을 때)
CombatMotions.ByType = {}

--[[
	사용자가 스튜디오 애니메이션 편집기로 고친 모션(2026-09-29 요청: "직업별 모션은 내가 짤 수 있게").
	서버(MotionStudioService)가 플레이 시작 때 고친 저장본만 ReplicatedStorage.MotionStudio.<직업>.<이름> 으로 모은다.
	있으면 코드 모션 대신 쓴다. 이름: Idle · Held · Drop · Hit · Guard · Dodge · Death · Skill_<스킬 Id>
	(MotionImport 는 Roblox 형(CFrame·Enum)을 쓰므로 여기서 늦게 부른다 — Lune 도구가 이 모듈을 그냥 읽을 수 있게)
]]
local converted: { [Instance]: any } = setmetatable({}, { __mode = "k" }) :: any
local function authored(classId: string, name: string, base: any): any?
	local rs = if game then game:GetService("ReplicatedStorage") else nil
	local studio = rs and rs:FindFirstChild("MotionStudio")
	local folder = studio and studio:FindFirstChild(classId)
	local seq = folder and folder:FindFirstChild(name)
	if not seq or not seq:IsA("KeyframeSequence") then
		return nil
	end
	local motion = converted[seq]
	if not motion then
		motion = require(script.Parent.MotionImport).FromSequence(seq, base)
		converted[seq] = motion
	end
	return motion
end

-- 직업·무기 종류로 모션 하나를 찾는다(없으면 Common)
function CombatMotions.Get(classId: string, name: string, weaponType: string?): any
	local set = CombatMotions.Sets[classId]
	local typed = weaponType and CombatMotions.ByType[weaponType]
	local code = if typed and typed[name] then typed[name]
		elseif set and set[name] then set[name]
		else CombatMotions.Sets.Common[name]
	return authored(classId, name, code) or code
end

function CombatMotions.Skill(classId: string, skillId: string): any
	local set = CombatMotions.Sets[classId]
	local common = CombatMotions.Sets.Common.Skills
	local code = if set and set.Skills and set.Skills[skillId] then set.Skills[skillId] else (common[skillId] or common.Default)
	return authored(classId, "Skill_" .. skillId, code) or code
end

return CombatMotions
