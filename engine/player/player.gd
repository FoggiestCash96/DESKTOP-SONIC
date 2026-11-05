class_name Player
extends CharacterBody3D
## Kinematic player controller with classic momentum physics: speed along the surface, slopes
## that add and take away speed, walls and loops through surface alignment, rolling and the spin
## dash, free 3D velocity in the air, the homing attack and air dash, the boost and the quickstep,
## grinding on rails and swimming. Each movement state is a script in engine/player/states/; the
## shared surface handling lives here, along with rings, hits, power-ups, air under water, being
## crushed and staying on 2.5D paths. Input is relative to the active camera, and all tuning lives
## in `physics`.

signal died  ## The player died. The stage restarts, or the game ends, a moment later.

const GROUP := "players"  ## Every player joins this group, so stages can find them.
const OVERLAY_LABELS: Array[String] = ["State", "Speed", "Velocity", "Surface", "Heading", "Position", "Items"]
const NEAR_VERTICAL := 75.0  ## Running off the top of a surface this steep (degrees) launches straight up, as at the lip of a half-pipe.
const COLLECTIBLES_LAYER := 1 << 4  ## Physics layer the ring magnet searches.
const MAGNET_MAX_RINGS := 64  ## Most rings the magnet can start pulling in one tick.
const FLASH_PERIOD := 0.1  ## Seconds per flash while invulnerable or invincible.
const PUSH_INPUT := 0.5  ## The stick must point at least this squarely into a wall to push against it...
const PUSH_SPEED := 1.0  ## ...with the player moving slower than this (m/s).
const FINISH_SPEED := 1.0  ## After the goal, the victory pose starts below this speed (m/s).
const LOST_RING_SCENE := "res://engine/collectibles/lost_ring.tscn"
const BOOST_BURST_SCENE := "res://engine/enemies/base/explosion.tscn"
const BOOST_BURST_COLOR := Color(0.6, 0.85, 1.0, 0.8)
const SPLASH_COLOR := Color(0.85, 0.97, 1.0, 0.85)
const WORLD_MASK := 1  ## Physics layer of level geometry, which blocks the homing attack's line of sight.
const SAFE_SPOT_INTERVAL := 0.5  ## With the assist on, where the player stands is remembered this often (s)...
const SAFE_GROUND := 0.8  ## ...on ground at least this level (the up component of its normal).
const SKID_SOUND_SPEED := 4.0  ## Braking from at least this fast (m/s) screeches.
const WATER_HEIGHT := 0.5  ## The player is under water once this point above their feet is (m).
const CRUSH_MARGIN := 0.12  ## Squeezed this far into level geometry by something moving, the player is crushed (m).
const CRUSH_REACH := 30.0  ## Only things that move within this distance can crush (m).

static var _lost_ring: PackedScene  # Loaded on first use; preloading it here would make a load cycle with the rings.

@export var character: CharacterDef  ## Who the player is: their model and, optionally, movement values. Empty plays the stand-in capsule.
@export var physics: PlayerPhysics = preload("res://engine/player/player_physics.tres")  ## Swapped for a faster copy while speed shoes last.
@export var kill_height: float = -50.0  ## Falling below this height (m) costs a life.

var ground_speed := 0.0  ## Speed along the ground (m/s).
var heading := Vector3.FORWARD  ## Direction of travel along the ground, as a unit vector.
var ground_normal := Vector3.UP  ## Normal of the surface underfoot, or straight up in the air.
var rings := 0
var shield := false  ## A shield takes the next hit in place of the rings.

# Input, read once at the start of every physics tick.
var wish := Vector3.ZERO  ## Camera-relative stick direction on the horizontal plane, length 0 to 1.
var jump_pressed := false
var jump_held := false
var crouch_held := false
var boost_pressed := false
var boost_held := false
var quickstep_pressed := 0  ## -1 for a quickstep left this tick, 1 for right, else 0.
var boost_gauge := 0.0  ## How much boost is left (percent).
var boosting := false  ## Boosting: on the ground the boost holds boost_speed. Lasts while the button is held, through jumps.

var state: PlayerState
var ground_state: GroundState
var roll_state: RollState
var spin_dash_state: SpinDashState
var air_state: AirState
var hurt_state: HurtState
var death_state: DeathState
var homing_state: HomingState
var grind_state: GrindState
var homing_candidate: HomingTarget  ## What a homing attack would lock on to right now, shown with a reticle. Null on the ground or with the attack used.

var _spawn: Transform3D
var _base_physics: PlayerPhysics
var _control_lock := 0.0
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _flat_heading := Vector3.FORWARD  # Horizontal direction of travel from before the surface got steep.
var _curled := false
var _intangible := false
var _hidden_by_camera := false
var _invulnerable_timer := 0.0
var _shoes_timer := 0.0
var _invincible_timer := 0.0
var _magnet_timer := 0.0
var _magnet_query := PhysicsShapeQueryParameters3D.new()
var _input_enabled := true
var _lane: CameraVolume  # The 2.5D section holding the player to its path, if any.
var _model: CharacterModel  # The character's model, if `character` has one.
var _braking := false  # Braking against the direction of travel this tick.
var _pushing := false  # Pushing against a wall this tick.
var _sprung := false  # Launched by a spring and not landed since.
var _air_action_ready := true  # The homing attack or air dash hasn't been used since the player left the ground.
var _safe_spots: Array[Transform3D] = []  # Where the player last stood on solid ground, older first, for the assist.
var _air_boost_timer := 0.0  # Seconds of air boost left.
var _air_boost_ready := true  # The air boost hasn't been used since the player left the ground.
var _quickstep_timer := 0.0  # Seconds of quickstep left.
var _quickstep_side := 0.0  # Which way the quickstep goes: -1 left, 1 right.
var _safe_timer := 0.0
var _was_braking := false
var _underwater := false  # Below a WaterVolume's surface.
var _air := 30.0  # Seconds of air left under water.
var _physics_variants: Dictionary[int, PlayerPhysics] = {}  # `physics` with speed shoes and under water, worked out once each.
var _rail_cooldown := 0.0  # Seconds before a rail can catch the player again.
var _crush_query := PhysicsShapeQueryParameters3D.new()
var _crush_ball := SphereShape3D.new()
var _crush_capsule := CapsuleShape3D.new()

