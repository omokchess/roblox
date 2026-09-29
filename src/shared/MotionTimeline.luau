--!strict

local MotionTimeline = {}

function MotionTimeline.FrameTime(motion: any, frameIndex: number): number
	local frames = motion and motion.Frames or {}
	local frame = frames[math.clamp(math.floor(frameIndex), 1, math.max(1, #frames))]
	return frame and math.max(0, tonumber(frame.Time) or 0) or 0
end

function MotionTimeline.DamageEvents(motion: any): { any }
	local groups: { [string]: any } = {}
	local order = {}
	for _, hit in (motion and motion.Hits or {}) do
		local attackId = tostring(hit.AttackId or "Hit")
		local frame = math.clamp(math.floor(tonumber(hit.Frame) or 1), 1, math.max(1, #(motion.Frames or {})))
		local existing = groups[attackId]
		if not existing then
			existing = {
				AttackId = attackId,
				Frame = frame,
				Time = MotionTimeline.FrameTime(motion, frame),
				Ratio = math.clamp(tonumber(hit.DamageRatio) or 0, 0, 1),
			}
			groups[attackId] = existing
			table.insert(order, existing)
		elseif frame < existing.Frame then
			existing.Frame = frame
			existing.Time = MotionTimeline.FrameTime(motion, frame)
		end
	end
	if #order == 0 then
		return {
			{
				AttackId = "Fallback",
				Frame = 1,
				Time = math.min(0.25, math.max(0, tonumber(motion and motion.Duration) or 0.25)),
				Ratio = 1,
			},
		}
	end
	local assigned = 0
	local automatic = 0
	for _, event in order do
		if event.Ratio > 0 then
			assigned += event.Ratio
		else
			automatic += 1
		end
	end
	if automatic > 0 then
		local automaticRatio = math.max(0, 1 - assigned) / automatic
		if assigned <= 0 then
			automaticRatio = 1 / automatic
		end
		for _, event in order do
			if event.Ratio <= 0 then
				event.Ratio = automaticRatio
			end
		end
	end
	table.sort(order, function(a, b)
		if a.Time == b.Time then
			return a.AttackId < b.AttackId
		end
		return a.Time < b.Time
	end)
	return order
end

function MotionTimeline.Duration(motion: any): number
	local duration = math.max(0.1, tonumber(motion and motion.Duration) or 0.6)
	for _, event in MotionTimeline.DamageEvents(motion) do
		duration = math.max(duration, event.Time + 0.1)
	end
	return duration
end

return MotionTimeline
