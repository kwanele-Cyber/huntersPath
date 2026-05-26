extends CharacterBody2D

@export var move_speed = 2000
@export var deceleration = 0.1
@export var jump_force = -70
@export var gravity = 98
@export var mass = 50.0
@export var sit_delay_time = 20.0 # How long to wait before sitting

var current_state = "none"
var sit_cooldown = 20.0 # Our manual float timer
var sitting = false
var is_animating = false

# Add a RayCast2D node to your character named "FloorDetector"
@onready var floor_detector = $FloorDetector

func _physics_process(delta: float) -> void:
	
	# 1. Always apply gravity, even if animating
	if not is_on_floor():
		velocity.y += mass * gravity * delta
		update_jump_animation()
	else:
		# Reset jump state when landing
		if current_state == "jumping":
			current_state = "none"
			is_animating = false
	
	# --- DELTA-BASED COOLDOWN LOGIC ---
	var any_input_pressed = (
		Input.is_action_pressed("ui_left") or 
		Input.is_action_pressed("ui_right") or 
		Input.is_action_pressed("ui_up") or 
		Input.is_action_pressed("ui_down")
	)
	
	if any_input_pressed:
		# Keep pushing the timer back as long as the player is active
		sit_cooldown = sit_delay_time
	elif is_on_floor() and not sitting and not is_animating:
		# Tick downward only when standing idle on the ground
		sit_cooldown -= delta
		if sit_cooldown <= 0.0:
			trigger_sit_down_sequence()

	# 2. Track inputs and movement
	if not is_animating || current_state == "jumping":
		var input_direction = get_horizontal_input_direction()
		
		# Handle Jump Input
		if Input.is_action_just_pressed("ui_up") and is_on_floor() and current_state != "jumping":
			handle_jump_trigger()
		
		# Handle Horizontal Movement (even mid-jump)
		horizontal_movement(input_direction)
	else:
		# --- LOCK BREAKING LOGIC ---
		var trying_to_move = Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right") or Input.is_action_pressed("ui_up")
		
		if trying_to_move and (sitting or $PlayerAnimation.animation == "sit"):
			break_sit_lock()
		
		velocity.x = 0 
		
	move_and_slide()

func get_horizontal_input_direction() -> float:
	return Input.get_axis("ui_left", "ui_right")

func horizontal_movement(direction: float):
	if current_state == "jumping":
		steer_character(direction)
		return

	# Grounded State Logic
	if direction != 0:
		if sitting:
			await perform_stand_up() 
		
		steer_character(direction)
		if $PlayerAnimation.animation != "run":
			$PlayerAnimation.play("run")
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * deceleration)
		
		if Input.is_action_pressed("ui_down"):
			velocity.x = 0
			if !sitting and $PlayerAnimation.animation != "feel_ground":
				$PlayerAnimation.play("feel_ground")
		else:
			do_idle()

func steer_character(direction: float):
	velocity.x = direction * move_speed
	if direction != 0:
		$PlayerAnimation.flip_h = (direction < 0)

func handle_jump_trigger():
	if sitting:
		await perform_stand_up()
		
	current_state = "jumping"
	is_animating = true 
	velocity.y = jump_force * mass
	$PlayerAnimation.play("jump")

# --- Sitting Logic (Look! No more start/cancel timer functions!) ---
	
func trigger_sit_down_sequence():
	if !sitting:
		is_animating = true
		$PlayerAnimation.play("sit")
		await $PlayerAnimation.animation_finished
		if is_animating and $PlayerAnimation.animation == "sit":
			sitting = true
			is_animating = false
		
func perform_stand_up():
	is_animating = true
	$PlayerAnimation.play_backwards("sit")
	await $PlayerAnimation.animation_finished
	sitting = false
	is_animating = false 

func break_sit_lock():
	sitting = false
	is_animating = true
	$PlayerAnimation.play_backwards("sit")
	await $PlayerAnimation.animation_finished
	is_animating = false
	sit_cooldown = sit_delay_time # Reset cooldown immediately upon breaking lock

func do_idle():
	if !sitting:
		if $PlayerAnimation.animation != "standing_idle":
			$PlayerAnimation.play("standing_idle")
	elif sitting:
		if $PlayerAnimation.animation != "idle":
			$PlayerAnimation.play("idle")
			
func update_jump_animation():
	var total_frames = $PlayerAnimation.sprite_frames.get_frame_count("jump")
	var jump_progress = clamp(abs(velocity.y) / abs(jump_force*mass), 0.0, 1.0)
	var dist_to_floor = floor_detector.get_collision_point().distance_to(global_position) if floor_detector.is_colliding() else 999
	
	if dist_to_floor < 30 and velocity.y > 0:
		$PlayerAnimation.frame = int(total_frames * 0.5)
	else:
		var target_frame = 0
		if velocity.y < 0: 
			target_frame = int(jump_progress * (total_frames * 0.25))
		else: 
			target_frame = int((total_frames * 0.5) + ((1.0 - jump_progress) * (total_frames * 0.25)))
			
		$PlayerAnimation.frame = target_frame
