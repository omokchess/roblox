--!strict

export type JointPose = { X: number, Y: number, Z: number }
export type JointRotation = { X: number, Y: number, Z: number, W: number }
export type WeaponPose = { Position: JointPose, Rotation: JointPose }
export type MotionFrame = {
	Time: number,
	Joints: { [string]: JointPose },
	JointRotations: { [string]: JointRotation }?,
	JointOffsets: { [string]: JointPose }?,
	Weapon: WeaponPose?,
}
export type Hitbox = { Offset: JointPose, Size: JointPose }
export type HitEvent = { Frame: number, AttackId: string, DamageRatio: number, Hitbox: Hitbox? }
export type MotionDefinition = {
	Id: string,
	Name: string,
	Duration: number,
	Frames: { MotionFrame },
	Hits: { HitEvent },
}

local motions: { [string]: MotionDefinition } = {
	BasicSlash = {
		Id = "BasicSlash",
		Name = "기본 베기",
		Duration = 0.65,
		Frames = {
			{ Time = 0, Joints = { ["Right Shoulder"] = { X = 0, Y = 0, Z = 35 } } },
			{
				Time = 0.28,
				Joints = { ["Right Shoulder"] = { X = 0, Y = 0, Z = -75 }, ["Torso"] = { X = 0, Y = -18, Z = 0 } },
			},
			{ Time = 0.65, Joints = { ["Right Shoulder"] = { X = 0, Y = 0, Z = 0 } } },
		},
		Hits = { { Frame = 2, AttackId = "Slash", DamageRatio = 1 } },
	},
	HeavySlash = {
		Id = "HeavySlash",
		Name = "강한 베기",
		Duration = 0.9,
		Frames = {
			{ Time = 0, Joints = { ["Right Shoulder"] = { X = 0, Y = 0, Z = 65 } } },
			{
				Time = 0.35,
				Joints = { ["Right Shoulder"] = { X = 0, Y = 0, Z = 95 }, ["Left Shoulder"] = { X = 0, Y = 0, Z = 35 } },
			},
			{
				Time = 0.58,
				Joints = { ["Right Shoulder"] = { X = 0, Y = 0, Z = -100 }, ["Torso"] = { X = 0, Y = -25, Z = 0 } },
			},
			{ Time = 0.9, Joints = { ["Right Shoulder"] = { X = 0, Y = 0, Z = 0 } } },
		},
		Hits = { { Frame = 3, AttackId = "Heavy", DamageRatio = 1 } },
	},
	RangedShot = {
		Id = "RangedShot",
		Name = "사격",
		Duration = 0.7,
		Frames = {
			{ Time = 0, Joints = {} },
			{
				Time = 0.2,
				Joints = {
					["Right Shoulder"] = { X = 0, Y = 0, Z = -90 },
					["Left Shoulder"] = { X = 0, Y = 0, Z = -75 },
				},
			},
			{
				Time = 0.42,
				Joints = {
					["Right Shoulder"] = { X = 0, Y = 0, Z = -82 },
					["Left Shoulder"] = { X = 0, Y = 0, Z = -65 },
				},
			},
			{ Time = 0.7, Joints = {} },
		},
		Hits = { { Frame = 3, AttackId = "Shot", DamageRatio = 1 } },
	},
	Guard = {
		Id = "Guard",
		Name = "가드",
		Duration = 0.55,
		Frames = {
			{ Time = 0, Joints = {} },
			{
				Time = 0.22,
				Joints = {
					["Left Shoulder"] = { X = 0, Y = 0, Z = -70 },
					["Right Shoulder"] = { X = 0, Y = 0, Z = -25 },
				},
			},
			{ Time = 0.55, Joints = {} },
		},
		Hits = {},
	},
}

local MotionCatalog = {}

function MotionCatalog.Get(id: string): MotionDefinition
	return motions[id] or motions.BasicSlash
end

function MotionCatalog.All(): { MotionDefinition }
	return { motions.BasicSlash, motions.HeavySlash, motions.RangedShot, motions.Guard }
end

return MotionCatalog
