class_name ProductionRecipe
extends Resource
## Generic round-based conversion rule for buildings, units, and map resources.

@export var id: String = ""
@export var inputs: Array = []
@export var outputs: Array = []
@export var requires_garrison: bool = false
@export var per_garrison_unit: bool = false
@export var required_unit_tags: Array = []
@export var max_multiplier: int = 0


static func make_outputs(p_id: String, p_outputs: Array):
	var recipe = load("res://scripts/templates/production_recipe.gd").new()
	recipe.id = p_id
	recipe.outputs = p_outputs
	return recipe


func get_input_dict(multiplier: int = 1) -> Dictionary:
	return _amounts_to_scaled_dict(inputs, multiplier)


func get_output_dict(multiplier: int = 1) -> Dictionary:
	return _amounts_to_scaled_dict(outputs, multiplier)


func get_multiplier(garrison_count: int = 0) -> int:
	if requires_garrison and garrison_count <= 0:
		return 0
	var multiplier := 1
	if per_garrison_unit:
		multiplier = garrison_count
	if max_multiplier > 0:
		multiplier = mini(multiplier, max_multiplier)
	return maxi(multiplier, 0)


func _amounts_to_scaled_dict(items: Array, multiplier: int) -> Dictionary:
	var result: Dictionary = {}
	for item in items:
		if item == null or item.key.is_empty():
			continue
		var value: int = item.amount * multiplier
		if value == 0:
			continue
		result[item.key] = int(result.get(item.key, 0)) + value
	return result
