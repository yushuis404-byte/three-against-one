class_name ResourceAmount
extends Resource
## A reusable resource key + amount pair used by costs and recipes.

@export var key: String = ""
@export var amount: int = 0


static func make(p_key: String, p_amount: int):
	var item = load("res://scripts/templates/resource_amount.gd").new()
	item.key = p_key
	item.amount = p_amount
	return item


static func list_to_dict(items: Array) -> Dictionary:
	var result: Dictionary = {}
	for item in items:
		if item == null or item.key.is_empty() or item.amount == 0:
			continue
		result[item.key] = int(result.get(item.key, 0)) + item.amount
	return result
