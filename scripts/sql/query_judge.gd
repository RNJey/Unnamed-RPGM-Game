class_name QueryJudge
extends RefCounted
## Evaluates SQL execution results and database mutations against expected conditions.


## Compares two SELECT result sets: same column names and same row multiset.
## Order-sensitive only when `order_sensitive` is true (i.e. query has ORDER BY).
static func judge_select(actual_res: Dictionary, expected_cols: Array, expected_rows: Array, order_sensitive: bool = false) -> Dictionary:
	if not actual_res.get("ok", false):
		return {"ok": false, "error": str(actual_res.get("error", "Query gagal dieksekusi."))}

	var actual_cols: Array = actual_res.get("columns", [])
	var actual_rows: Array = actual_res.get("rows", [])

	if actual_cols.size() != expected_cols.size():
		return {"ok": false, "error": "Jumlah kolom tidak sesuai (dapat %d, seharusnya %d)." % [actual_cols.size(), expected_cols.size()]}
	for i in expected_cols.size():
		if str(actual_cols[i]) != str(expected_cols[i]):
			return {"ok": false, "error": "Nama kolom tidak sesuai: '%s' seharusnya '%s'." % [str(actual_cols[i]), str(expected_cols[i])]}

	if actual_rows.size() != expected_rows.size():
		return {"ok": false, "error": "Jumlah baris hasil (%d) tidak sesuai target (%d)." % [actual_rows.size(), expected_rows.size()]}

	if order_sensitive:
		for i in expected_rows.size():
			if not _rows_equal(actual_rows[i], expected_rows[i], expected_cols):
				return {"ok": false, "error": "Urutan atau isi baris ke-%d tidak sesuai dengan target." % (i + 1)}
		return {"ok": true, "error": ""}

	# Order-insensitive multiset match
	var used: Array[bool] = []
	used.resize(actual_rows.size())
	for exp_r: Dictionary in expected_rows:
		var found := false
		for j in actual_rows.size():
			if not used[j] and _rows_equal(actual_rows[j], exp_r, expected_cols):
				used[j] = true
				found = true
				break
		if not found:
			return {"ok": false, "error": "Isi baris hasil SELECT belum sesuai dengan target."}

	return {"ok": true, "error": ""}


## Evaluates full DDL/DML/DCL conditions from a terminal spec in data/levels.json.
static func judge_terminal(exec_res: Dictionary, target_conditions: Array) -> Dictionary:
	if not exec_res.get("ok", false):
		return {"ok": false, "checks": [], "error": str(exec_res.get("error", "Query gagal."))}

	var db: Dictionary = exec_res.get("db_state", {})
	var tables: Dictionary = db.get("tables", {})
	var perms: Dictionary = db.get("permissions", {})
	var checks: Array[Dictionary] = []
	var all_ok := true
	var first_err := ""

	for cond: Dictionary in target_conditions:
		var ctype := str(cond.get("type", ""))
		var label := str(cond.get("label", ctype))
		var passed := false

		match ctype:
			"table_exists":
				passed = tables.has(str(cond.get("table", "")))
			"columns":
				var tname := str(cond.get("table", ""))
				if tables.has(tname):
					var have_cols: Array = []
					for c: Dictionary in tables[tname]["columns"]:
						have_cols.append(c["name"])
					passed = true
					for req: String in cond.get("columns", []):
						if not req in have_cols:
							passed = false
							break
			"column_type":
				var tname := str(cond.get("table", ""))
				var col := str(cond.get("column", ""))
				var req_t := str(cond.get("value", "")).to_upper()
				if tables.has(tname):
					for c: Dictionary in tables[tname]["columns"]:
						if c["name"] == col and str(c["type"]).to_upper() == req_t:
							passed = true
							break
			"row":
				var tname := str(cond.get("table", ""))
				var needle: Dictionary = cond.get("row", {})
				if tables.has(tname):
					for r: Dictionary in tables[tname]["rows"]:
						if _row_matches_partial(r, needle):
							passed = true
							break
			"no_row":
				var tname := str(cond.get("table", ""))
				var needle: Dictionary = cond.get("row", {})
				if tables.has(tname):
					passed = true
					for r: Dictionary in tables[tname]["rows"]:
						if _row_matches_partial(r, needle):
							passed = false
							break
			"row_count":
				var tname := str(cond.get("table", ""))
				if tables.has(tname):
					passed = tables[tname]["rows"].size() == int(cond.get("count", 0))
			"max_statements":
				passed = int(exec_res.get("statement_count", 0)) <= int(cond.get("count", 1))
			"select_result":
				var order_matters := bool(cond.get("order_matters", false)) or bool(exec_res.get("has_order_by", false))
				var jr := judge_select(exec_res, cond.get("columns", []), cond.get("rows", []), order_matters)
				passed = bool(jr["ok"])
				if not passed and first_err.is_empty():
					first_err = str(jr["error"])
			"permissions":
				var user := str(cond.get("user", ""))
				var tname := str(cond.get("table", ""))
				var user_p: Array = perms.get(user, {}).get(tname, [])
				passed = true
				for rp: String in cond.get("privs", []):
					if not rp in user_p and not "ALL" in user_p:
						passed = false
						break
			"no_permissions":
				var user := str(cond.get("user", ""))
				var tname := str(cond.get("table", ""))
				var user_p: Array = perms.get(user, {}).get(tname, [])
				if "ALL" in cond.get("privs", []):
					passed = user_p.is_empty()
				else:
					passed = true
					for fp: String in cond.get("privs", []):
						if fp in user_p:
							passed = false
							break

		if not passed:
			all_ok = false
			if first_err.is_empty():
				first_err = "Syarat belum terpenuhi: %s" % label
		checks.append({"label": label, "ok": passed})

	return {"ok": all_ok, "checks": checks, "error": first_err if not all_ok else ""}


static func _rows_equal(a: Dictionary, b: Dictionary, cols: Array) -> bool:
	for col in cols:
		var ck := str(col)
		var va = a.get(ck)
		var vb = b.get(ck)
		if va is float or vb is float or va is int or vb is int:
			if (va is int or va is float) and (vb is int or vb is float):
				if not is_equal_approx(float(va), float(vb)):
					return false
				continue
		if str(va) != str(vb):
			return false
	return true


static func _row_matches_partial(row: Dictionary, needle: Dictionary) -> bool:
	for k in needle.keys():
		var va = row.get(k)
		var vb = needle[k]
		if (va is int or va is float) and (vb is int or vb is float):
			if not is_equal_approx(float(va), float(vb)):
				return false
		elif str(va) != str(vb):
			return false
	return true
