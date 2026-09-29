--!strict
--[[
	TowerService — 탑 등반과 격자 전투를 실제로 굴리는 **서버 권위** 서비스.

	사양 출처: 추가&수정.md `#### 탑 시스템`, `#### 전투 시스템`

	여기까지 있던 조각들
	  TowerRun    등반 생명주기(입장 제약 / 층 클리어 / 보상 / 종료)
	  GridBattle  한 층의 전투 상태 기계(순수 로직)
	  CardDraft   보상 뽑기·리롤·획득

	그 둘을 **한 사람의 세션**으로 묶어 리모트에 연결하는 것이 이 파일이다.

	판정은 전부 여기서 한다. 클라이언트는
	  GridAction  {Kind="Move"|"Skill"|"Dodge", ...}   의도만 보낸다
	  TowerAction {Kind="Enter"|"Exit"|"Reroll"|"Acquire", ...}
	를 보내고, 내려주는 스냅샷을 그리기만 한다.

	QTE 등급(Grade)은 클라이언트가 보낸다. 입력 타이밍은 클라이언트에만 있기 때문인데,
	그래서 **등급 외의 모든 것**(누가 어디 있고, 무엇을 맞고, 얼마나 아픈지)은 서버가
	쥔다. 등급까지 서버로 옮기려면 입력 시각을 왕복시켜야 해서, 지금 단계에서는
	여기까지를 경계로 둔다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityCardDefinitions = require(ReplicatedStorage.Shared.AbilityCardDefinitions)
local BattleSkills = require(ReplicatedStorage.Shared.BattleSkills)
local CardDraft = require(ReplicatedStorage.Shared.CardDraft)
local GridBattle = require(ReplicatedStorage.Shared.GridBattle)
local CharacterDefinitions = require(ReplicatedStorage.Shared.CharacterDefinitions)
local PlayerProfile = require(ReplicatedStorage.Shared.PlayerProfile)
local ProgressionDefinitions = require(ReplicatedStorage.Shared.ProgressionDefinitions)
local StatDefinitions = require(ReplicatedStorage.Shared.StatDefinitions)
local TowerRewardDefinitions = require(ReplicatedStorage.Shared.TowerRewardDefinitions)
local TowerArena = require(ReplicatedStorage.Shared.TowerArena)
local TowerRun = require(ReplicatedStorage.Shared.TowerRun)

local VALID_GRADES: { [string]: boolean } = { Success = true, Partial = true, Fail = true }

-- 등반문 앞이라고 인정하는 거리. ProximityPrompt(14)보다 넉넉히 잡아,
-- 문을 누른 직후 한두 걸음 움직여도 거절당하지 않게 한다.
local GATE_RANGE = 24

local TowerService = {}
TowerService.__index = TowerService

export type Session = {
	Battle: GridBattle.State?,
	-- 보상 화면에 걸린 카드들. 고르거나 리롤할 때까지 유지된다.
	Offered: { AbilityCardDefinitions.AbilityCard },
	--[[
		이번 턴에 아군을 노린 적들. **한 명씩 차례로** 회피 판정을 받는다.
		목록을 한꺼번에 내려보내면 클라이언트가 첫 번째만 처리해 나머지 공격이 사라진다.
	]]
	Threats: { any },
	-- 등반문을 눌러 직업 선택 화면이 떠 있는 상태.
	PickClass: boolean,
	Rng: Random,
}

--[[
	returnHome은 등반이 끝난 사람을 광장으로 돌려보내는 함수다(`PlazaService.PlacePlayer`).

	여기서 PlazaService를 직접 require하지 않는 이유는, 탑이 광장을 알 필요가 없기
	때문이다. "끝나면 이걸 불러 달라"만 받으면 나중에 돌아갈 곳이 바뀌어도 이 파일은
	그대로다.
]]
function TowerService.new(
	remotes: Folder,
	profiles: { [number]: any },
	persist: (Player) -> (),
	returnHome: ((Player) -> ())?
)
	local self = setmetatable({}, TowerService)
	self.Remotes = remotes
	self.Profiles = profiles
	self.Persist = persist
	self.ReturnHome = returnHome
	self.Sessions = {} :: { [Player]: Session }
	--[[
		등반실 배정표. 겹침 방지의 핵심이다.
		  Slots[index]      → 그 방을 쓰는 사람
		  PlayerSlot[player] → 그 사람이 쓰는 방
		두 방향을 다 들고 있어야 배정도 반납도 O(1)로 끝난다.
	]]
	self.Slots = {} :: { [number]: Player }
	self.PlayerSlot = {} :: { [Player]: number }
	self.Gate = nil :: BasePart?
	self:_buildChambers()
	return self
end

-- 광장의 등반문. 여기서 멀면 등반을 시작할 수 없다.
function TowerService:SetGate(gate: BasePart?)
	self.Gate = gate
end

--=== 등반실 ===--

--[[
	하늘에 개인 등반실을 SLOT_COUNT개 지어 둔다.

	바닥판이 **필요한** 이유: 전투 중에는 캐릭터를 고정하지만, 보상(카드 선택) 화면
	에서는 풀어 준다. 발판이 없으면 그 순간 하늘에서 떨어진다.

	타일과 적 더미는 클라이언트가 자기 화면에만 그리지만(그래서 남에게 안 보인다),
	바닥은 물리가 걸려야 하므로 서버가 만든다.
]]
function TowerService:_buildChambers()
	local previous = workspace:FindFirstChild("TowerChambers")
	if previous then
		previous:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "TowerChambers"
	folder.Parent = workspace

	for index = 1, TowerArena.SLOT_COUNT do
		local origin = TowerArena.SlotOrigin(index)

		local floor = Instance.new("Part")
		floor.Name = string.format("Chamber%02d", index)
		floor.Anchored = true
		floor.Size = Vector3.new(TowerArena.FLOOR_LENGTH, TowerArena.FLOOR_THICKNESS, TowerArena.FLOOR_WIDTH)
		-- 윗면이 정확히 ZONE_Y에 오게 한다. 격자 타일이 이 면을 레이캐스트로 찾는다.
		floor.Position = Vector3.new(origin.X, origin.Y - TowerArena.FLOOR_THICKNESS / 2, origin.Z)
		floor.Color = Color3.fromRGB(38, 32, 52)
		floor.Material = Enum.Material.Slate
		floor.TopSurface = Enum.SurfaceType.Smooth
		floor.Parent = folder

		--[[
			난간. 캐릭터가 굴러떨어지지 않게 사방을 막는다. 투명도를 주어
			카메라가 밖에서 안을 볼 때 시야를 가리지 않게 했다.
		]]
		local rails = {
			{ Vector3.new(TowerArena.FLOOR_LENGTH, 8, 2), Vector3.new(0, 4, TowerArena.FLOOR_WIDTH / 2) },
			{ Vector3.new(TowerArena.FLOOR_LENGTH, 8, 2), Vector3.new(0, 4, -TowerArena.FLOOR_WIDTH / 2) },
			{ Vector3.new(2, 8, TowerArena.FLOOR_WIDTH), Vector3.new(TowerArena.FLOOR_LENGTH / 2, 4, 0) },
			{ Vector3.new(2, 8, TowerArena.FLOOR_WIDTH), Vector3.new(-TowerArena.FLOOR_LENGTH / 2, 4, 0) },
		}
		for railIndex, spec in rails do
			local rail = Instance.new("Part")
			rail.Name = string.format("Rail%d", railIndex)
			rail.Anchored = true
			rail.Size = spec[1]
			rail.Position = Vector3.new(origin.X, origin.Y, origin.Z) + spec[2]
			rail.Color = Color3.fromRGB(120, 96, 170)
			rail.Material = Enum.Material.Neon
			rail.Transparency = 0.72
			rail.Parent = folder
		end
	end

	self.Chambers = folder
end

--[[
	빈 방을 하나 잡는다. 다 차 있으면 nil.

	방이 없는데도 입장시키면 결국 누군가와 같은 자리에 서게 되므로, 여기서 막는 것이
	"겹침 없음"을 지키는 마지막 방벽이다.
]]
function TowerService:_allocateSlot(player: Player): number?
	local existing = self.PlayerSlot[player]
	if existing then
		return existing
	end
	for index = 1, TowerArena.SLOT_COUNT do
		if not self.Slots[index] then
			self.Slots[index] = player
			self.PlayerSlot[player] = index
			return index
		end
	end
	return nil
end

function TowerService:_freeSlot(player: Player)
	local index = self.PlayerSlot[player]
	if index then
		self.Slots[index] = nil
		self.PlayerSlot[player] = nil
	end
end

-- 배정된 방 한가운데로 옮긴다.
function TowerService:_placeInChamber(player: Player)
	local index = self.PlayerSlot[player]
	local character = player.Character
	if not index or not character then
		return
	end
	local stand = TowerArena.SlotStand(index)
	local origin = TowerArena.SlotOrigin(index)
	local position = Vector3.new(stand.X, stand.Y + 4, stand.Z)
	character:PivotTo(CFrame.lookAt(position, Vector3.new(origin.X + 20, position.Y, origin.Z)))
end

--[[
	등반을 끝낸다. 방을 반납하고 광장으로 돌려보낸다.

	성공·실패·포기·접속 종료가 모두 여기를 지나야 방이 새지 않는다.
]]
function TowerService:_releaseRun(player: Player, sendHome: boolean)
	self:_freeSlot(player)
	if sendHome and self.ReturnHome then
		self.ReturnHome(player)
	end
end

-- 등반문 앞인지. 문을 아직 안 지었으면 검사를 건너뛴다(테스트·초기화 순서 대비).
function TowerService:_atGate(player: Player): boolean
	local gate = self.Gate
	if not gate then
		return true
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - gate.Position).Magnitude <= GATE_RANGE
end

function TowerService:_profile(player: Player): any?
	return self.Profiles[player.UserId]
end

function TowerService:_session(player: Player): Session
	local session = self.Sessions[player]
	if not session then
		session = {
			Battle = nil,
			Offered = {},
			Threats = {},
			PickClass = false,
			Rng = Random.new(os.clock() * 1000 + player.UserId),
		}
		self.Sessions[player] = session
	end
	return session
end

--=== 전송 ===--

function TowerService:_publishTower(player: Player, message: string?)
	local profile = self:_profile(player)
	if not profile then
		return
	end
	local run = profile.TowerRun
	local offered = self:_session(player).Offered

	--[[
		Tags를 반드시 함께 보낸다.

		`CardArt`가 태그로 문양을 고른다. 예전 페이로드에는 Tags가 없어서, 그대로
		두면 340장이 전부 기본 문양(구슬) 하나로 그려진다.
	]]
	local cards = {}
	for _, card in offered do
		local level = run and CardDraft.CardLevel(run, card.Id) or 0
		table.insert(cards, {
			Id = card.Id,
			Name = card.Name,
			Grade = card.Grade,
			--[[
				**고르면 되는 레벨**의 수치를 보낸다(현재 레벨 + 1).

				요청("매 레벨마다 카드에 적힌 수치를 다르게")대로 설명 안의 숫자가
				레벨을 따라간다. 보상 화면에서 궁금한 것은 "지금 뭘 갖고 있나"가
				아니라 "이걸 고르면 얼마가 되나"이므로 다음 레벨로 그린다.
			]]
			Description = AbilityCardDefinitions.Describe(card, level + 1),
			Tags = card.Tags,
			Level = level,
		})
	end

	--[[
		보유 카드 목록(요청: "탑에선 항상 볼 수 있는 내 카드 목록").
		등반 중 얻은 카드를 등급·레벨과 함께 내려보낸다.
	]]
	local owned = {}
	if run then
		for _, progress in run.Cards do
			local definition = AbilityCardDefinitions.Get(progress.CardId)
			table.insert(owned, {
				Id = progress.CardId,
				Name = definition and definition.Name or progress.CardId,
				-- 보유 목록은 **지금 갖고 있는 레벨**의 수치를 보여준다.
				Description = if definition then AbilityCardDefinitions.Describe(definition, progress.Level) else "",
				Grade = progress.Grade,
				-- 목록 왼쪽의 작은 문양도 같은 그림을 쓰므로 태그가 필요하다.
				Tags = definition and definition.Tags or {},
				Level = progress.Level,
				MaxLevel = if definition
					then AbilityCardDefinitions.MaxLevelFor(definition)
					else AbilityCardDefinitions.MaxLevel(progress.Grade :: any),
			})
		end
		table.sort(owned, function(a, b)
			if a.Grade ~= b.Grade then
				return a.Grade < b.Grade
			end
			return a.Name < b.Name
		end)
	end

	local slot = PlayerProfile.ActiveSlot(profile)

	--[[
		배정된 등반실의 좌표를 함께 내려보낸다.

		클라이언트는 예전에 **자기 캐릭터 위치**에 격자를 깔았다. 그러면 두 사람이
		나란히 서서 동시에 등반할 때 전장이 겹친다. 이제 어디에 그릴지도 서버가 정한다.
	]]
	local chamber = self.PlayerSlot[player]
	local origin = chamber and TowerArena.SlotOrigin(chamber) or nil

	--[[
		직업 선택 화면에 띄울 목록. 등반문을 눌렀을 때만 채워 보낸다.
		이름·역할·체력은 전부 CharacterDefinitions에 있으므로 그대로 옮긴다.
	]]
	local classes = nil
	if self:_session(player).PickClass then
		classes = {}
		for _, definition in CharacterDefinitions.All() do
			table.insert(classes, {
				Id = definition.Id,
				Name = definition.Name,
				Role = definition.Role,
				Description = definition.Description,
				MaxHealth = definition.MaxHealth,
				Color = definition.Color,
			})
		end
	end

	self.Remotes.TowerState:FireClient(player, {
		Active = run ~= nil and run.Active,
		Floor = run and run.Floor or 0,
		PickClass = self:_session(player).PickClass,
		Classes = classes,
		ClassId = PlayerProfile.ActiveSlot(profile).ClassId,
		Chamber = chamber,
		Arena = origin,
		Owned = owned,
		--[[
			층마다 스탯을 찍을 수 있도록 슬롯 상태를 함께 보낸다(요청).
			등반 중 오른 레벨은 PendingLevel에 쌓이지만, 스탯 포인트는 **지금 쓸 수
			있어야** 등반 도중의 선택이 된다. 그래서 UnspentPoints를 그대로 노출한다.
		]]
		Level = slot.Level,
		UnspentPoints = slot.UnspentPoints,
		Stats = slot.Stats.Main,
		MaxFloor = TowerRewardDefinitions.MAX_FLOOR,
		Cost = run and run.Cost or 0,
		NextRerollCost = run and TowerRewardDefinitions.RerollCost(run.RerollCount) or 0,
		RemainingPicks = run and TowerRun.RemainingPicks(run) or 0,
		PendingLevel = run and run.PendingLevel or 0,
		HighestFloor = profile.Account.HighestFloor,
		Cards = cards,
		Message = message,
	})
end

--[[
	전투 스냅샷을 내려보낸다.

	threats는 "이번에 아군을 실제로 노리는 적" 목록이다. 라인이 어긋나면 비어 있고,
	그때는 회피 QTE 자체가 뜨지 않는다(사양의 라인 규칙이 그대로 연출로 이어진다).

	**항상 표 하나만 보낸다.** 경로마다 인자 개수가 다르면 클라이언트가 그걸 다 분기해야
	한다 — Threats를 페이로드 안에 넣어 모양을 하나로 고정했다.
]]
function TowerService:_publishBattle(player: Player, threats: { any }?)
	local session = self:_session(player)
	if not session.Battle then
		self.Remotes.GridState:FireClient(player, nil)
		return
	end
	local snapshot = GridBattle.Snapshot(session.Battle)
	snapshot.Threats = threats or {}
	self.Remotes.GridState:FireClient(player, snapshot)
end

--=== 등반 ===--

--[[
	등반을 시작하고 1층 전투를 연다.

	입장 제약(장비 보관 / 기본 무기 / 스탯 초기화)은 TowerRun.Start가 건다.
	여기서는 그 뒤에 첫 층 전투를 세우는 것만 맡는다.
]]
--[[
	등반문을 눌렀다. 바로 올리지 않고 **직업부터 고르게** 한다(요청).

	새 리모트를 파지 않고 TowerState에 깃발 하나를 얹는다 — 클라이언트는 이미 그
	페이로드를 그리고 있으므로 붙일 자리가 그대로 있다.
]]
function TowerService:PromptClass(player: Player)
	if not self:_profile(player) then
		return
	end
	if not self:_atGate(player) then
		self:_publishTower(player, "광장의 고대 대탑 앞에서만 등반을 시작할 수 있습니다.")
		return
	end
	self:_session(player).PickClass = true
	self:_publishTower(player, "등반할 직업을 고르세요.")
end

--[[
	[개발 전용] OP 결투사로 바로 등반을 시작한다.

	전투를 끝까지 굴려 보려면 1층에서 죽지 않는 캐릭터가 필요하다. 정상 경로는
	레벨 1·기본 무기라 3~4층이면 막히는데, 그때마다 손으로 올리기엔 오래 걸린다.

	**Studio에서만 통한다.** 라이브 서버에서 이 요청이 오면 그냥 무시한다 —
	클라이언트 버튼도 Studio에서만 뜨지만, 리모트는 누구나 쏠 수 있으므로 서버가
	직접 막아야 한다. 등반문 거리 검사는 건너뛴다(테스트 편의).
]]
function TowerService:DevEnter(player: Player)
	if not RunService:IsStudio() then
		return
	end
	local profile = self:_profile(player)
	if not profile then
		return
	end

	local slot = PlayerProfile.ActiveSlot(profile)
	slot.ClassId = "Duelist"

	local ok, reason = TowerRun.Start(profile)
	if not ok then
		self:_publishTower(player, reason)
		return
	end

	local chamber = self:_allocateSlot(player)
	if not chamber then
		TowerRun.Exit(profile)
		self:_publishTower(player, "등반실이 모두 찼습니다.")
		return
	end

	--[[
		`TowerRun.Start`가 레벨·스탯을 초기화한 **뒤에** 올린다. 순서를 뒤집으면
		초기화가 그대로 덮어써서 아무 효과가 없다.
	]]
	slot.Level = 40
	for _, statId in StatDefinitions.Order do
		slot.Stats.Main[statId] = 60
	end
	slot.UnspentPoints = 30
	slot.Items = {
		{
			Id = "DevOpBlade",
			Name = "[개발] 시험용 레이피어",
			Rarity = "Legendary" :: any,
			PrimaryStat = "Strength" :: any,
			StatRequirement = 0,
			BaseDamage = 400,
			StatBonus = nil,
			Affix = nil,
		},
	}

	self:_placeInChamber(player)
	self:_beginFloorBattle(player)
	self:_session(player).PickClass = false
	self:_publishTower(player, string.format("[개발] OP 결투사 — %d번 등반실", chamber))
end

--[[
	classId를 받으면 그 직업으로 등반을 시작한다.

	직업은 프리셋 슬롯(`slot.ClassId`)에 들어간다 — `TowerRun.Start`가 거기서 기본
	무기를 뽑고, 카드 풀도 같은 값으로 결정되기 때문이다.
]]
function TowerService:Enter(player: Player, classId: string?)
	local profile = self:_profile(player)
	if not profile then
		return
	end

	-- 요청: "따로 등반 장소로 가서 등반 해야 해."
	if not self:_atGate(player) then
		self:_publishTower(player, "광장의 고대 대탑 앞에서만 등반을 시작할 수 있습니다.")
		return
	end

	--[[
		클라이언트가 보낸 직업 이름을 **그대로 믿지 않는다.**
		없는 직업이면 슬롯에 써 넣는 순간 등반 내내 카드도 무기도 뽑히지 않는다.
	]]
	if classId ~= nil then
		if not CharacterDefinitions.IsValid(classId) then
			self:_publishTower(player, "그런 직업이 없습니다.")
			return
		end
		PlayerProfile.ActiveSlot(profile).ClassId = classId
	end

	--[[
		방을 먼저 잡는다.

		`TowerRun.Start`가 장비를 보관하고 스탯을 초기화한 **뒤에** 방이 없다고 되돌리면
		되돌릴 게 많아진다. 순서를 뒤집어 두면 실패해도 아무것도 건드리지 않은 상태다.
	]]
	local slot = self:_allocateSlot(player)
	if not slot then
		self:_publishTower(player, "등반실이 모두 찼습니다. 잠시 후 다시 시도하세요.")
		return
	end

	local ok, reason = TowerRun.Start(profile)
	if not ok then
		self:_freeSlot(player)
		self:_publishTower(player, reason)
		return
	end

	self:_placeInChamber(player)
	self:_beginFloorBattle(player)
	-- 선택 화면은 닫는다. 등반 중에 다시 뜨면 안 된다.
	self:_session(player).PickClass = false
	self:_publishTower(
		player,
		string.format(
			"%d번 등반실 — %s로 등반을 시작했습니다.",
			slot,
			CharacterDefinitions.Get(PlayerProfile.ActiveSlot(profile).ClassId).Name
		)
	)
	self.Persist(player)
end

--[[
	접속을 끊었다 돌아온 사람의 등반을 이어 준다.

	프로필은 `TowerRun`을 저장하므로(테스트: "restored run must keep its floor")
	재접속하면 등반이 살아 있다. 그런데 **등반실 배정은 세션에만 있다** — 서버가
	재시작됐거나 다른 서버로 붙었다면 방이 없다.

	방 없이 두면 클라이언트가 폴백으로 1번 방에 격자를 깔고, 마침 1번 방을 쓰는
	사람이 있으면 겹친다. 그래서 돌아온 순간 방부터 다시 잡는다.
]]
function TowerService:Resume(player: Player)
	local profile = self:_profile(player)
	local run = profile and profile.TowerRun
	if not run or not run.Active then
		return
	end

	local slot = self:_allocateSlot(player)
	if not slot then
		-- 방이 없으면 등반을 이어갈 자리가 없다. 장비를 돌려주고 정리한다.
		local summary = TowerRun.Exit(profile)
		self:_publishTower(
			player,
			string.format(
				"등반실이 없어 등반이 종료됐습니다. 장비 %d개 반환.",
				summary.ReturnedItems
			)
		)
		self.Persist(player)
		return
	end

	self:_placeInChamber(player)
	self:_beginFloorBattle(player)
	self:_publishTower(
		player,
		string.format("%d번 등반실 — %d층부터 이어서 오릅니다.", slot, TowerRun.NextFloor(run))
	)
end

-- 다음 층의 전투를 세운다. 아군 능력치는 슬롯 레벨에서 뽑는다.
function TowerService:_beginFloorBattle(player: Player)
	local profile = self:_profile(player)
	local run = profile and profile.TowerRun
	if not run then
		return
	end

	local slot = PlayerProfile.ActiveSlot(profile)
	local session = self:_session(player)
	local health = ProgressionDefinitions.MaxHealthWithStats(slot.Level, slot.Stats)
	local power = 0
	for _, item in slot.Items do
		power = math.max(power, item.BaseDamage or 0)
	end

	--[[
		신앙심을 함께 넘긴다. 월 필그림스 세 직업이 이 값으로 [광신]·[벽]의 수치를
		키운다(`상태이상.md`: "기도력은 스탯 신앙심의 오타임").
	]]
	local faith = StatDefinitions.TotalValue(slot.Stats, "Faith")

	--[[
		이번 층까지 모은 능력 카드를 그대로 넘긴다.

		여기가 카드와 전투가 만나는 **유일한 지점**이다. 보상 화면에서 고른 카드는
		`run.Cards`에 쌓이고, 다음 층 전투가 만들어질 때 이 줄을 타고 들어간다.
		그래서 고른 카드는 **다음 층부터** 적용된다 — 지금 싸우는 층에 소급되지 않는다.
	]]
	session.Battle =
		GridBattle.New(TowerRun.NextFloor(run), slot.Name, health, power, slot.ClassId, faith, nil, run.Cards)
	session.Offered = {}
	-- 지난 층의 위협이 남아 있으면 새 층에서 엉뚱한 회피 QTE가 뜬다.
	session.Threats = {}

	--[[
		첫 턴부터 예고가 보여야 한다. 이걸 안 하면 1턴에는 위협 칸이 비어 있고,
		플레이어가 아무 정보 없이 자리를 잡게 된다.
	]]
	GridBattle.EnemyPlan(session.Battle, function()
		return session.Rng:NextNumber()
	end)
	self:_publishBattle(player)
end

--[[
	층을 이겼다. 보상 화면으로 넘긴다.

	여기가 `TowerRun.ClearFloor`를 부르는 유일한 지점이다 — 전투 결과와 등반 진행이
	만나는 곳이라, 승리 판정을 GridBattle이 내리고 그 사실만 여기로 넘어온다.
]]
function TowerService:_onVictory(player: Player)
	local profile = self:_profile(player)
	if not profile or not profile.TowerRun then
		return
	end

	local session = self:_session(player)
	local levelBefore = profile.TowerRun.PendingLevel
	-- 마지막 일격의 결과(피해·쓰러짐)를 먼저 보낸다. 안 그러면 클라이언트는 그 타격을 못 그린다.
	self:_publishBattle(player)
	local draft = TowerRun.ClearFloor(profile, session.Rng:NextInteger(1, 2 ^ 30))
	session.Offered = draft.Cards
	session.Battle = nil

	--[[
		이번 층에서 오른 레벨만큼 스탯 포인트를 **바로** 준다(요청: "층마다 스탯도
		찍을 수 있게"). 완주 시 두 번 주지 않도록 준 양을 run에 적어 둔다.
	]]
	local run = profile.TowerRun
	local gained = (run.PendingLevel - levelBefore) * StatDefinitions.POINTS_PER_LEVEL
	if gained > 0 then
		PlayerProfile.ActiveSlot(profile).UnspentPoints += gained
		run.GrantedPoints += gained
	end

	self:_publishBattle(player)

	if TowerRun.IsCleared(profile.TowerRun) then
		local completed, summary = TowerRun.Complete(profile)
		if completed and summary then
			-- 정복도 등반의 끝이다. 방을 반납하고 광장으로 돌아간다.
			self:_releaseRun(player, true)
			self:_publishTower(
				player,
				string.format(
					"탑 정복! 레벨 +%d, 장비 %d개 반환",
					summary.GainedLevels,
					summary.ReturnedItems
				)
			)
			self.Persist(player)
			return
		end
	end

	self:_publishTower(player, string.format("%d층 클리어 — 보상을 고르세요.", profile.TowerRun.Floor))
	self.Persist(player)
end

-- 졌다. 사양대로 장비는 돌려주고 레벨은 날린다.
function TowerService:_onDefeat(player: Player)
	local profile = self:_profile(player)
	if not profile or not profile.TowerRun then
		return
	end
	local summary = TowerRun.Exit(profile)
	local session = self:_session(player)
	-- 쓰러지는 타격을 그릴 수 있게 마지막 상태를 먼저 보낸다
	self:_publishBattle(player)
	session.Battle = nil
	session.Offered = {}
	session.Threats = {}
	self:_publishBattle(player)
	self:_releaseRun(player, true)
	self:_publishTower(
		player,
		string.format(
			"%d층에서 쓰러졌다. 장비 %d개를 돌려받았다.",
			summary.Floor,
			summary.ReturnedItems
		)
	)
	self.Persist(player)
end

-- 승패가 갈렸으면 그에 맞게 처리한다. 전투 행동마다 이걸 통과시킨다.
function TowerService:_settle(player: Player): boolean
	local session = self:_session(player)
	local battle = session.Battle
	if not battle then
		return false
	end
	if battle.Outcome == "Victory" then
		self:_onVictory(player)
		return true
	elseif battle.Outcome == "Defeat" then
		self:_onDefeat(player)
		return true
	end
	return false
end

--[[
	보상을 고른 뒤 다음 층으로 넘어간다.
	고를 게 남아 있으면 아직 넘어가지 않는다(층당 획득 장수는 사양이 정한다).
]]
function TowerService:_advanceIfDone(player: Player)
	local profile = self:_profile(player)
	local run = profile and profile.TowerRun
	if not run or not run.Active then
		return
	end
	if TowerRun.RemainingPicks(run) > 0 then
		return
	end
	self:_beginFloorBattle(player)
	self:_publishTower(player, string.format("%d층으로 올라갑니다.", TowerRun.NextFloor(run)))
end

--=== 리모트 진입점 ===--

function TowerService:HandleTowerAction(player: Player, request: any)
	if typeof(request) ~= "table" then
		return
	end
	local profile = self:_profile(player)
	if not profile then
		return
	end

	local kind = tostring(request.Kind)

	if kind == "Enter" then
		self:Enter(player, if type(request.ClassId) == "string" then request.ClassId else nil)
	elseif kind == "DevEnter" then
		self:DevEnter(player)
	elseif kind == "PickClass" then
		self:PromptClass(player)
	elseif kind == "CancelPick" then
		self:_session(player).PickClass = false
		self:_publishTower(player)
	elseif kind == "Exit" then
		if profile.TowerRun then
			local summary = TowerRun.Exit(profile)
			local session = self:_session(player)
			session.Battle = nil
			session.Offered = {}
			session.Threats = {}
			self:_publishBattle(player)
			self:_releaseRun(player, true)
			self:_publishTower(
				player,
				string.format("등반을 그만뒀다. 장비 %d개 반환.", summary.ReturnedItems)
			)
			self.Persist(player)
		end
	elseif kind == "Reroll" then
		local session = self:_session(player)
		local draft = TowerRun.Reroll(profile, session.Rng:NextInteger(1, 2 ^ 30))
		if draft.Ok then
			session.Offered = draft.Cards
		end
		self:_publishTower(player, draft.Reason)
	elseif kind == "SpendStat" then
		--[[
			스탯 포인트를 하나 찍는다(요청: "층마다 스탯도 찍을 수 있게").

			어떤 스탯인지는 클라이언트가 고르지만, **포인트가 실제로 있는지와 스탯
			이름이 유효한지는 서버가 확인한다.**
		]]
		local run = profile.TowerRun
		if not run or not run.Active then
			return
		end
		local statId = tostring(request.StatId)
		local slot = PlayerProfile.ActiveSlot(profile)
		local valid = false
		for _, id in StatDefinitions.Order do
			if id == statId then
				valid = true
				break
			end
		end
		if not valid or slot.UnspentPoints <= 0 then
			self:_publishTower(player, "찍을 수 있는 포인트가 없습니다.")
			return
		end
		slot.UnspentPoints -= 1
		slot.Stats.Main[statId] = (slot.Stats.Main[statId] or 0) + 1
		local definition = StatDefinitions.Get(statId :: any)
		self:_publishTower(player, string.format("%s +1", definition and definition.Name or statId))
		self.Persist(player)
	elseif kind == "Acquire" then
		local session = self:_session(player)
		local cardId = tostring(request.CardId)
		local chosen: AbilityCardDefinitions.AbilityCard? = nil
		-- 제시한 목록 안에서만 고를 수 있다. 클라이언트가 보낸 Id를 그대로 믿지 않는다.
		for _, card in session.Offered do
			if card.Id == cardId then
				chosen = card
				break
			end
		end
		if not chosen then
			self:_publishTower(player, "제시된 카드가 아닙니다.")
			return
		end
		local ok, reason = TowerRun.Acquire(profile, chosen)
		if ok then
			--[[
				5층부터 등반이 멈추던 버그.

				사양: "5층 단위로 획득 가능한 능력 카드가 1개씩 증가한다."
				→ `AcquireSlotsForFloor = 1 + floor/5`라 5층은 2장이다.

				그런데 한 장 고르면 Offered를 비우기만 하고 **남은 장수를 위한 카드를 다시
				뽑지 않았다.** 그래서 5층에서 카드도 사라지고(고를 게 없음) 남은 획득이
				1이라 다음 층으로도 못 넘어가는 교착이 됐다.

				남은 장수가 있으면 **새로 제시**한다. 리롤이 아니므로 코스트는 받지 않는다.
			]]
			local run = profile.TowerRun
			if run and TowerRun.RemainingPicks(run) > 0 then
				--[[
					`AcquiredThisFloor`를 넘긴다. 필수 층에서 필수를 한 장 고른 직후라면
					이 값이 1이라 **다음 화면은 희귀·일반**이 된다
					(요청: "필수 카드 먼저 나오고 일반 희귀 카드가 나오도록").
				]]
				session.Offered = AbilityCardDefinitions.DrawForFloor(
					PlayerProfile.ActiveSlot(profile).ClassId,
					run.Floor,
					session.Rng:NextInteger(1, 2 ^ 30),
					CardDraft.MaxedCardIds(run),
					run.AcquiredThisFloor
				)
				self:_publishTower(
					player,
					string.format(
						"%s 획득 — %d장 더 고를 수 있습니다.",
						chosen.Name,
						TowerRun.RemainingPicks(run)
					)
				)
			else
				session.Offered = {}
				self:_publishTower(player, string.format("%s 획득", chosen.Name))
				self:_advanceIfDone(player)
			end
		else
			self:_publishTower(player, reason)
		end
		self.Persist(player)
	end
end

function TowerService:HandleGridAction(player: Player, request: any)
	if typeof(request) ~= "table" then
		return
	end
	local session = self:_session(player)
	local battle = session.Battle
	if not battle then
		return
	end

	local kind = tostring(request.Kind)

	if kind == "Move" then
		GridBattle.MoveAlly(battle, tonumber(request.X) or 1, tonumber(request.Y) or 1)
		self:_publishBattle(player)
		return
	end

	if kind == "Skill" then
		local grade = tostring(request.Grade)
		if not VALID_GRADES[grade] then
			return
		end
		--[[
			rng를 넘긴다. 연금술사 `섞기`가 병 종류를 굴리는 데 쓴다.
			서버 세션의 씨앗을 쓰므로 결과가 재현·검증된다.
		]]
		--[[
			SkillId도 함께 넘긴다. 강화 스킬이 열리고 닫히면 가드·명상의 번호가 한 칸
			밀리는데, 번호만 믿으면 그 틈에 엉뚱한 스킬이 나갈 수 있다.
			서버가 목록에 있는 Id인지 확인하므로 그대로 믿는 것은 아니다.
		]]
		GridBattle.ResolveSkill(battle, request.SkillIndex, grade :: any, function()
			return session.Rng:NextNumber()
		end, if type(request.SkillId) == "string" then request.SkillId else nil)
		if self:_settle(player) then
			return
		end

		--[[
			**이미 예고돼 있던** 적 공격을 해소한다. 여기서 새로 고르지 않는다.

			예전에는 이 자리에서 적이 움직이고 스킬을 고른 **뒤 그대로 때렸다.**
			그래서 플레이어는 예고를 볼 틈이 없었고, 라인을 비켜서 피한다는 선택이
			아예 성립하지 않았다("적 공격이 한 템포 빠르다"). 이제 다음 예고는 턴이
			끝날 때(`_pumpThreats`) 만든다.

			라인이 겹쳐 실제로 닿는 적만 회피 QTE 대상이 된다 — 플레이어가 방금
			비켜섰으면 그 공격은 그냥 빗나간다.
		]]
		local threats = {}
		for _, enemy in GridBattle.PlannedThreats(battle) do
			local foeSkill = BattleSkills.ByIndex(BattleSkills.Enemy(), enemy.SkillIndex)
			table.insert(threats, {
				Id = enemy.Id,
				Name = enemy.Name,
				SkillId = foeSkill.Id,
				SkillName = foeSkill.Name,
			})
		end
		--[[
			노린 적을 **줄로 세운다**.

			처음엔 목록을 통째로 내려보내고 클라이언트가 첫 번째만 회피 QTE로 띄웠다.
			그러면 적이 2~3기 동시에 노려도 **나머지 공격이 그냥 사라진다**. 한 명씩
			차례로 판정해야 하므로 대기열을 서버가 들고, 한 번에 하나만 내려보낸다.
		]]
		session.Threats = threats
		self:_pumpThreats(player)
		return
	end

	if kind == "Dodge" then
		local grade = tostring(request.Grade)
		if not VALID_GRADES[grade] then
			return
		end
		--[[
			**대상은 서버가 고른다.** 클라이언트가 보낸 EnemyId는 쓰지 않는다.

			처음엔 "대기열 맨 앞과 일치할 때만 수락"으로 짰는데, 그러면 어긋난 순간
			서버는 거부하고 클라이언트는 이미 QTE를 닫아 다시 보낼 수도 없어 **턴이
			영구히 멈춘다**(교착). 순서를 정하는 것이 서버이니 대상도 서버가 집으면
			그 경우가 아예 없어지고, 권위 경계("클라는 등급만")도 더 깨끗해진다.
		]]
		local queue = session.Threats or {}
		if #queue == 0 then
			return
		end
		local pending = table.remove(queue, 1)
		local enemyId = pending.Id

		GridBattle.ResolveDodge(battle, enemyId, grade :: any)
		if self:_settle(player) then
			return
		end
		self:_pumpThreats(player)
		return
	end
end

--[[
	대기열에 남은 적이 있으면 그 하나만 내려보내고, 다 끝났으면 턴을 마무리한다.
]]
function TowerService:_pumpThreats(player: Player)
	local session = self:_session(player)
	local battle = session.Battle
	if not battle then
		return
	end
	local queue = session.Threats or {}
	if #queue > 0 then
		self:_publishBattle(player, { queue[1] })
		return
	end
	session.Threats = {}
	GridBattle.EndTurn(battle)

	--[[
		턴이 끝났으니 **다음 턴 적 행동을 미리 예고한다.**

		여기서 예고해 두면 플레이어는 자기 차례를 시작할 때 이미 위협 칸을 볼 수
		있다. 그게 라인을 비켜설 근거가 된다.
	]]
	if battle.Outcome == "Ongoing" then
		GridBattle.EnemyPlan(battle, function()
			return session.Rng:NextNumber()
		end)
	end
	self:_publishBattle(player)
end

function TowerService:Remove(player: Player)
	self.Sessions[player] = nil
	-- 접속을 끊어도 방은 반납해야 한다. 안 그러면 자리가 하나씩 새어나간다.
	self:_releaseRun(player, false)
end

return TowerService
