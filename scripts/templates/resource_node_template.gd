class_name ResourceNodeTemplate
extends "res://scripts/templates/game_template.gd"
## Reusable definition for a resource point placed on the map.

const ResourceAmountScript := preload("res://scripts/templates/resource_amount.gd")

@export var resource_key: String = ""
@export var marker_color: Color = Color.WHITE
@export var gather_results: Array = []
@export var compatible_terrains: Array[int] = []
@export var preferred_zone_tags: Array[int] = []
@export var default_total: int = 0
@export var consumed_on_gather: bool = true


func get_gather_dict() -> Dictionary:
	return ResourceAmountScript.list_to_dict(gather_results)
