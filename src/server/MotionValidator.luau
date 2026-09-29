--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local CharacterDefinitions = require(ReplicatedStorage.Shared.CharacterDefinitions)

local MotionValidator = {}

local VALID_JOINTS = {
	["Right Shoulder"] = true,
	["Left Shoulder"] = true,
	["Right Hip"] = true,
	["Left Hip"] = true,
	Neck = true,
	RootJoint = true,
}

local function finite(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function vector(raw: any, minimum: number, maximum: number, fallback: number?): any
	local value = typeof(raw) == "table" and raw or {}
	return {
		X = math.clamp(tonumber(value.X) or fallback or 0, minimum, maximum),
		Y = math.clamp(tonumber(value.Y) or fallback or 0, minimum, maximum),
		Z = math.clamp(tonumber(value.Z) or fallback or 0, minimum, maximum),
	}
end

local function assetId(raw: any): string
	local digits = string.match(tostring(raw or ""), "%d+")
	return digits and ("rbxassetid://" .. string.sub(digits, 1, 20)) or ""
end

local function colorHex(raw: any): string
	local digits = string.upper(string.gsub(tostring(raw or ""), "[^%x]", ""))
	if #digits == 3 then
		digits = string.sub(digits, 1, 1):rep(2) .. string.sub(digits, 2, 2):rep(2) .. string.sub(digits, 3, 3):rep(2)
	end
	return #digits == 6 and ("#" .. digits) or "#FFFFFF"
end

local function sanitizeWeapon(raw: any): any
	local weapon = typeof(raw) == "table" and raw or {}
	return {
		Position = vector(weapon.Position, -8, 8),
		Rotation = vector(weapon.Rotation, -180, 180),
		AssetId = assetId(weapon.AssetId),
		Size = {
			X = math.clamp(tonumber(weapon.Size and weapon.Size.X) or 0.35, 0.1, 12),
			Y = math.clamp(tonumber(weapon.Size and weapon.Size.Y) or 3, 0.1, 12),
			Z = math.clamp(tonumber(weapon.Size and weapon.Size.Z) or 0.12, 0.05, 4),
		},
		FlipX = weapon.FlipX == true,
		FlipY = weapon.FlipY == true,
	}
end

local function sanitizeDecorations(raw: any): { any }
	local result = {}
	local source = typeof(raw) == "table" and raw or {}
	for index, decoration in source do
		if index > 5 then
			break
		end
		if typeof(decoration) == "table" then
			table.insert(result, {
				Name = string.sub(tostring(decoration.Name or ("장식 " .. index)), 1, 24),
				AssetId = assetId(decoration.AssetId),
				Attach = decoration.Attach == "Head" and "Head" or "Root",
				Offset = vector(decoration.Offset, -20, 20),
				Rotation = vector(decoration.Rotation, -360, 360),
				Size = vector(decoration.Size, 0.1, 12, 2),
				Layer = math.clamp(math.floor(tonumber(decoration.Layer) or index), 1, 12),
			})
		end
	end
	return result
end

local function sanitizeLayerOrder(raw: any, decorationCount: number, dualWield: boolean): { string }
	local wanted = { "Player", "Weapon" }
	if dualWield then
		table.insert(wanted, "DualWeapon")
	end
	for index = 1, decorationCount do
		table.insert(wanted, "Decoration:" .. index)
	end
	local allowed = {}
	for _, key in wanted do
		allowed[key] = true
	end
	local result = {}
	local used = {}
	for _, key in (typeof(raw) == "table" and raw or {}) do
		key = tostring(key)
		if allowed[key] and not used[key] then
			table.insert(result, key)
			used[key] = true
		end
	end
	for _, key in wanted do
		if not used[key] then
			table.insert(result, key)
		end
	end
	return result
end

local function sanitizeEvents(rawEvents: any, frameCount: number): any
	local result = { Effects = {}, Projectiles = {}, Teleports = {} }
	local source = typeof(rawEvents) == "table" and rawEvents or {}
	local validEffectPresets = { slash = true, spark = true, burst = true, ring = true, smoke = true }
	for _, kind in { "Effects", "Projectiles", "Teleports" } do
		local bucket = typeof(source[kind]) == "table" and source[kind] or {}
		for index, event in bucket do
			if index > 64 then
				break
			end
			if typeof(event) == "table" then
				table.insert(result[kind], {
					Frame = math.clamp(math.floor(tonumber(event.Frame) or 1), 1, frameCount),
					AssetId = assetId(event.AssetId),
					Offset = vector(event.Offset, -20, 20),
					Size = vector(event.Size, -20, 20, 2),
					Rotation = vector(event.Rotation, -360, 360),
					Duration = math.clamp(tonumber(event.Duration) or 0.35, 0.05, 10),
					ColorHex = colorHex(event.ColorHex),
					Opacity = math.clamp(tonumber(event.Opacity) or 1, 0, 1),
					FlipX = event.FlipX == true,
					FlipY = event.FlipY == true,
					DirectionMode = (event.DirectionMode == "target" or event.DirectionMode == "fixed")
							and event.DirectionMode
						or "facing",
					FixedAngle = math.clamp(tonumber(event.FixedAngle) or 0, -180, 180),
					Speed = math.clamp(tonumber(event.Speed) or 12, 1, 100),
					EndFrame = math.clamp(
						math.floor(tonumber(event.EndFrame) or tonumber(event.Frame) or 1),
						math.clamp(math.floor(tonumber(event.Frame) or 1), 1, frameCount),
						frameCount
					),
					EffectPreset = validEffectPresets[tostring(event.EffectPreset)] and tostring(event.EffectPreset)
						or "slash",
				})
			end
		end
	end
	return result
end

local VALID_STATUS = { slow = true, bleed = true, burn = true, stun = true, airborne = true }
local VALID_BUFF = {
	damageUp = true,
	dotGuard = true,
	skillGuard = true,
	moveSpeed = true,
	shield = true,
	iframe = true,
}
local VALID_CAST_DIRECTION = { target = true, preserve = true, away = true }

local function combatCost(combat: any, presetKey: string): number
	local cost = math.floor((combat.Damage or 0) * (presetKey == "Ultimate" and 1 or 1.5) + 0.5)
	if presetKey ~= "Basic" and presetKey ~= "Heavy" and presetKey ~= "Ultimate" then
		cost += math.max(0, 3 - (combat.CooldownTurns or 0)) * 8
	end
	cost += math.floor((combat.Knockback or 0) / 5) * 2
	cost += (combat.TargetCount - 1) * 10
	local defaultGain = (presetKey == "Basic" or presetKey == "Heavy") and 5 or 10
	if presetKey ~= "Ultimate" then
		cost += math.max(0, math.floor(((combat.UltimateGain or defaultGain) - defaultGain) / 5)) * 3
	end
	for _, status in combat.Statuses do
		if status.Type == "bleed" or status.Type == "burn" then
			cost += status.Power * 4 + status.Stacks * 5
		else
			cost += status.DurationTurns * ((status.Type == "stun" or status.Type == "airborne") and 15 or 8)
		end
	end
	for _, buff in combat.Buffs do
		cost += math.floor(buff.Value * (buff.Type == "iframe" and 3 or 0.5))
		cost += buff.DurationTurns * 3
	end
	return math.floor(cost + 0.5)
end

local function sanitizeCombat(raw: any, presetKey: string, frameCount: number, enforceBudget: boolean?): (any?, string?)
	local source = typeof(raw) == "table" and raw or {}
	local statuses = {}
	for index, status in (typeof(source.Statuses) == "table" and source.Statuses or {}) do
		if index > 8 then
			break
		end
		if typeof(status) == "table" and VALID_STATUS[tostring(status.Type)] then
			local kind = tostring(status.Type)
			table.insert(statuses, {
				Type = kind,
				ApplyFrame = math.clamp(math.floor(tonumber(status.ApplyFrame) or 1), 1, frameCount),
				Power = (kind == "bleed" or kind == "burn")
						and math.clamp(math.floor(tonumber(status.Power) or 2), 1, 9)
					or 0,
				Stacks = (kind == "bleed" or kind == "burn")
						and math.clamp(math.floor(tonumber(status.Stacks) or 2), 1, 3)
					or 0,
				DurationTurns = math.clamp(math.floor(tonumber(status.DurationTurns) or 1), 0, 10),
			})
		end
	end
	local buffs = {}
	for index, buff in (typeof(source.Buffs) == "table" and source.Buffs or {}) do
		if index > 8 then
			break
		end
		if typeof(buff) == "table" and VALID_BUFF[tostring(buff.Type)] then
			local kind = tostring(buff.Type)
			if kind ~= "iframe" or presetKey == "Ultimate" then
				table.insert(buffs, {
					Type = kind,
					ApplyFrame = math.clamp(math.floor(tonumber(buff.ApplyFrame) or 1), 1, frameCount),
					Value = math.clamp(
						tonumber(buff.Value) or (kind == "iframe" and 5 or 10),
						0,
						kind == "iframe" and 30 or 50
					),
					DurationTurns = kind == "iframe" and 0
						or math.clamp(math.floor(tonumber(buff.DurationTurns) or 2), 0, 10),
				})
			end
		end
	end
	local combat = {
		Enabled = source.Enabled ~= false,
		Damage = math.clamp(
			math.floor(
				tonumber(source.Damage)
					or (presetKey == "Ultimate" and 60 or (presetKey == "Guard" or presetKey == "Dash") and 0 or 20)
			),
			0,
			presetKey == "Ultimate" and 100 or 60
		),
		CooldownTurns = (presetKey == "Basic" or presetKey == "Heavy" or presetKey == "Ultimate") and 0
			or math.clamp(math.floor(tonumber(source.CooldownTurns) or 2), 0, 10),
		Knockback = math.clamp(math.floor(tonumber(source.Knockback) or 0), 0, 200),
		TargetCount = math.clamp(math.floor(tonumber(source.TargetCount) or 1), 1, 3),
		CastDirection = VALID_CAST_DIRECTION[tostring(source.CastDirection)] and tostring(source.CastDirection)
			or "target",
		Ranged = source.Ranged == true,
		UltimateGain = math.clamp(
			math.floor(tonumber(source.UltimateGain) or ((presetKey == "Basic" or presetKey == "Heavy") and 5 or 10)),
			0,
			35
		),
		DashDistance = presetKey == "Dash" and math.clamp(math.floor(tonumber(source.DashDistance) or 120), 0, 320)
			or 0,
		HeavyAfter = presetKey == "Heavy" and math.clamp(math.floor(tonumber(source.HeavyAfter) or 3), 1, 5) or 0,
		Statuses = statuses,
		Buffs = buffs,
	}
	if enforceBudget ~= false and combatCost(combat, presetKey) > 100 then
		return nil, "프리셋 예산 100을 초과함"
	end
	return combat, nil
end

function MotionValidator.Sanitize(raw: any, enforceBudget: boolean?): (any?, string?)
	if typeof(raw) ~= "table" or typeof(raw.Frames) ~= "table" then
		return nil, "잘못된 모션 데이터"
	end
	local duration = math.clamp(tonumber(raw.Duration) or 0.6, 0.1, Constants.MAX_MOTION_DURATION)
	if #raw.Frames < 2 or #raw.Frames > Constants.MAX_MOTION_FRAMES then
		return nil, "프레임 수 제한 위반"
	end
	local frames = {}
	local currentCastDirection = "target"
	local dualWield = raw.DualWield == true
	for _, frame in raw.Frames do
		if typeof(frame) ~= "table" or not finite(frame.Time) then
			return nil, "프레임 시간 오류"
		end
		local joints = {}
		local jointRotations = {}
		local jointOffsets = {}
		for jointName, pose in frame.Joints or {} do
			if VALID_JOINTS[jointName] and typeof(pose) == "table" then
				joints[jointName] = {
					X = tonumber(pose.X) or 0,
					Y = tonumber(pose.Y) or 0,
					Z = tonumber(pose.Z) or 0,
				}
			end
		end
		for jointName, rotation in frame.JointRotations or {} do
			if
				VALID_JOINTS[jointName]
				and typeof(rotation) == "table"
				and finite(rotation.X)
				and finite(rotation.Y)
				and finite(rotation.Z)
				and finite(rotation.W)
			then
				jointRotations[jointName] = {
					X = rotation.X,
					Y = rotation.Y,
					Z = rotation.Z,
					W = rotation.W,
				}
			end
		end
		for jointName, offset in frame.JointOffsets or {} do
			if VALID_JOINTS[jointName] and typeof(offset) == "table" then
				jointOffsets[jointName] = vector(offset, -6, 6)
			end
		end
		if VALID_CAST_DIRECTION[tostring(frame.CastDirection)] then
			currentCastDirection = tostring(frame.CastDirection)
		end
		local decorations = sanitizeDecorations(frame.Decorations)
		table.insert(frames, {
			Time = math.clamp(frame.Time, 0, duration),
			Joints = joints,
			JointRotations = jointRotations,
			JointOffsets = jointOffsets,
			CastDirection = currentCastDirection,
			RootOffset = vector(frame.RootOffset, -20, 20),
			Weapon = sanitizeWeapon(frame.Weapon),
			DualWeapon = typeof(frame.DualWeapon) == "table" and sanitizeWeapon(frame.DualWeapon) or nil,
			HandSwap = frame.HandSwap == true,
			Decorations = decorations,
			LayerOrder = sanitizeLayerOrder(frame.LayerOrder, #decorations, dualWield),
		})
	end
	table.sort(frames, function(a, b)
		return a.Time < b.Time
	end)
	local hits = {}
	local totalRatio = 0
	local attackRatios: { [string]: number } = {}
	if #(raw.Hits or {}) > 128 then
		return nil, "히트박스 수 제한 위반"
	end
	for _, hit in raw.Hits or {} do
		if typeof(hit) == "table" then
			local ratio = math.clamp(tonumber(hit.DamageRatio) or 0, 0, 1)
			local attackId = string.sub(tostring(hit.AttackId or "Hit"), 1, 32)
			local previousRatio = attackRatios[attackId]
			if previousRatio and math.abs(previousRatio - ratio) > 0.0001 then
				return nil, "같은 AttackId의 대미지 비율이 서로 다름"
			end
			if not previousRatio then
				attackRatios[attackId] = ratio
				totalRatio += ratio
			end
			local hitbox = typeof(hit.Hitbox) == "table" and hit.Hitbox or {}
			table.insert(hits, {
				Frame = math.clamp(math.floor(tonumber(hit.Frame) or 1), 1, #frames),
				AttackId = attackId,
				DamageRatio = ratio,
				Hitbox = {
					Offset = vector(hitbox.Offset, -20, 20),
					Size = vector(hitbox.Size, 0.25, 20, 3),
					Rotation = vector(hitbox.Rotation, -180, 180),
				},
			})
		end
	end
	if totalRatio > 1.0001 then
		return nil, "타격 대미지 비율 합계가 100%를 초과함"
	end
	local presetKey = string.sub(tostring(raw.Id or "UserMotion"), 1, 32)
	local combat, combatError = sanitizeCombat(raw.Combat, presetKey, #frames, enforceBudget)
	if not combat then
		return nil, combatError
	end
	return {
		Id = presetKey,
		Name = string.sub(tostring(raw.Name or "사용자 모션"), 1, 32),
		Description = string.sub(tostring(raw.Description or ""), 1, 120),
		DualWield = dualWield,
		Duration = duration,
		Frames = frames,
		Hits = hits,
		Events = sanitizeEvents(raw.Events, #frames),
		Combat = combat,
	},
		nil
end

function MotionValidator.SanitizePack(raw: any): (any?, string?)
	if typeof(raw) ~= "table" or typeof(raw.Presets) ~= "table" then
		return nil, "잘못된 모션 프리셋 묶음"
	end
	local allowed = {
		Basic = true,
		Heavy = true,
		Skill1 = true,
		Skill2 = true,
		Skill3 = true,
		Ultimate = true,
		Guard = true,
		Dash = true,
		Idle = true,
		Walk = true,
		Jump = true,
		Hit = true,
	}
	local presets = {}
	for key in allowed do
		local source = raw.Presets[key]
		if source then
			local motion, err = MotionValidator.Sanitize(source, source.Complete == true)
			if not motion then
				return nil, string.format("%s 프리셋: %s", key, err or "검증 실패")
			end
			motion.Complete = source.Complete == true
			presets[key] = motion
		end
	end
	if not presets.Basic then
		return nil, "평타 프리셋이 필요합니다."
	end
	local activePreset = allowed[tostring(raw.ActivePreset)] and tostring(raw.ActivePreset) or "Basic"
	local authorCharacterId = tostring(raw.AuthorCharacterId or "Berserker")
	if not CharacterDefinitions.IsValid(authorCharacterId) then
		authorCharacterId = "Berserker"
	end
	return {
		Name = string.sub(tostring(raw.Name or "내 모션"), 1, 32),
		Description = string.sub(tostring(raw.Description or ""), 1, 160),
		BodyColorHex = colorHex(raw.BodyColorHex or "#E8D5A3"),
		AuthorCharacterId = authorCharacterId,
		ActivePreset = activePreset,
		Presets = presets,
	},
		nil
end

return MotionValidator
