--!strict

local RotationUtil = {}

export type Quaternion = { X: number, Y: number, Z: number, W: number }

function RotationUtil.FromEuler(pose: any): CFrame
	return CFrame.Angles(math.rad(pose and pose.X or 0), math.rad(pose and pose.Y or 0), math.rad(pose and pose.Z or 0))
end

function RotationUtil.ToCFrame(rotation: any, fallbackPose: any?): CFrame
	if typeof(rotation) ~= "table" then
		return RotationUtil.FromEuler(fallbackPose)
	end
	local x = tonumber(rotation.X) or 0
	local y = tonumber(rotation.Y) or 0
	local z = tonumber(rotation.Z) or 0
	local w = tonumber(rotation.W) or 1
	local magnitude = math.sqrt(x * x + y * y + z * z + w * w)
	if magnitude < 0.000001 then
		return RotationUtil.FromEuler(fallbackPose)
	end
	x /= magnitude
	y /= magnitude
	z /= magnitude
	w /= magnitude
	return CFrame.new(
		0,
		0,
		0,
		1 - 2 * (y * y + z * z),
		2 * (x * y - z * w),
		2 * (x * z + y * w),
		2 * (x * y + z * w),
		1 - 2 * (x * x + z * z),
		2 * (y * z - x * w),
		2 * (x * z - y * w),
		2 * (y * z + x * w),
		1 - 2 * (x * x + y * y)
	)
end

function RotationUtil.FromCFrame(rotation: CFrame): Quaternion
	local axis, angle = rotation:ToAxisAngle()
	local sine = math.sin(angle * 0.5)
	return {
		X = axis.X * sine,
		Y = axis.Y * sine,
		Z = axis.Z * sine,
		W = math.cos(angle * 0.5),
	}
end

function RotationUtil.ToEuler(rotation: CFrame): { X: number, Y: number, Z: number }
	local x, y, z = rotation:ToEulerAnglesXYZ()
	return { X = math.deg(x), Y = math.deg(y), Z = math.deg(z) }
end

return RotationUtil
