--!strict

local DataStoreService = game:GetService("DataStoreService")

local MotionStorage = {}
local profileStore: GlobalDataStore? = nil
local legacyStore: GlobalDataStore? = nil

local function getStore(name: string, current: GlobalDataStore?): (GlobalDataStore?, string?)
	if current then
		return current, nil
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if not ok then
		return nil, tostring(result)
	end
	return result, nil
end

function MotionStorage.LoadProfile(userId: number): (any?, string?)
	local resolved, resolveError = getStore("PorcelainProfiles_v2", profileStore)
	if not resolved then
		return nil, resolveError
	end
	profileStore = resolved
	local ok, result = pcall(function()
		return resolved:GetAsync("u_" .. userId)
	end)
	if not ok then
		return nil, tostring(result)
	end
	if result ~= nil then
		return result, nil
	end

	local legacy, legacyError = getStore("PorcelainMotionPacks_v1", legacyStore)
	if not legacy then
		return nil, legacyError
	end
	legacyStore = legacy
	local legacyOk, legacyPack = pcall(function()
		return legacy:GetAsync("u_" .. userId)
	end)
	if not legacyOk then
		return nil, tostring(legacyPack)
	end
	if legacyPack then
		return {
			Version = 2,
			Packs = { legacy = legacyPack },
			Equipped = { Berserker = "legacy" },
			SelectedCharacterId = "Berserker",
			HighestFloor = 0,
		},
			nil
	end
	return {
		Version = 2,
		Packs = {},
		Equipped = {},
		SelectedCharacterId = "Berserker",
		HighestFloor = 0,
	},
		nil
end

function MotionStorage.SaveProfile(userId: number, profile: any): (boolean, string?)
	local resolved, resolveError = getStore("PorcelainProfiles_v2", profileStore)
	if not resolved then
		return false, resolveError
	end
	profileStore = resolved
	local ok, result = pcall(function()
		resolved:SetAsync("u_" .. userId, profile)
	end)
	return ok, ok and nil or tostring(result)
end

return MotionStorage
