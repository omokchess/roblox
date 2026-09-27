--!nocheck
local Vector3 = require("@lune/roblox").Vector3
return function(H)
	local Shared = "src/ReplicatedStorage/Shared"
	local FerryRoute = H.require(Shared .. "/Ferry/FerryRoute.luau")
	local FerryConfig = H.require(Shared .. "/Ferry/FerryConfig.luau")
	local data = H.require(Shared .. "/World/Generated/FerryRouteData.luau")
	local route = FerryRoute.new(data)
	H.check("항로 길이 일치", math.abs(route:Length() - data.Length) / data.Length < 0.01, route:Length())
	H.check("주기 > 0", route:Cycle() > 60, route:Cycle())
	local s0 = route:StateAt(0)
	H.check("t=0 첫 기항지 정박", s0.Phase == "Docked" and s0.At == "Mistmire", s0.Phase .. "/" .. tostring(s0.At))
	local p = route:PositionAt(route:StopS("Mistmire"))
	H.check("안개늪 정박 위치 ≈ (143, 0, 0)", H.near(p.X, 143, 0.6) and H.near(p.Z, 0, 0.6), p)
	local tan = route:TangentAt(route:StopS("Mistmire"))
	H.check("안개늪 정박 방향 = 북(-Z)", tan.Z < -0.99, tan)
	local ph = route:PositionAt(route:StopS("Harbor"))
	H.check("항구 정박 위치 ≈ (-528, 0, 0)", H.near(ph.X, -528, 0.6) and H.near(ph.Z, 0, 0.6), ph)
	local th = route:TangentAt(route:StopS("Harbor"))
	H.check("항구 정박 방향 = 남(+Z)", th.Z > 0.99, th)
	-- 연속성 & 속도 한계
	local dt = 0.1
	local prev = route:CFrameAt(0).Position
	local maxStep = 0
	local docked, sailing = 0, 0
	for i = 1, math.floor(route:Cycle() / dt) do
		local t = i * dt
		local st = route:StateAt(t)
		if st.Phase == "Docked" then docked += dt else sailing += dt end
		local pos = route:CFrameAt(t, st).Position
		local step = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(prev.X, 0, prev.Z)).Magnitude
		if step > maxStep then maxStep = step end
		prev = pos
	end
	H.check("프레임 간 이동량 ≤ 최고속도×dt×1.1", maxStep <= FerryConfig.MaxSpeed * dt * 1.1, maxStep)
	H.check("정박 시간 합 ≈ DwellTime×2", H.near(docked, FerryConfig.DwellTime * 2, 0.3), docked)
	print(string.format("    (주기 %.1fs, 항해 %.1fs, 정박 %.1fs)", route:Cycle(), sailing, docked))
	-- 도착 직전 속도 → 0
	local leg = route:StateAt(0).Leg
	local arrive = leg.Dwell + leg.Travel - 0.05
	local sArr = route:StateAt(arrive)
	H.check("도착 직전 감속", sArr.Speed < 0.5, sArr.Speed)
	local cf = route:CFrameAt(15)
	H.check("CFrame 직교성", math.abs(cf.LookVector:Dot(cf.UpVector)) < 1e-5)
end
