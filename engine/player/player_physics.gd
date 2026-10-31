class_name PlayerPhysics
extends Resource
## Movement, damage and power-up values for a player character, in SI units (m, m/s, m/s², s,
## degrees per second). The defaults are the classic 60 fps platformer values (px/frame and
## px/frame²), converted with PIXELS_PER_METER: speeds × 60 / 32, accelerations × 3600 / 32.

const PIXELS_PER_METER := 32.0
const CLASSIC_FPS := 60.0
const SPEED := CLASSIC_FPS / PIXELS_PER_METER  ## Converts a classic speed (px/frame) to m/s.
const ACCEL := CLASSIC_FPS * CLASSIC_FPS / PIXELS_PER_METER  ## Converts a classic acceleration (px/frame²) to m/s².

@export_group("Ground")
@export var acc: float = 0.046875 * ACCEL  ## Acceleration while running (m/s²).
@export var dec: float = 0.5 * ACCEL  ## Braking while input points against the motion (m/s²).
@export var frc: float = 0.046875 * ACCEL  ## Slowdown with no input (m/s²).
@export var top: float = 6.0 * SPEED  ## Top speed from running alone (m/s). Slopes and boosts can go faster.
@export var max_ground_speed: float = 16.0 * SPEED  ## Hard speed cap that keeps collision stable (m/s).
@export var turnaround_speed: float = 0.5 * SPEED  ## Speed in the new direction after braking to a stop (m/s).

@export_group("Turning")
@export var turn_rate_low: float = 720.0  ## Turn rate when standing or moving slowly (degrees per second).
@export var turn_rate_high: float = 180.0  ## Turn rate at top speed and above (degrees per second).
@export_range(90.0, 180.0) var brake_angle: float = 135.0  ## Input more than this many degrees from the heading brakes instead of turning.

@export_group("Slopes")
@export var slp: float = 0.125 * ACCEL  ## Pull of gravity along slopes while running (m/s²).
@export var slp_roll_up: float = 0.078125 * ACCEL  ## Pull of gravity along slopes while rolling uphill (m/s²).
@export var slp_roll_down: float = 0.3125 * ACCEL  ## Pull of gravity along slopes while rolling downhill (m/s²).
@export var slip_threshold: float = 2.5 * SPEED  ## Slower than this on a steep surface, the player slips (m/s).
@export var slip_angle: float = 46.0  ## Surfaces steeper than this (degrees) can make a slow player slip, and the stick no longer steers on them.
@export var slip_lock_time: float = 0.5  ## Seconds the stick is ignored after slipping.
@export var ground_magnetism: float = 0.0  ## Extra pull toward the surface (m/s²) that helps a slow player stay on overhangs and ceilings. 0 is classic.
@export var snap_length: float = 0.5  ## How far the player reaches for the ground to stay on it over crests (m).
@export var surface_step_angle: float = 46.0  ## Sharpest change of surface (degrees) the player follows in one step. Sharper edges act as ledges or walls.

@export_group("Rolling")
@export var roll_frc: float = 0.0234375 * ACCEL  ## Slowdown while rolling, always applied (m/s²).
@export var roll_dec: float = 0.125 * ACCEL  ## Extra braking while rolling with input against the motion (m/s²).
@export var roll_min_speed: float = 1.0 * SPEED  ## Holding crouch starts a roll at this speed or faster (m/s).
@export var unroll_speed: float = 0.5 * SPEED  ## A roll ends below this speed (m/s).
@export_range(0.0, 1.0) var roll_turn_factor: float = 0.5  ## Turn rate while rolling, as a share of the running turn rate.

@export_group("Spin dash")
@export var spin_dash_speed: float = 8.0 * SPEED  ## Launch speed with no charge (m/s).
@export var spin_dash_charge_speed: float = 0.5 * SPEED  ## Extra launch speed per whole unit of charge (m/s).
@export var spin_dash_charge_per_press: float = 2.0  ## Charge added by each jump press.
@export var spin_dash_max_charge: float = 8.0  ## Most charge the spin dash can hold.

