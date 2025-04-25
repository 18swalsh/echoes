extends Node2D

@onready var camera = $Camera2D
@onready var tilemap_layer: TileMapLayer = $"../TileMapLayer"

@export var vertical_snap_speed_threshold: float = 500.0  # Speed for snapping during fast falls
@export var vertical_lookahead_distance := 64.0          # Vertical lookahead range
@export var horizontal_lookahead_distance := 48.0        # Horizontal lookahead range
@export var lookahead_speed := 200.0                     # Lookahead adjustment speed

var player: Node2D
var level_bounds: Rect2
var screen_half_size: Vector2

var current_vertical_lookahead := 0.0
var current_horizontal_lookahead := 0.0

func _ready():
	initialize_camera()
	initialize_player()

func initialize_camera():
	if not tilemap_layer:
		push_error("TileMapLayer path not set or invalid.")
		return

	var used_rect = tilemap_layer.get_used_rect()
	var tile_size = tilemap_layer.tile_set.tile_size

	level_bounds = Rect2(
		tilemap_layer.map_to_local(used_rect.position),
		Vector2(used_rect.size.x * tile_size.x, used_rect.size.y * tile_size.y)
	)
	screen_half_size = get_viewport_rect().size * 0.5

func initialize_player():
	player = get_tree().get_root().find_child("Player", true, false)
	if not player:
		push_error("Could not find Player node!")

func _process(delta):
	if not player:
		return
	update_camera_position(delta)

func update_camera_position(delta):
	var target_x = calculate_horizontal_target(delta)
	var target_y = calculate_vertical_target(delta)
	global_position = Vector2(target_x, target_y)

func calculate_horizontal_target(delta) -> float:
	var player_x = player.global_position.x
	var target_horizontal_lookahead = 0.0

	if player.velocity.x != 0.0:
		# Lookahead based on horizontal movement direction
		target_horizontal_lookahead = horizontal_lookahead_distance * sign(player.velocity.x)

	current_horizontal_lookahead = move_toward(
		current_horizontal_lookahead, target_horizontal_lookahead, lookahead_speed * delta
	)

	return clamp(
		player_x + current_horizontal_lookahead,
		level_bounds.position.x + screen_half_size.x,
		level_bounds.position.x + level_bounds.size.x - screen_half_size.x
	)

func calculate_vertical_target(delta) -> float:
	var player_y = player.global_position.y
	var target_vertical_lookahead = 0.0

	if player.velocity.y > 0.0:
		# Lookahead based on downward movement
		target_vertical_lookahead = vertical_lookahead_distance

	current_vertical_lookahead = move_toward(
		current_vertical_lookahead, target_vertical_lookahead, lookahead_speed * delta
	)

	var smoothed_y = lerp(
		global_position.y, player_y + current_vertical_lookahead, delta * 20.0
	)

	# Snap during steep falls
	if abs(player.velocity.y) > vertical_snap_speed_threshold:
		smoothed_y = player_y + current_vertical_lookahead

	return clamp(
		smoothed_y,
		level_bounds.position.y + screen_half_size.y,
		level_bounds.position.y + level_bounds.size.y - screen_half_size.y
	)
