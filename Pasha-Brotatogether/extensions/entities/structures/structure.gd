extends Structure

var network_id
var player_id = -1

func _ready():
	if  $"/root".has_node("GameController"):
		var game_controller = $"/root/GameController"
		if game_controller and game_controller.is_source_of_truth:
			network_id = game_controller.id_count
			game_controller.id_count = network_id + 1

func set_data(data:Resource) -> void :
	if data.player_id == -1:
		.set_data(data)
		return
		 
	base_stats = data.stats
	effects = data.effects
	player_id = data.player_id
	
	make_fake_stats()
	
	call_deferred("reload_data")

func make_fake_stats() -> void:
	# satisfy the setup
	stats = RangedWeaponStats.new()
	
	stats.max_range = 100
	stats.cooldown = 100

func reload_data() -> void:
	if player_id == -1:
		.reload_data()
		return
		
	var multiplayer_weapon_service = $"/root/MultiplayerWeaponService"
	stats = multiplayer_weapon_service.init_ranged_stats_multiplayer(player_id, base_stats, "", [], effects, true)
	
	for effect in effects:
		if effect is BurningEffect:
			var base_burning = BurningData.new(
				effect.burning_data.chance, 
				max(1.0, effect.burning_data.damage + multiplayer_weapon_service.get_scaling_stats_value_multiplayer(player_id, stats.scaling_stats)) as int, 
				effect.burning_data.duration, 
				effect.burning_data.spread, 
				effect.burning_data.type
			)
			
			stats.burning_data = multiplayer_weapon_service.init_burning_data_multiplayer(player_id, base_burning, false, true)
			
	_ready()
