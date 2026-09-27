--!strict
-- 연락선 항로 & 시간표 (결정적, 서버/클라이언트 동일 결과)
--   입력: 서버 시각 t (workspace:GetServerTimeNow())
--   출력: 배의 CFrame, 상태(정박/항해), 다음 기항지, 남은 시간
-- 모든 클라이언트가 같은 시각으로 계산하므로 배를 로컬에서 60fps 로 부드럽게 움직일 수 있다.

local FerryConfig = require(script.Parent.FerryConfig)

export type RouteData = { Length: number, Stops: { { Name: string, S: number } }, Points: { { number } } }

export type Leg = {
	From: string,
	To: string,
	S0: number, -- 출발 호 길이
	Distance: number,
	Dwell: number,
	Travel: number,
	TAcc: number,
	TCruise: number,
	VPeak: number,
	Start: number, -- 주기 안에서 이 구간의 시작 시각
}

export type State = {
	Phase: string, -- "Docked" | "Sailing"
	S: number,
	Speed: number,
	Leg: Leg,
	At: string?, -- 정박 중인 기항지
	From: string,
	To: string,
	TimeToDeparture: number, -- 정박 중일 때
	TimeToArrival: number, -- 항해 중일 때 (정박 중이면 다음 도착까지)
	SinceArrival: number, -- 정박 경과 시간
	Progress: number, -- 항해 진행률 0..1
}

local FerryRoute = {}
FerryRoute.__index = FerryRoute

export type Route = typeof(setmetatable(
	{} :: {
		xs: { number },
		zs: { number },
		cum: { number },
		length: number,
		legs: { Leg },
		cycle: number,
		offset: Vector3,
		cfg: typeof(FerryConfig),
	},
	FerryRoute
))

local function travelProfile(D: number, a: number, vmax: number): (number, number, number, number)
	-- 반환: 총 시간, 가속 시간, 순항 시간, 최고 속도
	local dAcc = vmax * vmax / (2 * a)
	if D >= 2 * dAcc then
		local tAcc = vmax / a
		local tCruise = (D - 2 * dAcc) / vmax
		return 2 * tAcc + tCruise, tAcc, tCruise, vmax
	end
	local vPeak = math.sqrt(D * a)
	local tAcc = vPeak / a
	return 2 * tAcc, tAcc, 0, vPeak
end

