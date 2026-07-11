extends Node

const size := 256.0
var terrain: MeshInstance3D
var noise: FastNoiseLite
var terrainShader: Shader
var color_gradient
var noise_texture: NoiseTexture2D

# Perlin noise parameters
@export_range(0.0, 1.0, 0.001, "0 to 1 - lower is smoother") var noise_frequency := 0.1
@export var noise_seed := 12345
@export var noise_offset := Vector3.ZERO

# Chuck adjustable parameters
@export_range(4, 256, 4) var resolution := 32:
	set(new_resolution):
		resolution = new_resolution
		#update_mesh()

@export_range(4.0, 128.0, 4.0) var height := 64.0:
	set(new_height):
		height = new_height
		#print("Override", material_override.get_class())
		#material_override.set_shader_parameter("height", height * 2.0)
		#update_mesh()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Chunk on ready called")

	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency
	noise.seed = noise_seed
	noise.offset = noise_offset
	print("noise created")
	
	terrain = MeshInstance3D.new()
	
	color_gradient = preload("res://Terrain/gradient_texture.tres")
	terrainShader = preload("res://Terrain/terrain.gdshader")
	
	noise_texture = NoiseTexture2D.new()
	noise_texture.noise = noise
	noise_texture.as_normal_map = true
	noise_texture.seamless = true

	var current_material = terrain.get_surface_override_material(0)
	if not current_material:
		print("No Material set up")
		current_material = ShaderMaterial.new()
		current_material.shader = terrainShader
		current_material.set_shader_parameter("height", height * 2)
		current_material.set_shader_parameter("color_gradient", color_gradient)
		current_material.set_shader_parameter("normal_map", noise_texture)
		terrain.set_surface_override_material(0, current_material)
	
	add_child(terrain)
	
	#var gradientTexture1D: GradientTexture1D = preload("res://gradient_texture.tres")
	#var terrain_shader: Shader = preload("res://terrain.gdshader")
	#terrain_shader.set_shader_parameter("height", height * 2)
	#terrain_shader.set_shader_parameter("color_gradient", gradientTexture1D)
	#var terrain_shader_material: ShaderMaterial = ShaderMaterial.new()
	#for i in range(0, terrain.get_surface_override_material_count() - 1):
		#terrain.set_surface_override_material(i, terrain_shader_material)
	
	update_mesh()

func update_mesh() -> void:
	if not noise or not terrain:
		return
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	plane.size = Vector2(size, size)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array: PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	
	for i:int in vertex_array.size():
		var vertex := vertex_array[i]
		var normal := Vector3.UP
		var tangent := Vector3.RIGHT
		if noise:
			vertex.y = get_height(vertex.x, vertex.z)
			normal = get_normal(vertex.x, vertex.z)
			tangent = normal.cross(Vector3.UP)
		vertex_array[i] = vertex
		normal_array[i] = normal
		tangent_array[4 * i] = tangent.x
		tangent_array[4 * i + 1] = tangent.y
		tangent_array[4 * i + 2] = tangent.z
	
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	# set the terrain's mesh
	terrain.mesh = array_mesh
	print("Made mesh")
	terrain.create_trimesh_collision()
	print("Made collision")
	setMaterial()
	print("Set material")

func get_height(x: float, y: float) -> float:
	return noise.get_noise_2d(x, y) * height

func get_normal(x: float, y: float) -> Vector3:
	var epsilon := size / resolution
	var normal := Vector3(
		(get_height(x + epsilon, y) - get_height(x - epsilon, y)) / (2.0 * epsilon),
		1.0,
		(get_height(x, y + epsilon) - get_height(x, y - epsilon)) / (2.0 * epsilon),
	)
	return normal.normalized()

func setMaterial() -> void:
	# Grab the applied material
	var count = terrain.get_surface_override_material_count()
	print("Setting matteria: count=", count)
	var current_material = terrain.get_surface_override_material(0)
	if not current_material:
		print("No Material")
		current_material = ShaderMaterial.new()
		current_material.shader = terrainShader
		current_material.set_shader_parameter("height", height * 2)
		current_material.set_shader_parameter("color_gradient", color_gradient)
		current_material.set_shader_parameter("normal_map", noise_texture)
		terrain.set_surface_override_material(0, current_material)

# If it's a BaseMaterial3D (like StandardMaterial3D), you can set properties directly
	if current_material is StandardMaterial3D:
		current_material.albedo_color = Color(1, 0, 0) # Change to red
		print("set Matterial for StandardMaterial3D")
# For ShaderMaterials, use set_shader_parameter instead
	elif current_material is ShaderMaterial:
		current_material.set_shader_parameter("your_parameter_name", Color(1, 0, 0))
		print("set Matterial for ShaderMaterial")
	else:
		print("not setting Matterial")

	return
