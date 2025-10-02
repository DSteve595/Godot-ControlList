class_name ControlList
extends Node
## Renders a dynamic list of items as UI Controls under its parent Control.
## Add this as a child of the Control you want to contain your list items.
## Call `update_list()` whenever your data changes.
## The Control items are inserted/removed/moved to match.
## Structural edits are computed (insert/delete/move) using Myers' diff algorithm.
##
## Usage
## - Add this node as a child of a Control (its parent must be a Control).
## - Provide a factory with set_control_factory(func(item) -> Control) to create a
##   Control for each inserted item (defaults to a basic Label).
## - (Recommended) Provide a key with set_item_key(func(item) -> Variant) to define
##   identity across updates (items with equal keys are considered the same).
## - Call update_list(new_items) to schedule an update; changes are applied in _process
##   (or during idle time if set beforehand).
##
## Notes
## - Only structural edits are performed; existing Controls are reused as-is when keys match.
## - Unchanged (equal) regions are not reported by the diff.
## - Items are added to this node's parent as immediate siblings of this node.
##   This can be used to combine lists with static items
##
## Example:
## 		```
## 		var cl := get_node("MyItemsContainer/ControlList")
## 		cl.set_control_factory(
##  		func(item):
## 				var label := Label.new()
## 				label.text = item.name
## 				return label
## 		)
## 		cl.set_item_key(func(item): return item.id)
## 		cl.update_list([
## 			Item.new(ID_SWORD, "Sword"),
## 			Item.new(ID_SHIELD, "Shield"),
## 			Item.new(ID_HELMET, "Helmet"),
## 		])
## 		```

var __dirty := true
var __parent_control: Control
var __set_first_list := false
var __last_list: Array = []
var __list: Array = []
var __factory: Callable = __default_label_factory
var __key_func: Callable = __default_identity_key
var __position_in_parent: int

## Sets the factory used to create a Control for each list item.
## The factory is called when items are inserted into the list
## to instantiate UI children.
## - factory: Callable taking (item: Variant) and returning a Control node.
##   Example:
##   	```
##   	func(item):
##   		var label := Label.new()
##   		label.text = str(item)
##   		return label
##   	```
func set_control_factory(factory: Callable) -> void:
	__factory = factory

## Sets the key function used to compare items when updating the list.
## Items with equal keys are considered the same logical element.
## - key_func: Callable taking (item: Variant) -> Variant (a comparable key).
##   Example:
##   	```
##   	func(item): return item["id"]
##   	```
func set_item_key(key_func: Callable) -> void:
	__key_func = key_func

## Updates the target list of items to render as Controls.
## The diff algorithm computes inserts/deletes/moves to transform
## the current list into new_list.
## If `immediate` is false (default), this schedules an update to happen
## the next time the ControlList's `_process` function runs
## (or during idle time if set before ready).
## Otherwise if `immediate` is true, the update will happen now.
## Note: Only structural edits are applied;
## per-item visuals should be handled by the factory.
## - new_list: Array of items. This is read once and duplicated internally.
##   Changes to the list must be done via another call to `update_list`.
## - immediate: Whether to update the list of Controls now, or wait until
##   this ControlList's next `_process()`.
func update_list(new_list: Array, immediate: bool = false) -> void:
	__list = new_list.duplicate()
	__set_first_list = true
	if immediate:
		assert(is_node_ready())
		__update()
	else:
		__dirty = true

func _ready() -> void:
	var parent := get_parent()
	assert(parent is Control)
	__parent_control = parent
	if __set_first_list:
		__update.call_deferred()

func _process(_delta: float) -> void:
	if __dirty:
		__update()

func _enter_tree() -> void:
	assert(get_parent() is Control)

func __update() -> void:
	__position_in_parent = get_index()
	var edits := ControlListDiff.myers_diff(__last_list, __list, __key_func)
	for edit in edits:
		match edit["op"]:
			"insert": __edit_insert(edit["b_start"], edit["length"])
			"delete": __edit_delete(edit["a_start"], edit["length"])
			"move": __edit_move(edit["a_start"], edit["b_start"], edit["length"])
	__last_list = __list
	__dirty = false

func __edit_insert(list_position: int, amount: int) -> void:
	for i in amount:
		var control: Control = __factory.call(__list[list_position + i])
		control.set_meta("control_list_instance_id", get_instance_id())
		__parent_control.add_child(control)
		__parent_control.move_child(control, __position_in_parent + 1 + list_position + i)

func __edit_delete(last_list_position: int, amount: int) -> void:
	for i in amount:
		var control = __parent_control.get_child(__position_in_parent + 1 + last_list_position)
		__parent_control.remove_child(control)
		control.queue_free()

func __edit_move(last_list_position: int, list_position: int, amount: int) -> void:
	assert(amount > 0)
	
	var nodes: Array[Node] = []
	nodes.resize(amount)
	for i in amount:
		nodes[i] = __parent_control.get_child(__position_in_parent + 1 + last_list_position + i)
	var dest_index := __position_in_parent + 1 + list_position
	if list_position > last_list_position:
		# Forward move: move in reverse order so the block lands contiguously after destination
		for i in range(amount - 1, -1, -1):
			__parent_control.move_child(nodes[i], dest_index + i)
	else:
		# Backward move or same index: move in natural order
		for i in amount:
			__parent_control.move_child(nodes[i], dest_index + i)

static var __default_label_factory := func(item):
	var label := Label.new()
	label.text = str(item)
	return label

static var __default_identity_key := func(x): return x
