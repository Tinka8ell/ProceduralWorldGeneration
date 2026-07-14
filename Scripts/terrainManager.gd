extends Node

const size := 256.0
var noise: FastNoiseLite
var terrainShader: Shader
var color_gradient
var noise_texture: NoiseTexture2D
var chunks := {}

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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Chunk on ready called")

	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency
	noise.seed = noise_seed
	noise.offset = noise_offset
	print("noise created")
	
	color_gradient = preload("res://Terrain/gradient_texture.tres")
	terrainShader = preload("res://Terrain/terrain.gdshader")
	
	noise_texture = NoiseTexture2D.new()
	noise_texture.noise = noise
	noise_texture.as_normal_map = true
	noise_texture.seamless = true

	createTerrainChunk(Vector2i(0, 0))
	createTerrainChunk(Vector2i(0, 1))
	createTerrainChunk(Vector2i(1, 1))
	createTerrainChunk(Vector2i(1, 0))
	createTerrainChunk(Vector2i(1, -1))
	createTerrainChunk(Vector2i(0, -1))
	createTerrainChunk(Vector2i(-1, -1))
	createTerrainChunk(Vector2i(-1, 0))
	createTerrainChunk(Vector2i(-1, 1))
	
	# Checking for presence of a chunk?
	findChunk(Vector2i(1, -1))
	findChunk(Vector2i(-7, 30))
	
func findChunk(index: Vector2i) -> bool:
	var chunkName := getChunkName(index)
	var chunk: MeshInstance3D = chunks.get(chunkName)
	if chunk:
		print("Found ", chunkName)
		return true
	print("Not found ", chunkName)
	return false

func getChunkName(index: Vector2i) -> String:
	return "Chunk_" + str(index.x) + "_" + str(index.y)

func createTerrainChunk(index: Vector2i) -> void:
	print("Creating chunk: ", index)
	var chunk := MeshInstance3D.new()
	var chunkName := getChunkName(index)
	chunk.name = chunkName
	var transform := chunk.transform
	print("Name: ", chunk.name, " - ", transform)
	var move := Vector3(index.x * size, 0.0, index.y * size)
	print("Move: ", move)
	chunk.translate(move)
	print("Name: ", chunk.name, " - ", chunk.transform)
	
	print("Creating Material")
	var meshMaterial = ShaderMaterial.new()
	meshMaterial.shader = terrainShader
	meshMaterial.set_shader_parameter("height", height * 2)
	meshMaterial.set_shader_parameter("color_gradient", color_gradient)
	meshMaterial.set_shader_parameter("normal_map", noise_texture)

	add_child(chunk)
	chunks.set(chunkName, chunk)
	update_mesh(chunk, meshMaterial)

func update_mesh(chunk: MeshInstance3D, meshMaterial: ShaderMaterial) -> void:
	if not noise or not chunk:
		return
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	plane.size = Vector2(size, size)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array: PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	
	var offset := chunk.global_position
	for i:int in vertex_array.size():
		var vertex := vertex_array[i]
		var normal := Vector3.UP
		var tangent := Vector3.RIGHT
		if noise:
			# have to add in mesh location / translation
			vertex.y = get_height(vertex.x + offset.x, vertex.z + offset.z)
			normal = get_normal(vertex.x + offset.x, vertex.z + offset.z)
			tangent = normal.cross(Vector3.UP)
		vertex_array[i] = vertex
		normal_array[i] = normal
		tangent_array[4 * i] = tangent.x
		tangent_array[4 * i + 1] = tangent.y
		tangent_array[4 * i + 2] = tangent.z
	
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	array_mesh.surface_set_material(0, meshMaterial)
	# set the chunk's mesh
	chunk.mesh = array_mesh
	print("Made mesh")
	chunk.create_trimesh_collision()
	print("Made collision")

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
