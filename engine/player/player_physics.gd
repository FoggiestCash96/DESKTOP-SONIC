class_name PlayerPhysics
extends Resource
## Movement constants for a player character, in SI units (m, m/s, m/s², s, degrees per second).
## The defaults are the classic 60 fps platformer values (px/frame and px/frame²), converted
## with PIXELS_PER_METER: speeds × 60 / 32, accelerations × 3600 / 32.
## Slope and rolling constants arrive with slope physics in Milestone 3.

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

@export_group("Air")
@export var air_acc: float = 0.09375 * ACCEL  ## Acceleration from input while airborne (m/s²).
@export var grv: float = 0.21875 * ACCEL  ## Gravity (m/s²).
@export var jmp: float = 6.5 * SPEED  ## Upward speed at the start of a jump (m/s).
@export var jmp_release_cap: float = 4.0 * SPEED  ## Letting go of jump early caps the upward speed to this (m/s).
@export var max_fall: float = 16.0 * SPEED  ## Terminal fall speed (m/s).
@export var air_drag: bool = true  ## Classic drag on horizontal speed near the top of a jump.

@export_group("Assists")
@export var coyote_time: float = 0.1  ## Seconds after running off a ledge during which a jump still works.
@export var jump_buffer_time: float = 0.1  ## Seconds a jump press is remembered before landing.
