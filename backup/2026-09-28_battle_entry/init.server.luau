--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityCards = require(ReplicatedStorage.Shared.AbilityCards)
local CharacterDefinitions = require(ReplicatedStorage.Shared.CharacterDefinitions)
local Constants = require(ReplicatedStorage.Shared.Constants)
local PlayerProfile = require(ReplicatedStorage.Shared.PlayerProfile)
local MotionStorage = require(script.MotionStorage)
local MotionValidator = require(script.MotionValidator)
local PlazaService = require(script.PlazaService)
local PrototypeTests = require(script.PrototypeTests)
local TowerService = require(script.TowerService)

Players.CharacterAutoLoads = false

--[[
	직업 카드를 실제로 등록한다.

	`AbilityCardDefinitions`는 빈 표로 시작하고, 각 직업 카드 모듈을 여기서 밀어
	넣어야 `DrawForFloor`가 뭔가를 돌려준다. 그런데 이 호출이 지금까지
	**PrototypeTests 안에만** 있었다 — 테스트가 검증하는 김에 등록까지 대신 해 준
	것이었다.

	그 결과
	  - 배포된(퍼블리시된) 서버는 `RunService:IsStudio()`가 거짓이라 테스트 자체가
	    안 돌아가고, 카드 풀이 **영원히 비어 있었다.**
	  - Studio에서도 `task.defer`로 미뤄 두는 호출이라 타이밍이 보장되지 않았다.

	그래서 층을 깨도 카드가 0장 나오고, 보상 화면이 뜨지 않은 채 등반이 그대로
	멈춘 것처럼 보였다. 이제 서버가 켜지자마자, 테스트 여부와 무관하게 직접 등록한다.
]]
AbilityCards.Register()

if RunService:IsStudio() then
	task.defer(PrototypeTests.Run)
end

local remoteFolder = ReplicatedStorage:FindFirstChild(Constants.REMOTE_FOLDER) or Instance.new("Folder")
remoteFolder.Name = Constants.REMOTE_FOLDER
remoteFolder.Parent = ReplicatedStorage

for _, name in Constants.REMOTES do
	if not remoteFolder:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remoteFolder
	end
end

local plaza = PlazaService.new()
local sessionProfiles: { [number]: any } = {}
local creatingCharacters: { [Player]: boolean } = {}

--[[
	프로필을 v3(`PlayerProfile`)로 올렸다.

	여태 서버는 모션 팩만 담는 v2 표를 직접 들고 있었다. 그래서 육성·아이템·탑 진행
	(`PlayerProfile` / `TowerRun`)이 아무 데도 붙어 있지 않았고, 탑을 굴려도 저장할
	곳이 없었다. 이제 저장 단위는 v3 하나다.

	  Account   모션 팩·장착·명예·프리셋 슬롯·최고 층 (계정 귀속)
	  Slots     프리셋별 레벨·스탯·아이템
	  TowerRun  등반 중에만 존재

	**클라이언트로 나가는 InventoryState 모양은 그대로 둔다.** 모션 에디터·인벤토리
	UI가 그 모양을 읽고 있어서, 여기서 같이 바꾸면 UI가 통째로 깨진다.
]]
local function defaultProfile(): any
	return PlayerProfile.New()
end

