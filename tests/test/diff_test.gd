extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

static var identity_key := func(x): return x

func test_remove_one_at_start() -> void:
	var list_before := ["a", "b", "c"]
	var list_after := ["b", "c"]
	
	var expected_edits := [
		{ "op": "delete", "a_start": 0, "length": 1 }
	]
	var edits := ControlListDiff.myers_diff(list_before, list_after, identity_key)
	assert_array(edits).contains_exactly(expected_edits)
	var list_with_edits := __with_edits(list_before, list_after, edits)
	assert_array(list_with_edits).contains_exactly(list_after)

func test_insert_one_at_end() -> void:
	var list_before := ["a", "b"]
	var list_after := ["a", "b", "c"]
	var expected_edits := [
		{ "op": "insert", "b_start": 2, "length": 1 }
	]
	var edits := ControlListDiff.myers_diff(list_before, list_after, identity_key)
	assert_array(edits).contains_exactly(expected_edits)
	var list_with_edits := __with_edits(list_before, list_after, edits)
	assert_array(list_with_edits).contains_exactly(list_after)

func test_insert_two_at_start() -> void:
	var list_before := ["c"]
	var list_after := ["a", "b", "c"]
	var expected_edits := [
		{ "op": "insert", "b_start": 0, "length": 2 }
	]
	var edits := ControlListDiff.myers_diff(list_before, list_after, identity_key)
	assert_array(edits).contains_exactly(expected_edits)
	var list_with_edits := __with_edits(list_before, list_after, edits)
	assert_array(list_with_edits).contains_exactly(list_after)

func test_delete_two_at_middle() -> void:
	var list_before := ["a", "x", "y", "b"]
	var list_after := ["a", "b"]
	var expected_edits := [
		{ "op": "delete", "a_start": 1, "length": 2 }
	]
	var edits := ControlListDiff.myers_diff(list_before, list_after, identity_key)
	assert_array(edits).contains_exactly(expected_edits)
	var list_with_edits := __with_edits(list_before, list_after, edits)
	assert_array(list_with_edits).contains_exactly(list_after)

func test_delete_two_split() -> void:
	var list_before := ["a", "x", "b", "y"]
	var list_after := ["a", "b"]
	var expected_edits := [
		{ "op": "delete", "a_start": 3, "length": 1 },
		{ "op": "delete", "a_start": 1, "length": 1 },
	]
	var edits := ControlListDiff.myers_diff(list_before, list_after, identity_key)
	assert_array(edits).contains_exactly(expected_edits)
	var list_with_edits := __with_edits(list_before, list_after, edits)
	assert_array(list_with_edits).contains_exactly(list_after)

func test_move_single_forward() -> void:
	var list_before := ["A", "B", "C", "D"]
	var list_after := ["A", "C", "B", "D"]
	var expected_edits := [
		{ "op": "move", "a_start": 1, "b_start": 2, "length": 1 }
	]
	var edits := ControlListDiff.myers_diff(list_before, list_after, identity_key)
	assert_array(edits).contains_exactly(expected_edits)
	var list_with_edits := __with_edits(list_before, list_after, edits)
	assert_array(list_with_edits).contains_exactly(list_after)

func test_move_two_backward() -> void:
	var list_before := ["A", "B", "C", "D", "E"]
	var list_after := ["A", "D", "E", "B", "C"]
	var expected_edits := [
		{ "op": "move", "a_start": 1, "b_start": 3, "length": 2 }
	]
	var edits := ControlListDiff.myers_diff(list_before, list_after, identity_key)
	assert_array(edits).contains_exactly(expected_edits)
	var list_with_edits := __with_edits(list_before, list_after, edits)
	assert_array(list_with_edits).contains_exactly(list_after)

func test_identical_returns_empty() -> void:
	var list_before := ["a", "b", "c"]
	var list_after := ["a", "b", "c"]
	var edits := ControlListDiff.myers_diff(list_before, list_after, identity_key)
	assert_array(edits).is_empty()
	var list_with_edits := __with_edits(list_before, list_after, edits)
	assert_array(list_with_edits).contains_exactly(list_after)

