--!strict
-- 피해량 계산 (순수 함수)

local CombatConfig = require(script.Parent.CombatConfig)

local DamageCalc = {}

export type Input = {
	Base: number,
	Power: number?,
	ChargeMult: number?,
	Crit: boolean?,
	Backstab: boolean?,
	Riposte: boolean?,
	Defense: number?,
	BlockReduction: number?, -- 방어 성공 시 감소율 (0.8 = 80% 감소)
	Variance: number?, -- 0..1 난수 (±5%)
}

function DamageCalc.Compute(i: Input): number
	local dmg = i.Base * (i.Power or 1) * (i.ChargeMult or 1)
	if i.Crit then
		dmg *= CombatConfig.Crit.Mult
	end
	if i.Backstab then
		dmg *= CombatConfig.Backstab.Mult
	end
	if i.Riposte then
		dmg *= CombatConfig.Parry.RiposteMult
	end
	dmg *= 1 - math.clamp(i.Defense or 0, 0, 0.9)
	if i.BlockReduction then
		dmg *= 1 - math.clamp(i.BlockReduction, 0, 1)
	end
	if i.Variance then
		dmg *= 0.95 + 0.1 * i.Variance
	end
	return math.max(0, math.floor(dmg + 0.5))
end

-- 공격자가 대상의 정면(halfAngle 이내)에 있는가 → 방어 가능
function DamageCalc.IsFrontal(attackerPos: Vector3, targetCF: CFrame, halfAngle: number): boolean
	local to = attackerPos - targetCF.Position
	to = Vector3.new(to.X, 0, to.Z)
	if to.Magnitude < 1e-4 then
		return true
	end
	local look = targetCF.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 1e-4 then
		return true
	end
	local cos = look.Unit:Dot(to.Unit)
	return cos >= math.cos(math.rad(halfAngle))
end

-- 공격자가 대상의 등 뒤(halfAngle 이내)에 있는가 → 백어택
function DamageCalc.IsBehind(attackerPos: Vector3, targetCF: CFrame, halfAngle: number): boolean
	local to = attackerPos - targetCF.Position
	to = Vector3.new(to.X, 0, to.Z)
	local look = targetCF.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	if to.Magnitude < 1e-4 or look.Magnitude < 1e-4 then
		return false
	end
	return (-look.Unit):Dot(to.Unit) >= math.cos(math.rad(halfAngle))
end

-- 충전 비율(0..1) → 피해 배율
function DamageCalc.ChargeMult(chargeRatio: number): number
	return 1 + CombatConfig.Heavy.ChargeDamageBonus * math.clamp(chargeRatio, 0, 1)
end

return DamageCalc