@export_group("Air")
@export var air_acc: float = 0.09375 * ACCEL  ## Acceleration from input while airborne (m/s²).
@export var grv: float = 0.21875 * ACCEL  ## Gravity (m/s²).
@export var jmp: float = 6.5 * SPEED  ## Speed of a jump, away from the surface (m/s).
@export var jmp_release_cap: float = 4.0 * SPEED  ## Letting go of jump early caps the upward speed to this (m/s).
@export var max_fall: float = 16.0 * SPEED  ## Terminal fall speed (m/s).
@export var air_drag: bool = true  ## Classic drag on horizontal speed near the top of a jump.
@export var upright_speed: float = 540.0  ## How fast the player turns back upright in the air (degrees per second).

@export_group("Homing attack")
@export var homing_range: float = 12.0  ## Jump in the air locks on to targets this close (m)...
@export_range(10.0, 180.0) var homing_cone: float = 90.0  ## ...within this angle of the way the player faces (degrees, both sides together).
@export var homing_speed: float = 28.0  ## Speed of the homing attack (m/s).
@export var homing_max_time: float = 0.6  ## Seconds before a homing attack that hasn't reached its target gives up.
@export var homing_bounce: float = 10.0  ## Upward speed after a homing attack hits (m/s).
@export var air_dash_speed: float = 15.0  ## With nothing in reach, jump in the air dashes ahead at least this fast (m/s).

@export_group("Enemies")
@export var rebound_slowdown: float = 1.0 * SPEED  ## Destroying an enemy in the air while rising, or from below its middle, only slows the player by this much (m/s). From above they bounce back up.

@export_group("Assists")
@export var coyote_time: float = 0.1  ## Seconds after running off a ledge during which a jump still works.
@export var jump_buffer_time: float = 0.1  ## Seconds a jump press is remembered before landing.

@export_group("2.5D")
@export var lane_pull_speed: float = 8.0  ## How fast a 2.5D section pulls the player onto its path (m/s).

@export_group("Damage")
@export var hurt_speed: float = 2.0 * SPEED  ## Speed of the knockback from a hit, away from what hurt the player (m/s).
@export var hurt_rise: float = 4.0 * SPEED  ## Upward speed of that knockback (m/s).
@export var hurt_gravity: float = 0.1875 * ACCEL  ## Gravity while knocked back, lighter than normal (m/s²).
@export var invulnerable_time: float = 120.0 / CLASSIC_FPS  ## Seconds of flashing invulnerability after a hit.
@export var death_rise: float = 7.0 * SPEED  ## Upward speed of the hop on dying (m/s).

@export_group("Ring loss")
@export var max_lost_rings: int = 32  ## Most rings a hit scatters. Any more are lost outright.
@export var lost_ring_speed_fast: float = 4.0 * SPEED  ## Launch speed of the first 16 scattered rings (m/s).
@export var lost_ring_speed_slow: float = 2.0 * SPEED  ## Launch speed of the rest (m/s).
@export var lost_ring_gravity: float = 0.09375 * ACCEL  ## Gravity on scattered rings (m/s²).
@export_range(0.0, 1.0) var lost_ring_bounce: float = 0.75  ## Share of a scattered ring's speed into a surface that it bounces back with.
@export var lost_ring_pickup_delay: float = 64.0 / CLASSIC_FPS  ## Seconds before scattered rings can be collected.
@export var lost_ring_lifetime: float = 256.0 / CLASSIC_FPS  ## Seconds before scattered rings vanish.

@export_group("Power-ups")
@export var speed_shoes_time: float = 20.0  ## Seconds speed shoes last.
@export var speed_shoes_factor: float = 2.0  ## Speed shoes multiply acc, frc, top, air_acc and roll_frc by this.
@export var invincibility_time: float = 20.0  ## Seconds invincibility lasts.
@export var magnet_time: float = 20.0  ## Seconds the ring magnet lasts.
@export var magnet_range: float = 5.0  ## Rings this close (m) fly to a player with the magnet.
@export var magnet_pull_speed: float = 15.0  ## How much faster than the player a pulled ring flies (m/s).