@onready var _standing_shape: CollisionShape3D = %StandingShape
@onready var _ball_shape: CollisionShape3D = %BallShape
@onready var _visual: Node3D = %Visual
@onready var _body_mesh: Node3D = %Body
@onready var _ball_mesh: Node3D = %Ball
@onready var _shield_mesh: Node3D = %Shield
@onready var _sparkle_mesh: Node3D = %Sparkle
@onready var _magnet_mesh: Node3D = %Magnet
@onready var _reticle: Node3D = %HomingReticle
@onready var _boost_aura: Node3D = %BoostAura


func _ready() -> void:
	add_to_group(GROUP)
	ground_state = GroundState.new(self)
	roll_state = RollState.new(self)
	spin_dash_state = SpinDashState.new(self)
	air_state = AirState.new(self)
	hurt_state = HurtState.new(self)
	death_state = DeathState.new(self)
	homing_state = HomingState.new(self)
	grind_state = GrindState.new(self)
	if character:
		if character.physics:
			physics = character.physics
		if character.model:
			_model = character.model.instantiate() as CharacterModel
			_visual.add_child(_model)
	_base_physics = physics
	boost_gauge = physics.boost_start
	_air = physics.air_time
	_crush_ball.radius = (_ball_shape.shape as SphereShape3D).radius - CRUSH_MARGIN
	var standing := _standing_shape.shape as CapsuleShape3D
	_crush_capsule.radius = standing.radius - CRUSH_MARGIN
	_crush_capsule.height = standing.height - CRUSH_MARGIN * 2.0
	_crush_query.collision_mask = WORLD_MASK
	_crush_query.exclude = [get_rid()]
	floor_snap_length = physics.snap_length
	floor_max_angle = deg_to_rad(physics.surface_step_angle)
	# The states set velocity themselves; without this a falling body touching an edge would stop dead on it.
	floor_stop_on_slope = false
	# After a death the stage reloads, and the player starts from the last checkpoint touched.
	_spawn = GameState.spawn_point(owner.scene_file_path if owner else "", global_transform)
	global_transform = _spawn
	_safe_spots = [_spawn, _spawn]
	heading = _flat(-global_basis.z, Vector3.FORWARD)
	_flat_heading = heading
	var magnet_shape := SphereShape3D.new()
	magnet_shape.radius = physics.magnet_range
	_magnet_query.shape = magnet_shape
	_magnet_query.collision_mask = COLLECTIBLES_LAYER
	_magnet_query.collide_with_areas = true
	_magnet_query.collide_with_bodies = false
	state = air_state
	state.enter(null)

	DebugOverlay.watch("State", func() -> String: return state.label())
	DebugOverlay.watch("Speed", func() -> String: return "%.2f m/s  (top %.2f)" % [ground_speed, physics.top])
	DebugOverlay.watch("Velocity", func() -> String: return "horizontal %.2f  vertical %.2f m/s" % [Vector2(velocity.x, velocity.z).length(), velocity.y])
	DebugOverlay.watch("Surface", func() -> String: return "%.0f° from flat%s" % [PlayerMotion.steepness(ground_normal), "  (stick locked %.2f s)" % _control_lock if _control_lock > 0.0 else ""])
	DebugOverlay.watch("Heading", func() -> String: return "%.0f°  (turn rate %.0f°/s)" % [rad_to_deg(atan2(-horizontal_heading().x, -horizontal_heading().z)), rad_to_deg(PlayerMotion.turn_rate(ground_speed, physics))])
	DebugOverlay.watch("Position", func() -> String: return "%.1f, %.1f, %.1f" % [global_position.x, global_position.y, global_position.z])
	DebugOverlay.watch("Items", describe_items)


func _exit_tree() -> void:
	for label in OVERLAY_LABELS:
		DebugOverlay.unwatch(label)
	# The stage is going (reloading or changing): power-up music and the boost's sound go with it.
	Sfx.set_looping(&"boost_loop", false)
	Sfx.set_looping(&"grind_loop", false)
	_end_power_ups()


func _physics_process(delta: float) -> void:
	_lane = _find_lane()
	_braking = false
	_pushing = false
	_read_input()
	_update_water(delta)
	_update_boost(delta)
	_start_quickstep()
	state.tick(delta)
	move_and_slide()
	state.after_move(delta)
	_catch_rail()
	if state != death_state and _crushed():
		die()
	# Running head-on into a wall stops the boost rather than grinding into it.
	if boosting and state == ground_state and ground_speed < physics.boost_speed * 0.5:
		boosting = false
	_hold_to_lane(delta)
	if _braking and not _was_braking and ground_speed >= SKID_SOUND_SPEED:
		Sfx.play(&"skid")
	_was_braking = _braking
	Sfx.set_looping(&"boost_loop", is_boosting() and state != death_state)
	Sfx.set_looping(&"grind_loop", state == grind_state)
	_count_down(delta)
	if _magnet_timer > 0.0:
		_pull_rings()
	_remember_safe_spot(delta)
	if global_position.y < kill_height and state != death_state:
		if GameSettings.assist:
			_return_to_safe_ground()
		else:
			die(false)
	homing_candidate = find_homing_target() if state == air_state and _air_action_ready and _input_enabled else null


func _process(_delta: float) -> void:
	_update_visual()
	_boost_aura.visible = is_boosting() and _visual.visible
	_reticle.visible = is_instance_valid(homing_candidate)
	if _reticle.visible:
		_reticle.global_position = homing_candidate.get_global_transform_interpolated().origin
	if _model:
		_model.animate(pose(), ground_speed if is_grounded() else velocity.length())


## Which of CharacterModel.POSES the player's model should show right now.
func pose() -> StringName:
	if state == grind_state:
		return &"skid"  # Leaning back on the rail.
	var finished := not _input_enabled and is_grounded() and absf(ground_speed) < FINISH_SPEED
	var sprung := _sprung and state == air_state and velocity.y > 0.0
	return PlayerMotion.pose(state == death_state, state == hurt_state, is_attacking(), is_grounded(), sprung, finished, _braking, _pushing)


## Leaves the current state and enters `next`.
func change_state(next: PlayerState) -> void:
	var previous := state
	previous.exit()
	state = next
	next.enter(previous)


