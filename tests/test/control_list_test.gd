extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

func test_initial_insert_and_order() -> void:
	var host := create_and_add_host()
	var cl := host.control_list
	cl.set_control_factory(label_factory)
	cl.update_list([1, 2, 3], true)
	var nodes := host.get_all_list_nodes()
	assert_array(host.get_texts(nodes))\
		.contains_exactly(["item_1", "item_2", "item_3"]) 

func test_noop_update_does_not_recreate() -> void:
	var host := create_and_add_host()
	var cl := host.control_list
	var controls_created := [0] # wrap in an array because lambdas capture
	cl.set_control_factory(
		func(item):
			var label := label_factory(item)
			controls_created[0] += 1
			return label
	)
	cl.update_list([1, 2, 3], true)
	cl.update_list([1, 2, 3], true)
	assert_int(controls_created[0]).is_equal(3)

func test_delete_front_and_back() -> void:
	var host := create_and_add_host()
	var cl := host.control_list
	cl.set_control_factory(label_factory)
	cl.update_list([1, 2, 3, 4], true)
	var nodes_init := host.get_all_list_nodes()
	var to_delete_front := nodes_init[0]
	var to_delete_back := nodes_init[3]
	cl.update_list([2, 3], true)
	var nodes := host.get_all_list_nodes()
	assert_array(host.get_texts(nodes))\
		.contains_exactly(["item_2", "item_3"]) 
	assert_bool(to_delete_front.is_queued_for_deletion()).is_true()
	assert_bool(to_delete_back.is_queued_for_deletion()).is_true()

func test_move_block_preserves_identity() -> void:
	var host := create_and_add_host()
	var cl := host.control_list
	cl.set_control_factory(label_factory)
	cl.update_list(["A", "B", "C", "D", "E"], true)
	var nodes_before := host.get_all_list_nodes()
	var node_B = nodes_before[1]
	var node_C = nodes_before[2]
	cl.update_list(["A", "D", "E", "B", "C"], true) # move block [B,C] behind [D,E]
	var nodes := host.get_all_list_nodes()
	assert_array(host.get_texts(nodes))\
		.contains_exactly(["item_A", "item_D", "item_E", "item_B", "item_C"]) 
	assert_bool(nodes[3] == node_B).is_true()
	assert_bool(nodes[4] == node_C).is_true()

func test_keyed_identity_reuse_and_reorder() -> void:
	var host := create_and_add_host()
	var cl := host.control_list
	cl.set_control_factory(label_factory)
	cl.set_item_key(id_key)
	var list1 := [
		{ "id": 1, "n": "a" },
		{ "id": 2, "n": "b" },
	]
	cl.update_list(list1, true)
	var nodes1 := host.get_all_list_nodes()
	# Change only non-key field -> identities unchanged
	var list2 := [
		{ "id": 1, "n": "ax" },
		{ "id": 2, "n": "bx" },
	]
	cl.update_list(list2, true)
	var nodes2 := host.get_all_list_nodes()
	assert_bool(nodes1[0] == nodes2[0]).is_true()
	assert_bool(nodes1[1] == nodes2[1]).is_true()
	# Reorder by id -> nodes moved, not recreated
	var list3 := [
		{ "id": 2, "n": "bx2" },
		{ "id": 1, "n": "ax2" },
	]
	cl.update_list(list3, true)
	var nodes3 := host.get_all_list_nodes()
	assert_bool(nodes3[0] == nodes2[1]).is_true() # id 2 moved to front
	assert_bool(nodes3[1] == nodes2[0]).is_true()

func test_sibling_positioning_relative_to_control_list() -> void:
	var host := create_and_add_host()
	var cl := host.control_list
	var after_label := Label.new()
	after_label.text = "after_label"
	host.add_child(after_label)
	cl.set_control_factory(label_factory)
	cl.update_list([10, 20], true)
	var cl_index := cl.get_index()
	# Expect: [CL, item_10, item_20, after_label]
	assert_int(after_label.get_index()).is_equal(cl_index + 1 + 2)
	var nodes := host.get_all_list_nodes()
	assert_array(host.get_texts(nodes))\
		.contains_exactly(["item_10", "item_20"]) 

func test_update_before_ready_applies_before_process() -> void:
	var host := HostControl.new()
	auto_free(host)
	var cl := host.control_list
	cl.set_control_factory(label_factory)
	cl.update_list([1], false) # before host is added to the scene tree, so before ready
	add_child(host)
	await get_tree().process_frame # tree process runs before nodes' _process
	var nodes := host.get_all_list_nodes()
	assert_array(host.get_texts(nodes))\
		.contains_exactly(["item_1"]) 

func test_multiple_updates_coalesced_to_last() -> void:
	var host := create_and_add_host()
	var cl := host.control_list
	cl.set_control_factory(label_factory)
	cl.update_list([1], false)
	cl.update_list([1, 2, 3], false)
	await get_tree().process_frame
	await get_tree().process_frame
	var nodes := host.get_all_list_nodes()
	assert_array(host.get_texts(nodes))\
		.contains_exactly(["item_1", "item_2", "item_3"]) 


func label_factory(item) -> Label:
	var label := Label.new()
	label.text = "item_%s" % str(item)
	return label

func id_key(it):
	return it["id"]

class HostControl:
	extends Control
	
	var control_list := ControlList.new()
	
	func _init() -> void:
		add_child(control_list)
	
	func get_all_list_nodes() -> Array[Node]:
		return get_children().filter(
			func(child):
				return child.get_meta("control_list_instance_id", -1) == \
					control_list.get_instance_id()
		)
		
	func get_texts(nodes: Array) -> Array:
		return nodes.map(func(x): return x.text)

func create_and_add_host() -> HostControl:
	var host := HostControl.new()
	auto_free(host)
	add_child(host)
	return host
