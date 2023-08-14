extends Node

func add_item(player_id: int, item:ItemData) -> void:
	var game_controller = get_game_controller()

	if not game_controller:
		return

	var run_data = game_controller.tracked_players[player_id]["run_data"]

	run_data["items"].push_back(item)
	apply_item_effects(player_id, item, run_data)
	add_item_displayed(player_id, item)
	update_item_related_effects(player_id)
	reset_linked_stats(player_id)

func add_gold(player_id:int, value:int) -> void:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return
			
	var tracked_players = game_controller.tracked_players
	var run_data = tracked_players[player_id]["run_data"]
	
	run_data.gold += value
	RunData.emit_signal("gold_changed", run_data.gold)
	
	if tracked_players[player_id]["linked_stats"]["update_on_gold_chance"]:
		reset_linked_stats(player_id)

func get_currency(player_id: int) -> int:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return 0
			
	var tracked_players = game_controller.tracked_players
	var run_data = tracked_players[player_id]["run_data"]
	
	return get_stat(player_id, "stat_max_hp") as int if run_data["effects"]["hp_shop"] else run_data["gold"]

func can_combine_multiplayer(player_id:int, weapon_data:WeaponData)->bool:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return false
			
	var tracked_players = game_controller.tracked_players
	var run_data = tracked_players[player_id]["run_data"]
	
	var nb_duplicates = 0
	
	for weapon in run_data.weapons:
		if weapon.my_id == weapon_data.my_id:
			nb_duplicates += 1
	
	return nb_duplicates >= 2 and weapon_data.upgrades_into != null and weapon_data.tier < run_data.effects["max_weapon_tier"]


func remove_currency(player_id: int, value:int) -> void:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return
			
	var tracked_players = game_controller.tracked_players
	var run_data = tracked_players[player_id]["run_data"]
	
	if run_data["effects"]["hp_shop"]:
		remove_stat(player_id, "stat_max_hp", value)
	else:
		remove_gold(player_id, value)

func remove_gold(player_id, value:int) -> void:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return
			
	var tracked_players = game_controller.tracked_players
	var run_data = tracked_players[player_id]["run_data"]
	
	run_data.gold = max(0, run_data.gold - value) as int
	
	RunData.emit_signal("gold_changed", run_data.gold)

	if tracked_players[player_id]["linked_stats"]["update_on_gold_chance"]:
		reset_linked_stats(player_id)

func remove_stat(player_id: int, stat_name:String, value:int)->void :
	var game_controller = get_game_controller()
	
	if not game_controller:
		return
			
	var tracked_players = game_controller.tracked_players
	var run_data = tracked_players[player_id]["run_data"]
	
	run_data["effects"][stat_name] -= value

func add_weapon(player_id: int, weapon:WeaponData, is_starting:bool = false)->WeaponData:
	var game_controller = get_game_controller()

	if not game_controller:
		return null
		
	RunData.weapon_paths[weapon.my_id] = weapon.get_path()

	var run_data = game_controller.tracked_players[player_id]["run_data"]
	
	var new_weapon = weapon.duplicate()
	
	if is_starting:
		run_data["starting_weapon"] = weapon
	
	run_data.weapons.push_back(new_weapon)
	apply_item_effects(player_id, new_weapon, run_data)
	update_sets(player_id)
	update_item_related_effects(player_id)
	reset_linked_stats(player_id)
	
	return new_weapon

func remove_weapon(player_id:int, weapon:WeaponData) -> int:
	var game_controller = get_game_controller()

	if not game_controller:
		return -1
		
	RunData.weapon_paths[weapon.my_id] = weapon.get_path()

	var run_data = game_controller.tracked_players[player_id]["run_data"]
	
	var removed_weapon_tracked_value = 0
	for current_weapon in run_data.weapons:
		if current_weapon.my_id == weapon.my_id:
			removed_weapon_tracked_value = current_weapon.tracked_value
			run_data.weapons.erase(current_weapon)
			break
			
	unapply_item_effects(player_id, weapon, run_data)
	update_sets(player_id)
	update_item_related_effects(player_id)
	reset_linked_stats(player_id)
	
	return removed_weapon_tracked_value

func add_starting_items_and_weapons(player_id:int) -> void:
	var game_controller = $"/root/GameController"

	var player = game_controller.tracked_players[player_id]
	var run_data = player.run_data
	
	if run_data.effects["starting_item"].size() > 0:
		for item_id in run_data.effects["starting_item"]:
			for i in item_id[1]:
				var item = ItemService.get_element(ItemService.items, item_id[0])
				add_item(player_id, item)
	
	if run_data.effects["starting_weapon"].size() > 0:
		for weapon_id in run_data.effects["starting_weapon"]:
			for i in weapon_id[1]:
				var weapon = ItemService.get_element(ItemService.weapons, weapon_id[0])
				var _weapon = add_weapon(player_id, weapon)

func add_character(player_id: int, character:CharacterData) -> void:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return
		
	var run_data = game_controller.tracked_players[player_id]["run_data"]
	run_data["current_character"] = character
	add_item(player_id, character)

