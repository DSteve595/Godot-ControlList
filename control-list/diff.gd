class_name ControlListDiff

## Myers diff implementation for arrays.
## Returns a list of edits that turns a into b.
## Each edit is one of:
## - { "op": "insert", "b_start": int, "length": int }
## - { "op": "delete", "a_start": int, "length": int }
## - { "op": "move", "a_start": int, "b_start": int, "length": int }
##
## - a, b: Arrays of any data type.
##
## Example:
## ```
## myers_diff([1,2,3], [2,3,4])
## [
## 	{ op: "delete", a_start: 0, length: 1 },
## 	{ op: "insert", b_start: 2, length: 1 },
## ]
## ```
static func myers_diff(a: Array, b: Array, key: Callable) -> Array:
	var n := a.size()
	var m := b.size()

	# Trivial fast paths
	if n == 0 && m == 0:
		return []
	if n == 0:
		return [{ "op": "insert", "b_start": 0, "length": m }]
	if m == 0:
		return [{ "op": "delete", "a_start": 0, "length": n }]

	var ak := []
	ak.resize(n)
	for i in n:
		ak[i] = key.call(a[i])
	var bk := []
	bk.resize(m)
	for j in m:
		bk[j] = key.call(b[j])

	var trace := __build_trace(ak, bk)
	# Inline backtrack using key arrays
	var edits := []
	var x := n
	var y := m
	for d in range(trace.size() - 1, 0, -1):
		var v := trace[d - 1]
		var k := x - y

		var prev_k: int
		var prev_x: int
		var prev_y: int
		var took_down := false

		var v_km1: int = v.get(k - 1, __NO_VALUE)
		var v_kp1: int = v.get(k + 1, __NO_VALUE)
		if k == -d || (k != d && v_km1 < v_kp1):
			prev_k = k + 1
			prev_x = v.get(prev_k, 0)
			prev_y = prev_x - prev_k
			took_down = true
		else:
			prev_k = k - 1
			# Corner before the right move: do NOT +1 here; we want the pre-step x
			prev_x = v.get(prev_k, 0)
			prev_y = prev_x - prev_k
			took_down = false
		while x > prev_x && y > prev_y:
			x -= 1
			y -= 1
		# Now positioned at or beyond the previous corner (prev_x, prev_y)
		if d > 0:
			if took_down:
				# Previous step was a down move => insertion
				edits.append({ "op": "insert", "b_start": prev_y, "length": 1 })
			else:
				# Previous step was a right move => deletion
				edits.append({ "op": "delete", "a_start": prev_x, "length": 1 })
			# Step fully back to the previous corner for the next iteration
			x = prev_x
			y = prev_y
	edits.reverse() # un-reverse
	var chunks := __coalesce_chunks(edits)
	chunks = __detect_moves(chunks, ak, bk)
	return __plan_apply_order(chunks)

# Build the V trace across D from 0..(n+m). Returns an array of V dictionaries.
static func __build_trace(ak: Array, bk: Array) -> Array[Dictionary]:
	var n = ak.size()
	var m = bk.size()
	var max_d = n + m
	var v := { 1: 0 }
	var trace: Array[Dictionary] = []

	for d in range(0, max_d + 1):
		for k in range(-d, d + 1, 2):
			var x: int
			if k == -d || (k != d && v.has(k - 1) && v.has(k + 1) && v[k - 1] < v[k + 1]):
				# Down move (insert into a): take from k+1
				x = v.get(k + 1, 0)
			else:
				# Right move (delete from a): take from k-1 then step right
				x = v.get(k - 1, 0) + 1
			var y = x - k

			# Follow diagonal (snakes) based on key equality
			while x < n && y < m && ak[x] == bk[y]:
				x += 1
				y += 1

			v[k] = x

			if x >= n && y >= m:
				# Final state reached; append snapshot for this d and return trace
				trace.append(v.duplicate(true))
				return trace

		# Store a copy of V for backtracking at end of this d
		trace.append(v.duplicate(true))

	return trace

# Coalesce singleton edits into chunks with contiguous identical ops
static func __coalesce_chunks(singletons: Array) -> Array:
	var out := []
	if singletons.is_empty():
		return out

	var last: Dictionary
	for entry in singletons:
		var op: String = entry["op"]
		if out.is_empty():
			if op == "delete":
				last = { "op": "delete", "a_start": entry["a_start"], "length": 1 }
			else:
				last = { "op": "insert", "b_start": entry["b_start"], "length": 1 }
			out.append(last)
			continue

		last = out[out.size() - 1]
		if op != last["op"]:
			if op == "delete":
				out.append({ "op": "delete", "a_start": entry["a_start"], "length": 1 })
			else:
				out.append({ "op": "insert", "b_start": entry["b_start"], "length": 1 })
			continue

		if op == "delete":
			var next_a: int = int(last["a_start"]) + int(last["length"])
			if int(entry["a_start"]) == next_a:
				last["length"] = int(last["length"]) + 1
			else:
				out.append({"op": "delete", "a_start": entry["a_start"], "length": 1 })
		else:
			var next_b: int = int(last["b_start"]) + int(last["length"])
			if int(entry["b_start"]) == next_b:
				last["length"] = int(last["length"]) + 1
			else:
				out.append({"op": "insert", "b_start": entry["b_start"], "length": 1 })

	return out

