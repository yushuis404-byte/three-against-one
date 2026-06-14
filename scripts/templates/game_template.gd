class_name GameTemplate
extends Resource
## Base metadata shared by data-driven game templates.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon_key: String = ""
@export var tags: Array = []
@export var sort_order: int = 0


func has_tag(tag: String) -> bool:
	return tag in tags


func has_any_tag(query_tags: Array) -> bool:
	for tag in query_tags:
		if tag in tags:
			return true
	return false


func has_all_tags(query_tags: Array) -> bool:
	for tag in query_tags:
		if not (tag in tags):
			return false
	return true


func copy_common_to(target: Resource) -> void:
	target.id = id
	target.display_name = display_name
	target.description = description
	target.icon_key = icon_key
	target.tags = tags.duplicate()
	target.sort_order = sort_order