func apply_item_effects(player_id: int, item_data:ItemParentData, run_data) -> void:
	for effect in item_data.effects:
		effect.multiplayer_apply(run_data)

func unapply_item_effects(player_id: int, item_data:ItemParentData, run_data) -> void:
	for effect in item_data.effects:
		effect.multiplayer_unapply(run_data)

func update_sets(player_id: int) -> void:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return
			
	var tracked_players = game_controller.tracked_players
	var run_data = tracked_players[player_id]["run_data"]
	
	for effect in run_data["active_set_effects"]:
		effect[1].multiplayer_unapply(run_data)
	
	run_data["active_set_effects"] = []
	run_data["active_sets"] = {}
	
	for weapon in run_data["weapons"]:
		for set in weapon.sets:
			if run_data["active_sets"].has(set.my_id):
				run_data["active_sets"][set.my_id] += 1
			else :
				run_data["active_sets"][set.my_id] = 1
	
	for key in run_data["active_sets"]:
		if run_data["active_sets"][key] >= 2:
			var set = ItemService.get_set(key)
			var set_effects = set.set_bonuses[min(run_data["active_sets"][key] - 2, set.set_bonuses.size() - 1)]
			
			for effect in set_effects:
				effect.multiplayer_apply(run_data)
				run_data["active_set_effects"].push_back([key, effect])


func get_nb_item(player_id, item_id:String, use_cache:bool = true)->int:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return 0
			
	var tracked_players = game_controller.tracked_players
	var run_data = tracked_players[player_id]["run_data"]
	
	var nb = 0
	
#	if use_cache and items_nb_cache.has(item_id):
#		return items_nb_cache[item_id]
	
	for item in run_data.items:
		if item_id == item.my_id:
			nb += 1
	
#	if use_cache:
#		items_nb_cache[item_id] = nb
	
	return nb


func get_nb_different_items_of_tier(player_id, tier:int = Tier.COMMON)->int:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return 0
			
	var tracked_players = game_controller.tracked_players
	var run_data = tracked_players[player_id]["run_data"]
		
	var nb = 0
	var parsed_items = {}
	
	for item in run_data.items:
		if item.tier == tier and not parsed_items.has(item.my_id) and not item.my_id.begins_with("character_"):
			parsed_items[item.my_id] = true
			nb += 1
	
	return nb

# Mirrors LinkedStats.reset()
# Zeroes out the stats in linked_stats and recalculates them based on effects
# with linked stats
func reset_linked_stats(player_id: int) -> void:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return
	
	var multiplayer_utils = $"/root/MultiplayerUtils"
	
	var tracked_players = game_controller.tracked_players
	var run_data = tracked_players[player_id]["run_data"]
	
	var linked_stats = RunData.init_stats(true)
	var update_on_gold_chance = false
	
	for linked_stat in run_data["effects"]["stat_links"]:
		var stat_to_tweak = linked_stat[0]
		var stat_scaled = 0
		
		if linked_stat[2] == "materials":
			stat_scaled = run_data.gold
			update_on_gold_chance = true
		elif linked_stat[2] == "structure":
			stat_scaled = run_data.effects["structures"].size()
		elif linked_stat[2] == "living_enemy":
			stat_scaled = RunData.current_living_enemies
		elif linked_stat[2] == "living_tree":
			stat_scaled = RunData.current_living_trees
		elif linked_stat[2] == "common_item":
			stat_scaled = get_nb_different_items_of_tier(player_id, Tier.COMMON)
		elif linked_stat[2] == "legendary_item":
			stat_scaled = get_nb_different_items_of_tier(player_id, Tier.LEGENDARY)
		elif linked_stat[2].begins_with("item_"):
			stat_scaled = get_nb_item(player_id, linked_stat[2], false)
		else :
			if run_data.effects.has(linked_stat[2]):
				if linked_stat[4] == true:
					stat_scaled = get_stat(player_id, linked_stat[2])
				else :
					stat_scaled = get_stat(player_id, linked_stat[2]) + multiplayer_utils.get_temp_stat(player_id, linked_stat[2])
			else :
				continue
		
		var amount_to_add = linked_stat[1] * (stat_scaled / linked_stat[3])
		
		linked_stats[stat_to_tweak] = linked_stat[stat_to_tweak] + amount_to_add
	
	tracked_players[player_id]["linked_stats"]["update_on_gold_chance"]  = update_on_gold_chance
	tracked_players[player_id]["linked_stats"]["stats"] = linked_stats

func get_stat(player_id: int, stat_name:String) -> float:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return 1.0
			
	var tracked_players = game_controller.tracked_players
	var run_data = tracked_players[player_id]["run_data"]
	
	return run_data["effects"][stat_name.to_lower()] * get_stat_gain(player_id, stat_name)


func get_stat_gain(player_id: int, stat_name:String)->float:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return 1.0
			
	var tracked_players = game_controller.tracked_players
	var run_data = tracked_players[player_id]["run_data"]
	
	if not run_data["effects"].has("gain_" + stat_name.to_lower()):
		return 1.0
	
	return (1 + (run_data["effects"]["gain_" + stat_name.to_lower()] / 100.0))

