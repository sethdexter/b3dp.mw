class_name MeleeSwing
extends Resource

## One melee attack animation: the hand winds up, then strikes. Offsets from the hand's rest pose.

@export var windup_rotation := Vector3.ZERO ## degrees
@export var windup_offset := Vector3.ZERO ## metres, camera space (-Z = forward)
@export var strike_rotation := Vector3.ZERO
@export var strike_offset := Vector3.ZERO
## The hand moves first and the blade whips round after it, for sweeping cuts.
@export var hand_leads := false
