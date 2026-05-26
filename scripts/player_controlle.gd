extends CharacterBody2D

@export var move_speed = 2000
@export var deceleration = 0.1
@export var jump_force = -70
@export var gravity = 98
@export var mass = 50.0

var current_state = "none"
var sit_timer: SceneTreeTimer = null
var sitting = false
var is_animating = false
 

# Add a RayCast2D node to your character named "FloorDetector"
@onready var floor_detector = $FloorDetector

func _physics_process(delta: float) -> void:
	
	# 1. Always apply gravity, even if animating
	if not is_on_floor():
		velocity.y += mass * gravity * delta # Use your gravity value
		update_jump_animation()
	else:
		pass
	# 2. Only block INPUT and MOVEMENT logic if animating
	if not is_animating:
		current_state = get_input_state()
		horizontal_movement()
	move_and_slide()

func horizontal_movement():
	match current_state:
		"left", "right":
			cancel_sit_timer()
			if sitting:
				await perform_stand_up() 
			
			if !is_animating:
				move_character()
				if $PlayerAnimation.animation != "run":
					$PlayerAnimation.play("run")
			
		"up":
			cancel_sit_timer()
			jump()
			velocity.y = jump_force * mass
			
		"down":
			cancel_sit_timer()
			velocity.x = 0
			if !sitting and $PlayerAnimation.animation != "feel_ground":
				$PlayerAnimation.play("feel_ground")
			
		"none":
			velocity.x = move_toward(velocity.x, 0, move_speed * deceleration)
			if !Input.is_action_pressed("ui_down"):
				do_idle()

func get_input_state():
	if Input.is_action_pressed("ui_left"): return "left"
	if Input.is_action_pressed("ui_right"): return "right"
	if Input.is_action_pressed("ui_up"): return "up"
	if Input.is_action_pressed("ui_down"): return "down"
	return "none"
	
func start_sit_timer(duration: float = 5.0):
	sit_timer = get_tree().create_timer(duration)
	await sit_timer.timeout
	if sit_timer != null:	
		trigger_sit_down_sequence()

func cancel_sit_timer():
	sit_timer = null
	
func trigger_sit_down_sequence():
	if !sitting:
		is_animating = true
		$PlayerAnimation.play("sit")
		await $PlayerAnimation.animation_finished
		sitting = true
		is_animating = false
		
func perform_stand_up():
	is_animating = true
	$PlayerAnimation.play_backwards("sit")
	await $PlayerAnimation.animation_finished
	sitting = false
	is_animating = false 
	
func jump():
	is_animating = true
	$PlayerAnimation.play("jump")
	await $PlayerAnimation.animation_finished
	sitting = false
	is_animating = false 

func move_character():
	velocity.x = (1 if current_state == "right" else -1) * move_speed
	$PlayerAnimation.flip_h = (current_state == "left")
	
func do_idle():
	if !sitting:
		if $PlayerAnimation.animation != "standing_idle" and sit_timer == null:
			$PlayerAnimation.play("standing_idle")
			if sit_timer == null:
				start_sit_timer()
	elif sitting:
		if $PlayerAnimation.animation != "idle":
			$PlayerAnimation.play("idle")
			
func update_jump_animation():
	# 1. Get the total number of frames in your jump animation
	var total_frames = $PlayerAnimation.sprite_frames.get_frame_count("jump")
	
	# 2. Calculate progress (0.0 to 1.0)
	var jump_progress = clamp(abs(velocity.y) / abs(jump_force*mass), 0.0, 1.0)
	
	# 3. Check for ground proximity (the "3/4" pause logic)
	var dist_to_floor = floor_detector.get_collision_point().distance_to(global_position) if floor_detector.is_colliding() else 999
	
	if dist_to_floor < 30 and velocity.y > 0:
		# Pause at 3/4 of the total frames
		$PlayerAnimation.frame = int(total_frames * 0.5)
	else:
		# Map jump_progress to a frame index
		# Going up: 0 to 50% of frames. Going down: 50% to 75% of frames
		var target_frame = 0
		if velocity.y < 0: # Rising
			target_frame = int(jump_progress * (total_frames * 0.25))
		else: # Falling
			target_frame = int((total_frames * 0.5) + ((1.0 - jump_progress) * (total_frames * 0.25)))
			
		$PlayerAnimation.frame = target_frame
