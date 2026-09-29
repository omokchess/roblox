--!strict
--[[
	AfterlifeDefinitions — 사망 처리와 사후 차원 분기.

	사양 출처: 추가&수정.md `## 사망 처리`, 세계관.md 38~64줄

	사망 시
	  아이템·골드·레벨은 **잃지 않는다.** 대신 살아있을 때의 행동에 따라
	  네 차원 중 한 곳으로 이동한다.

	분기 조건 (세계관.md)
	  천계(Heaven)            선행 100 이상
	  마계(Hell)              악행 100 이상
	  신계(The Astral Nexus)  선행·악행 **둘 다** 100 이상
	  영계(Spirit World)      둘 다 100 미만

	→ 둘 다 100을 넘으면 신계가 우선한다.
]]

export type Realm = "Heaven" | "Hell" | "AstralNexus" | "SpiritWorld"

export type RealmDefinition = {
	Id: Realm,
	Name: string,
	EnglishName: string,
	Description: string,
	-- 이 차원에서 부활할 때 일어나는 일
	ReviveEffect: string,
}

local THRESHOLD = 100

local realms: { RealmDefinition } = {
	{
		Id = "Heaven",
		Name = "천계",
		EnglishName = "Heaven",
		Description = "구름 위, 파괴된 로마 건축물이 흩뿌려진 단일 바이옴. 신은 없고 고위급 천사가 있다.",
		ReviveEffect = "고위급 천사가 플레이어를 부활시킨다.",
	},
	{
		Id = "Hell",
		Name = "마계",
		EnglishName = "Hell",
		Description = "용암 위 거대한 바위 형상. 7죄종을 관장하는 악마들이 있다.",
		ReviveEffect = "선택한 악마의 특성에 맞는 특전과, 초기화 전까지 지속되는 영구 디버프를 얻고 부활한다.",
	},
	{
		Id = "AstralNexus",
		Name = "신계",
		EnglishName = "The Astral Nexus",
		Description = "신 먹는 자(God Eater)가 침입해 있는 곳.",
		ReviveEffect = "신 먹는 자와 상호작용 시 종족을 한 번 바꾸고, 모든 아이템과 스탯을 유지한 채 부활한다.",
	},
	{
		Id = "SpiritWorld",
		Name = "영계",
		EnglishName = "Spirit World",
		Description = "먹히고 싶지 않은 신들이 도망쳐 온 곳. 대부분 겁에 질려 있다.",
		ReviveEffect = "신들 중 아무에게나 말을 걸면 죽어도 초기화되지 않는 퀘스트를 얻고 부활한다.",
	},
}

local AfterlifeDefinitions = {}

AfterlifeDefinitions.THRESHOLD = THRESHOLD

function AfterlifeDefinitions.All(): { RealmDefinition }
	return realms
end

function AfterlifeDefinitions.Get(id: Realm): RealmDefinition?
	for _, realm in realms do
		if realm.Id == id then
			return realm
		end
	end
	return nil
end

--[[
	선행/악행 수치로 갈 차원을 정한다.
	둘 다 임계값을 넘으면 신계가 우선한다.
]]
function AfterlifeDefinitions.ResolveRealm(goodDeeds: number, evilDeeds: number): Realm
	local good = goodDeeds >= THRESHOLD
	local evil = evilDeeds >= THRESHOLD

	if good and evil then
		return "AstralNexus"
	elseif good then
		return "Heaven"
	elseif evil then
		return "Hell"
	end
	return "SpiritWorld"
end

--[[
	사망 시 보존되는 것들(사양: 아이템·골드·레벨 유지).
	사망 처리 로직이 이 규칙을 참조하도록 명시해 둔다.
]]
AfterlifeDefinitions.PRESERVED_ON_DEATH = table.freeze({
	Items = true,
	Gold = true,
	Level = true,
	Honor = true, -- 명예는 계정 귀속이라 부활해도 유지된다
})

return AfterlifeDefinitions