local function sanitizeProfile(raw: any): any
	local source = typeof(raw) == "table" and raw or {}

	-- 아주 오래된 저장본은 팩이 아니라 프리셋 표 하나였다. 그 시절 것을 팩 하나로 감싼다.
	if source.Presets then
		source = {
			Version = 2,
			Packs = { legacy = source },
			Equipped = { Berserker = "legacy" },
			SelectedCharacterId = source.SelectedCharacterId,
			HighestFloor = source.HighestFloor,
		}
	end

	-- v2면 v3로 옮기고(Migrate), 어느 쪽이든 값 범위를 강제한다(Sanitize).
	local profile = PlayerProfile.Sanitize(PlayerProfile.Migrate(source))

	-- 모션 팩은 전용 검증기가 따로 있다. 옮겨온 것을 한 번 더 거른다.
	local packs: { [string]: any } = {}
	for rawId, rawPack in profile.Account.Packs do
		local id = string.sub(string.gsub(tostring(rawId), "[^%w_%-]", ""), 1, 48)
		local pack = MotionValidator.SanitizePack(rawPack)
		if id ~= "" and pack then
			packs[id] = pack
		end
	end
	profile.Account.Packs = packs

	local equipped: { [string]: string } = {}
	for rawCharacterId, rawPackId in profile.Account.Equipped do
		local characterId = tostring(rawCharacterId)
		local packId = tostring(rawPackId)
		if CharacterDefinitions.IsValid(characterId) and packs[packId] then
			equipped[characterId] = packId
		end
	end
	profile.Account.Equipped = equipped

	if not CharacterDefinitions.IsValid(profile.Account.SelectedCharacterId) then
		profile.Account.SelectedCharacterId = "Berserker"
	end
	return profile
end

local function publishInventory(player: Player, profile: any)
	remoteFolder.InventoryState:FireClient(player, {
		Version = 2,
		Packs = profile.Account.Packs,
		Equipped = profile.Account.Equipped,
		SelectedCharacterId = profile.Account.SelectedCharacterId,
		HighestFloor = profile.Account.HighestFloor,
	})
end

local function persistProfile(player: Player, profile: any): boolean
	local saved, saveError = MotionStorage.SaveProfile(player.UserId, profile)
	if not saved then
		warn("Profile DataStore save failed:", player.UserId, saveError)
	end
	return saved
end

local function ensureR6(player: Player): Model?
	while creatingCharacters[player] do
		task.wait()
	end
	local current = player.Character
	local humanoid = current and current:FindFirstChildOfClass("Humanoid")
	if current and humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
		return current
	end
	creatingCharacters[player] = true
	local description = Instance.new("HumanoidDescription")
	local fetched, result = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
	end)
	if fetched and result then
		description = result
	end
	local created, character = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
	end)
	creatingCharacters[player] = nil
	if not created or not character then
		warn("Failed to create R6 character for", player.Name, character)
		return nil
	end
	if not player.Parent then
		character:Destroy()
		return nil
	end
	character.Name = player.Name
	character.Parent = workspace
	player.Character = character
	return character
end

--[[
	탑 등반 + 격자 전투.

	사양이 기존 전투(파티·행동 선택)를 폐기하라고 했으므로, 전투는 전부
	`TowerService`(→ `TowerRun` + `GridBattle`)가 맡는다. 원정대 시스템
	(`BattleService`)은 삭제됐다.

	판정은 서버에 있고, 클라이언트는 의도만 보낸다.
]]
local tower = TowerService.new(remoteFolder, sessionProfiles, function(player: Player)
	local profile = sessionProfiles[player.UserId]
	if profile then
		task.spawn(function()
			persistProfile(player, profile)
		end)
	end
end, function(player: Player)
	-- 등반이 끝나면 광장으로 돌려보낸다. 탑은 광장을 몰라도 되도록 함수로 넘긴다.
	plaza:PlacePlayer(player)
end)

--[[
	광장의 등반문과 탑을 잇는다.

	요청("등반 장소로 가서 등반")대로 여기가 **유일한 정식 입구**다. UI 버튼도 같은
	TowerAction을 쏘지만, `TowerService`가 문과의 거리를 다시 재므로 멀리서는 거절된다.
]]
tower:SetGate(plaza.TowerGate)
if plaza.TowerGatePrompt then
	plaza.TowerGatePrompt.Triggered:Connect(function(player)
		-- 바로 올리지 않는다. 직업부터 고르게 한다.
		tower:PromptClass(player)
	end)
end

remoteFolder.TowerAction.OnServerEvent:Connect(function(player, request)
	tower:HandleTowerAction(player, request)
end)

remoteFolder.GridAction.OnServerEvent:Connect(function(player, request)
	tower:HandleGridAction(player, request)
end)

