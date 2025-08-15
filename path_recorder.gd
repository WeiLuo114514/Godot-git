extends Node3D

var path_points = PackedVector3Array()  # 仍使用 PackedVector3Array 提高性能
var recording = true
var point_interval = 0.1
var last_recorded_position = Vector3.ZERO

func _ready():
	last_recorded_position = get_parent().global_position

func _physics_process(delta):
	if not recording:
		return

	var current_pos = get_parent().global_position
	if last_recorded_position.distance_to(current_pos) > point_interval:
		# 新增路径点（直接 append 到 PackedVector3Array）
		path_points.append(current_pos)
		last_recorded_position = current_pos
		# 实时更新路径
		var path_visualizer = get_parent().get_node_or_null("path_visualizer")
		if path_visualizer:
			path_visualizer.visualize_path(path_points)
