@tool
extends EditorPlugin


func _handles(object: Object) -> bool:
	if object == null:
		return false
	if object is Node and object.has_method("editor_handle_canvas_paint_event"):
		return true
	return false


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var grid_manager: Node = _get_selected_grid_manager()
	if grid_manager == null:
		return false
	return bool(grid_manager.call("editor_handle_canvas_paint_event", event))


func _get_selected_grid_manager() -> Node:
	var selection: EditorSelection = get_editor_interface().get_selection()
	var nodes: Array[Node] = selection.get_selected_nodes()
	for node in nodes:
		var current: Node = node
		while current != null:
			if current.has_method("editor_handle_canvas_paint_event"):
				return current
			current = current.get_parent()
	return null
