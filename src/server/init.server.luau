--!strict

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
local BattleService = require(script.BattleService)
local TowerRun = require(ReplicatedStorage.Shared.TowerRun)

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

-- 스튜디오 애니메이션 편집기로 고친 전투 모션을 클라이언트로(인형 무대는 치운다)
require(script.MotionStudioService).Start()

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

	모션 에디터·인벤토리 UI 와 그 리모트는 2026-09-29 뺐다(다시 설계할 때까지).
	저장된 모션 팩(Account.Packs·Equipped)은 지우지 않고 계속 검증·저장한다.
]]
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
	격자 전투 입장·세션 (2026-09-28). 예전 탑 입장(`TowerService`, 광장 등반문)은 지웠다.
	디버그 패널·필드 만남 몹으로 들어가고, 판정은 `GridBattle` 이 서버에서 한다.
	하늘 전장에서 돌아갈 자리를 모르면 스폰으로 보낸다.
]]
local battles = BattleService.new(remoteFolder, function(player: Player)
	plaza:PlacePlayer(player)
end)

remoteFolder.BattleAction.OnServerEvent:Connect(function(player, request)
	battles:HandleAction(player, request)
end)

remoteFolder.GridAction.OnServerEvent:Connect(function(player, request)
	battles:HandleGridAction(player, request)
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
		--[[
			탑 입장을 걷어냈으므로 저장본에 **살아 있는 등반**이 남아 있으면 끝내 준다.
			등반을 시작할 때 장비를 보관함(StoredItems)으로 옮겼기 때문에, 그대로 두면 장비가 갇힌다.
		]]
		if profile.TowerRun and profile.TowerRun.Active then
			local summary = TowerRun.Exit(profile)
			warn(string.format("[Battle] %s 의 남은 탑 등반을 끝냄 — 장비 %d개 돌려줌", player.Name, summary.ReturnedItems))
			persistProfile(player, profile)
		end
		battles:Hello(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	battles:Remove(player)
	creatingCharacters[player] = nil
	sessionProfiles[player.UserId] = nil
end)