# Plan an ordering of edits that's safe to run on a list in place:
# - deletes first (by descending a_start)
# - moves next (by ascending a_start)
# - inserts last (by ascending b_start)
static func __plan_apply_order(chunks: Array) -> Array:
	var deletes := []
	var moves := []
	var inserts := []
	for c in chunks:
		var op := String(c.get("op", ""))
		if op == "delete":
			deletes.append(c)
		elif op == "move":
			moves.append(c)
		elif op == "insert":
			inserts.append(c)
	# Sort deletes by a_start descending
	for i in range(0, deletes.size()):
		for j in range(i + 1, deletes.size()):
			if int(deletes[i]["a_start"]) < int(deletes[j]["a_start"]):
				var tmp = deletes[i]
				deletes[i] = deletes[j]
				deletes[j] = tmp
	# Sort moves by a_start ascending (fallback to b_start if missing)
	for i in range(0, moves.size()):
		for j in range(i + 1, moves.size()):
			var ai := int(moves[i].get("a_start", -2147483648))
			var aj := int(moves[j].get("a_start", -2147483648))
			if ai == -2147483648 || aj == -2147483648:
				ai = int(moves[i].get("b_start", -2147483648))
				aj = int(moves[j].get("b_start", -2147483648))
			if ai > aj:
				var tmpm = moves[i]
				moves[i] = moves[j]
				moves[j] = tmpm
	# Sort inserts by b_start ascending
	for i in range(0, inserts.size()):
		for j in range(i + 1, inserts.size()):
			if int(inserts[i]["b_start"]) > int(inserts[j]["b_start"]):
				var tmpi = inserts[i]
				inserts[i] = inserts[j]
				inserts[j] = tmpi
	var out2 := []
	out2.append_array(deletes)
	out2.append_array(moves)
	out2.append_array(inserts)
	return out2

# Detect move operations by pairing equal-key delete/insert blocks.
# Produces a new chunk list where matched pairs are replaced by { op: "move" }.
static func __detect_moves(chunks: Array, ak: Array, bk: Array) -> Array:
	if chunks.is_empty():
		return chunks

	# Collect delete and insert chunks with metadata
	var deletes := []
	var inserts := []
	for i in chunks.size():
		var c = chunks[i]
		var op = String(c["op"])
		if op == "delete":
			var a_start: int = c["a_start"]
			var length: int = c["length"]
			var keys := []
			keys.resize(length)
			for t in length:
				keys[t] = ak[a_start + t]
			deletes.append({ "idx": i, "a_start": a_start, "length": length, "keys": keys })
		elif op == "insert":
			var b_start: int = c["b_start"]
			var length2: int = c["length"]
			var keys2 := []
			keys2.resize(length2)
			for t2 in length2:
				keys2[t2] = bk[b_start + t2]
			inserts.append({ "idx": i, "b_start": b_start, "length": length2, "keys": keys2 })

	if deletes.is_empty() || inserts.is_empty():
		return chunks

	# Track which delete/insert entries are paired
	var ins_used := {}
	var pairs: Array[Dictionary] = []

	# For each delete, find the best matching insert with identical key sequence and same length
	for d in deletes:
		var best_ins = null
		var best_dist := 2147483647
		for ins in inserts:
			if ins_used.has(ins["idx"]):
				continue
			if int(ins["length"]) != int(d["length"]):
				continue
			# Compare sequences
			var same := true
			for t in int(d["length"]):
				if d["keys"][t] != ins["keys"][t]:
					same = false
					break
			if !same:
				continue
			# Compute distance preference (nearer move wins)
			var dist = absi(d["a_start"] - ins["b_start"])
			if dist < best_dist:
				best_dist = dist
				best_ins = ins
		if best_ins != null:
			ins_used[best_ins["idx"]] = true
			pairs.append({
				"del_idx": int(d["idx"]),
				"ins_idx": int(best_ins["idx"]),
				"a_start": int(d["a_start"]),
				"b_start": int(best_ins["b_start"]),
				"length": int(d["length"]),
				"emit_at": mini(d["idx"], best_ins["idx"])
			})

	if pairs.is_empty():
		return chunks

	# Build quick lookup from indices to pair and record emit positions
	var del_to_pair := {}
	var ins_to_pair := {}
	var emit_at_map := {}
	for p in pairs:
		del_to_pair[p["del_idx"]] = p
		ins_to_pair[p["ins_idx"]] = p
		emit_at_map[p["emit_at"]] = true

	# Reconstruct chunk list: emit move at first of the two indices, skip the counterpart
	var out := []
	for i in chunks.size():
		# If we should emit move at this position
		if emit_at_map.has(i):
			var p = null
			if del_to_pair.has(i):
				p = del_to_pair[i]
			elif ins_to_pair.has(i):
				p = ins_to_pair[i]
			if p != null:
				out.append({
					"op": "move",
					"a_start": p["a_start"],
					"b_start": p["b_start"],
					"length": p["length"]
				})
				continue
		# Skip chunks that are part of a move pair (but not the emit position)
		if del_to_pair.has(i) || ins_to_pair.has(i):
			# If it's not the emit_at, skip
			var p2 = null
			if del_to_pair.has(i):
				p2 = del_to_pair[i]
			else:
				p2 = ins_to_pair[i]
			if int(p2["emit_at"]) != i:
				continue
		# Otherwise, pass the chunk through
		out.append(chunks[i])

	return out

const __NO_VALUE := -2147483648