func test_empty_before_all_insert() -> void:
	var list_before := []
	var list_after := ["a", "b"]
	var expected_edits := [
		{ "op": "insert", "b_start": 0, "length": 2 }
	]
	var edits := ControlListDiff.myers_diff(list_before, list_after, identity_key)
	assert_array(edits).contains_exactly(expected_edits)
	var list_with_edits := __with_edits(list_before, list_after, edits)
	assert_array(list_with_edits).contains_exactly(list_after)

func test_empty_after_all_delete() -> void:
	var list_before := ["a", "b"]
	var list_after := []
	var expected_edits := [
		{ "op": "delete", "a_start": 0, "length": 2 }
	]
	var edits := ControlListDiff.myers_diff(list_before, list_after, identity_key)
	assert_array(edits).contains_exactly(expected_edits)
	var list_with_edits := __with_edits(list_before, list_after, edits)
	assert_array(list_with_edits).contains_exactly(list_after)

func test_key_function_ignores_non_key_changes() -> void:
	var list_before := [
		{ "id": 1, "v": "x" },
		{ "id": 2, "v": "x" },
	]
	var list_after := [
		{ "id": 1, "v": "y" },
		{ "id": 2, "v": "z" },
	]
	var key := func(x): return x["id"]
	var result := ControlListDiff.myers_diff(list_before, list_after, key)
	assert_array(result).is_empty()

func test_key_function_move_by_id() -> void:
	var list_before := [
		{ "id": 1, "v": "a" },
		{ "id": 2, "v": "b" },
		{ "id": 3, "v": "c" },
	]
	var list_after := [
		{ "id": 1, "v": "a" },
		{ "id": 3, "v": "c" },
		{ "id": 2, "v": "b" },
	]
	var key := func(x): return x["id"]
	var expected_edits := [
		{ "op": "move", "a_start": 1, "b_start": 2, "length": 1 }
	]
	var edits := ControlListDiff.myers_diff(list_before, list_after, key)
	assert_array(edits).contains_exactly(expected_edits)
	var list_with_edits := __with_edits(list_before, list_after, edits)
	assert_array(list_with_edits).contains_exactly(list_after)

func test_duplicates_nearest_pairing() -> void:
	var list_before := ["A", "B", "A", "C"]
	var list_after := ["A", "A", "B", "C"]
	var expected_edits := [
		{ "op": "move", "a_start": 1, "b_start": 2, "length": 1 }
	]
	var edits := ControlListDiff.myers_diff(list_before, list_after, identity_key)
	assert_array(edits).contains_exactly(expected_edits)
	var list_with_edits := __with_edits(list_before, list_after, edits)
	assert_array(list_with_edits).contains_exactly(list_after)


func __with_edits(list: Array, list_after: Array, edits: Array) -> Array:
	list = list.duplicate()
	for edit in edits:
		match edit["op"]:
			"insert": __do_edit_insert(list, list_after, edit["b_start"], edit["length"])
			"delete": __do_edit_delete(list, edit["a_start"], edit["length"])
			"move": __do_edit_move(list, edit["a_start"], edit["b_start"], edit["length"])
	return list

func __do_edit_insert(list: Array, list_after: Array, list_position: int, amount: int) -> void:
	for i in amount:
		var item = list_after[list_position + i]
		list.insert(list_position + i, item)

func __do_edit_delete(list: Array, last_list_position: int, amount: int) -> void:
	for i in amount:
		list.remove_at(last_list_position)

func __do_edit_move(list: Array, last_list_position: int, list_position: int, amount: int) -> void:
	if amount <= 0: return
	
	# Collect items to move from the current list state
	var items := []
	items.resize(amount)
	for i in amount:
		items[i] = list[last_list_position + i]
	
	# Remove the block from the list starting at last_list_position.
	# Always remove at the same index because the next item shifts into place
	for i in amount:
		list.remove_at(last_list_position)
	
	# Compute destination index in current list after removal
	var dest_index: int = list_position
	# For array-based implementation, insert at the target b_start index directly
	# (moves are applied before inserts and after deletes, so this is safe)
	for i in amount:
		list.insert(dest_index + i, items[i])