## Puts the player back at its spawn point, standing still, without power-ups. Rings are kept.
func respawn() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	ground_speed = 0.0
	heading = _flat(-_spawn.basis.z, Vector3.FORWARD)
	_flat_heading = heading
	_control_lock = 0.0
	_invulnerable_timer = 0.0
	_air_action_ready = true
	_end_power_ups()
	_catch_breath()
	change_state(air_state)
	reset_physics_interpolation()


## Direction of travel on the horizontal plane, for cameras: the heading, or on steep surfaces
## the way the player was going before it got steep.
func horizontal_heading() -> Vector3:
	return _flat_heading if _is_steep() else _flat(heading, _flat_heading)


func is_dead() -> bool:
	return state == death_state


## Whether the player is on the ground: running, rolling or spin dashing.
func is_grounded() -> bool:
	return state == ground_state or state == roll_state or state == spin_dash_state


## Whether the player is curled into a ball (jumping, rolling, spin dashing or homing in) or
## boosting, which breaks item monitors and destroys enemies.
func is_attacking() -> bool:
	return (_curled or is_boosting()) and not _intangible


## Boosting on the ground or through the air, or in the middle of an air boost.
func is_boosting() -> bool:
	return boosting or _air_boost_timer > 0.0


func air_boost_time_left() -> float:
	return _air_boost_timer


func is_homing() -> bool:
	return state == homing_state


func is_grinding() -> bool:
	return state == grind_state


## Whether the player can smash a breakable wall: rolling (after a spin dash too) or boosting.
func can_smash() -> bool:
	return (state == roll_state or is_boosting()) and not _intangible


## Below the surface of a WaterVolume, swimming.
func is_underwater() -> bool:
	return _underwater


## Seconds of air left under water.
func air_left() -> float:
	return _air


## The middle of the curled-up ball, where homing attacks aim from.
func ball_center() -> Vector3:
	return global_position + global_basis.y.normalized() * _ball_shape.position.y


# --- Input --------------------------------------------------------------------------------

func wants_jump() -> bool:
	return jump_pressed or _jump_buffer_timer > 0.0


## Uses up this tick's jump press for something other than jumping, such as charging a spin dash.
func consume_jump() -> void:
	jump_pressed = false
	_jump_buffer_timer = 0.0


func coyote_jump_ready() -> bool:
	return _coyote_timer > 0.0


## Ignores the stick for at least `seconds`, as after a slip or a spring.
func lock_controls(seconds: float) -> void:
	_control_lock = maxf(_control_lock, seconds)


func controls_locked() -> bool:
	return _control_lock > 0.0


## The stick as a direction along the current surface, length 0 to 1. On surfaces steeper than
## slip_angle it only speeds up or slows down along the path ("forward" is the way the player was
## going before it got steep), so loops and walls work the same from any camera angle.
func surface_wish() -> Vector3:
	if _control_lock > 0.0 or wish == Vector3.ZERO:
		return Vector3.ZERO
	if _is_steep():
		return heading * wish.dot(_flat_heading)
	var along := PlayerMotion.along_surface(wish, ground_normal)
	if along.length_squared() < 1e-6:
		return Vector3.ZERO
	return along.normalized() * wish.length()


# --- Ground movement, used by the ground states -------------------------------------------

## Classic slope physics: gravity's pull along the surface speeds the player up downhill and slows
## them uphill. Across a slope it also bends their path downhill.
func apply_slope(strength: float, delta: float) -> void:
	var motion := heading * ground_speed + PlayerMotion.downhill(ground_normal) * strength * delta
	ground_speed = motion.length()
	if ground_speed > 1e-4:
		heading = motion / ground_speed
	else:
		ground_speed = 0.0


## Running: speeds up toward the stick, brakes when the stick points back, turns at the
## speed-dependent turn rate, and coasts to a stop without input.
func run(delta: float) -> void:
	var input := surface_wish()
	var strength := input.length()
	if strength <= 0.0:
		coast(delta)
		return
	var direction := input / strength
	if ground_speed > 0.0 and rad_to_deg(heading.angle_to(direction)) > physics.brake_angle:
		_braking = true
		ground_speed = PlayerMotion.brake_speed(ground_speed, physics, delta)
		if ground_speed < 0.0:  # Braked to a stop: turn around.
			heading = direction
			ground_speed = -ground_speed
		return
	if ground_speed > 0.0:
		var max_turn := PlayerMotion.turn_rate(ground_speed, physics) * delta
		heading = PlayerMotion.turn_toward(heading, direction, ground_normal, max_turn)
	else:
		heading = direction  # From a standstill, face the stick straight away.
	ground_speed = PlayerMotion.run_speed(ground_speed, strength, physics, delta)


## Slowing down with no input.
func coast(delta: float) -> void:
	ground_speed = PlayerMotion.run_speed(ground_speed, 0.0, physics, delta)


## Rolling: the stick can only steer gently or brake, and roll friction always applies.
func roll(delta: float) -> void:
	var input := surface_wish()
	var braking := false
	if input.length_squared() > 1e-6 and ground_speed > 0.0:
		var direction := input.normalized()
		if rad_to_deg(heading.angle_to(direction)) > physics.brake_angle:
			braking = true
		else:
			var max_turn := PlayerMotion.turn_rate(ground_speed, physics) * physics.roll_turn_factor * delta
			heading = PlayerMotion.turn_toward(heading, direction, ground_normal, max_turn)
	ground_speed = PlayerMotion.roll_speed(ground_speed, braking, physics, delta)


## Turns to face the stick without moving, as when lining up a spin dash.
func aim() -> void:
	var input := surface_wish()
	if input.length_squared() > 1e-6:
		heading = input.normalized()


## Sets this tick's velocity from the ground speed and heading (plus any quickstep), and stands the
## body on the surface.
func move_on_ground() -> void:
	ground_speed = minf(ground_speed, physics.max_ground_speed)
	velocity = heading * ground_speed
	if _quickstep_timer > 0.0:
		# The last tick only covers what's left, so the step is quickstep_distance at any tick rate.
		var share := minf(_quickstep_timer / get_physics_process_delta_time(), 1.0)
		velocity += PlayerMotion.quickstep_velocity(heading, ground_normal, _quickstep_side, physics) * share
	up_direction = ground_normal
	_orient(ground_normal, heading, 1.0)


