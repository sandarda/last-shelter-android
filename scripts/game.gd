extends Node2D

# Last Shelter v0.2 — playable systems prototype.
const PLAYER_SPEED := 210.0
const ROOM_W := 250.0
const ROOM_H := 150.0
const DAY_MINUTES := 24 * 60
const SAVE_PATH := "user://last_shelter_save.cfg"

const LEVELS := [
	{"name":"НИЖНИЙ ЭТАЖ — ГОСТЕВЫЕ И АРСЕНАЛ", "rooms":[
		{"id":"guest1","name":"ГОСТЕВАЯ I","pos":Vector2(-270,0),"color":Color("80634b")},
		{"id":"arsenal","name":"АРСЕНАЛ","pos":Vector2(0,0),"color":Color("70513d")},
		{"id":"guest2","name":"ГОСТЕВАЯ II","pos":Vector2(270,0),"color":Color("80634b")}], "links":[[0,1],[1,2]]},
	{"name":"СРЕДНИЙ ЭТАЖ — ЖИЛОЙ", "rooms":[
		{"id":"bedroom","name":"СПАЛЬНЯ","pos":Vector2(-270,0),"color":Color("80634b")},
		{"id":"living","name":"ГОСТИНАЯ","pos":Vector2(0,0),"color":Color("8a6045")},
		{"id":"kitchen","name":"КУХНЯ","pos":Vector2(270,0),"color":Color("806b48")}], "links":[[0,1],[1,2]]},
	{"name":"ВЕРХНИЙ ЭТАЖ — РАБОТА И ЗАПАСЫ", "rooms":[
		{"id":"workshop","name":"МАСТЕРСКАЯ И ЛАБОРАТОРИЯ","pos":Vector2(-135,0),"color":Color("776044")},
		{"id":"storage","name":"СКЛАД","pos":Vector2(135,0),"color":Color("786044")}], "links":[[0,1]]}
]

var current_floor := 1
var player_pos := Vector2(640, 420)
var target_pos := Vector2.ZERO
var moving := false
var day := 1
var minute_of_day := 7 * 60
var health := 100.0
var hunger := 85.0
var thirst := 80.0
var energy := 90.0
var wood := 8
var food := 5
var water := 4
var scrap := 3
var traps := 0
var medkits := 1
var zombies := 0
var shelter_integrity := 100.0
var status_label: Label
var clock_label: Label
var inventory_label: Label
var message_label: Label
var floor_label: Label
var action_panel: VBoxContainer
var room_rects: Array[Rect2] = []
var action_cooldown := 0.0
var time_fraction := 0.0
var stair_up_button: Button
var stair_down_button: Button
var selected_room_id := "living"
var selected_room_name := "ГОСТИНАЯ"
var selected_room_label: Label
var room_interact_button: Button
var needs_bars: Dictionary = {}
var interaction_hint := "Подойдите к винтовой лестнице и нажмите E или кнопку перехода."
var last_message := "Добро пожаловать домой. Проверь запасы и осмотри убежище."
var game_over := false
# On-screen virtual joystick for Android. Drag in the lower-left control zone.
var virtual_axis := Vector2.ZERO
var joystick_touch_index := -1
var joystick_center := Vector2(112.0, 600.0)
var joystick_radius := 72.0
# Illustrated room backplates and a 4-direction / 4-frame survivor sprite sheet.
var room_textures: Dictionary = {}
var survivor_texture: Texture2D
var animation_clock := 0.0
var animation_frame := 0
var facing_row := 0 # 0 down, 1 left, 2 right, 3 up
var pending_stair_floor := -1
# v0.21: ten additional survival systems.
var weather := "ЯСНО"
var noise_level := 0.0
var backpack_capacity := 30
var carried_weight := 0
var purified_water := 0
var fish := 0
var morale := 75.0
var barricade_level := 1
var journal_step := 0
var explored_cache := false
var last_weather_day := 1
# v0.22: ten additional island-survival systems.
var island_location := "ПЛЯЖ"
var explored_locations: Dictionary = {"ПЛЯЖ": true}
var berries := 0
var medicine_herbs := 0
var garden_level := 0
var garden_progress := 0.0
var spear_durability := 0
var weapon_durability := 100.0
var radio_battery := 0
var radio_signal_sent := false
var rescued_supplies := 0
var shelter_upgrades := 0
var quest_flags: Dictionary = {}
var injury := 0.0
var temperature := 20.0
# v0.23 mobile lifecycle and periodic save support.
var autosave_elapsed := 0.0
const AUTOSAVE_INTERVAL := 60.0

func _ready() -> void:
	randomize()
	_load_art_assets()
	_validate_room_connectivity()
	_build_ui()
	_load_game()
	_update_ui()
	queue_redraw()

func _exit_tree() -> void:
	_save_game_silent()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game_silent()
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_set_message("С возвращением. Прогресс сохранён автоматически.")


func _validate_room_connectivity() -> void:
	# Validate that every room on every floor belongs to one connected
	# corridor network. This catches accidental isolated rooms during layout edits.
	for floor_index in range(LEVELS.size()):
		var floor_data: Dictionary = LEVELS[floor_index]
		var rooms: Array = floor_data["rooms"]
		var links: Array = floor_data["links"]
		var visited: Dictionary = {0: true}
		var queue: Array[int] = [0]
		while not queue.is_empty():
			var current: int = queue.pop_front()
			for link in links:
				var next_room := -1
				if int(link[0]) == current:
					next_room = int(link[1])
				elif int(link[1]) == current:
					next_room = int(link[0])
				if next_room >= 0 and not visited.has(next_room):
					visited[next_room] = true
					queue.append(next_room)
		if visited.size() != rooms.size():
			push_error("Изолированное помещение на этаже %d: доступно %d из %d" % [floor_index + 1, visited.size(), rooms.size()])
		else:
			print("Этаж %d: все %d помещений соединены коридорами." % [floor_index + 1, rooms.size()])

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 12)
	panel.custom_minimum_size = Vector2(360, 150)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = "ПОСЛЕДНЕЕ УБЕЖИЩЕ"
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)
	floor_label = Label.new()
	v.add_child(floor_label)
	clock_label = Label.new()
	v.add_child(clock_label)
	status_label = Label.new()
	v.add_child(status_label)
	inventory_label = Label.new()
	v.add_child(inventory_label)
	var meters_row := HBoxContainer.new()
	meters_row.add_theme_constant_override("separation", 5)
	v.add_child(meters_row)
	for meter_name in ["Здоровье", "Голод", "Жажда", "Энергия", "Прочность"]:
		var meter := ProgressBar.new()
		meter.custom_minimum_size = Vector2(58, 12)
		meter.max_value = 100.0
		meter.show_percentage = false
		needs_bars[meter_name] = meter
		meters_row.add_child(meter)
	# Vertical movement is explicit: the player can only move to an adjacent floor.
	stair_up_button = Button.new()
	stair_up_button.text = "Подняться на этаж выше"
	stair_up_button.pressed.connect(_use_stairs_up)
	v.add_child(stair_up_button)
	stair_down_button = Button.new()
	stair_down_button.text = "Спуститься на этаж ниже"
	stair_down_button.pressed.connect(_use_stairs_down)
	v.add_child(stair_down_button)
	selected_room_label = Label.new()
	selected_room_label.text = "Комната: ГОСТИНАЯ"
	v.add_child(selected_room_label)
	room_interact_button = Button.new()
	room_interact_button.text = "Взаимодействовать с комнатой"
	room_interact_button.pressed.connect(_interact_with_room)
	v.add_child(room_interact_button)
	var actions := PanelContainer.new()
	actions.position = Vector2(14, 178)
	layer.add_child(actions)
	action_panel = VBoxContainer.new()
	actions.add_child(action_panel)
	_add_action_button("Поесть", _eat)
	_add_action_button("Выпить воды", _drink)
	_add_action_button("Отдохнуть 2 часа", _rest)
	_add_action_button("Поработать 1 час", _work)
	_add_action_button("Заготовить дрова", _gather_wood)
	_add_action_button("Набрать воду", _collect_water)
	_add_action_button("Приготовить еду", _cook_meal)
	_add_action_button("Изготовить ловушку", _craft_trap)
	_add_action_button("Собрать аптечку", _craft_medkit)
	_add_action_button("Использовать аптечку", _use_medkit)
	_add_action_button("Проверить берег", _scout_shore)
	_add_action_button("Рыбачить у берега", _fish)
	_add_action_button("Поискать припасы", _scavenge)
	_add_action_button("Очистить воду", _purify_water)
	_add_action_button("Улучшить баррикады", _upgrade_barricades)
	_add_action_button("Записать в журнал", _journal_update)
	_add_action_button("Исследовать остров", _explore_island)
	_add_action_button("Собрать ягоды и травы", _forage)
	_add_action_button("Ухаживать за огородом", _tend_garden)
	_add_action_button("Изготовить копьё", _craft_spear)
	_add_action_button("Охотиться на мелкую дичь", _hunt)
	_add_action_button("Собрать дождевую воду", _collect_rainwater)
	_add_action_button("Проверить радиомаяк", _use_radio)
	_add_action_button("Улучшить мастерскую", _upgrade_workshop)
	_add_action_button("Проверить медицинское состояние", _treat_injury)
	_add_action_button("Разобрать найденные припасы", _process_salvage)
	_add_action_button("Отбиться от зомби", _defend_shelter)
	_add_action_button("Починить укрепления", _repair_shelter)
	_add_action_button("Сохранить игру", _save_game)
	_add_action_button("Начать заново", _new_game)
	message_label = Label.new()
	message_label.position = Vector2(390, 18)
	message_label.add_theme_color_override("font_color", Color("f0d7aa"))
	layer.add_child(message_label)
	add_child(layer)

