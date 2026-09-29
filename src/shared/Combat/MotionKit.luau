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

return MotionKit
