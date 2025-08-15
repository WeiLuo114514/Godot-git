extends CharacterBody3D

@export var camera : Camera3D
@export var path_recorder: Node
@export var ground : Node3D
@export var camera2 : Camera3D
@export var light : DirectionalLight3D

# 移动参数
@export var speed := 5
@export var jump_force := 3
@export var gravity := 10
# 视角参数
@export var mouse_sensitivity := 0.1
var y_rotation := 0

# 俯视角相关变量
@export var top_down_height := 15.0  # 俯视角高度
@export var transition_speed := 15.0  # 视角切换速度
@export var min_height := 10.0  # 俯视角最小高度
@export var max_height := 35.0  # 俯视角最大高度
@export var zoom_speed := 2.0  # 滚轮缩放速度
var is_top_down := false  # 是否处于俯视角
var normal_cam_transform : Transform3D  # 存储正常视角的相机变换
var is_transitioning := false  # 新增变量
var finish_reached = false
var free_camera_mode = false  # 是否处于自由摄像机模式
var free_cam_speed = 10.0  # 自由摄像机移动速度
var free_cam_rotation = Vector2.ZERO  # 存储自由摄像机旋转角度
var is_total := false

# 用于存储角色进入total状态前的原始朝向
var original_rotation := Vector3.ZERO

# 飞行相关变量
var is_flying := false
@export var fly_force := 5.0   # 飞行的上升/下降力
@export var fly_speed := 10.0 # 飞行时的移动速度
var original_speed := 0.0     # 存储原始速度
var original_gravity := 0.0   # 存储原始重力

const camera2_position = Vector3(0,35,0)
const camera2_rotation = Vector3(-90,0,0)

# total状态过渡变量
var is_total_transitioning := false
var total_transition_timer := 0.0
var total_transition_duration := 0.6  # 过渡持续时间（秒）
var total_transition_start_transform : Transform3D
var total_transition_target_transform : Transform3D

# 回溯相关变量
var is_rewinding := false  # 是否处于回溯状态
var rewind_speed := 70.0  # 回溯速度（数值越大越快）
var rewind_timer := 0.0   # 回溯帧间隔计时器

# 光源相关变量
var original_light_color: Color
var original_light_energy: float
var original_light_rotation: Vector3  # 存储光源原始旋转

@export var UI_tips : RichTextLabel
@export var shuiyin : RichTextLabel

func _ready():
	var sy_position = Vector2(0 ,get_viewport().size.y -shuiyin.size.y)
	shuiyin.position = sy_position
	
	camera.current = true
	camera2.current = false
	is_total = false
	# 隐藏鼠标并锁定到窗口中心
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# 保存初始的正常视角相机变换
	normal_cam_transform = camera.transform
	
	var finish_area = get_parent().get_node_or_null("FinishArea")
	if finish_area:
		finish_area.connect("body_entered", _on_finish_area_entered)
	
	free_cam_rotation = Vector2(camera.rotation.x, rotation.y)
	original_speed = speed
	original_gravity = gravity
	
	# 保存光源原始属性
	if light:
		original_light_color = light.light_color
		original_light_energy = light.light_energy
		original_light_rotation = light.rotation

func _unhandled_input(event):
	if event.is_action_pressed("ui_input"):
		if UI_tips.visible == true:
			UI_tips.visible = false
		else:
			UI_tips.visible = true
	
	# 优先处理回溯输入
	if event.is_action_pressed("rewind"):
		start_rewind()
	elif event.is_action_released("rewind"):
		stop_rewind()

	# 回溯期间只处理鼠标移动（视角控制）和rewind键释放
	if is_rewinding:
		# 处理鼠标移动（允许视角转动）
		if event is InputEventMouseMotion:
			handle_rewind_camera_control(event)
		return  # 除了鼠标移动外忽略其他输入

	# 非回溯状态的输入处理
	if event is InputEventMouseMotion:
		if is_top_down:
			# 俯视角水平旋转
			rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity * 0.5))
		elif not is_top_down and not get_tree().paused:
			# 正常视角旋转
			rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
			y_rotation -= event.relative.y * mouse_sensitivity
			y_rotation = clamp(y_rotation, -80, 80)
			camera.rotation.x = deg_to_rad(y_rotation)
	
	if event is InputEventKey:
		if event.is_action_pressed("ui_tab"):
			toggle_top_down_view()
		if event.is_action_pressed("ui_cancel"):
			toggle_pause()
		if event.is_action_pressed("total") and not is_total_transitioning:
			if is_top_down:
				toggle_top_down_view()
			if not is_total:
				start_enter_total_transition()
			else:
				start_exit_total_transition()
	
	if event is InputEventMouseButton and is_top_down:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			top_down_height = clamp(top_down_height - zoom_speed, min_height, max_height)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			top_down_height = clamp(top_down_height + zoom_speed, min_height, max_height)

# 新增：回溯时的相机控制
func handle_rewind_camera_control(event: InputEventMouseMotion):
	# 回溯时允许水平和垂直视角旋转
	# 水平旋转（角色旋转）
	rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
	
	# 垂直旋转（相机旋转）
	y_rotation -= event.relative.y * mouse_sensitivity
	y_rotation = clamp(y_rotation, -80, 80)  # 限制垂直旋转角度
	camera.rotation.x = deg_to_rad(y_rotation)

func toggle_top_down_view():
	is_top_down = not is_top_down
	is_transitioning = true
	if is_top_down && !is_transitioning:
		normal_cam_transform = camera.transform

