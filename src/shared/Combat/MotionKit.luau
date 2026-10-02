--!strict
--[[
	MotionKit — 모션 자료를 손으로 쓰기 쉽게 하는 도움 함수. (2026-09-28)
	각도 뜻은 MotionMath 주석. 여기엔 계산 없이 표를 만드는 것만 둔다.
]]

local MotionKit = {}

-- 좌우 뒤집기: R↔L 을 바꾸고 Y(돌기)·Z(기울기)의 부호를 뒤집는다. 무기 슬롯 W↔O 도 바꾼다.
local SWAP = { RArm = "LArm", LArm = "RArm", RLeg = "LLeg", LLeg = "RLeg", RElbow = "LElbow", LElbow = "RElbow", RKnee = "LKnee", LKnee = "RKnee" }
function MotionKit.Mirror(pose: { [string]: any }): { [string]: any }
	local out = {}
	for name, v in pose do
		if type(v) ~= "table" then
			out[name] = v
			continue
		end
		local target = SWAP[name] or name
		if #v == 3 then
			out[target] = { v[1], -v[2], -v[3] }
		elseif #v == 6 then
			out[target] = { -v[1], v[2], v[3], v[4], -v[5], -v[6] }
		else
			out[target] = v
		end
	end
	return out
end

-- 표 합치기: base 위에 over 를 덮는다(키 하나 만들 때 자세 + 바뀐 관절)
function MotionKit.With(base: { [string]: any }, over: { [string]: any }): { [string]: any }
	local out = table.clone(base)
	for k, v in over do
		out[k] = v
	end
	return out
end

-- 키 만들기: K(t, 곡선, 자세[, 덮을 것])
function MotionKit.K(t: number, e: string?, pose: { [string]: any }, over: { [string]: any }?): { [string]: any }
	local key = MotionKit.With(pose, over or {})
	key.t = t
	key.e = e
	return key
end

--[[
	숨 쉬는 대기(2026-10-02 사용자: "끊기는 느낌이 아니라 부드럽게 숨을 쉬고 있는 느낌" — 모든 직업).
	자세 하나로 되풀이 모션을 만든다: 내쉰 끝(0초) → 들이쉰 끝(Inhale 초) → 내쉬는 중(반쯤 돌아옴) → 다시 처음.
	Smooth 라 키에서 멈추지 않고 이어진다(MotionMath.smoothSample).
	들숨엔 가슴이 올라온다: 몸통이 Chest° 젖혀지고(X+, 허리에서 굽힘 — 다리는 그대로) 몸이 Rise 스터드 뜨며,
	고개는 Head° 만큼 되숙여 시선을 지킨다. 팔은 몸통에 붙어 함께 움직이므로 두 손으로 쥔 무기도 떨어지지 않는다.
	Out · In · Mid = 그 키에 덮을 것(무기가 떠도는 것, 어깨가 오르는 것 …).
]]
function MotionKit.Breath(pose: { [string]: any }, opts: { [string]: any }): { [string]: any }
	local chest, rise, head = opts.Chest or 2.5, opts.Rise or 0.03, opts.Head or -1.5
	local duration = opts.Duration or 3.6
	local inhale = opts.Inhale or duration * 0.4
	local function at(k: number): { [string]: any }
		local t, r, h = pose.Torso or { 0, 0, 0 }, pose.Root or { 0, 0, 0, 0, 0, 0 }, pose.Head or { 0, 0, 0 }
		return MotionKit.With(pose, {
			Torso = { t[1] + chest * k, t[2], t[3] },
			Root = { r[1], r[2] + rise * k, r[3], r[4], r[5], r[6] },
			Head = { h[1] + head * k, h[2], h[3] },
		})
	end
	return {
		Duration = duration,
		Loop = true,
		Smooth = true,
		Keys = {
			MotionKit.K(0, nil, at(0), opts.Out),
			MotionKit.K(inhale, nil, at(1), opts.In),
			MotionKit.K(inhale + (duration - inhale) * 0.45, nil, at(0.5), opts.Mid),
		},
	}
end

return MotionKit
