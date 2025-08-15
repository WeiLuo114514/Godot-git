extends MeshInstance3D

var path_mesh: MeshInstance3D
var immediate_mesh: ImmediateMesh
var normal_material: StandardMaterial3D  # 正常状态材质
var rewind_material: StandardMaterial3D  # 回溯状态材质
var line_width = 0.2

# 新增：标记当前是否处于回溯状态
var is_rewinding: bool = false

func _ready():
	immediate_mesh = ImmediateMesh.new()
	path_mesh = MeshInstance3D.new()
	path_mesh.mesh = immediate_mesh
	add_child(path_mesh)
	
	# 正常状态材质（橙色）
	normal_material = StandardMaterial3D.new()
	normal_material.albedo_color = Color(1, 0.6, 0, 0.8)  # 橙色半透明
	normal_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	normal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# 回溯状态材质（蓝色）
	rewind_material = StandardMaterial3D.new()
	rewind_material.albedo_color = Color(0.5, 0.8, 1, 0.8)  # 蓝色半透明
	rewind_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	rewind_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# 默认使用正常材质
	path_mesh.material_override = normal_material
	path_mesh.visible = true

# 新增：设置回溯状态的方法（供player调用）
func set_rewind_state(state: bool):
	is_rewinding = state
	# 立即更新材质
	path_mesh.material_override = rewind_material if state else normal_material

func visualize_path(points: PackedVector3Array):
	immediate_mesh.clear_surfaces()
	
	if points.size() < 2:
		return
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(points.size()):
		var current = points[i]
		var next_point = points[i + 1] if i < points.size() - 1 else current
		var direction = (next_point - current).normalized()
		var width_dir = direction.cross(Vector3.UP).normalized() * line_width
		
		immediate_mesh.surface_add_vertex(current + width_dir)
		immediate_mesh.surface_add_vertex(current - width_dir)
	immediate_mesh.surface_end()
