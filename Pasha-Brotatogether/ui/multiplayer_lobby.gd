extends Control

onready var players_container = get_node("%Players")
onready var start_button = $ControlBox/Buttons/StartButton

onready var game_mode_dropdown:OptionButton = get_node("%GameModeDropdown")

const PlayerSelections = preload("res://mods-unpacked/Pasha-Brotatogether/ui/player_selections.tscn")

onready var selections_by_player = {}

func _ready():
	var _error = Steam.connect("lobby_chat_update", self, "_on_Lobby_Chat_Update")
	
	var game_controller = $"/root/GameController"
	if game_controller.is_host:
		pass
#		start_button.disabled = true
		
#		character_select_button.hide()
#		weapon_select_button.hide()
#		danger_select_button.hide()
	
	for child in players_container.get_children():
		players_container.remove_child(child)
	
	game_controller.connect("lobby_info_updated", self, "update_selections")
	init_mode_dropdown()
	update_selections()


func init_mode_dropdown() -> void:
	game_mode_dropdown.clear()
	game_mode_dropdown.add_item("Versus", 0)
	game_mode_dropdown.add_item("Co-op", 1)


func update_player_list() -> void:
	# TODO make this work with direct connections too
	var steam_connection = $"/root/SteamConnection"
	steam_connection.update_tracked_players()


func _on_Lobby_Chat_Update(_lobby_id: int, _change_id: int, _making_change_id: int, _chat_state: int) -> void:
	update_selections()


func update_selections() -> void:
	var game_controller = $"/root/GameController"
	var steam_connection = $"/root/SteamConnection"
	var host = steam_connection.get_lobby_host()
	
	if game_controller.lobby_data.has("game_mode"):
		game_mode_dropdown.select(game_controller.lobby_data["game_mode"]) 
	
	for player_id in game_controller.tracked_players:
		var username = game_controller.tracked_players[player_id].username
		
		if not selections_by_player.has(player_id):
			if not game_controller.lobby_data["players"].has(player_id):
				game_controller.lobby_data["players"][player_id] = {}
			var player_to_add = PlayerSelections.instance()
			
			var name = username
			if username == host:
				name += " (HOST)"
			
			player_to_add.call_deferred("set_player_name", name)
			player_to_add.call_deferred("set_player_selections", game_controller.lobby_data["players"][player_id])
			if player_id != game_controller.self_peer_id:
				player_to_add.call_deferred("disable_selections")
			players_container.add_child(player_to_add)
			selections_by_player[player_id] = player_to_add
	
	var can_start = false
	
	if game_controller.is_host:
		game_controller.send_lobby_update(game_controller.lobby_data)
	can_start = can_start and game_controller.all_players_ready
#	if can_start and game_controller.is_host:
#		start_button.disabled = false
#	else:
#		start_button.disabled = true


func _on_StartButton_pressed():
	var game_controller = $"/root/GameController"
	if not game_controller.is_host:
		return
	
	var game_mode = game_mode_dropdown.selected
	game_controller.is_source_of_truth = game_mode == 1
	var game_info = {"current_wave":1, "mode":game_mode, "danger":0}
	
	game_info["lobby_info"] = game_controller.lobby_data
	game_controller.send_start_game(game_info)
	game_controller.game_mode = game_mode

	game_controller.start_game(game_info)
	
	var steam_connection = $"/root/SteamConnection"
	steam_connection.close_lobby()


func _on_CharacterButton_pressed():
	$"/root/GameController".back_to_lobby = true
	
	RunData.weapons = []
	RunData.items = []
	RunData.appearances_displayed = []
	
	RunData.effects = RunData.init_effects()
	RunData.current_character = null
	RunData.starting_weapon = null
	
	var _error = get_tree().change_scene(MenuData.character_selection_scene)


func _on_WeaponButton_pressed():
	RunData.weapons = []
	RunData.items = []
	RunData.appearances_displayed = []
	
	RunData.add_character(RunData.current_character)
	RunData.effects = RunData.init_effects()
	RunData.starting_weapon = null
	
	$"/root/GameController".back_to_lobby = true
	var _error = get_tree().change_scene(MenuData.weapon_selection_scene)


func _on_DangerButton_pressed():
	$"/root/GameController".back_to_lobby = true
	var _error = get_tree().change_scene(MenuData.difficulty_selection_scene)


func clear_selections() -> void:
	RunData.weapons = []
	RunData.items = []
	RunData.effects = RunData.init_effects()
	RunData.current_character = null
	RunData.init_appearances_displayed()


func remote_update_lobby(lobby_info:Dictionary) -> void:
	# Remote only
	if $"/root/GameController".is_host:
		return
	
	RunData.weapons = []
	RunData.items = []
	RunData.effects = RunData.init_effects()
	RunData.current_character = null
	RunData.starting_weapon = null
	
	if lobby_info.has("character"):
		RunData.add_character(load(lobby_info.character))
		
	if lobby_info.has("weapon"):
		var _unused_weapon = RunData.add_weapon(load(lobby_info.weapon), true)
		
	if lobby_info.has("danger"):
		var character_difficulty = ProgressData.get_character_difficulty_info(RunData.current_character.my_id, RunData.current_zone)
		character_difficulty.difficulty_selected_value = lobby_info.danger
	
	update_selections()
 

func _input(event:InputEvent)->void :
	manage_back(event)


func manage_back(event:InputEvent)->void :
	if event.is_action_pressed("ui_cancel"):
		exit_lobby()


func exit_lobby() -> void:
	var game_controller = $"/root/GameController"
	
	if game_controller.is_host:
		var steam_connection = $"/root/SteamConnection"
		steam_connection.close_lobby()
		
	RunData.current_zone = 0
	RunData.reload_music = false
	var _error = get_tree().change_scene(MenuData.title_screen_scene)


func _on_game_mode_changed(_index):
	var game_controller = $"/root/GameController"
	game_controller.lobby_data["game_mode"] = game_mode_dropdown.selected


func _on_BackButton_pressed():
	exit_lobby()
