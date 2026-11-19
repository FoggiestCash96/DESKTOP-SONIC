extends "res://tests/test_suite.gd"
## Guards what every act's level design promises players: five red rings, each lighting its own slot
## in the HUD (docs/DESIGN.md, hidden collectibles). A red ring's slot is the number its name ends in,
## or its `slot` where the names (which saves keep) aren't in the order the rings come along the act.

const GameStateScript := preload("res://engine/systems/game_state.gd")
const RED_RING := "res://engine/collectibles/hidden_collectible.tscn"
const ACTS: Array[String] = [
	"res://content/sonic/stages/emerald_shore/act_1.tscn",
	"res://content/sonic/stages/emerald_shore/act_2.tscn",
	"res://content/sonic/stages/emerald_shore/act_3.tscn",
	"res://content/sonic/stages/emerald_shore/act_4.tscn",
	"res://content/sonic/stages/emerald_shore/act_5.tscn",
	"res://content/sonic/stages/emerald_shore/act_6.tscn",
	"res://content/sonic/stages/emerald_shore/act_7.tscn",
	"res://content/sonic/stages/emerald_shore/act_8.tscn",
]


func test_each_acts_five_red_rings_fill_a_slot_each() -> void:
	var game := GameStateScript.new()
	for act in ACTS:
		var state := (load(act) as PackedScene).get_state()
		var slots := []
		for node in state.get_node_count():
			var scene := state.get_node_instance(node)
			if scene == null or scene.resource_path != RED_RING:
				continue
			var slot: Variant = _value(state, node, &"slot")
			slots.append(int(slot) if slot != null else game.number_at_end(String(state.get_node_name(node))))
		slots.sort()
		assert_true(slots == [1, 2, 3, 4, 5], "%s: its red rings fill slots %s" % [act.get_file(), slots])
	game.free()


func _value(state: SceneState, node: int, property: StringName) -> Variant:
	for i in state.get_node_property_count(node):
		if state.get_node_property_name(node, i) == property:
			return state.get_node_property_value(node, i)
	return null
