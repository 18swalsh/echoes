extends CharacterBody2D

#debug timer

@onready var log_timer = $Timer
func _on_timer_timeout() -> void:
	# Print the player's global position to the debugger
	print("Player Position - X:", global_position.x, ", Y:", global_position.y)



# Movement variables
@export var move_speed := 422
@export var gravity := 5125
@export var fall_multiplier := 1.0
@export var max_fall_speed := 2000.0

# Jump variables
@export_category("Jump")
@export var jump_force := -1800.0
@export var jump_crouch_delay := 0.1
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.1
@export var jump_cut_multiplier := 6.0

# Dash variables
@export_category("Dash")
@export var dash_speed := 1188.0 
@export var dash_duration := 0.29
@export var dash_cooldown := 0.5

# State tracking
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var jump_requested := false
var jump_timer := 0.0

var is_dashing := false
var dash_timer := 0.0
var cooldown_timer := 0.0
var dash_direction := Vector2.ZERO
var last_input_direction := Vector2.ZERO  # Tracks last input direction for dashing

var current_anim: String = ""

func _physics_process(delta: float) -> void:
	if is_dashing:
		process_dash(delta)
	else:
		handle_horizontal_input()
		apply_gravity(delta)
		process_jump_logic(delta)
		handle_animation()

	move_and_slide()

	# Update dash cooldown
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

# Horizontal movement
func handle_horizontal_input() -> void:
	var direction = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if direction.x != 0:  # Track horizontal input
		velocity.x = direction.x * move_speed
		$AnimatedSprite2D.flip_h = direction.x < 0
		last_input_direction = Vector2(direction.x, 0).normalized()  # Update last input direction
	else:
		velocity.x = 0.0

	# Track vertical input (optional, only needed if vertical movement influences facing)
	if direction.y != 0:
		last_input_direction = Vector2(0, direction.y).normalized()

# Gravity application
func apply_gravity(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

		if velocity.y > 0.0:  # Falling
			velocity.y += gravity * fall_multiplier * delta
		elif not Input.is_action_pressed("jump"):  # Jump cut
			velocity.y += gravity * jump_cut_multiplier * delta
		else:  # Rising
			velocity.y += gravity * delta

		velocity.y = min(velocity.y, max_fall_speed)

# Jump logic
func process_jump_logic(delta: float) -> void:
	track_jump_input(delta)
	execute_jump(delta)

func track_jump_input(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	if not jump_requested and jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		jump_requested = true
		jump_timer = jump_crouch_delay
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

		# Play jump animation directly
		$AnimatedSprite2D.play("jump")

func execute_jump(delta: float) -> void:
	if jump_requested:
		jump_timer -= delta
		if jump_timer <= 0.0:
			velocity.y = jump_force
			jump_requested = false
			coyote_timer = 0.0

# Dash logic
func process_dash(delta: float) -> void:
	dash_timer -= delta
	if dash_timer <= 0.0:
		is_dashing = false
		return

	# Apply dash physics
	velocity = dash_direction * dash_speed

func start_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration
	cooldown_timer = dash_cooldown

	# Determine dash direction
	var input_direction = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	dash_direction = input_direction if input_direction != Vector2.ZERO else last_input_direction

	# Trigger dash animation or effects
	#$AnimatedSprite2D.play("dash")

# Handle animations
func handle_animation() -> void:
	var new_anim: String = determine_animation()
	if new_anim != current_anim:
		current_anim = new_anim
		$AnimatedSprite2D.play(current_anim)

func determine_animation() -> String:
	if is_dashing:
		return "dash"
	if not is_on_floor():
		return "jump" if velocity.y < 0.0 else "fall"
	elif abs(velocity.x) > 10.0:
		return "run"
	else:
		return "idle"

# Input handling for dash
func _input(event) -> void:
	if event.is_action_pressed("dash") and cooldown_timer <= 0.0 and not is_dashing:
		start_dash()