## After a move on the ground: follows the surface underfoot, or leaves it at an edge, or drops off
## an overhang that is too steep for this speed. Starts a slip when too slow on a steep surface.
func follow_ground() -> void:
	if not is_on_floor():
		# move_and_slide() only snaps when the velocity points into the surface, and velocity along
		# a slope rounds either way, so snap explicitly. Crests stay stuck; real edges still let go.
		apply_floor_snap()
	var below := _ground_below() if is_on_floor() else {}
	if below.is_empty():
		# Drop any motion into the surface just left. Off a near-vertical wall that means all motion
		# toward it, so the player goes straight up and falls back in instead of drifting over the edge.
		var away := ground_normal
		if PlayerMotion.steepness(ground_normal) > NEAR_VERTICAL:
			away = _flat(ground_normal, ground_normal)
		velocity -= away * minf(velocity.dot(away), 0.0)
		_coyote_timer = physics.coyote_time
		change_state(air_state)
		return
	ground_normal = below["normal"]
	heading = _on_plane(heading, ground_normal, _any_perpendicular(ground_normal))
	_slide_along_walls()
	if not _is_steep():
		_flat_heading = _flat(heading, _flat_heading)
	if PlayerMotion.falls_off(ground_speed, ground_normal, physics):
		change_state(air_state)
		return
	if _control_lock <= 0.0 and PlayerMotion.slips(ground_speed, ground_normal, physics):
		_control_lock = physics.slip_lock_time


## Jumps away from the surface, or straight up just after running off a ledge.
func jump() -> void:
	var grounded := state != air_state
	if grounded:
		velocity = heading * ground_speed + ground_normal * physics.jmp
	else:
		velocity.y = physics.jmp
		set_ball(true)
	air_state.jumped = true
	air_state.rising = true
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	Sfx.play(&"jump")
	if grounded:
		change_state(air_state)


## Lands on the floor just touched: the part of the velocity along the surface becomes ground speed.
## Touching only an edge, with no ground under the player's middle, isn't a landing: they slide off.
func land() -> void:
	var below := _ground_below()
	if below.is_empty():
		return
	ground_normal = below["normal"]
	var along := PlayerMotion.along_surface(velocity, ground_normal)
	ground_speed = along.length()
	if ground_speed < 1e-4:
		ground_speed = 0.0
		along = heading
	heading = _on_plane(along, ground_normal, _any_perpendicular(ground_normal))
	_flat_heading = _flat(heading, _flat_heading)
	_sprung = false
	_air_action_ready = true
	_air_boost_ready = true
	_air_boost_timer = 0.0
	change_state(ground_state)


# --- Gimmicks -----------------------------------------------------------------------------

## Throws the player into the air at `new_velocity`, uncurled, as a spring does. The stick is
## ignored for `lock_time` seconds.
func launch(new_velocity: Vector3, lock_time: float) -> void:
	if state == death_state:
		return
	velocity = new_velocity
	if state != air_state:
		change_state(air_state)
	air_state.jumped = false
	air_state.rising = false
	set_ball(false)
	_sprung = true
	_air_action_ready = true
	_air_boost_ready = true
	_coyote_timer = 0.0
	lock_controls(lock_time)


## Sends a grounded player along the surface in `direction` at `speed`, as sideways springs and
## dash panels do. With `keep_faster` a faster player keeps their speed. The stick is ignored for
## `lock_time` seconds. Returns false, doing nothing, if the player isn't on the ground.
func push_along_ground(direction: Vector3, speed: float, keep_faster: bool, lock_time: float) -> bool:
	if not is_grounded():
		return false
	heading = _on_plane(direction, ground_normal, heading)
	ground_speed = maxf(ground_speed, speed) if keep_faster else speed
	if state == spin_dash_state:
		change_state(roll_state)
	lock_controls(lock_time)
	return true


## Bounces back up off something broken from above, such as an item monitor: falling speed turns
## into rising speed. Letting go of jump still cuts the rise short, as it would a jump. After a
## homing attack it's the homing bounce instead.
func bounce() -> void:
	if state == homing_state:
		_bounce_up(physics.homing_bounce)
	elif state == air_state and velocity.y < 0.0:
		velocity.y = -velocity.y
		air_state.rising = air_state.jumped


# --- Homing attack and enemies ------------------------------------------------------------

## The boost button in the air: a straight dash at boost_speed where the player faces, for
## air_boost_time, at the cost of air_boost_cost of the gauge. Once each time the player leaves the
## ground. Holding the button on, the boost carries on after landing. Returns whether it boosted.
func try_air_boost() -> bool:
	if not _air_boost_ready or boost_gauge < physics.air_boost_cost or state != air_state:
		return false
	_air_boost_ready = false
	add_boost(-physics.air_boost_cost)
	_air_boost_timer = physics.air_boost_time
	velocity = air_aim() * physics.boost_speed
	boosting = boost_held
	set_ball(false)
	Sfx.play(&"air_boost")
	return true


## A second press of jump in the air: a homing attack on the nearest target in reach, or with none,
## an air dash ahead. Once each time the player leaves the ground; landing a homing attack gives it
## back. Returns whether it did either.
func try_air_action() -> bool:
	if not _air_action_ready:
		return false
	_air_action_ready = false
	consume_jump()
	var target := find_homing_target()
	if target:
		homing_state.target = target
		change_state(homing_state)
		Sfx.play(&"homing")
		return true
	var horizontal := PlayerMotion.air_dash(Vector3(velocity.x, 0.0, velocity.z), air_aim(), physics.air_dash_speed)
	velocity = horizontal + Vector3.UP * maxf(velocity.y, 0.0)
	air_state.jumped = true
	air_state.rising = false
	set_ball(true)
	Sfx.play(&"air_dash")
	return true


## The way the player faces in the air, for the homing attack and air dash: where the stick points,
## or with the stick let go, their direction of travel.
func air_aim() -> Vector3:
	if wish.length_squared() > 0.01:
		return _flat(wish, horizontal_heading())
	return _flat(velocity, horizontal_heading())


