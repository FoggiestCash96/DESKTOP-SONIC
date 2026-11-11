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
@export var finish_brake: float = 0.5 * ACCEL  ## After the goal, the player skids to a stop at this rate (m/s²), as hard as braking, so they stop within a short run past it even at boost speed.
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

@export_group("Boost")
@export var boost_speed: float = 30.0  ## Speed the boost holds on the ground, and an air boost's speed (m/s).
@export var boost_drain: float = 20.0  ## Gauge used per second of boosting on the ground (percent): a full gauge lasts 5 s.
@export var air_boost_cost: float = 10.0  ## Gauge an air boost uses (percent).
@export var air_boost_time: float = 0.4  ## Seconds an air boost carries the player straight ahead.
@export var boost_start: float = 33.0  ## Gauge at the start of a stage (percent).
@export var boost_per_ring: float = 2.0  ## Gauge each ring adds (percent): 50 rings fill it.
@export var boost_per_enemy: float = 10.0  ## Gauge each enemy destroyed adds (percent).

@export_group("Quickstep")
@export var quickstep_distance: float = 2.5  ## How far a quickstep moves the player sideways (m).
@export var quickstep_time: float = 0.12  ## Seconds a quickstep takes.
@export var quickstep_min_speed: float = 8.0  ## Quickstep only works running at least this fast (m/s).

@export_group("Stomp")
@export var stomp_speed: float = 16.0 * SPEED  ## Speed of a stomp, straight down (m/s): the classic top falling speed.

@export_group("Drop dash")
@export var drop_dash_time: float = 20.0 / CLASSIC_FPS  ## Seconds the second jump press must be held, with no homing target, to charge a drop dash.
@export var drop_dash_speed: float = 8.0 * SPEED  ## A drop dash launches a roll at this speed (m/s), plus a quarter of the speed already going that way...
@export var drop_dash_max: float = 12.0 * SPEED  ## ...up to this (m/s).

@export_group("Super Peel Out")
@export var peel_out_time: float = 30.0 / CLASSIC_FPS  ## Seconds of revving before the peel out is ready.
@export var peel_out_speed: float = 12.0 * SPEED  ## Running speed it launches at (m/s).

@export_group("Drift")
@export var drift_min_speed: float = 10.0  ## A drift needs at least this speed (m/s).
@export var drift_turn_rate: float = 300.0  ## How fast a drift turns with the stick pushed into the turn (degrees per second); half that with it straight.

@export_group("Light speed dash")
@export var light_dash_reach: float = 3.0  ## A ring this close to the player starts a light speed dash (m)...
@export var light_dash_link: float = 6.0  ## ...which goes on to each next ring this close (m)...
@export var light_dash_speed: float = 40.0  ## ...at this speed (m/s)...
@export var light_dash_exit_speed: float = 15.0  ## ...and carries on from the last ring at this speed (m/s).

@export_group("Walls")
@export var wall_cling_time: float = 1.0  ## Seconds a player can cling to a wall-jump panel before falling off.
@export var wall_cling_slide: float = 2.0  ## How fast they slide down it meanwhile (m/s).
@export var wall_jump_out: float = 9.0  ## A wall jump's speed away from the wall (m/s)...
@export var wall_jump_up: float = 13.0  ## ...and up (m/s).
@export var wall_jump_lock: float = 0.25  ## Seconds the stick is ignored after a wall jump, so the player arcs away from the wall.
@export var wall_run_min_speed: float = 10.0  ## A wall-run strip catches a player going at least this fast along it (m/s).

@export_group("Enemies")
@export var rebound_slowdown: float = 1.0 * SPEED  ## Destroying an enemy in the air while rising, or from below its middle, only slows the player by this much (m/s). From above they bounce back up.

@export_group("Assists")
@export var coyote_time: float = 0.1  ## Seconds after running off a ledge during which a jump still works.
@export var jump_buffer_time: float = 0.1  ## Seconds a jump press is remembered before landing.

@export_group("2.5D")
@export var lane_pull_speed: float = 8.0  ## How fast a 2.5D section pulls the player onto its path at the least (m/s)...
@export var lane_pull_ratio: float = 1.5  ## ...or this many m/s for every m/s they go along it, if faster, so they come onto it at the same slant at any speed: 1.5 is about 56°, two metres of travel for every three off it, as quick as a quickstep. A section's lead-in eases them in at that slant too, and its funnel opens at it.

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

@export_group("Water")
@export var water_factor: float = 0.5  ## Underwater, acc, dec, frc, top, air_acc, roll_frc and boost_speed are multiplied by this, as the classic games halve them.
@export var water_grv: float = 0.0625 * ACCEL  ## Gravity underwater (m/s²).
@export var water_jmp: float = 3.5 * SPEED  ## Speed of a jump underwater (m/s).
@export var water_jmp_release_cap: float = 2.0 * SPEED  ## Letting go of jump early underwater caps the upward speed to this (m/s).
@export var water_hurt_gravity: float = 0.0625 * ACCEL  ## Gravity while knocked back underwater (m/s²).
@export_range(0.0, 1.0) var water_entry_horizontal: float = 0.5  ## Falling into water keeps this share of the horizontal speed...
@export_range(0.0, 1.0) var water_entry_vertical: float = 0.25  ## ...and this share of the vertical speed.
@export var water_exit_boost: float = 2.0  ## Leaving the water while rising multiplies the upward speed by this (up to max_fall), so a jump carries the player out.
@export var air_time: float = 30.0  ## Seconds of air underwater before drowning.
@export var drown_countdown: float = 12.0  ## With this many seconds of air left, the countdown and its music start.
@export var breathe_pause: float = 0.35  ## Seconds the player stops still while taking a breath from an air bubble.

@export_group("Grind rails")
@export var grind_catch: float = 0.6  ## A rail this close to the player's feet catches them (m).
@export var grind_min_speed: float = 5.0  ## Landing on a rail with less speed along it than this grinds at this speed (m/s).
@export var grind_frc: float = 0.5  ## Slowdown while grinding (m/s²), though never below grind_min_speed. Slopes use slp_roll_up and slp_roll_down, as rolling does.
@export var grind_switch_reach: float = 5.0  ## A quickstep while grinding hops to another rail at most this far to the side (m).
@export var grind_switch_time: float = 0.18  ## Seconds a hop to another rail takes.
@export var grind_cooldown: float = 0.3  ## Seconds after leaving a rail before it can catch the player again.

@export_group("Power-ups")
@export var speed_shoes_time: float = 20.0  ## Seconds speed shoes last.
@export var speed_shoes_factor: float = 2.0  ## Speed shoes multiply acc, frc, top, air_acc and roll_frc by this.
@export var invincibility_time: float = 20.0  ## Seconds invincibility lasts.
@export var magnet_time: float = 20.0  ## Seconds the ring magnet lasts.
@export var magnet_range: float = 5.0  ## Rings this close (m) fly to a player with the magnet.
@export var magnet_pull_speed: float = 15.0  ## How much faster than the player a pulled ring flies (m/s).