func update_item_related_effects(player_id: int)->void :
	update_unique_bonuses(player_id)
	update_additional_weapon_bonuses(player_id)
	update_tier_iv_weapon_bonuses(player_id)
	update_tier_i_weapon_bonuses(player_id)

func update_tier_i_weapon_bonuses(player_id: int)->void :
	var game_controller = get_game_controller()
	
	if not game_controller:
		return
		
	var run_data = game_controller.tracked_players[player_id]["run_data"]
	
	for effect in run_data["tier_i_weapon_effects"]:
		run_data["effects"][effect[0]] -= effect[1]
	
	run_data["tier_i_weapon_effects"] = []
	
	for weapon in run_data["weapons"]:
		if weapon.tier <= Tier.COMMON:
			for effect in run_data["effects"]["tier_i_weapon_effects"]:
				run_data["effects"][effect[0]] += effect[1]
				run_data["tier_i_weapon_effects"].push_back(effect)

func update_tier_iv_weapon_bonuses(player_id: int) -> void:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return
		
	var run_data = game_controller.tracked_players[player_id]["run_data"]
	
	for effect in run_data["tier_iv_weapon_effects"]:
		run_data["effects"][effect[0]] -= effect[1]
	
	run_data["tier_iv_weapon_effects"] = []
	
	for weapon in run_data["weapons"]:
		if weapon.tier >= Tier.LEGENDARY:
			for effect in run_data["effects"]["tier_iv_weapon_effects"]:
				run_data["effects"][effect[0]] += effect[1]
				run_data["tier_iv_weapon_effects"].push_back(effect)

func update_unique_bonuses(player_id: int) -> void:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return
		
	var run_data = game_controller.tracked_players[player_id]["run_data"]
	var unique_effects = run_data["unique_effects"]
		
	for effect in unique_effects:
		run_data["effects"][effect[0]] -= effect[1]
	
	unique_effects = []
	var unique_weapon_ids = get_unique_weapon_ids(player_id)
	
	for i in unique_weapon_ids.size():
		for effect in run_data["effects"]["unique_weapon_effects"]:
			run_data["effects"][effect[0]] += effect[1]
			unique_effects.push_back(effect)

func get_unique_weapon_ids(player_id: int) -> Array:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return []
		
	var run_data = game_controller.tracked_players[player_id]["run_data"]
	
	var unique_weapon_ids = []
	
	for weapon in run_data["weapons"]:
		if not unique_weapon_ids.has(weapon.weapon_id):
			unique_weapon_ids.push_back(weapon.weapon_id)
	
	return unique_weapon_ids

func update_additional_weapon_bonuses(player_id: int)->void :
	var game_controller = get_game_controller()
	
	if not game_controller:
		return

	var run_data = game_controller.tracked_players[player_id]["run_data"]
	
	for effect in run_data["additional_weapon_effects"]:
		run_data["effects"][effect[0]] -= effect[1]
	
	run_data["additional_weapon_effects"] = []
	
	for weapon in run_data["weapons"]:
		for effect in run_data["effects"]["additional_weapon_effects"]:
			run_data["effects"][effect[0]] += effect[1]
			run_data["additional_weapon_effects"].push_back(effect)

func add_item_displayed(player_id: int, new_item:ItemData) -> void:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return
		
	var appearances_displayed = game_controller.tracked_players[player_id]["run_data"]["appearances_displayed"]
	
	for new_appearance in new_item.item_appearances:	
		if new_appearance == null:
			continue
		
		var display_appearance: = true
		
		if new_appearance.position != 0:
			var appearance_to_erase = null
			
			for appearance in appearances_displayed:
				if appearance.position != new_appearance.position or new_appearance.position == 0:
					continue
				
				if new_appearance.display_priority >= appearance.display_priority:
					appearance_to_erase = appearance
				else :
					display_appearance = false
				
				break
			
			if appearance_to_erase:
				appearances_displayed.erase(appearance_to_erase)
		
		if display_appearance:
			appearances_displayed.push_back(new_appearance)
		
	appearances_displayed.sort_custom(Sorter, "sort_depth_ascending")

func get_game_controller():
	if not $"/root".has_node("GameController"):
		return null
	return $"/root/GameController"

func has_weapon_slot_available(player_id: int, weapon_type:int = -1) -> bool:
	var game_controller = get_game_controller()
	
	if not game_controller:
		return false
		
	var run_data = game_controller.tracked_players[player_id]["run_data"]
	
	if weapon_type == - 1:
		return run_data["weapons"].size() < run_data["effects"]["weapon_slot"]
	else :
		var count = 0
		
		for weapon in run_data["weapons"]:
			if weapon.type == weapon_type:
				count += 1
		
		var max_slots = run_data["effects"]["max_melee_weapons"] if weapon_type == WeaponType.MELEE else run_data["effects"]["max_ranged_weapons"]
		
		return run_data["weapons"].size() < run_data["effects"]["weapon_slot"] and count < min(run_data["effects"]["weapon_slot"], max_slots)