func _add_action_button(caption: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.pressed.connect(callback)
	action_panel.add_child(b)

func _set_floor(index: int) -> void:
	# Debug/navigation shortcut retained for testing; normal play uses the stairwell.
	current_floor = clampi(index, 0, 2)
	var first_room: Dictionary = LEVELS[current_floor]["rooms"][0]
	selected_room_id = str(first_room["id"])
	selected_room_name = str(first_room["name"])
	player_pos = Vector2(640, 570)
	moving = false
	_update_ui()
	queue_redraw()

func _use_stairs_up() -> void:
	if player_pos.distance_to(Vector2(640, 590)) > 115.0:
		_set_message("Подойди к центральной лестничной площадке.")
		return
	if current_floor >= 2:
		_set_message("Это самый верхний этаж. Выше лестницы нет.")
		return
	_change_floor(current_floor + 1)

func _use_stairs_down() -> void:
	if player_pos.distance_to(Vector2(640, 590)) > 115.0:
		_set_message("Подойди к центральной лестничной площадке.")
		return
	if current_floor <= 0:
		_set_message("Это нижний этаж. Ниже лестницы нет.")
		return
	_change_floor(current_floor - 1)

func _change_floor(destination: int) -> void:
	var was_ascending := destination > current_floor
	pending_stair_floor = -1
	current_floor = clampi(destination, 0, 2)
	var first_room: Dictionary = LEVELS[current_floor]["rooms"][0]
	selected_room_id = str(first_room["id"])
	selected_room_name = str(first_room["name"])
	player_pos = Vector2(640, 555)
	target_pos = Vector2.ZERO
	moving = false
	_set_message("Ты поднялся по винтовой лестнице." if was_ascending else "Ты спустился по винтовой лестнице.")
	_update_ui()
	queue_redraw()

func _input(event: InputEvent) -> void:
	# Touch joystick is deliberately placed below the action panels so it does
	# not conflict with room selection or the upper-left status HUD.
	if event is InputEventScreenTouch:
		if event.pressed and joystick_touch_index == -1 and event.position.distance_to(joystick_center) <= joystick_radius * 1.65:
			joystick_touch_index = event.index
			_update_virtual_joystick(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == joystick_touch_index:
			joystick_touch_index = -1
			virtual_axis = Vector2.ZERO
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == joystick_touch_index:
		_update_virtual_joystick(event.position)
		get_viewport().set_input_as_handled()

func _update_virtual_joystick(touch_position: Vector2) -> void:
	var offset := touch_position - joystick_center
	if offset.length() > joystick_radius:
		offset = offset.normalized() * joystick_radius
	virtual_axis = offset / joystick_radius
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			if current_floor < 2:
				_use_stairs_up()
			else:
				_use_stairs_down()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_walkable_screen_point(event.position):
			if _try_stair_navigation(event.position):
				get_viewport().set_input_as_handled()
				return
			if _try_furniture_interaction(event.position):
				get_viewport().set_input_as_handled()
				return
			_select_room_at(event.position)
			target_pos = _clamp_walkable_point(event.position)
			moving = true
	elif event is InputEventScreenTouch and event.pressed:
		if _is_walkable_screen_point(event.position):
			if _try_stair_navigation(event.position):
				get_viewport().set_input_as_handled()
				return
			if _try_furniture_interaction(event.position):
				get_viewport().set_input_as_handled()
				return
			_select_room_at(event.position)
			target_pos = _clamp_walkable_point(event.position)
			moving = true

func _is_walkable_screen_point(point: Vector2) -> bool:
	# Keep taps on the HUD from becoming movement orders.
	return point.y >= 205 and point.y <= 645 and point.x >= 70 and point.x <= 1210

func _walkable_rectangles() -> Array[Rect2]:
	var areas: Array[Rect2] = []
	var rooms: Array = LEVELS[current_floor]["rooms"]
	var center := Vector2(640, 420)
	var rects: Array[Rect2] = []
	for room in rooms:
		var r := Rect2(center + room["pos"] - Vector2(ROOM_W / 2.0, ROOM_H / 2.0), Vector2(ROOM_W, ROOM_H))
		rects.append(r)
		areas.append(r)
	for link in LEVELS[current_floor]["links"]:
		var a: Rect2 = rects[int(link[0])]
		var b: Rect2 = rects[int(link[1])]
		areas.append(Rect2(a.end.x - 2.0, a.get_center().y - 22.0, b.position.x - a.end.x + 4.0, 44.0))
	areas.append(Rect2(610.0, 475.0, 60.0, 155.0))
	return areas

func _can_stand_at(point: Vector2) -> bool:
	for area in _walkable_rectangles():
		if area.grow(8.0).has_point(point):
			return true
	return false

func _clamp_walkable_point(point: Vector2) -> Vector2:
	var bounded := Vector2(clampf(point.x, 82.0, 1198.0), clampf(point.y, 245.0, 625.0))
	if _can_stand_at(bounded):
		return bounded
	var best := player_pos
	var best_distance := INF
	for area in _walkable_rectangles():
		var candidate := Vector2(clampf(bounded.x, area.position.x + 5.0, area.end.x - 5.0), clampf(bounded.y, area.position.y + 5.0, area.end.y - 5.0))
		var distance := candidate.distance_squared_to(bounded)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best



func _try_stair_navigation(point: Vector2) -> bool:
	# Tapping the visible stairwell makes the survivor walk there first;
	# changing floors is never an instant teleport from another room.
	if not Rect2(600.0, 485.0, 80.0, 155.0).has_point(point):
		return false
	if current_floor >= 2:
		pending_stair_floor = 1
	elif current_floor <= 0:
		pending_stair_floor = 1
	else:
		pending_stair_floor = 2 if point.y < 555.0 else 0
	target_pos = Vector2(640.0, 555.0)
	moving = true
	_set_message("Ты направился к винтовой лестнице…")
	return true

func _try_furniture_interaction(point: Vector2) -> bool:
	for i in range(room_rects.size()):
		var rect: Rect2 = room_rects[i]
		if not rect.has_point(point):
			continue
		var room: Dictionary = LEVELS[current_floor]["rooms"][i]
		var room_id := str(room["id"])
		var local := (point - rect.position) / rect.size
		# Hotspots correspond to the large, readable furniture silhouettes
		# painted into each room illustration. Tapping elsewhere selects/moves.
		var hotspot := false
		match room_id:
			"bedroom", "guest1", "guest2": hotspot = local.x < 0.53 and local.y > 0.30 and local.y < 0.88
			"living": hotspot = (local.x < 0.48 and local.y > 0.38) or (local.x > 0.72 and local.y < 0.72)
			"kitchen": hotspot = local.x > 0.48 and local.y > 0.42
			"workshop": hotspot = local.y > 0.52 and local.x < 0.78
			"storage": hotspot = local.x < 0.78 and local.y > 0.18
			"arsenal": hotspot = local.x < 0.72 and local.y > 0.20
		if hotspot:
			selected_room_id = room_id
			selected_room_name = str(room["name"])
			_interact_with_furniture(room_id)
			_update_ui()
			queue_redraw()
			return true
	return false

func _interact_with_furniture(room_id: String) -> void:
	match room_id:
		"bedroom", "guest1", "guest2":
			_rest()
			_set_message("Ты прилёг на кровать и восстановил силы.")
		"living":
			_advance_time(30)
			energy = minf(100.0, energy + 8.0)
			_set_message("Ты устроился у камина. В гостиной стало немного теплее.")
		"kitchen":
			_cook_meal()
		"workshop":
			_work()
		"storage":
			_set_message("Ты перебрал ящики и проверил запасы: дерево %d, еда %d, вода %d, металл %d." % [wood, food, water, scrap])
		"arsenal":
			_scout_shore()

func _select_room_at(point: Vector2) -> void:
	for i in range(room_rects.size()):
		if room_rects[i].has_point(point):
			var room: Dictionary = LEVELS[current_floor]["rooms"][i]
			selected_room_id = str(room["id"])
			selected_room_name = str(room["name"])
			_set_message("Выбрано помещение: %s" % selected_room_name)
			_update_ui()
			queue_redraw()
			return

func _interact_with_room() -> void:
	match selected_room_id:
		"bedroom", "guest1", "guest2":
			_rest()
			_set_message("Ты отдохнул в комнате. Силы восстановлены.")
		"living":
			_advance_time(30)
			energy = minf(100.0, energy + 8.0)
			_set_message("Ты спокойно провёл полчаса в гостиной.")
		"kitchen":
			_cook_meal()
		"workshop":
			_work()
		"storage":
			_set_message("Ты проверил полки склада: древесина %d, еда %d, вода %d, металл %d." % [wood, food, water, scrap])
		"arsenal":
			_scout_shore()
	_update_ui()

func _process(delta: float) -> void:
	autosave_elapsed += delta
	if autosave_elapsed >= AUTOSAVE_INTERVAL:
		autosave_elapsed = 0.0
		_save_game_silent()
	if game_over:
		return
	var axis := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if virtual_axis.length() > 0.08:
		axis = virtual_axis
	if axis.length() > 0.1:
		var axis_candidate := player_pos + axis.normalized() * PLAYER_SPEED * delta
		if _can_stand_at(axis_candidate):
			player_pos = axis_candidate
		moving = false
		_update_facing(axis)
		animation_clock += delta
		if animation_clock >= 0.12:
			animation_clock = 0.0
			animation_frame = (animation_frame + 1) % 4
	elif moving:
		var diff := target_pos - player_pos
		if diff.length() < 5.0:
			moving = false
			if pending_stair_floor >= 0:
				_change_floor(pending_stair_floor)
		else:
			var move_dir := diff.normalized()
			var target_candidate := player_pos + move_dir * PLAYER_SPEED * delta
			if _can_stand_at(target_candidate):
				player_pos = target_candidate
			else:
				moving = false
			_update_facing(move_dir)
			animation_clock += delta
			if animation_clock >= 0.12:
				animation_clock = 0.0
				animation_frame = (animation_frame + 1) % 4
	if axis.length() <= 0.1 and not moving:
		animation_frame = 0
	player_pos = _clamp_walkable_point(player_pos)
	# Advance the clock with a fractional accumulator so sub-minute frame
	# increments are not discarded (the old int(delta * 2) never advanced).
	time_fraction += delta * 2.0
	var elapsed_minutes := int(time_fraction)
	if elapsed_minutes > 0:
		time_fraction -= float(elapsed_minutes)
		_advance_time(elapsed_minutes)
	# _advance_time() applies needs exactly once for every whole in-game
	# minute accumulated above. Do not apply delta a second time here: doing
	# so would double the hunger/thirst/energy drain during real-time play.
	if health <= 0 and not game_over:
		game_over = true
		_set_message("Ты погиб. Загрузи последнее сохранение или начни заново.")
	var near_stairs := player_pos.distance_to(Vector2(640, 590)) <= 115.0
	if is_instance_valid(stair_up_button):
		stair_up_button.disabled = not near_stairs or current_floor >= 2
	if is_instance_valid(stair_down_button):
		stair_down_button.disabled = not near_stairs or current_floor <= 0
	_update_ui()
	queue_redraw()

func _eat() -> void:
	if food <= 0:
		_set_message("Еды нет. Нужно пополнить запасы.")
		return
	food -= 1
	hunger = minf(100, hunger + 35)
	_advance_time(20)
	_set_message("Ты поел. Потрачено 20 минут.")
	_update_ui()

func _drink() -> void:
	if purified_water > 0:
		purified_water -= 1
	elif water > 0:
		water -= 1
	else:
		_set_message("Запас воды пуст. Нужно набрать и очистить воду.")
		return
	thirst = minf(100, thirst + 45)
	_advance_time(10)
	_set_message("Ты выпил воды. Потрачено 10 минут.")
	_update_ui()

func _rest() -> void:
	energy = minf(100, energy + 55)
	hunger = maxf(0, hunger - 4)
	thirst = maxf(0, thirst - 6)
	_advance_time(120)
	_set_message("Два часа отдыха. Силы восстановлены.")
	_update_ui()

func _work() -> void:
	if energy < 15:
		_set_message("Слишком мало сил для работы. Отдохни.")
		return
	if wood < 2:
		_set_message("Не хватает древесины для простого ремонта.")
		return
	wood -= 2
	scrap += 1
	energy = maxf(0, energy - 18)
	hunger = maxf(0, hunger - 3)
	_advance_time(60)
	_set_message("Ремонт завершён: -2 древесины, +1 металл.")
	_update_ui()


func _apply_needs(elapsed_minutes: float) -> void:
	var elapsed := maxf(elapsed_minutes, 0.0)
	hunger = maxf(0.0, hunger - elapsed * 0.012)
	thirst = maxf(0.0, thirst - elapsed * 0.020)
	energy = maxf(0.0, energy - elapsed * 0.004)
	if hunger <= 0.0 or thirst <= 0.0:
		health = maxf(0.0, health - elapsed * 0.08)

func _fish() -> void:
	if energy < 8.0:
		_set_message("Ты слишком устал для рыбалки.")
		return
	energy -= 8.0
	_advance_time(50)
	var catch := randi_range(0, 2 if weather == "ДОЖДЬ" else 3)
	fish += catch
	food += catch
	noise_level = minf(100.0, noise_level + 3.0)
	_set_message("Рыбалка завершена. Улов: %d. Погода: %s." % [catch, weather])
	_update_ui()

func _scavenge() -> void:
	if energy < 15.0:
		_set_message("Для поиска припасов нужно больше сил.")
		return
	energy -= 15.0
	_advance_time(75)
	var found := randi_range(1, 3)
	var metal_found := randi_range(0, 1)
	wood += found
	scrap += metal_found
	noise_level = minf(100.0, noise_level + 18.0)
	if noise_level > 55.0:
		zombies += 1
		_set_message("Найдено древесины: %d, металла: %d. Шум привлёк зомби!" % [found, metal_found])
	else:
		_set_message("Найдено древесины: %d, металла: %d." % [found, metal_found])
	_update_ui()

func _purify_water() -> void:
	if water < 1:
		_set_message("Нет сырой воды для очистки.")
		return
	water -= 1
	purified_water += 1
	_advance_time(20)
	_set_message("Одна порция воды очищена. Чистая вода: %d." % purified_water)
	_update_ui()

func _upgrade_barricades() -> void:
	if wood < 6 or scrap < 3 or energy < 20.0:
		_set_message("Улучшение требует 6 древесины, 3 металла и 20 энергии.")
		return
	wood -= 6
	scrap -= 3
	energy -= 20.0
	barricade_level = mini(barricade_level + 1, 5)
	shelter_integrity = minf(100.0, shelter_integrity + 12.0)
	_advance_time(120)
	_set_message("Баррикады улучшены до уровня %d." % barricade_level)
	_update_ui()

func _journal_update() -> void:
	journal_step = mini(journal_step + 1, 5)
	morale = minf(100.0, morale + 4.0)
	_advance_time(10)
	_set_message("Запись в дневнике сделана. Этап истории: %d/5. Боевой дух: %d%%." % [journal_step, int(morale)])
	_update_ui()


# v0.22 — stage 1: island exploration with location unlocks and travel cost.
func _explore_island() -> void:
	var destinations := ["ПЛЯЖ", "ЛЕС", "ЛАГУНА", "СКАЛЬНЫЙ ПЕРЕВАЛ", "СТАРЫЙ ПИРС"]
	var next_location: String = destinations[randi_range(0, destinations.size() - 1)]
	if energy < 12.0:
		_set_message("Сил не хватает для выхода на остров.")
		return
	energy -= 12.0
	island_location = next_location
	explored_locations[next_location] = true
	_advance_time(45)
	_set_message("Исследован район: %s. Известных мест: %d/5." % [island_location, explored_locations.size()])
	_update_ui()

# v0.22 — stage 2: forage with location/weather-dependent yields.
func _forage() -> void:
	if not explored_locations.has("ЛЕС") and island_location != "ЛЕС":
		_set_message("Сначала найди лес во время исследования острова.")
		return
	var berry_gain := randi_range(1, 3)
	var herb_gain := randi_range(0, 2)
	berries += berry_gain
	medicine_herbs += herb_gain
	energy = maxf(0.0, energy - 7.0)
	_advance_time(30)
	_set_message("Собрано ягод: %d, лекарственных трав: %d." % [berry_gain, herb_gain])
	_update_ui()

# v0.22 — stage 3: garden progression provides renewable food.
func _tend_garden() -> void:
	if garden_level == 0:
		if wood < 4 or scrap < 1:
			_set_message("Для грядки нужны 4 древесины и 1 металл.")
			return
		wood -= 4
		scrap -= 1
		garden_level = 1
		_set_message("Первая грядка устроена. Теперь ухаживай за ней ежедневно.")
	else:
		garden_progress += 1.0
		if garden_progress >= 3.0:
			garden_progress = 0.0
			food += 2
			_set_message("Урожай собран: +2 еды.")
		else:
			_set_message("Грядка ухожена. До урожая осталось %d дня ухода." % int(3.0 - garden_progress))
	_advance_time(25)
	_update_ui()

# v0.22 — stage 4: craft a reusable melee tool.
func _craft_spear() -> void:
	if wood < 3 or scrap < 2:
		_set_message("Для копья нужны 3 древесины и 2 металла.")
		return
	wood -= 3
	scrap -= 2
	spear_durability = mini(spear_durability + 40, 100)
	noise_level = minf(100.0, noise_level + 4.0)
	_advance_time(40)
	_set_message("Копьё изготовлено. Прочность: %d%%." % spear_durability)
	_update_ui()

# v0.22 — stage 5: hunting converts weapon durability into food.
func _hunt() -> void:
	if spear_durability <= 0:
		_set_message("Нужно изготовить копьё в мастерской.")
		return
	if energy < 10.0:
		_set_message("Слишком мало сил для охоты.")
		return
	spear_durability = maxi(0, spear_durability - randi_range(8, 18))
	energy -= 10.0
	var catch := randi_range(0, 2)
	food += catch
	_advance_time(60)
	_set_message("Охота завершена. Добыча: %d еды. Прочность копья: %d%%." % [catch, spear_durability])
	_update_ui()

# v0.22 — stage 6: rainwater collection is weather-gated.
func _collect_rainwater() -> void:
	if weather != "ДОЖДЬ":
		_set_message("Собирать дождевую воду можно только во время дождя.")
		return
	var amount := randi_range(1, 3)
	water += amount
	_advance_time(15)
	_set_message("Собрано дождевой воды: %d порции." % amount)
	_update_ui()

# v0.22 — stage 7: radio beacon consumes batteries and can trigger a supply drop.
func _use_radio() -> void:
	if radio_battery < 1:
		_set_message("Для радиомаяка нужна батарея. Найди её среди припасов.")
		return
	radio_battery -= 1
	radio_signal_sent = true
	_advance_time(20)
	if randi_range(1, 100) <= 35:
		rescued_supplies += 1
		food += 2
		water += 1
		_set_message("Сигнал принят! На берегу обнаружен пакет помощи: +2 еды, +1 воды.")
	else:
		_set_message("Сигнал отправлен. Ответа пока нет.")
	_update_ui()

# v0.22 — stage 8: workshop upgrades improve future salvage yields.
func _upgrade_workshop() -> void:
	if wood < 5 or scrap < 4 or shelter_upgrades >= 3:
		_set_message("Улучшение требует 5 древесины и 4 металла. Максимум — 3 уровня.")
		return
	wood -= 5
	scrap -= 4
	shelter_upgrades += 1
	_advance_time(90)
	_set_message("Мастерская улучшена: уровень %d/3." % shelter_upgrades)
	_update_ui()

# v0.22 — stage 9: injury care consumes herbs before health can recover.
func _treat_injury() -> void:
	if injury <= 0.0:
		_set_message("Серьёзных ранений нет. Здоровье: %d%%." % int(health))
		return
	if medicine_herbs < 2:
		_set_message("Для обработки ран нужны 2 лекарственные травы.")
		return
	medicine_herbs -= 2
	injury = maxf(0.0, injury - 35.0)
	health = minf(100.0, health + 12.0)
	_advance_time(30)
	_set_message("Раны обработаны. Травма: %d%%." % int(injury))
	_update_ui()

# v0.22 — stage 10: salvage sorting yields different resources.
func _process_salvage() -> void:
	if rescued_supplies <= 0 and scrap < 2:
		_set_message("Нет найденных пакетов или металлолома для разбора.")
		return
	if rescued_supplies > 0:
		rescued_supplies -= 1
		wood += 2
		radio_battery += 1
	else:
		scrap -= 2
		wood += 1
		medicine_herbs += 1
	_advance_time(20)
	_set_message("Припасы разобраны и отсортированы. Батареи: %d." % radio_battery)
	_update_ui()

func _advance_time(minutes: int) -> void:
	# Explicit actions advance the same survival clock as movement/waiting.
	var elapsed := float(maxi(minutes, 0))
	_apply_needs(elapsed)
	minute_of_day += minutes
	while minute_of_day >= DAY_MINUTES:
		minute_of_day -= DAY_MINUTES
		day += 1
		noise_level = maxf(0.0, noise_level - 25.0)
		morale = maxf(0.0, morale - 1.0)
		var weather_roll := randi_range(0, 3)
		weather = ["ЯСНО", "ТУМАН", "ДОЖДЬ", "ВЕТЕР"][weather_roll]
		# Small shoreline arrivals keep pressure on the shelter without spawning
		# a large horde every night. Traps may reduce the incoming group.
		var incoming := randi_range(1, 3)
		var caught := mini(traps, incoming)
		traps -= caught
		zombies += incoming - caught
		if zombies > 0:
			var raid_damage := maxf(1.0, float(zombies) * (2.0 - float(barricade_level - 1) * 0.18))
			shelter_integrity = maxf(0.0, shelter_integrity - raid_damage)
			if shelter_integrity <= 0.0:
				health = maxf(0.0, health - float(zombies) * 3.0)
				_set_message("ПРОРЫВ! Зомби проникли в убежище. Здоровье под угрозой.")
			else:
				_set_message("День %d. Прибыло %d зомби; ловушки остановили %d. Урон укреплениям: %d." % [day, incoming, caught, int(raid_damage)])
		else:
			_set_message("День %d. Берег чист: ловушки остановили всю группу." % day)
		_save_game_silent()

func _gather_wood() -> void:
	if energy < 12:
		_set_message("Слишком мало сил. Сначала отдохни.")
		return
	wood += 3
	energy = maxf(0, energy - 12)
	hunger = maxf(0, hunger - 2)
	_advance_time(45)
	_set_message("Заготовлено 3 единицы древесины. Потрачено 45 минут.")
	_update_ui()

func _collect_water() -> void:
	if energy < 5:
		_set_message("Не хватает сил поднять ведро с водой.")
		return
	water += 2
	energy = maxf(0, energy - 5)
	_advance_time(20)
	_set_message("Набрано 2 единицы воды через лебёдку.")
	_update_ui()

func _cook_meal() -> void:
	if food < 2:
		_set_message("Для приготовления блюда нужны 2 единицы продуктов.")
		return
	food -= 2
	hunger = minf(100, hunger + 55)
	_advance_time(35)
	_set_message("Приготовлена горячая еда. Потрачено 35 минут.")
	_update_ui()

func _craft_trap() -> void:
	if wood < 4 or scrap < 2:
		_set_message("Для ловушки нужны 4 древесины и 2 металла.")
		return
	if energy < 18:
		_set_message("Слишком мало сил для изготовления ловушки.")
		return
	wood -= 4
	scrap -= 2
	energy -= 18
	traps += 1
	_advance_time(90)
	_set_message("Изготовлена и установлена ловушка у подхода к убежищу.")
	_update_ui()

func _craft_medkit() -> void:
	if scrap < 2 or food < 1:
		_set_message("Для аптечки нужны 2 металла и 1 единица чистых материалов.")
		return
	if energy < 12.0:
		_set_message("Не хватает сил собрать аптечку.")
		return
	scrap -= 2
	food -= 1
	energy -= 12.0
	medkits += 1
	_advance_time(50)
	_set_message("Аптечка собрана. В запасе: %d." % medkits)
	_update_ui()

func _use_medkit() -> void:
	if medkits <= 0:
		_set_message("Аптечек нет. Собери новую в мастерской.")
		return
	if health >= 100.0:
		_set_message("Здоровье уже полностью восстановлено.")
		return
	medkits -= 1
	health = minf(100.0, health + 40.0)
	_advance_time(10)
	_set_message("Использована аптечка. Здоровье восстановлено до %d%%." % int(health))
	_update_ui()

func _scout_shore() -> void:
	_advance_time(25)
	if zombies == 0:
		_set_message("Берег пока чист. Можно заняться хозяйством.")
	else:
		_set_message("На подходах замечено зомби: %d. Подготовь оборону." % zombies)
	_update_ui()

func _defend_shelter() -> void:
	if zombies <= 0:
		_set_message("Сейчас убежищу ничего не угрожает.")
		return
	if energy < 15:
		_set_message("Слишком мало сил для обороны.")
		return
	var defeated := mini(zombies, 2 if scrap >= 1 else 1)
	zombies -= defeated
	if scrap > 0:
		scrap -= 1
	energy = maxf(0.0, energy - 15.0)
	if zombies == 0:
		_set_message("Нападение отражено. Берег временно безопасен.")
	else:
		_set_message("Остановлено %d зомби. Осталось: %d." % [defeated, zombies])
	_advance_time(35)
	_update_ui()

func _repair_shelter() -> void:
	if wood < 2 or energy < 10:
		_set_message("Для ремонта нужны 2 древесины и 10 энергии.")
		return
	wood -= 2
	energy -= 10
	shelter_integrity = minf(100.0, shelter_integrity + 20.0)
	_advance_time(45)
	_set_message("Укрепления отремонтированы. Прочность: %d%%." % int(shelter_integrity))
	_update_ui()

func _new_game() -> void:
	current_floor = 1
	selected_room_id = "living"
	selected_room_name = "ГОСТИНАЯ"
	player_pos = Vector2(640, 420)
	target_pos = Vector2.ZERO
	moving = false
	day = 1
	minute_of_day = 7 * 60
	health = 100.0
	hunger = 85.0
	thirst = 80.0
	energy = 90.0
	wood = 8
	food = 5
	water = 4
	scrap = 3
	traps = 0
	medkits = 1
	zombies = 0
	shelter_integrity = 100.0
	game_over = false
	time_fraction = 0.0
	weather = "ЯСНО"
	noise_level = 0.0
	island_location = "ПЛЯЖ"
	explored_locations = {"ПЛЯЖ": true}
	berries = 0
	medicine_herbs = 0
	garden_level = 0
	garden_progress = 0.0
	spear_durability = 0
	radio_battery = 0
	radio_signal_sent = false
	rescued_supplies = 0
	shelter_upgrades = 0
	injury = 0.0
	purified_water = 0
	fish = 0
	morale = 75.0
	barricade_level = 1
	journal_step = 0
	explored_cache = false
	_set_message("Новая жизнь начинается. Береги запасы.")
	_update_ui()
	_save_game()
	queue_redraw()

func _advance_day_if_needed() -> void:
	while minute_of_day >= DAY_MINUTES:
		minute_of_day -= DAY_MINUTES
		day += 1
		noise_level = maxf(0.0, noise_level - 25.0)
		morale = maxf(0.0, morale - 1.0)
		var weather_roll := randi_range(0, 3)
		weather = ["ЯСНО", "ТУМАН", "ДОЖДЬ", "ВЕТЕР"][weather_roll]

func _set_message(text: String) -> void:
	last_message = text
	if is_instance_valid(message_label):
		message_label.text = text

func _update_ui() -> void:
	if not is_instance_valid(floor_label): return
	floor_label.text = LEVELS[current_floor]["name"]
	if is_instance_valid(stair_up_button):
		stair_up_button.disabled = current_floor >= 2 or player_pos.distance_to(Vector2(640, 590)) > 115.0
	if is_instance_valid(stair_down_button):
		stair_down_button.disabled = current_floor <= 0 or player_pos.distance_to(Vector2(640, 590)) > 115.0
	clock_label.text = "ДЕНЬ %d  •  %02d:%02d" % [day, int(minute_of_day / 60), minute_of_day % 60]
	status_label.text = "Здоровье %d  |  Голод %d  |  Жажда %d  |  Энергия %d" % [int(health), int(hunger), int(thirst), int(energy)]
	inventory_label.text = "Дерево %d | Еда %d | Вода %d+%d | Металл %d | Ловушки %d | Аптечки %d | Ягоды %d | Травы %d | Копьё %d%%" % [wood, food, water, purified_water, scrap, traps, medkits, berries, medicine_herbs, spear_durability]
	clock_label.text += "  •  %s" % weather
	var meter_values := {"Здоровье": health, "Голод": hunger, "Жажда": thirst, "Энергия": energy, "Прочность": shelter_integrity}
	for meter_name in needs_bars:
		var meter: ProgressBar = needs_bars[meter_name]
		meter.value = clampf(float(meter_values[meter_name]), 0.0, 100.0)
		meter.tooltip_text = "%s: %d%%" % [meter_name, int(meter.value)]
	if is_instance_valid(selected_room_label):
		selected_room_label.text = "Комната: %s" % selected_room_name
	if is_instance_valid(room_interact_button):
		room_interact_button.text = "Действие: %s" % _room_action_caption()
	if zombies > 0:
		message_label.text = "%s\nУГРОЗА: %d зомби | Убежище: %d%% | Шум: %d | Баррикады: %d" % [last_message, zombies, int(shelter_integrity), int(noise_level), barricade_level]
	else:
		message_label.text = last_message

func _room_action_caption() -> String:
	match selected_room_id:
		"bedroom", "guest1", "guest2": return "отдых"
		"living": return "посидеть у камина"
		"kitchen": return "приготовить еду"
		"workshop": return "поработать в мастерской"
		"storage": return "проверить запасы"
		"arsenal": return "осмотреть обстановку у берега"
	return "осмотреть помещение"

func _save_game() -> void:
	_save_game_silent()
	_set_message("Игра сохранена.")

func _save_game_silent() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "floor", current_floor)
	cfg.set_value("player", "selected_room_id", selected_room_id)
	cfg.set_value("player", "selected_room_name", selected_room_name)
	cfg.set_value("player", "day", day)
	cfg.set_value("player", "minute", minute_of_day)
	cfg.set_value("player", "health", health)
	cfg.set_value("player", "hunger", hunger)
	cfg.set_value("player", "thirst", thirst)
	cfg.set_value("player", "energy", energy)
	cfg.set_value("player", "x", player_pos.x)
	cfg.set_value("player", "y", player_pos.y)
	cfg.set_value("inventory", "wood", wood)
	cfg.set_value("inventory", "food", food)
	cfg.set_value("inventory", "water", water)
	cfg.set_value("inventory", "scrap", scrap)
	cfg.set_value("inventory", "traps", traps)
	cfg.set_value("inventory", "medkits", medkits)
	cfg.set_value("inventory", "purified_water", purified_water)
	cfg.set_value("inventory", "fish", fish)
	cfg.set_value("world", "weather", weather)
	cfg.set_value("world", "noise_level", noise_level)
	cfg.set_value("world", "morale", morale)
	cfg.set_value("world", "barricade_level", barricade_level)
	cfg.set_value("world", "journal_step", journal_step)
	cfg.set_value("world", "explored_cache", explored_cache)
	cfg.set_value("world", "zombies", zombies)
	cfg.set_value("world", "shelter_integrity", shelter_integrity)
	cfg.set_value("world", "version", 10)
	cfg.set_value("island", "location", island_location)
	cfg.set_value("island", "explored_locations", explored_locations)
	cfg.set_value("island", "berries", berries)
	cfg.set_value("island", "medicine_herbs", medicine_herbs)
	cfg.set_value("island", "garden_level", garden_level)
	cfg.set_value("island", "garden_progress", garden_progress)
	cfg.set_value("island", "spear_durability", spear_durability)
	cfg.set_value("island", "radio_battery", radio_battery)
	cfg.set_value("island", "radio_signal_sent", radio_signal_sent)
	cfg.set_value("island", "rescued_supplies", rescued_supplies)
	cfg.set_value("island", "shelter_upgrades", shelter_upgrades)
	cfg.set_value("island", "injury", injury)
	cfg.set_value("world", "time_fraction", time_fraction)
	cfg.set_value("world", "game_over", game_over)
	cfg.set_value("world", "last_message", last_message)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		_set_message("Ошибка сохранения: %s" % err)

func _load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK: return
	current_floor = int(cfg.get_value("player", "floor", 1))
	selected_room_id = str(cfg.get_value("player", "selected_room_id", "living"))
	selected_room_name = str(cfg.get_value("player", "selected_room_name", "ГОСТИНАЯ"))
	day = int(cfg.get_value("player", "day", 1))
	minute_of_day = int(cfg.get_value("player", "minute", 420))
	time_fraction = float(cfg.get_value("world", "time_fraction", 0.0))
	health = float(cfg.get_value("player", "health", 100.0))
	hunger = float(cfg.get_value("player", "hunger", 85.0))
	thirst = float(cfg.get_value("player", "thirst", 80.0))
	energy = float(cfg.get_value("player", "energy", 90.0))
	player_pos = Vector2(float(cfg.get_value("player", "x", 640.0)), float(cfg.get_value("player", "y", 420.0)))
	current_floor = clampi(current_floor, 0, 2)
	wood = int(cfg.get_value("inventory", "wood", 8))
	food = int(cfg.get_value("inventory", "food", 5))
	water = int(cfg.get_value("inventory", "water", 4))
	scrap = int(cfg.get_value("inventory", "scrap", 3))
	traps = int(cfg.get_value("inventory", "traps", 0))
	medkits = int(cfg.get_value("inventory", "medkits", 1))
	zombies = int(cfg.get_value("world", "zombies", 0))
	shelter_integrity = float(cfg.get_value("world", "shelter_integrity", 100.0))
	game_over = bool(cfg.get_value("world", "game_over", false))
	last_message = str(cfg.get_value("world", "last_message", "Сохранение загружено."))
	# Sanitize values from older or damaged save files before they reach gameplay/UI.
	day = maxi(day, 1)
	minute_of_day = clampi(minute_of_day, 0, DAY_MINUTES - 1)
	health = clampf(health, 0.0, 100.0)
	hunger = clampf(hunger, 0.0, 100.0)
	thirst = clampf(thirst, 0.0, 100.0)
	energy = clampf(energy, 0.0, 100.0)
	shelter_integrity = clampf(shelter_integrity, 0.0, 100.0)
	wood = maxi(wood, 0)
	food = maxi(food, 0)
	water = maxi(water, 0)
	scrap = maxi(scrap, 0)
	traps = maxi(traps, 0)
	medkits = maxi(medkits, 0)
	purified_water = maxi(int(cfg.get_value("inventory", "purified_water", 0)), 0)
	fish = maxi(int(cfg.get_value("inventory", "fish", 0)), 0)
	weather = str(cfg.get_value("world", "weather", "ЯСНО"))
	island_location = str(cfg.get_value("island", "location", "ПЛЯЖ"))
	explored_locations = cfg.get_value("island", "explored_locations", {"ПЛЯЖ": true})
	berries = maxi(int(cfg.get_value("island", "berries", 0)), 0)
	medicine_herbs = maxi(int(cfg.get_value("island", "medicine_herbs", 0)), 0)
	garden_level = clampi(int(cfg.get_value("island", "garden_level", 0)), 0, 1)
	garden_progress = clampf(float(cfg.get_value("island", "garden_progress", 0.0)), 0.0, 2.99)
	spear_durability = clampi(int(cfg.get_value("island", "spear_durability", 0)), 0, 100)
	radio_battery = maxi(int(cfg.get_value("island", "radio_battery", 0)), 0)
	radio_signal_sent = bool(cfg.get_value("island", "radio_signal_sent", false))
	rescued_supplies = maxi(int(cfg.get_value("island", "rescued_supplies", 0)), 0)
	shelter_upgrades = clampi(int(cfg.get_value("island", "shelter_upgrades", 0)), 0, 3)
	injury = clampf(float(cfg.get_value("island", "injury", 0.0)), 0.0, 100.0)
	noise_level = clampf(float(cfg.get_value("world", "noise_level", 0.0)), 0.0, 100.0)
	morale = clampf(float(cfg.get_value("world", "morale", 75.0)), 0.0, 100.0)
	barricade_level = clampi(int(cfg.get_value("world", "barricade_level", 1)), 1, 5)
	journal_step = clampi(int(cfg.get_value("world", "journal_step", 0)), 0, 5)
	explored_cache = bool(cfg.get_value("world", "explored_cache", false))
	zombies = maxi(zombies, 0)
	player_pos = _clamp_walkable_point(player_pos)

func _load_art_assets() -> void:
	var ids := ["bedroom", "living", "kitchen", "workshop", "storage", "arsenal", "guest1", "guest2"]
	for room_id in ids:
		var path := "res://art/rooms/%s.png" % room_id
		if ResourceLoader.exists(path):
			room_textures[room_id] = load(path)
	var character_path := "res://art/characters/survivor_sheet.png"
	if ResourceLoader.exists(character_path):
		survivor_texture = load(character_path)

func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		facing_row = 2 if direction.x > 0.0 else 1
	else:
		facing_row = 0 if direction.y > 0.0 else 3

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("211a14"), true)
	# Atmospheric day/night and weather tint over the shelter illustration.
	var hour := float(minute_of_day) / 60.0
	var night_strength := 0.48 if hour < 6.0 or hour >= 20.0 else (0.22 if hour < 8.0 or hour >= 18.0 else 0.0)
	if night_strength > 0.0:
		draw_rect(Rect2(Vector2(70,205), Vector2(1140,435)), Color(0.05,0.08,0.16,night_strength), true)
	if weather == "ТУМАН":
		draw_rect(Rect2(Vector2(70,205), Vector2(1140,435)), Color(0.72,0.78,0.76,0.12), true)
	elif weather == "ДОЖДЬ":
		for rain_i in range(32):
			var rain_x := 90.0 + float((rain_i * 83) % 1100)
			draw_line(Vector2(rain_x,220), Vector2(rain_x-8,244), Color(0.55,0.68,0.78,0.35), 2.0)
	draw_rect(Rect2(70, 205, 1140, 435), Color("49392c"), true)
	for i in range(28):
		var x := 80.0 + float(i) * 42.0
		draw_line(Vector2(x,205), Vector2(x+22,188+float(i%4)*5), Color("79604a"), 5)
	var rooms: Array = LEVELS[current_floor]["rooms"]
	var center := Vector2(640, 420)
	room_rects.clear()
	for room in rooms:
		var p: Vector2 = center + room["pos"]
		room_rects.append(Rect2(p - Vector2(ROOM_W/2,ROOM_H/2), Vector2(ROOM_W,ROOM_H)))
	for link in LEVELS[current_floor]["links"]:
		var a: Rect2 = room_rects[link[0]]
		var b: Rect2 = room_rects[link[1]]
		draw_rect(Rect2(a.end.x, a.get_center().y-22, b.position.x-a.end.x, 44), Color("8c7054"), true)
		draw_rect(Rect2(a.end.x-3, a.get_center().y-17, 6, 34), Color("d8b98b"), true)
	for i in range(rooms.size()):
		var r: Rect2 = room_rects[i]
		var room: Dictionary = rooms[i]
		var room_id := str(room["id"])
		if room_textures.has(room_id):
			draw_texture_rect(room_textures[room_id], r, false)
		else:
			draw_rect(r, room["color"], true)
		draw_rect(r, Color("e9bd72") if room_id == selected_room_id else Color("c5a77c"), false, 7 if room_id == selected_room_id else 6)
		draw_rect(r.grow(-10), Color("4a3326"), false, 2)
		_draw_furniture(r, str(room["id"]))
		draw_string(ThemeDB.fallback_font, r.position+Vector2(12,24), room["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x-24, 15, Color("f2dfbd"))
	# Shared stair core and visible connector corridor. The stair is connected
	# to the central room via a vertical passage on every floor.
	draw_rect(Rect2(610, 495, 60, 95), Color("8c7054"), true)
	draw_rect(Rect2(610, 495, 60, 95), Color("c5a77c"), false, 3)
	# Corridor spur from the central room to the stairwell landing.
	draw_rect(Rect2(610, 475, 60, 45), Color("8c7054"), true)
	draw_line(Vector2(610,475), Vector2(610,520), Color("c5a77c"), 3)
	draw_line(Vector2(670,475), Vector2(670,520), Color("c5a77c"), 3)
	draw_circle(Vector2(640,590), 28, Color("302219"))
	draw_arc(Vector2(640,590), 21, 0, TAU*0.9, 32, Color("d5b17b"), 4)
	draw_string(ThemeDB.fallback_font, Vector2(605,632), "ВИНТОВАЯ ЛЕСТНИЦА • E", HORIZONTAL_ALIGNMENT_LEFT, 180, 11, Color("e5c99c"))
	if survivor_texture != null:
		var cell := Vector2i(64, 80)
		var source := Rect2(animation_frame * cell.x, facing_row * cell.y, cell.x, cell.y)
		draw_texture_rect_region(survivor_texture, Rect2(player_pos - Vector2(25, 37), Vector2(50, 62)), source)
	else:
		draw_circle(player_pos, 11, Color("d7a16b"))
	draw_string(ThemeDB.fallback_font, Vector2(82,670), "КАМЕННАЯ ТОЛЩА СКАЛЫ • ВНУТРЕННЕЕ ЖИЛИЩЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c5a77c"))
	_draw_virtual_joystick()

func _draw_virtual_joystick() -> void:
	# Subtle parchment-style touch control, visible on phones and harmless on desktop.
	var knob_offset := virtual_axis * joystick_radius * 0.62
	draw_circle(joystick_center, joystick_radius, Color(0.08, 0.06, 0.04, 0.30))
	draw_arc(joystick_center, joystick_radius, 0.0, TAU, 48, Color("c5a77c"), 3.0)
	draw_circle(joystick_center + knob_offset, 27.0, Color("b18a60", 0.88))
	draw_arc(joystick_center + knob_offset, 27.0, 0.0, TAU, 32, Color("ead0a5"), 2.0)
	draw_string(ThemeDB.fallback_font, joystick_center + Vector2(-34, 5), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 68, 11, Color("f2dfbd"))

func _draw_furniture(r: Rect2, id: String) -> void:
	var c := r.get_center()
	# Hand-built, warm rustic furnishing silhouettes. The dark inset and
	# repeated floor seams make the rooms read as carved stone with timber floors.
	for row in range(5):
		var y := r.position.y + 38.0 + float(row) * 22.0
		draw_line(Vector2(r.position.x + 14, y), Vector2(r.end.x - 14, y), Color(0.18, 0.11, 0.07, 0.28), 1.0)
	# A woven rug anchors the central part of each room.
	draw_rect(Rect2(c.x - 48, c.y + 18, 96, 38), Color("76503b"), true)
	draw_rect(Rect2(c.x - 43, c.y + 22, 86, 30), Color("b18a60"), false, 2)
	match id:
		"bedroom", "guest1", "guest2":
			# Bed, pillows, bedside table and kerosene lamp.
			draw_rect(Rect2(c.x - 94, c.y - 43, 112, 65), Color("4a3024"), true)
			draw_rect(Rect2(c.x - 89, c.y - 39, 102, 55), Color("a77c59"), true)
			draw_rect(Rect2(c.x - 81, c.y - 33, 34, 20), Color("e1c9a4"), true)
			draw_rect(Rect2(c.x - 42, c.y - 33, 47, 20), Color("e1c9a4"), true)
			draw_rect(Rect2(c.x + 55, c.y - 35, 37, 34), Color("60402d"), true)
			draw_circle(Vector2(c.x + 73, c.y - 43), 7, Color("e7ad52"))
			draw_circle(Vector2(c.x + 73, c.y - 43), 13, Color(1.0, 0.62, 0.22, 0.13))
			draw_rect(Rect2(c.x - 102, c.y + 40, 35, 20), Color("61442f"), true)
		"living":
			# Sofa, coffee table, bookcase, fireplace and round concealed window.
			draw_rect(Rect2(c.x - 100, c.y - 37, 95, 43), Color("563629"), true)
			draw_rect(Rect2(c.x - 94, c.y - 32, 83, 31), Color("a24f38"), true)
			draw_rect(Rect2(c.x + 16, c.y - 12, 63, 38), Color("69452f"), true)
			draw_rect(Rect2(c.x + 22, c.y - 7, 51, 28), Color("bd9568"), true)
			draw_rect(Rect2(c.x - 110, c.y + 40, 90, 18), Color("5b3d2b"), true)
			for j in range(4):
				draw_line(Vector2(c.x - 103 + j * 20, c.y + 42), Vector2(c.x - 103 + j * 20, c.y + 55), Color("d0ad79"), 2)
			draw_rect(Rect2(c.x + 82, c.y - 48, 28, 58), Color("392a22"), true)
			draw_circle(Vector2(c.x + 96, c.y - 20), 12, Color("ed9c3e"))
			_draw_round_window(Vector2(c.x + 108, c.y - 59))
		"kitchen":
			# Worktop, sink, stove and hanging cookware.
			draw_rect(Rect2(c.x - 105, c.y - 48, 178, 27), Color("9b7048"), true)
			draw_rect(Rect2(c.x - 98, c.y - 43, 55, 17), Color("d2b58b"), true)
			draw_rect(Rect2(c.x - 28, c.y - 43, 42, 17), Color("54463b"), true)
			draw_rect(Rect2(c.x - 23, c.y - 39, 32, 9), Color("9b9a8a"), true)
			draw_rect(Rect2(c.x + 46, c.y + 4, 53, 49), Color("40312a"), true)
			draw_rect(Rect2(c.x + 52, c.y + 10, 41, 35), Color("b45d32"), true)
			draw_circle(Vector2(c.x + 72, c.y + 27), 10, Color("f0a13e"))
			draw_line(Vector2(c.x - 66, c.y - 62), Vector2(c.x - 66, c.y - 49), Color("c6a77b"), 3)
			draw_line(Vector2(c.x - 5, c.y - 62), Vector2(c.x - 5, c.y - 49), Color("c6a77b"), 3)
		"workshop":
			# Heavy workbench, pegboard, tools and research desk.
			draw_rect(Rect2(c.x - 105, c.y + 20, 190, 27), Color("64432d"), true)
			draw_rect(Rect2(c.x - 99, c.y + 16, 178, 8), Color("c0945f"), true)
			draw_rect(Rect2(c.x - 92, c.y - 55, 170, 35), Color("553a2a"), true)
			for j in range(6):
				draw_line(Vector2(c.x - 78 + j * 28, c.y - 48), Vector2(c.x - 78 + j * 28, c.y - 27), Color("d4b17b"), 3)
			draw_circle(Vector2(c.x + 50, c.y + 4), 15, Color("8e9690"))
			draw_circle(Vector2(c.x + 50, c.y + 4), 8, Color("343b38"))
		"storage":
			# Shelving, crates, sacks and labeled supply boxes.
			for j in range(4):
				var sx := c.x - 104 + float(j) * 54.0
				draw_rect(Rect2(sx, c.y - 49, 43, 92), Color("5b3c2b"), true)
				draw_rect(Rect2(sx + 4, c.y - 44, 35, 18), Color("bd9562"), true)
				draw_rect(Rect2(sx + 4, c.y - 19, 35, 24), Color("8d6847"), true)
				draw_rect(Rect2(sx + 4, c.y + 10, 35, 27), Color("b18a59"), true)
		"arsenal":
			# Weapon rack and locked ammunition chest.
			draw_rect(Rect2(c.x - 105, c.y - 48, 160, 17), Color("4a3024"), true)
			for j in range(5):
				draw_line(Vector2(c.x - 92 + j * 29, c.y - 43), Vector2(c.x - 75 + j * 29, c.y - 5), Color("d1b68d"), 5)
			draw_rect(Rect2(c.x - 32, c.y + 24, 91, 34), Color("65432c"), true)
			draw_rect(Rect2(c.x - 28, c.y + 28, 83, 8), Color("b18a59"), true)
	# Every room gets a warm practical light source.
	var lamp_pos := Vector2(r.end.x - 25, r.position.y + 27)
	draw_circle(lamp_pos, 12, Color(1.0, 0.58, 0.18, 0.10))
	draw_circle(lamp_pos, 5, Color("efb45d"))

func _draw_round_window(center: Vector2) -> void:
	# The circular aperture is visible from inside; exterior camouflage is
	# represented by the thick rock wall around the room.
	draw_circle(center, 19, Color("332820"))
	draw_circle(center, 14, Color("8d9a83"))
	draw_circle(center, 10, Color("526b70"))
	draw_line(center + Vector2(-12, 0), center + Vector2(12, 0), Color("d0b78d"), 2)
	draw_line(center + Vector2(0, -12), center + Vector2(0, 12), Color("d0b78d"), 2)