func toggle_pause():
	if get_tree().paused:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_top_down else Input.MOUSE_MODE_CAPTURED
	else:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta):
	if is_rewinding:
		handle_rewind(delta)
		return
	
	if is_total_transitioning:
		total_transition_timer += delta
		var t = min(total_transition_timer / total_transition_duration, 1.0)
		camera2.global_transform = total_transition_start_transform.interpolate_with(
			total_transition_target_transform,t)
		if t >= 1.0:
			is_total_transitioning = false
			if not is_total:
				camera.current = true
				camera2.current = false
	
	if is_top_down:
		var target_position = global_position + Vector3(0, top_down_height, 0)
		camera.global_position = camera.global_position.lerp(target_position, transition_speed * delta)
		camera.rotation = Vector3(deg_to_rad(-90), 0, 0)
		if camera.global_position.distance_to(target_position) < 0.1:
			camera.rotation = Vector3(deg_to_rad(-90), 0, 0)
			is_transitioning = false
	elif is_transitioning:
		camera.transform = camera.transform.interpolate_with(normal_cam_transform, transition_speed * delta)
		if camera.transform.origin.distance_to(normal_cam_transform.origin) < 0.01:
			is_transitioning = false
	
	if get_tree().paused:
		return

	if finish_reached:
		is_flying = true
		gravity = 0
		speed = fly_speed
		if Input.is_action_pressed("jump"):
			velocity.y = fly_force
		elif Input.is_action_pressed("down"):
			velocity.y = -fly_force
		else:
			velocity.y = 0
	else:
		is_flying = false
		gravity = original_gravity
		speed = original_speed
	
	if not is_flying:
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			if Input.is_action_just_pressed("jump"):
				velocity.y = jump_force
			else:
				velocity.y = 0
	
	var input_dir := Vector3.ZERO
	var move_basis = transform.basis
	
	if is_top_down:
		var horizontal_basis = Basis()
		horizontal_basis = horizontal_basis.rotated(Vector3.UP, rotation.y)
		move_basis = horizontal_basis
	
	if Input.is_action_pressed("move_forward"):
		input_dir -= move_basis.z
	if Input.is_action_pressed("move_back"):
		input_dir += move_basis.z
	if Input.is_action_pressed("move_left"):
		input_dir -= move_basis.x
	if Input.is_action_pressed("move_right"):
		input_dir += move_basis.x
	
	input_dir = input_dir.normalized()
	
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed
	
	show_path_trail()
	move_and_slide()

func _on_finish_area_entered(body):
	if body == self and not finish_reached:
		finish_reached = true
		ground.finish_game()
		self.visible = false

func show_path_trail():
	var path_visualizer = get_parent().get_node_or_null("path_visualizer")
	if path_visualizer and not is_flying:
		path_visualizer.visualize_path(path_recorder.path_points)

func start_enter_total_transition():
	is_total_transitioning = true
	total_transition_timer = 0.0
	original_rotation = rotation
	camera2.global_transform = camera.global_transform
	var target_position = camera2_position
	var target_basis = Basis()
	target_basis = target_basis.rotated(Vector3.RIGHT, deg_to_rad(camera2_rotation.x))
	target_basis = target_basis.rotated(Vector3.UP, deg_to_rad(camera2_rotation.y))
	target_basis = target_basis.rotated(Vector3.BACK, deg_to_rad(camera2_rotation.z))
	total_transition_target_transform = Transform3D(target_basis, target_position)
	total_transition_start_transform = camera2.global_transform
	camera.current = false
	camera2.current = true
	camera2.visible = true
	rotation = Vector3.ZERO
	is_total = true
	ground.total_in()

func start_exit_total_transition():
	is_total_transitioning = true
	total_transition_timer = 0.0
	total_transition_start_transform = camera2.global_transform
	var target_basis = Basis()
	target_basis = target_basis.rotated(Vector3.UP, original_rotation.y)
	total_transition_target_transform = Transform3D(target_basis, camera.global_position)
	rotation = original_rotation
	is_total = false
	ground.total_out()

# 修改start_rewind函数
func start_rewind():
	if path_recorder.path_points.size() < 2:
		return
	
	is_rewinding = true
	path_recorder.recording = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# 通知路径可视化器切换到回溯颜色
	var path_visualizer = get_parent().get_node_or_null("path_visualizer")
	if path_visualizer:
		path_visualizer.set_rewind_state(true)
	
	is_flying = false
	finish_reached = false
	velocity = Vector3.ZERO
	if light:
		light.light_color = Color(0.7, 0.9, 1.0)
		light.light_energy = original_light_energy * 0.8
		light.rotation = original_light_rotation + Vector3(5, 10, 0)


# 修改stop_rewind函数
func stop_rewind():
	is_rewinding = false
	path_recorder.recording = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rewind_timer = 0.0
	
	# 通知路径可视化器恢复正常颜色
	var path_visualizer = get_parent().get_node_or_null("path_visualizer")
	if path_visualizer:
		path_visualizer.set_rewind_state(false)
	
	if light:
		light.light_color = original_light_color
		light.light_energy = original_light_energy
		light.rotation = original_light_rotation


func handle_rewind(delta):
	rewind_timer += delta
	if rewind_timer < 1.0 / rewind_speed:
		return
	rewind_timer = 0.0

	var points = path_recorder.path_points
	if points.size() < 1:
		stop_rewind()
		return

	global_position = points[points.size() - 1]
	
	if points.size() > 0:
		var new_points = PackedVector3Array()
		for i in range(points.size() - 1):
			new_points.append(points[i])
		path_recorder.path_points = new_points

	var path_visualizer = get_parent().get_node_or_null("path_visualizer")
	if path_visualizer:
		path_visualizer.visualize_path(path_recorder.path_points)

	if path_recorder.path_points.size() == 0:
		stop_rewind()