## The nearest enabled HomingTarget within reach (PlayerMotion.in_homing_reach()) that no level
## geometry hides, or null.
func find_homing_target() -> HomingTarget:
	var origin := ball_center()
	var facing := air_aim()
	var best: HomingTarget = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(HomingTarget.GROUP):
		var target := node as HomingTarget
		if target == null or not target.enabled or not target.is_visible_in_tree():
			continue
		var offset := target.global_position - origin
		var distance := offset.length()
		if distance >= best_distance or not PlayerMotion.in_homing_reach(offset, facing, physics.homing_range, physics.homing_cone):
			continue
		if not _in_sight(origin, target.global_position):
			continue
		best = target
		best_distance = distance
	return best


## Rebounds off an enemy just destroyed, whose middle is at `center`. After a homing attack the
## player bounces straight up, ready to chain into the next. Otherwise in the air it's the classic
## rebound (PlayerMotion.enemy_rebound()); on the ground, rolling or spin dashing, they carry on.
func rebound_from(center: Vector3) -> void:
	if state == homing_state:
		_bounce_up(physics.homing_bounce)
	elif state == air_state:
		var falling := velocity.y <= 0.0
		velocity.y = PlayerMotion.enemy_rebound(velocity.y, ball_center().y, center.y, physics.rebound_slowdown)
		if falling and velocity.y > 0.0:
			air_state.rising = air_state.jumped


## Thrown back off something hit hard, such as a boss's weak point: away from `from` at `speed` and
## up at `rise`, still curled, with the homing attack and air dash ready again.
func bounce_back(from: Vector3, speed: float, rise: float) -> void:
	if state == death_state:
		return
	_bounce_up(rise)
	velocity += _flat(global_position - from, -horizontal_heading()) * speed


## Straight up at `speed`, curled, with the homing attack and air dash ready again.
func _bounce_up(speed: float) -> void:
	velocity = Vector3.UP * speed
	air_state.jumped = true
	air_state.rising = false
	_air_action_ready = true
	if state == air_state:
		set_ball(true)
	else:
		change_state(air_state)


## Starts, keeps up or ends the boost. Pressing boost on the ground with gauge left starts it; it
## lasts while the button is held, through jumps, using boost_drain of the gauge per second on the
## ground and holding at least boost_speed there. Letting go, running out, a hit, rolling or a spin
## dash ends it.
func _update_boost(delta: float) -> void:
	var stopped := not boost_held or state == hurt_state or state == death_state or state == roll_state or state == spin_dash_state
	if boosting and (stopped or (is_grounded() and boost_gauge <= 0.0)):
		boosting = false
	elif not boosting and boost_pressed and (state == ground_state or state == grind_state) and boost_gauge > 0.0:
		boosting = true
		_boost_burst()
	if boosting and (state == ground_state or state == grind_state):
		add_boost(-physics.boost_drain * delta)
		ground_speed = maxf(ground_speed, physics.boost_speed)


## A flash of air as the boost starts.
func _boost_burst() -> void:
	Sfx.play(&"boost")
	var burst := (load(BOOST_BURST_SCENE) as PackedScene).instantiate() as Node3D
	burst.set("size", 3.0)
	get_parent().add_child(burst)
	burst.global_position = ball_center()
	var ball := burst.get_node_or_null("%Ball") as MeshInstance3D
	if ball and ball.material_override is StandardMaterial3D:
		(ball.material_override as StandardMaterial3D).albedo_color = BOOST_BURST_COLOR


## A quickstep: on the ground running at least quickstep_min_speed, quickstep_left or quickstep_right
## shifts the player quickstep_distance sideways over quickstep_time, keeping their speed. Not on a
## 2.5D path, where there is no sideways.
func _start_quickstep() -> void:
	if quickstep_pressed == 0 or _quickstep_timer > 0.0 or state != ground_state or _lane:
		return
	if ground_speed < physics.quickstep_min_speed:
		return
	_quickstep_side = float(quickstep_pressed)
	_quickstep_timer = physics.quickstep_time
	Sfx.play(&"quickstep")


## With the assist on: every SAFE_SPOT_INTERVAL on solid, fairly level ground, remembers where the
## player stands, keeping the last two.
func _remember_safe_spot(delta: float) -> void:
	_safe_timer += delta
	if _safe_timer < SAFE_SPOT_INTERVAL or not is_grounded() or ground_normal.y < SAFE_GROUND:
		return
	_safe_timer = 0.0
	_safe_spots = [_safe_spots[1], global_transform]


## With the assist on, falling into a pit puts the player back on the older remembered spot (the newer
## one may be the edge they just ran off), flashing, instead of costing a life.
func _return_to_safe_ground() -> void:
	var spot := _safe_spots[0]
	_safe_spots = [spot, spot]
	global_transform = spot
	velocity = Vector3.ZERO
	ground_speed = 0.0
	heading = _flat(-spot.basis.z, heading)
	_flat_heading = heading
	change_state(air_state)
	_invulnerable_timer = physics.invulnerable_time
	reset_physics_interpolation()


func _in_sight(from: Vector3, to: Vector3) -> bool:
	var exclude: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Moving water pushing the player along `direction` (a horizontal unit vector): it speeds them up
## along it by `amount` (m/s), but not past `max_speed`, and slows them down against it.
func push(direction: Vector3, max_speed: float, amount: float) -> void:
	if state == death_state or state == grind_state:
		return
	if not is_grounded():
		velocity = PlayerMotion.pushed(velocity, direction, max_speed, amount)
		return
	var along_ground := _on_plane(direction, ground_normal, Vector3.ZERO)
	var motion := PlayerMotion.pushed(heading * ground_speed, along_ground, max_speed, amount)
	ground_speed = motion.length()
	if ground_speed > 1e-4:
		heading = motion / ground_speed
	else:
		ground_speed = 0.0


## Turns the player's controls off, as at the goal, or back on.
func set_input_enabled(on: bool) -> void:
	_input_enabled = on


# --- Rings, damage and power-ups ----------------------------------------------------------

func collect_rings(amount: int) -> void:
	rings += amount
	Sfx.play(&"ring")
	add_boost(amount * physics.boost_per_ring)


## Adds `amount` to the boost gauge (percent), as rings, enemies and boost monitors do.
func add_boost(amount: float) -> void:
	boost_gauge = PlayerMotion.boost_fill(boost_gauge, amount)


