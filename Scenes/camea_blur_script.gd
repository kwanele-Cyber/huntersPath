extends Camera2D

@export_category("Dynamic Depth of Field")
## The Z-Index layer that remains perfectly in focus (and at full brightness)
@export var focal_z_index: int = 1
## Global multiplier for how strong the blur becomes per Z-Index step away from focus
@export var blur_scale: float = 1.5
## How much a layer darkens per Z-Index step away from focus (higher = darker faster)
@export var darkening_scale: float = 0.15

@export_category("Dynamic 2D Parallax")
## Global parallax intensity. Higher values create a more dramatic 3D depth effect.
@export var parallax_intensity: float = 0.25

var managed_layers: Array = []
var base_positions: Dictionary = {}
var camera_start_pos: Vector2

func _ready() -> void:
	camera_start_pos = global_position
	# Wait for the scene tree to initialize completely before scanning
	await get_tree().process_frame
	setup_layers_and_shaders()

func setup_layers_and_shaders() -> void:
	# 1. Compile the custom Blur + Darken shader
	var blur_shader = Shader.new()
	blur_shader.code = """
	shader_type canvas_item;
	
	uniform float blur_amount : hint_range(0.0, 15.0) = 0.0;
	uniform float brightness : hint_range(0.0, 1.0) = 1.0;
	
	void fragment() {
		vec4 final_color = vec4(0.0);
		
		if (blur_amount <= 0.05) {
			final_color = texture(TEXTURE, UV);
		} else {
			float total_weight = 0.0;
			for(float x = -1.0; x <= 1.0; x += 1.0) {
				for(float y = -1.0; y <= 1.0; y += 1.0) {
					vec2 offset = vec2(x, y) * blur_amount * TEXTURE_PIXEL_SIZE;
					final_color += texture(TEXTURE, UV + offset);
					total_weight += 1.0;
				}
			}
			final_color = final_color / total_weight;
		}
		COLOR = vec4(final_color.rgb * brightness, final_color.a);
	}
	"""

	# 2. Automatically locate all TileMapLayers
	managed_layers = find_all_tilemap_layers(get_tree().current_scene)

	# 3. Apply visuals and cache starting coordinates
	for layer in managed_layers:
		if layer is TileMapLayer:
			# Cache their original editor positions for parallax offsets
			base_positions[layer] = layer.global_position
			
			# Calculate Z-Index distance from our focus layer
			var z_distance = abs(layer.z_index - focal_z_index)
			
			# Calculate and apply Shader settings
			var calculated_blur = z_distance * blur_scale
			var calculated_brightness = clamp(1.0 - (z_distance * darkening_scale), 0.2, 1.0)
			
			var mat = ShaderMaterial.new()
			mat.shader = blur_shader
			mat.set_shader_parameter("blur_amount", calculated_blur)
			mat.set_shader_parameter("brightness", calculated_brightness)
			
			layer.material = mat

func _process(_delta: float) -> void:
	# Calculate how far the camera has shifted from its starting coordinate
	var camera_offset = global_position - camera_start_pos
	
	# Apply parallax movement to each layer based on its depth
	for layer in managed_layers:
		if layer is TileMapLayer:
			# Define the scroll scale based on depth. 
			# Focus layer (z=1) gets a factor of 0 (moves 1:1 with camera).
			# Background layers (z < 1) get negative factors (scroll slower/follow the camera).
			# Foreground layers (z > 1) get positive factors (scroll faster past the camera).
			var layer_depth_factor = (layer.z_index - focal_z_index) * parallax_intensity
			
			# Background layers scroll slower by subtracting a fraction of camera movement
			# We clamp it to prevent background layers from flipping movement direction inverse
			var parallax_modifier = camera_offset * (layer_depth_factor / (1.0 + abs(layer_depth_factor)))
			
			# Smoothly offset the tilemap layer's global position
			layer.global_position = base_positions[layer] + parallax_modifier

# Recursive function to scan and grab every TileMapLayer automatically
func find_all_tilemap_layers(node: Node) -> Array:
	var layers = []
	if node is TileMapLayer:
		layers.append(node)
	for child in node.get_children():
		layers.append_array(find_all_tilemap_layers(child))
	return layers