function FerryRoute.new(data: RouteData, offset: Vector3?, cfg: typeof(FerryConfig)?): Route
	local conf = cfg or FerryConfig
	local xs, zs, cum = {}, {}, { 0 }
	for i, p in data.Points do
		xs[i] = p[1]
		zs[i] = p[2]
	end
	local n = #xs
	for i = 1, n do
		local j = if i == n then 1 else i + 1
		cum[i + 1] = cum[i] + math.sqrt((xs[j] - xs[i]) ^ 2 + (zs[j] - zs[i]) ^ 2)
	end
	local length = cum[n + 1]
	local stops = table.clone(data.Stops)
	table.sort(stops, function(a, b)
		return a.S < b.S
	end)
	local legs: { Leg } = {}
	local tcur = 0
	for i, st in stops do
		local nxt = stops[(i % #stops) + 1]
		local D = (nxt.S - st.S) % length
		if D < 1e-3 then
			D = length
		end
		local T, tAcc, tCruise, vPeak = travelProfile(D, conf.Accel, conf.MaxSpeed)
		local leg: Leg = {
			From = st.Name,
			To = nxt.Name,
			S0 = st.S,
			Distance = D,
			Dwell = conf.DwellTime,
			Travel = T,
			TAcc = tAcc,
			TCruise = tCruise,
			VPeak = vPeak,
			Start = tcur,
		}
		table.insert(legs, leg)
		tcur += leg.Dwell + T
	end
	local self = setmetatable({
		xs = xs,
		zs = zs,
		cum = cum,
		length = length,
		legs = legs,
		cycle = tcur,
		offset = offset or Vector3.zero,
		cfg = conf,
	}, FerryRoute)
	return self
end

function FerryRoute.Length(self: Route): number
	return self.length
end

function FerryRoute.Cycle(self: Route): number
	return self.cycle
end

-- 호 길이 s 의 위치 (수면 y=0 + 오프셋)
function FerryRoute.PositionAt(self: Route, s: number): Vector3
	local L = self.length
	s = s % L
	local cum = self.cum
	-- 이분 탐색
	local lo, hi = 1, #self.xs
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if cum[mid] <= s then
			lo = mid
		else
			hi = mid - 1
		end
	end
	local i = lo
	local j = if i == #self.xs then 1 else i + 1
	local segLen = cum[i + 1] - cum[i]
	local f = if segLen > 1e-9 then (s - cum[i]) / segLen else 0
	local x = self.xs[i] + (self.xs[j] - self.xs[i]) * f
	local z = self.zs[i] + (self.zs[j] - self.zs[i]) * f
	return Vector3.new(x, 0, z) + self.offset
end

-- 매끄러운 접선 (±window 중앙 차분)
function FerryRoute.TangentAt(self: Route, s: number, window: number?): Vector3
	local w = window or 9
	local d = self:PositionAt(s + w) - self:PositionAt(s - w)
	d = Vector3.new(d.X, 0, d.Z)
	if d.Magnitude < 1e-6 then
		return Vector3.new(0, 0, -1)
	end
	return d.Unit
end

-- 좌회전 양수의 곡률 (1/stud)
function FerryRoute.CurvatureAt(self: Route, s: number): number
	local w = 14
	local t1 = self:TangentAt(s - w, 7)
	local t2 = self:TangentAt(s + w, 7)
	local cross = t1.Z * t2.X - t1.X * t2.Z -- Y 축 기준 회전 방향 (Roblox: -Z 전방)
	local ang = math.acos(math.clamp(t1:Dot(t2), -1, 1))
	return (if cross >= 0 then ang else -ang) / (2 * w)
end

function FerryRoute.StateAt(self: Route, t: number): State
	local cycle = self.cycle
	local phase = (t + self.cfg.PhaseOffset) % cycle
	local legs = self.legs
	local leg = legs[#legs]
	for _, lg in legs do
		if phase >= lg.Start then
			leg = lg
		else
			break
		end
	end
	local local_t = phase - leg.Start
	if local_t < leg.Dwell then
		return {
			Phase = "Docked",
			S = leg.S0 % self.length,
			Speed = 0,
			Leg = leg,
			At = leg.From,
			From = leg.From,
			To = leg.To,
			TimeToDeparture = leg.Dwell - local_t,
			TimeToArrival = leg.Dwell - local_t + leg.Travel,
			SinceArrival = local_t,
			Progress = 0,
		}
	end
	local tau = local_t - leg.Dwell
	local a = self.cfg.Accel
	local d, v
	if tau < leg.TAcc then
		d = 0.5 * a * tau * tau
		v = a * tau
	elseif tau < leg.TAcc + leg.TCruise then
		d = 0.5 * a * leg.TAcc * leg.TAcc + leg.VPeak * (tau - leg.TAcc)
		v = leg.VPeak
	else
		local rem = math.max(0, leg.Travel - tau)
		d = leg.Distance - 0.5 * a * rem * rem
		v = a * rem
	end
	d = math.clamp(d, 0, leg.Distance)
	return {
		Phase = "Sailing",
		S = (leg.S0 + d) % self.length,
		Speed = v,
		Leg = leg,
		At = nil,
		From = leg.From,
		To = leg.To,
		TimeToDeparture = 0,
		TimeToArrival = leg.Travel - tau,
		SinceArrival = 0,
		Progress = d / leg.Distance,
	}
end

-- 배의 월드 CFrame (진행 방향 = LookVector) + 흔들림/기울기
function FerryRoute.CFrameAt(self: Route, t: number, state: State?): CFrame
	local st = state or self:StateAt(t)
	local pos = self:PositionAt(st.S)
	local tan = self:TangentAt(st.S)
	local bob = self.cfg.Bob
	local k = if st.Phase == "Docked" then bob.DockedScale else 1
	local heave = bob.Heave * k * (math.sin(t * 1.05) + 0.5 * math.sin(t * 1.9 + 1.3))
	local pitch = math.rad(bob.Pitch * k * math.sin(t * 0.72 + 0.7) + 0.5 * st.Speed / math.max(1, self.cfg.MaxSpeed))
	local bank = 0
	if st.Speed > 0.5 then
		local curv = self:CurvatureAt(st.S)
		bank = math.clamp(-curv * st.Speed * st.Speed * bob.BankPerAccel, -bob.MaxBank, bob.MaxBank)
	end
	local roll = math.rad(bob.Roll * k * math.sin(t * 0.9 + 2.1) + bank)
	local p = pos + Vector3.new(0, heave, 0)
	return CFrame.lookAt(p, p + tan) * CFrame.Angles(pitch, 0, roll)
end

-- 기항지 이름 -> 호 길이
function FerryRoute.StopS(self: Route, name: string): number?
	for _, lg in self.legs do
		if lg.From == name then
			return lg.S0
		end
	end
	return nil
end

return FerryRoute