## Fills the boost gauge, as a boost monitor does.
func fill_boost() -> void:
	boost_gauge = 100.0
	Sfx.play(&"boost_fill")


## Takes a hit from something at `from`. A shield or the rings soak it up (the rings scatter), with
## a short knockback and a couple of seconds of flashing invulnerability. With neither, the player
## dies. Invincibility, that flashing, and the assist setting ignore hits. Returns whether the hit landed.
func hurt(from: Vector3) -> bool:
	if state == death_state or _invulnerable_timer > 0.0 or _invincible_timer > 0.0 or GameSettings.assist:
		return false
	if shield:
		shield = false
		Sfx.play(&"shield_loss")
	elif rings > 0:
		_scatter_rings()
		Sfx.play(&"ring_loss")
	else:
		die()
		return true
	_invulnerable_timer = physics.invulnerable_time
	velocity = PlayerMotion.hurt_velocity(_flat(global_position - from, -heading), physics)
	change_state(hurt_state)
	return true


## Dies: a hop up and a fall through everything, then the stage restarts or the game ends. A fall
## out of the world or drowning (`hop` false) skips the hop. With no stage listening, the player
## respawns.
func die(hop := true, sound := &"death") -> void:
	if state == death_state:
		return
	death_state.hop = hop
	change_state(death_state)
	Sfx.play(sound)
	_invulnerable_timer = 0.0
	_end_power_ups()
	if died.get_connections().is_empty():
		get_tree().create_timer(GameState.rules.restart_delay).timeout.connect(respawn)
	died.emit()


func give_shield() -> void:
	shield = true
	Sfx.play(&"shield")


## Speed shoes double acceleration, friction and top speed for a while, and speed up the music.
func give_speed_shoes() -> void:
	_shoes_timer = _base_physics.speed_shoes_time
	_refresh_physics()
	Music.set_fast(true)


## Invincibility, with its own music while it lasts.
func give_invincibility() -> void:
	_invincible_timer = _base_physics.invincibility_time
	Music.start_override(&"invincible")


func give_magnet() -> void:
	_magnet_timer = _base_physics.magnet_time
	Sfx.play(&"magnet")


func is_invincible() -> bool:
	return _invincible_timer > 0.0


## Seconds left of flashing invulnerability after a hit.
func invulnerable_time_left() -> float:
	return _invulnerable_timer


func shoes_time_left() -> float:
	return _shoes_timer


func invincibility_time_left() -> float:
	return _invincible_timer


func magnet_time_left() -> float:
	return _magnet_timer


## Rings and power-ups, for the debug overlay.
func describe_items() -> String:
	var parts: PackedStringArray = ["rings %d" % rings]
	if shield:
		parts.append("shield")
	if _shoes_timer > 0.0:
		parts.append("shoes %.1f s" % _shoes_timer)
	if _invincible_timer > 0.0:
		parts.append("invincible %.1f s" % _invincible_timer)
	if _magnet_timer > 0.0:
		parts.append("magnet %.1f s" % _magnet_timer)
	if _invulnerable_timer > 0.0:
		parts.append("flashing %.1f s" % _invulnerable_timer)
	if _underwater:
		parts.append("air %.1f s" % _air)
	parts.append("boost %d%%%s" % [roundi(boost_gauge), " (boosting)" if is_boosting() else ""])
	return "  ".join(parts)


# --- Water ----------------------------------------------------------------------------------

## Takes a breath from an air bubble: the air is full again, and the player stops still for a
## moment, as in the classic games.
func breathe() -> void:
	if state == death_state:
		return
	_catch_breath()
	Sfx.play(&"breathe")
	velocity = Vector3.ZERO
	ground_speed = 0.0
	lock_controls(physics.breathe_pause)


## Swimming: below a WaterVolume's surface the player moves with the underwater values
## (PlayerMotion.underwater()). Falling in takes most of their speed away, and leaving the water
## while rising carries them up and out. Under water the air runs down, with a chime at 25, 20 and
## 15 seconds left, the countdown and its music from drown_countdown, and drowning at nothing.
func _update_water(delta: float) -> void:
	if state == death_state:
		return
	var middle := global_position + global_basis.y.normalized() * WATER_HEIGHT
	var water := WaterVolume.find(get_tree(), middle)
	var was_underwater := _underwater
	_underwater = water != null
	if _underwater != was_underwater:
		_refresh_physics()
		if _underwater:
			velocity = PlayerMotion.water_entry(velocity, physics)
			if is_grounded():
				ground_speed *= physics.water_entry_horizontal
			_splash(water)
		else:
			if not is_grounded():
				velocity = PlayerMotion.water_exit(velocity, physics)
			_splash(WaterVolume.find(get_tree(), middle - Vector3.UP * 1.5))
			_catch_breath()
	if not _underwater:
		return
	var before := _air
	_air = maxf(_air - delta, 0.0)
	if PlayerMotion.air_warning(before, _air):
		Sfx.play(&"air_warning")
	if before > physics.drown_countdown and _air <= physics.drown_countdown:
		Music.start_override(&"drowning")
	if _air <= 0.0:
		die(false, &"drown")


## Full air again, and the drowning countdown's music gives way.
func _catch_breath() -> void:
	_air = physics.air_time
	Music.end_override(&"drowning")
	if _invincible_timer > 0.0:
		Music.start_override(&"invincible")


## A splash where the player crosses the surface of `water` (if they're still near it).
func _splash(water: WaterVolume) -> void:
	if water == null:
		return
	var at := Vector3(global_position.x, water.surface_height(global_position), global_position.z)
	Sfx.play_at(&"splash", at)
	var burst := (load(BOOST_BURST_SCENE) as PackedScene).instantiate() as Node3D
	burst.set("size", 1.6)
	get_parent().add_child(burst)
	burst.global_position = at
	var ball := burst.get_node_or_null("%Ball") as MeshInstance3D
	if ball and ball.material_override is StandardMaterial3D:
		(ball.material_override as StandardMaterial3D).albedo_color = SPLASH_COLOR


## `physics` as it should be now: the character's own values, under water and with speed shoes as
## they apply.
func _refresh_physics() -> void:
	var shoes := _shoes_timer > 0.0
	var key := int(shoes) + 2 * int(_underwater)
	if not _physics_variants.has(key):
		var variant := _base_physics
		if _underwater:
			variant = PlayerMotion.underwater(variant)
		if shoes:
			variant = PlayerMotion.with_speed_shoes(variant)
		_physics_variants[key] = variant
	physics = _physics_variants[key]


