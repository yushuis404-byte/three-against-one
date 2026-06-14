class_name TemplateRegistry
extends Node
## Loads and exposes data-driven templates. Can be autoloaded later.

const GameTemplateScript := preload("res://scripts/templates/game_template.gd")
const UnitTemplateScript := preload("res://scripts/templates/unit_template.gd")
const BuildingTemplateScript := preload("res://scripts/templates/building_template.gd")
const ResourceNodeTemplateScript := preload("res://scripts/templates/resource_node_template.gd")
const DefaultTemplateLibraryScript := preload("res://scripts/templates/default_template_library.gd")

@export var unit_template_dir: String = "res://data/templates/units"
@export var building_template_dir: String = "res://data/templates/buildings"
@export var resource_template_dir: String = "res://data/templates/resources"
@export var include_code_defaults: bool = true

var units: Dictionary = {}
var buildings: Dictionary = {}
var resources: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	units.clear()
	buildings.clear()
	resources.clear()

	if include_code_defaults:
		var defaults = DefaultTemplateLibraryScript.new()
		units.merge(defaults.make_unit_templates(), true)
		buildings.merge(defaults.make_building_templates(units), true)

	_load_templates_from_dir(unit_template_dir, "unit", units)
	_load_templates_from_dir(building_template_dir, "building", buildings)
	_load_templates_from_dir(resource_template_dir, "resource", resources)


func get_unit(id: String) -> Resource:
	return units.get(id, null)


func get_building(id: String) -> Resource:
	return buildings.get(id, null)


func get_resource_node(id: String) -> Resource:
	return resources.get(id, null)


func get_units_with_tag(tag: String) -> Array:
	var result: Array = []
	for template in units.values():
		var unit_template: Resource = template
		if unit_template.has_tag(tag):
			result.append(unit_template)
	return result


func get_buildings_with_tag(tag: String) -> Array:
	var result: Array = []
	for template in buildings.values():
		var building_template: Resource = template
		if building_template.has_tag(tag):
			result.append(building_template)
	return result


func _load_templates_from_dir(path: String, expected_kind: String, target: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			var resource := load(path.path_join(file_name))
			if _is_expected_template(resource, expected_kind):
				var template: Resource = resource
				if not template.id.is_empty():
					target[template.id] = template
		file_name = dir.get_next()
	dir.list_dir_end()


func _is_expected_template(resource: Resource, expected_kind: String) -> bool:
	match expected_kind:
		"unit":
			return resource.get_script() == UnitTemplateScript
		"building":
			return resource.get_script() == BuildingTemplateScript
		"resource":
			return resource.get_script() == ResourceNodeTemplateScript
	return false
