--!nocheck
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

return function(H)
	local C = "src/ReplicatedStorage/Shared/Combat"
	local Hitbox = H.require(C .. "/Hitbox.luau")
	local DamageCalc = H.require(C .. "/DamageCalc.luau")
	local MoveDefs = H.require(C .. "/MoveDefs.luau")
	local WeaponDefs = H.require(C .. "/WeaponDefs.luau")
	local EnemyDefs = H.require(C .. "/EnemyDefs.luau")
	local StatusDefs = H.require(C .. "/StatusDefs.luau")
	local PoseLibrary = H.require(C .. "/PoseLibrary.luau")

	local o = CFrame.new(0, 3, 0) -- 정면 = -Z
	local arc = { Shape = "Arc", Range = 8, Angle = 120, Height = 6 }
	H.check("Arc: 정면 5 stud 적중", Hitbox.Test(arc, o, Vector3.new(0, 3, -5), 1.5))
	H.check("Arc: 뒤쪽 불가", not Hitbox.Test(arc, o, Vector3.new(0, 3, 5), 1.5))
	H.check("Arc: 옆 80도 불가", not Hitbox.Test(arc, o, Vector3.new(6, 3, -1), 0.5))
	H.check("Arc: 사거리+반지름 경계 적중", Hitbox.Test(arc, o, Vector3.new(0, 3, -9.4), 1.5))
	H.check("Arc: 높이 초과 불가", not Hitbox.Test(arc, o, Vector3.new(0, 12, -4), 1.5))
	local rot = CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(90), 0) -- 왼쪽(-X)을 바라봄
	H.check("Arc: 회전된 공격자 기준", Hitbox.Test(arc, rot, Vector3.new(-5, 3, 0), 1.5) and not Hitbox.Test(arc, rot, Vector3.new(5, 3, 0), 1.5))
	local box = { Shape = "Box", Size = Vector3.new(4, 6, 10), Offset = Vector3.new(0, 0, -5) }
	H.check("Box: 내부", Hitbox.Test(box, o, Vector3.new(0, 3, -8), 1))
	H.check("Box: 뒤 불가", not Hitbox.Test(box, o, Vector3.new(0, 3, 3), 1))
	local line = { Shape = "Line", Length = 11, Width = 2 }
	H.check("Line: 끝 부근 적중", Hitbox.Test(line, o, Vector3.new(0.5, 3, -11.5), 1))
	H.check("Line: 옆 불가", not Hitbox.Test(line, o, Vector3.new(4, 3, -5), 1))
	local sph = { Shape = "Sphere", Radius = 8 }
	H.check("Sphere: 뒤 포함", Hitbox.Test(sph, o, Vector3.new(0, 3, 7), 1.5))

	-- 피해 계산
	H.check("피해: 기본", DamageCalc.Compute({ Base = 20 }) == 20)
	H.check("피해: 방어력 25%", DamageCalc.Compute({ Base = 20, Defense = 0.25 }) == 15)
	H.check("피해: 방어 80%", DamageCalc.Compute({ Base = 20, BlockReduction = 0.8 }) == 4)
	local tcf = CFrame.new(0, 0, 0) -- 대상 정면 -Z
	H.check("정면 판정", DamageCalc.IsFrontal(Vector3.new(0, 0, -5), tcf, 75))
	H.check("백어택 판정", DamageCalc.IsBehind(Vector3.new(0, 0, 5), tcf, 55) and not DamageCalc.IsBehind(Vector3.new(0, 0, -5), tcf, 55))

	-- 데이터 무결성: 모든 무기/적 기술과 애니메이션이 존재
	local missing = {}
	local function need(moveName)
		local m = MoveDefs.Moves[moveName]
		if not m then
			table.insert(missing, "move:" .. moveName)
			return
		end
		if not PoseLibrary.Clips[m.Anim] then
			table.insert(missing, "anim:" .. m.Anim)
		end
		if m.Projectile and not MoveDefs.Projectiles[m.Projectile] then
			table.insert(missing, "proj:" .. m.Projectile)
		end
		for _, s in m.Statuses or {} do
			if not StatusDefs[s.Id] then
				table.insert(missing, "status:" .. s.Id)
			end
		end
		if m.Area then
			for _, s in m.Area.Statuses or {} do
				if not StatusDefs[s.Id] then
					table.insert(missing, "status:" .. s.Id)
				end
			end
		end
	end
	for id, w in WeaponDefs.Weapons do
		for _, m in w.Light do need(m) end
		need(w.Heavy)
		for _, m in w.Skills do need(m) end
		if not PoseLibrary.Clips[w.Block] then table.insert(missing, "block:" .. w.Block) end
		if not PoseLibrary.Clips[w.HeavyCharge] then table.insert(missing, "charge:" .. w.HeavyCharge) end
	end
	for id, e in EnemyDefs do
		for _, c in e.Moves do need(c.Move) end
		for _, ph in e.Phases or {} do
			for _, c in ph.Moves do need(c.Move) end
			if ph.OnEnter then need(ph.OnEnter) end
		end
	end
	H.check("무기/적 기술·애니메이션·상태 참조 무결성", #missing == 0, table.concat(missing, ", "))
	-- 애니메이션 길이 ≥ 기술 총 시간 (잘리지 않도록)
	local short = {}
	for name, m in MoveDefs.Moves do
		local clip = PoseLibrary.Clips[m.Anim]
		if clip and clip.Duration + 0.05 < m.Windup + m.Active + m.Recovery then
			table.insert(short, string.format("%s(%.2f<%.2f)", name, clip.Duration, m.Windup + m.Active + m.Recovery))
		end
	end
	H.check("애니메이션 길이 ≥ 기술 시간", #short == 0, table.concat(short, ", "))
end