# --- Rails ----------------------------------------------------------------------------------

## Leaves the rail being ground: on along it into the air, or with `jumped` in a jump.
func leave_rail(jumped: bool) -> void:
	if state != grind_state:
		return
	velocity = grind_state.motion_direction() * ground_speed
	_rail_cooldown = physics.grind_cooldown
	if jumped:
		velocity += Vector3.UP * physics.jmp
		air_state.jumped = true
		air_state.rising = true
		Sfx.play(&"jump")
	change_state(air_state)


## Lands on a rail close enough to the feet (grind_catch), from the air or by running onto its end,
## grinding the way the player was going along it.
func _catch_rail() -> void:
	if _rail_cooldown > 0.0 or not (state == air_state or state == ground_state or state == roll_state):
		return
	if velocity.y > 2.0 and state == air_state:
		return  # Still rising: rails catch the player on the way down.
	var feet := global_position
	for node in get_tree().get_nodes_in_group(GrindRail.GROUP):
		var rail := node as GrindRail
		if rail == null or not rail.near(feet, physics.grind_catch):
			continue
		var at := rail.closest_offset(feet)
		var top := rail.top_at(at)
		if feet.distance_to(top) > physics.grind_catch or feet.y < top.y - 0.25:
			continue
		var tangent := rail.tangent_at(at)
		var along := velocity.dot(tangent)
		var toward := signf(along) if absf(along) > 0.5 else (1.0 if heading.dot(tangent) >= 0.0 else -1.0)
		ground_speed = maxf(absf(along), physics.grind_min_speed)
		grind_state.attach(rail, at, toward)
		_air_action_ready = true
		_air_boost_ready = true
		_sprung = false
		change_state(grind_state)
		return


# --- Crushing -------------------------------------------------------------------------------

## Whether something moving (a MovingPlatform) has squeezed the player into level geometry: after
## the move, a body a little smaller than theirs still overlaps something solid.
func _crushed() -> bool:
	var near := false
	for node in get_tree().get_nodes_in_group(MovingPlatform.GROUP):
		var crusher := node as Node3D
		if crusher and crusher.global_position.distance_to(global_position) < CRUSH_REACH:
			near = true
			break
	if not near or _intangible:
		return false
	var shape := _ball_shape if _curled else _standing_shape
	_crush_query.shape = (_crush_ball as Shape3D) if _curled else (_crush_capsule as Shape3D)
	_crush_query.transform = shape.global_transform
	return not get_world_3d().direct_space_state.intersect_shape(_crush_query, 1).is_empty()


# --- Body -----------------------------------------------------------------------------------

## Shows or hides the player's model, as when a wall pushes the camera right up against it.
func set_model_visible(on: bool) -> void:
	_hidden_by_camera = not on
	_update_visual()


## Switches between standing and curled into a ball (rolling, spin dash, jumping). A character
## model curls up through its animations; the stand-in capsule swaps for a sphere.
func set_ball(on: bool) -> void:
	_curled = on
	_update_shapes()
	_body_mesh.visible = not on and _model == null
	_ball_mesh.visible = on and _model == null


## Makes the player pass through everything, as when dead, or solid again.
func set_intangible(on: bool) -> void:
	_intangible = on
	_update_shapes()


## In the air: swings the body back upright and, unless `face_motion` is false, faces the
## direction of travel. Knocked back by a hit, the player keeps facing the same way.
func turn_upright(delta: float, face_motion := true) -> void:
	if face_motion:
		heading = _flat(velocity, heading)
	var up := global_basis.y.normalized()
	var angle := up.angle_to(Vector3.UP)
	var step := minf(deg_to_rad(physics.upright_speed) * delta / maxf(angle, 1e-6), 1.0)
	_orient(Vector3.UP, heading, step)


func _update_shapes() -> void:
	_standing_shape.disabled = _curled or _intangible
	_ball_shape.disabled = not _curled or _intangible


func _update_visual() -> void:
	var flash_off := _invulnerable_timer > 0.0 and fmod(_invulnerable_timer, FLASH_PERIOD) < FLASH_PERIOD * 0.5
	_visual.visible = not _hidden_by_camera and not flash_off
	_shield_mesh.visible = shield
	_sparkle_mesh.visible = _invincible_timer > 0.0 and fmod(_invincible_timer, FLASH_PERIOD) < FLASH_PERIOD * 0.6
	_magnet_mesh.visible = _magnet_timer > 0.0


## Turns the body toward `up` (all the way when `weight` is 1) and to face `forward`. It pivots on
## the center of the rounded bottom, shared by the standing and ball shapes, so the part touching
## the ground stays put instead of digging into it.
func _orient(up: Vector3, forward: Vector3, weight: float) -> void:
	var pivot_height := _ball_shape.position.y
	var current := global_basis.y.normalized()
	var pivot := global_position + current * pivot_height
	var target := up
	if weight < 1.0:
		var axis := current.cross(up)
		if axis.length_squared() < 1e-6:
			axis = forward.cross(current)  # Exactly upside down: tip over forwards.
		target = current.rotated(axis.normalized(), current.angle_to(up) * weight)
	global_basis = Basis.looking_at(_on_plane(forward, target, _any_perpendicular(target)), target)
	global_position = pivot - target * pivot_height


func _is_steep() -> bool:
	return PlayerMotion.steepness(ground_normal) > physics.slip_angle


