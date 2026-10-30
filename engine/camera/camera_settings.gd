class_name CameraSettings
extends Resource
## Tuning for the player camera, in metres, seconds and degrees.

@export_group("Framing")
@export var height: float = 1.0  ## Height above the player's feet that the camera orbits and aims at (m).
@export var distance: float = 6.0  ## Distance from the player in free mode (m).
@export var default_pitch: float = -15.0  ## Pitch in free mode (degrees). Negative looks down.
@export var min_pitch: float = -75.0  ## Lowest the camera can look (degrees).
@export var max_pitch: float = 20.0  ## Highest the camera can look (degrees).
@export var look_ahead_time: float = 0.3  ## Aims this many seconds of the player's velocity ahead of them.
@export var look_ahead_max: float = 6.0  ## Never aims further ahead than this (m).
@export var look_ahead_smoothing: float = 0.4  ## Seconds for the aim to catch up with a change of velocity.

@export_group("Field of view")
@export var fov_rest: float = 70.0  ## Field of view standing still (degrees).
@export var fov_fast: float = 85.0  ## Field of view at the player's top running speed and above (degrees).
@export var fov_smoothing: float = 0.3  ## Seconds for the field of view to catch up.

@export_group("Control")
@export var look_speed: float = 150.0  ## Stick and arrow-key orbit speed (degrees per second).
@export var mouse_sensitivity: float = 0.15  ## Degrees per pixel of mouse motion.
@export var auto_follow_delay: float = 1.0  ## Seconds after the player last moved the camera before it follows again.
@export var auto_follow_speed: float = 90.0  ## How fast the camera swings behind the player at top running speed (degrees per second).
@export var auto_follow_min_speed: float = 1.0  ## The camera only follows while the player moves at least this fast (m/s).
@export var auto_follow_max_angle: float = 135.0  ## The camera doesn't swing round while the player runs at it more steeply than this (degrees).
@export var recenter_time: float = 0.25  ## Seconds for camera_recenter to swing the camera behind the player.

@export_group("Collision")
@export var collision_radius: float = 0.25  ## Size of the probe that keeps the camera out of walls (m).
@export var collision_margin: float = 0.2  ## Gap kept between the camera and a wall in the way (m).
@export var ease_out_speed: float = 6.0  ## How fast the camera moves back out once a wall stops being in the way (m/s).
@export var hide_player_distance: float = 1.0  ## Hides the player's model when a wall pushes the camera closer than this (m).