remoteFolder.SaveMotion.OnServerEvent:Connect(function(player, payload)
	local profile = sessionProfiles[player.UserId] or defaultProfile()
	sessionProfiles[player.UserId] = profile
	local rawMotion = typeof(payload) == "table" and payload.Pack or payload
	local motion, err
	local savedPackId: string? = nil
	if typeof(rawMotion) == "table" and rawMotion.Presets then
		motion, err = MotionValidator.SanitizePack(rawMotion)
	else
		motion, err = MotionValidator.Sanitize(rawMotion)
	end
	if motion and motion.Presets then
		local requestedId = typeof(payload) == "table" and tostring(payload.PackId or "") or ""
		local packId = string.sub(string.gsub(requestedId, "[^%w_%-]", ""), 1, 48)
		if packId == "" then
			packId = string.gsub(HttpService:GenerateGUID(false), "%-", "")
		end
		profile.Account.Packs[packId] = motion
		savedPackId = packId
		local persisted = persistProfile(player, profile)
		err = persisted and "모션 인벤토리에 저장 완료"
			or "세션 저장 완료 (DataStore API 확인 필요)"
		publishInventory(player, profile)
	end
	remoteFolder.MotionSaved:FireClient(player, motion ~= nil, err or "모션 저장 완료", motion, savedPackId, nil)
end)

remoteFolder.RequestMotion.OnServerEvent:Connect(function(player, requestedCharacterId)
	local profile = sessionProfiles[player.UserId] or defaultProfile()
	local characterId = tostring(requestedCharacterId or profile.Account.SelectedCharacterId)
	if not CharacterDefinitions.IsValid(characterId) then
		characterId = profile.Account.SelectedCharacterId
	end
	local packId = profile.Account.Equipped[characterId]
	local motion = packId and profile.Account.Packs[packId]
	remoteFolder.MotionSaved:FireClient(
		player,
		motion ~= nil,
		motion and "계정 모션 불러오기 완료" or "저장된 모션 없음",
		motion
	)
end)

remoteFolder.RequestInventory.OnServerEvent:Connect(function(player)
	local profile = sessionProfiles[player.UserId] or defaultProfile()
	sessionProfiles[player.UserId] = profile
	publishInventory(player, profile)
end)

remoteFolder.EquipMotion.OnServerEvent:Connect(function(player, rawCharacterId, rawPackId)
	local profile = sessionProfiles[player.UserId] or defaultProfile()
	local characterId = tostring(rawCharacterId)
	local packId = tostring(rawPackId or "")
	if not CharacterDefinitions.IsValid(characterId) then
		return
	end
	if packId == "" then
		profile.Account.Equipped[characterId] = nil
	elseif profile.Account.Packs[packId] then
		profile.Account.Equipped[characterId] = packId
	else
		return
	end
	profile.Account.SelectedCharacterId = characterId
	sessionProfiles[player.UserId] = profile
	persistProfile(player, profile)
	publishInventory(player, profile)
end)

local function onPlayerAdded(player: Player)
	task.spawn(function()
		local rawProfile, loadError = MotionStorage.LoadProfile(player.UserId)
		local profile = sanitizeProfile(rawProfile)
		sessionProfiles[player.UserId] = profile
		if loadError then
			warn("Profile DataStore load failed:", player.UserId, loadError)
		end
		local character = ensureR6(player)
		if character then
			plaza:PlacePlayer(player)
			remoteFolder.PlazaState:FireClient(player, "Ready")
		end
		publishInventory(player, profile)
		--[[
			등반 중에 나갔던 사람이면 등반실을 다시 배정하고 이어서 올린다.
			광장에 세운 **뒤에** 부른다 — 이어가는 경우 다시 하늘로 옮겨야 하므로
			순서가 뒤집히면 광장 좌표가 나중에 덮어쓴다.
		]]
		tower:Resume(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	tower:Remove(player)
	creatingCharacters[player] = nil
	sessionProfiles[player.UserId] = nil
end)