## The surface straight below the center of the rounded bottom (along -up_direction), within the
## snap distance, as an intersect_ray() result. Like the classic games' ground sensors it reads the
## face underfoot rather than any edge the body brushes, and it ignores surfaces more than
## surface_step_angle away from the current one, so the player launches off the top of a wall
## instead of wrapping around its edge. Empty if there is no ground below.
func _ground_below() -> Dictionary:
	var radius := _ball_shape.position.y
	var center := global_position + global_basis.y.normalized() * radius
	var reach := center - up_direction * (radius + physics.snap_length)
	var query := PhysicsRayQueryParameters3D.create(center, reach, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return hit
	var normal: Vector3 = hit["normal"]
	if rad_to_deg(normal.angle_to(up_direction)) > physics.surface_step_angle:
		return {}
	return hit


## Running into a wall removes the part of the ground speed that points into it, so a head-on hit
## stops the player and a glancing one slides along the wall.
func _slide_along_walls() -> void:
	if not is_on_wall():
		return
	var normal := _on_plane(get_wall_normal(), ground_normal, Vector3.ZERO)
	_pushing = wish.dot(-normal) > PUSH_INPUT and ground_speed < PUSH_SPEED
	var into := heading.dot(normal)
	if into >= 0.0:
		return
	var slide := (heading - normal * into) * ground_speed
	ground_speed = slide.length()
	heading = _on_plane(slide, ground_normal, heading)


## Scatters the rings, up to max_lost_rings of them, as LostRings the player can grab back.
func _scatter_rings() -> void:
	if _lost_ring == null:
		_lost_ring = load(LOST_RING_SCENE)
	var center := global_position + global_basis.y * _ball_shape.position.y
	for ring_velocity in PlayerMotion.ring_scatter(rings, physics):
		var ring := _lost_ring.instantiate() as LostRing
		ring.drop(center, ring_velocity, physics)
		get_parent().add_child.call_deferred(ring)
	rings = 0


## The ring magnet: rings in range start flying to the player.
func _pull_rings() -> void:
	_magnet_query.transform = Transform3D(Basis.IDENTITY, global_position + global_basis.y * _ball_shape.position.y)
	for hit in get_world_3d().direct_space_state.intersect_shape(_magnet_query, MAGNET_MAX_RINGS):
		var collider: Object = hit["collider"]
		var ring := collider as Ring
		if ring:
			ring.attract(self)


func _count_down(delta: float) -> void:
	_control_lock = maxf(_control_lock - delta, 0.0)
	_air_boost_timer = maxf(_air_boost_timer - delta, 0.0)
	_quickstep_timer = maxf(_quickstep_timer - delta, 0.0)
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)
	_magnet_timer = maxf(_magnet_timer - delta, 0.0)
	_rail_cooldown = maxf(_rail_cooldown - delta, 0.0)
	if _invincible_timer > 0.0:
		_invincible_timer = maxf(_invincible_timer - delta, 0.0)
		if _invincible_timer == 0.0:
			Music.end_override(&"invincible")
	if _shoes_timer > 0.0:
		_shoes_timer = maxf(_shoes_timer - delta, 0.0)
		if _shoes_timer == 0.0:
			_refresh_physics()
			Music.set_fast(false)


func _end_power_ups() -> void:
	if _shoes_timer > 0.0:
		Music.set_fast(false)
	if _invincible_timer > 0.0:
		Music.end_override(&"invincible")
	shield = false
	_shoes_timer = 0.0
	_invincible_timer = 0.0
	_magnet_timer = 0.0
	_refresh_physics()


## The 2.5D section (a camera volume with lock_depth) the player is in, if any.
func _find_lane() -> CameraVolume:
	for node in get_tree().get_nodes_in_group(CameraVolume.GROUP):
		var volume := node as CameraVolume
		if volume and volume.lock_depth and volume.contains(global_position):
			return volume
	return null


## In a 2.5D section: eases the player onto the path's plane and drops any motion across it, so
## they can't step off the path into depth. On the ground they run along the path.
func _hold_to_lane(delta: float) -> void:
	if _lane == null or state == death_state:
		return
	var across := _lane.depth_axis()
	var offset := (global_position - _lane.global_position).dot(across)
	if absf(offset) > 1e-4:
		var step := physics.lane_pull_speed * delta
		move_and_collide(-across * clampf(offset, -step, step))
	velocity -= across * velocity.dot(across)
	if not is_grounded():
		return
	var along := across.cross(ground_normal)
	if along.length_squared() > 1e-6:
		along = along.normalized()
		heading = along if heading.dot(along) >= 0.0 else -along
		if not _is_steep():
			_flat_heading = _flat(heading, _flat_heading)


func _read_input() -> void:
	if not _input_enabled:
		jump_pressed = false
		jump_held = false
		crouch_held = false
		boost_pressed = false
		boost_held = false
		quickstep_pressed = 0
		wish = Vector3.ZERO
		return
	jump_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	crouch_held = Input.is_action_pressed("crouch")
	boost_pressed = Input.is_action_just_pressed("boost")
	boost_held = Input.is_action_pressed("boost")
	quickstep_pressed = int(Input.is_action_just_pressed("quickstep_right")) - int(Input.is_action_just_pressed("quickstep_left"))
	if jump_pressed:
		_jump_buffer_timer = physics.jump_buffer_time
	wish = _camera_wish()
	if _lane:
		# In a 2.5D section the stick only moves the player along the path.
		var along := _lane.path_axis()
		wish = along * wish.dot(along)


## The stick direction on the horizontal plane, relative to the active camera. Its length (0 to 1)
## is how far the stick is pushed. A PlayerCamera says which yaw to use, so a camera volume can
## switch views without turning a player who is holding the stick.
func _camera_wish() -> Vector3:
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if stick == Vector2.ZERO:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	var yaw := CameraMath.yaw_facing(-global_basis.z)
	if camera is PlayerCamera:
		yaw = (camera as PlayerCamera).input_yaw()
	elif camera:
		yaw = CameraMath.yaw_facing(-camera.global_basis.z)
	var forward := CameraMath.forward_for_yaw(yaw)
	var right := forward.cross(Vector3.UP)
	return (right * stick.x - forward * stick.y).limit_length(1.0)


## `v` projected onto the plane with normal `n` and normalized, or `fallback` if nothing is left.
static func _on_plane(v: Vector3, n: Vector3, fallback: Vector3) -> Vector3:
	var along := v - n * n.dot(v)
	return along.normalized() if along.length_squared() > 1e-6 else fallback


## `v` flattened onto the horizontal plane and normalized, or `fallback` if it has no horizontal part.
static func _flat(v: Vector3, fallback: Vector3) -> Vector3:
	return _on_plane(v, Vector3.UP, fallback)


## Some unit vector perpendicular to `n`.
static func _any_perpendicular(n: Vector3) -> Vector3:
	var other := Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	return n.cross(other).normalized()
