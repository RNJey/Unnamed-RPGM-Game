class_name QueryEngine
extends RefCounted
## In-memory SQL parser and execution engine supporting DDL, DML (incl. SELECT), and DCL.
##
## ECONOMY RULE: Energy refills to max_energy on solving any SQL terminal and on
## GameManager.reset_run(), preventing any energy softlock if a player retries queries.


static func execute(sql: String, tables_or_db: Dictionary, user: String = "pemain") -> Dictionary:
	var db_state := _normalize_db(tables_or_db)
	var tok_res := _tokenize(sql)
	if not tok_res["ok"]:
		return _err(str(tok_res["error"]), db_state)

	var tokens: Array = tok_res["tokens"]
	var stmts := _split_statements(tokens)
	if stmts.is_empty():
		return _err("Query kosong. Ketik perintah SQL terlebih dahulu.", db_state)

	var last_cols: Array = []
	var last_rows: Array = []
	var last_order := false
	var last_op := ""

	for stmt_tokens: Array in stmts:
		var res := _exec_statement(stmt_tokens, db_state, user)
		if not res["ok"]:
			return _err(str(res["error"]), db_state)
		last_cols = res.get("columns", [])
		last_rows = res.get("rows", [])
		last_order = bool(res.get("has_order_by", false))
		last_op = str(res.get("op", ""))

	return {
		"ok": true,
		"columns": last_cols,
		"rows": last_rows,
		"error": "",
		"db_state": db_state,
		"statement_count": stmts.size(),
		"has_order_by": last_order,
		"last_op": last_op,
	}


static func _err(msg: String, db_state: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"columns": [],
		"rows": [],
		"error": msg,
		"db_state": db_state,
		"statement_count": 0,
		"has_order_by": false,
		"last_op": "",
	}


static func _normalize_db(src: Dictionary) -> Dictionary:
	var db := src.duplicate(true)
	if db.has("tables") and db["tables"] is Dictionary:
		if not db.has("permissions"):
			db["permissions"] = {"pemain": {"*": ["ALL"]}}
		return db
	# Plain dictionary of {table_name: Array[RowDict]}
	var tables := {}
	for k in db.keys():
		var arr = db[k]
		if arr is Array:
			var cols: Array = []
			if arr.size() > 0 and arr[0] is Dictionary:
				for col_k in (arr[0] as Dictionary).keys():
					cols.append({"name": str(col_k), "type": "VARCHAR"})
			tables[str(k)] = {"columns": cols, "rows": arr.duplicate(true)}
	return {"tables": tables, "permissions": {"pemain": {"*": ["ALL"]}}}


static func _tokenize(sql: String) -> Dictionary:
	var tokens: Array = []
	var i := 0
	var n := sql.length()
	var depth := 0
	while i < n:
		var ch := sql[i]
		if ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
			i += 1
			continue
		# Line comments --
		if ch == "-" and i + 1 < n and sql[i + 1] == "-":
			while i < n and sql[i] != "\n":
				i += 1
			continue
		if ch == "'" or ch == "\"":
			var quote := ch
			i += 1
			var buf := ""
			var closed := false
			while i < n:
				if sql[i] == quote:
					closed = true
					i += 1
					break
				buf += sql[i]
				i += 1
			if not closed:
				return {"ok": false, "error": "Sintaks salah: tanda kutip belum ditutup."}
			tokens.append({"type": "STR", "val": buf, "raw": buf})
			continue
		if ch in ["(", ")", ",", ";", "*", "."]:
			if ch == "(":
				depth += 1
			elif ch == ")":
				depth -= 1
				if depth < 0:
					return {"ok": false, "error": "Sintaks salah: tanda kurung tutup berlebih."}
			tokens.append({"type": "SYM", "val": ch, "raw": ch})
			i += 1
			continue
		if ch in ["!", "<", ">", "="]:
			var op := ch
			if i + 1 < n and (sql[i + 1] == "=" or (ch == "<" and sql[i + 1] == ">")):
				op += sql[i + 1]
				i += 2
			elif ch == "!":
				return {"ok": false, "error": "Sintaks salah: operator '!' tidak dikenal."}
			else:
				i += 1
			tokens.append({"type": "OP", "val": op, "raw": op})
			continue
		if _is_num_start(ch, sql, i):
			var start := i
			var has_dot := false
			if ch == "-":
				i += 1
			while i < n and ((sql[i] >= "0" and sql[i] <= "9") or (sql[i] == "." and not has_dot)):
				if sql[i] == ".":
					has_dot = true
				i += 1
			var raw := sql.substr(start, i - start)
			var num_val = float(raw) if has_dot else int(raw)
			tokens.append({"type": "NUM", "val": num_val, "raw": raw})
			continue
		if _is_ident_char(ch):
			var start := i
			while i < n and _is_ident_char(sql[i]):
				i += 1
			var raw := sql.substr(start, i - start)
			tokens.append({"type": "WORD", "val": raw.to_upper(), "raw": raw})
			continue
		return {"ok": false, "error": "Karakter tidak dikenali dalam query: '%s'." % ch}
	if depth != 0:
		return {"ok": false, "error": "Sintaks salah: tanda kurung buka belum ditutup."}
	return {"ok": true, "tokens": tokens}


static func _is_num_start(ch: String, s: String, i: int) -> bool:
	if ch >= "0" and ch <= "9":
		return true
	if ch == "-" and i + 1 < s.length() and s[i + 1] >= "0" and s[i + 1] <= "9":
		return true
	return false


static func _is_ident_char(ch: String) -> bool:
	return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_"


static func _split_statements(tokens: Array) -> Array:
	var out: Array = []
	var cur: Array = []
	for t: Dictionary in tokens:
		if t["type"] == "SYM" and t["val"] == ";":
			if not cur.is_empty():
				out.append(cur)
				cur = []
		else:
			cur.append(t)
	if not cur.is_empty():
		out.append(cur)
	return out


static func _has_perm(db: Dictionary, user: String, table: String, needed: String) -> bool:
	var perms: Dictionary = db.get("permissions", {})
	if not perms.has(user):
		return false
	var uperms: Dictionary = perms[user]
	var wildcard: Array = uperms.get("*", [])
	if "ALL" in wildcard or needed in wildcard:
		return true
	var tperms: Array = uperms.get(table, [])
	return "ALL" in tperms or needed in tperms


static func _exec_statement(tokens: Array, db: Dictionary, user: String) -> Dictionary:
	if tokens.is_empty() or tokens[0]["type"] != "WORD":
		return {"ok": false, "error": "Sintaks salah: query harus diawali kata kunci SQL yang valid."}
	var kw: String = tokens[0]["val"]
	match kw:
		"SELECT":
			return _exec_select(tokens, db, user)
		"CREATE":
			return _exec_create(tokens, db)
		"ALTER":
			return _exec_alter(tokens, db)
		"DROP":
			return _exec_drop(tokens, db)
		"INSERT":
			return _exec_insert(tokens, db, user)
		"UPDATE":
			return _exec_update(tokens, db, user)
		"DELETE":
			return _exec_delete(tokens, db, user)
		"GRANT":
			return _exec_grant_revoke(tokens, db, true)
		"REVOKE":
			return _exec_grant_revoke(tokens, db, false)
		_:
			return {"ok": false, "error": "Perintah '%s' tidak didukung oleh mesin SQL Vault." % tokens[0]["raw"]}


# =====================================================================
# DDL: CREATE / ALTER / DROP
# =====================================================================
static func _exec_create(tokens: Array, db: Dictionary) -> Dictionary:
	if tokens.size() < 3 or tokens[1]["type"] != "WORD":
		return {"ok": false, "error": "Sintaks CREATE tidak lengkap."}
	var kind: String = tokens[1]["val"]
	if kind == "DATABASE":
		if tokens.size() != 3:
			return {"ok": false, "error": "Sintaks salah: gunakan CREATE DATABASE <nama>."}
		return {"ok": true, "op": "CREATE DATABASE", "columns": [], "rows": []}
	if kind != "TABLE":
		return {"ok": false, "error": "Hanya CREATE TABLE atau CREATE DATABASE yang didukung."}
	var tname := str(tokens[2]["raw"])
	var open_idx := _find_sym(tokens, "(", 3)
	if open_idx != 3 or tokens[tokens.size() - 1]["raw"] != ")":
		return {"ok": false, "error": "Sintaks CREATE TABLE salah: definisikan kolom di dalam ( ... )."}
	var cols_tokens := tokens.slice(open_idx + 1, tokens.size() - 1)
	if cols_tokens.is_empty():
		return {"ok": false, "error": "CREATE TABLE harus memiliki minimal 1 kolom."}
	var parts := _split_comma_top(cols_tokens)
	var col_defs: Array = []
	for p: Array in parts:
		if p.size() < 2 or p[0]["type"] != "WORD" or p[1]["type"] != "WORD":
			return {"ok": false, "error": "Definisi kolom tidak valid di CREATE TABLE (contoh: ukuran VARCHAR)."}
		var cname := str(p[0]["raw"])
		var ctype := str(p[1]["val"])
		col_defs.append({"name": cname, "type": ctype})
	db["tables"][tname] = {"columns": col_defs, "rows": []}
	return {"ok": true, "op": "CREATE TABLE", "columns": [], "rows": []}


static func _exec_alter(tokens: Array, db: Dictionary) -> Dictionary:
	if tokens.size() < 6 or tokens[1]["val"] != "TABLE":
		return {"ok": false, "error": "Sintaks ALTER TABLE salah. Contoh: ALTER TABLE kotak ADD bahan VARCHAR;"}
	var tname := str(tokens[2]["raw"])
	if not db["tables"].has(tname):
		return {"ok": false, "error": "Tabel '%s' tidak ditemukan." % tname}
	if tokens[3]["val"] != "ADD":
		return {"ok": false, "error": "Hanya ALTER TABLE ... ADD yang didukung."}
	var idx := 4
	if idx < tokens.size() and tokens[idx]["val"] == "COLUMN":
		idx += 1
	if idx + 1 >= tokens.size() or tokens[idx]["type"] != "WORD" or tokens[idx + 1]["type"] != "WORD":
		return {"ok": false, "error": "Sintaks ADD kolom salah (contoh: ADD bahan VARCHAR)."}
	var cname := str(tokens[idx]["raw"])
	var ctype := str(tokens[idx + 1]["val"])
	var tbl: Dictionary = db["tables"][tname]
	for c: Dictionary in tbl["columns"]:
		if c["name"] == cname:
			return {"ok": false, "error": "Kolom '%s' sudah ada di tabel '%s'." % [cname, tname]}
	tbl["columns"].append({"name": cname, "type": ctype})
	for r: Dictionary in tbl["rows"]:
		r[cname] = null
	return {"ok": true, "op": "ALTER TABLE", "columns": [], "rows": []}


static func _exec_drop(tokens: Array, db: Dictionary) -> Dictionary:
	if tokens.size() != 3 or tokens[1]["val"] != "TABLE":
		return {"ok": false, "error": "Sintaks salah: gunakan DROP TABLE <nama_tabel>."}
	var tname := str(tokens[2]["raw"])
	if not db["tables"].has(tname):
		return {"ok": false, "error": "Tabel '%s' tidak ditemukan." % tname}
	db["tables"].erase(tname)
	return {"ok": true, "op": "DROP TABLE", "columns": [], "rows": []}


# =====================================================================
# DML: INSERT / UPDATE / DELETE
# =====================================================================
static func _exec_insert(tokens: Array, db: Dictionary, user: String) -> Dictionary:
	if tokens.size() < 6 or tokens[1]["val"] != "INTO":
		return {"ok": false, "error": "Sintaks INSERT salah. Contoh: INSERT INTO kotak (ukuran, warna) VALUES ('besar', 'merah');"}
	var tname := str(tokens[2]["raw"])
	if not db["tables"].has(tname):
		return {"ok": false, "error": "Tabel '%s' tidak ditemukan. Buat tabel dengan CREATE TABLE terlebih dahulu." % tname}
	if not _has_perm(db, user, tname, "INSERT"):
		return {"ok": false, "error": "Izin ditolak: '%s' tidak memiliki hak INSERT pada tabel '%s'." % [user, tname]}

	var tbl: Dictionary = db["tables"][tname]
	var tbl_cols: Array = []
	for c: Dictionary in tbl["columns"]:
		tbl_cols.append(c["name"])

	var idx := 3
	var target_cols: Array = []
	if idx < tokens.size() and tokens[idx]["raw"] == "(":
		var close_i := _find_matching_paren(tokens, idx)
		var col_slice := tokens.slice(idx + 1, close_i)
		for part: Array in _split_comma_top(col_slice):
			if part.size() != 1:
				return {"ok": false, "error": "Daftar kolom pada INSERT tidak valid."}
			var cname := str(part[0]["raw"])
			if not cname in tbl_cols:
				return {"ok": false, "error": "Kolom '%s' tidak ditemukan pada tabel '%s'." % [cname, tname]}
			target_cols.append(cname)
		idx = close_i + 1
	else:
		target_cols = tbl_cols.duplicate()

	if idx >= tokens.size() or tokens[idx]["val"] != "VALUES":
		return {"ok": false, "error": "Sintaks INSERT salah: kata kunci VALUES tidak ditemukan."}
	idx += 1
	if idx >= tokens.size() or tokens[idx]["raw"] != "(":
		return {"ok": false, "error": "Sintaks VALUES salah: daftar nilai harus di dalam tanda kurung ( ... )."}
	var close_v := _find_matching_paren(tokens, idx)
	if close_v != tokens.size() - 1:
		return {"ok": false, "error": "Terdapat token tak dikenal setelah VALUES (...)."}

	var val_parts := _split_comma_top(tokens.slice(idx + 1, close_v))
	if val_parts.size() != target_cols.size():
		return {"ok": false, "error": "Jumlah nilai (%d) tidak sesuai dengan jumlah kolom (%d)." % [val_parts.size(), target_cols.size()]}

	var new_row := {}
	for c: String in tbl_cols:
		new_row[c] = null
	for i in target_cols.size():
		var vp: Array = val_parts[i]
		if vp.size() != 1:
			return {"ok": false, "error": "Nilai pada INSERT VALUES tidak valid."}
		new_row[target_cols[i]] = _token_literal(vp[0])

	tbl["rows"].append(new_row)
	return {"ok": true, "op": "INSERT", "columns": tbl_cols, "rows": tbl["rows"].duplicate(true)}


static func _exec_update(tokens: Array, db: Dictionary, user: String) -> Dictionary:
	if tokens.size() < 6 or tokens[2]["val"] != "SET":
		return {"ok": false, "error": "Sintaks UPDATE salah. Contoh: UPDATE kotak SET warna = 'biru' WHERE ukuran = 'besar';"}
	var tname := str(tokens[1]["raw"])
	if not db["tables"].has(tname):
		return {"ok": false, "error": "Tabel '%s' tidak ditemukan." % tname}
	if not _has_perm(db, user, tname, "UPDATE"):
		return {"ok": false, "error": "Izin ditolak: '%s' tidak memiliki hak UPDATE pada tabel '%s'." % [user, tname]}

	var tbl: Dictionary = db["tables"][tname]
	var tbl_cols: Array = []
	for c: Dictionary in tbl["columns"]:
		tbl_cols.append(c["name"])

	var where_idx := _find_kw(tokens, "WHERE", 3)
	var set_end := where_idx if where_idx >= 0 else tokens.size()
	var set_parts := _split_comma_top(tokens.slice(3, set_end))
	if set_parts.is_empty():
		return {"ok": false, "error": "Klausa SET pada UPDATE tidak boleh kosong."}

	var updates: Array = []
	for p: Array in set_parts:
		if p.size() != 3 or p[1]["raw"] != "=":
			return {"ok": false, "error": "Sintaks SET salah (gunakan kolom = nilai)."}
		var col := str(p[0]["raw"])
		if not col in tbl_cols:
			return {"ok": false, "error": "Kolom '%s' tidak ditemukan pada tabel '%s'." % [col, tname]}
		updates.append({"col": col, "val": _token_literal(p[2])})

	var where_tokens: Array = tokens.slice(where_idx + 1, tokens.size()) if where_idx >= 0 else []
	if where_idx >= 0 and where_tokens.is_empty():
		return {"ok": false, "error": "Klausa WHERE tidak boleh kosong."}

	for r: Dictionary in tbl["rows"]:
		if where_tokens.is_empty():
			for u: Dictionary in updates:
				r[u["col"]] = u["val"]
		else:
			var ev := _eval_where(where_tokens, r, tbl_cols)
			if not ev["ok"]:
				return {"ok": false, "error": ev["error"]}
			if ev["match"]:
				for u: Dictionary in updates:
					r[u["col"]] = u["val"]

	return {"ok": true, "op": "UPDATE", "columns": tbl_cols, "rows": tbl["rows"].duplicate(true)}


static func _exec_delete(tokens: Array, db: Dictionary, user: String) -> Dictionary:
	if tokens.size() < 3 or tokens[1]["val"] != "FROM":
		return {"ok": false, "error": "Sintaks DELETE salah. Contoh: DELETE FROM arsip WHERE status = 'rusak';"}
	var tname := str(tokens[2]["raw"])
	if not db["tables"].has(tname):
		return {"ok": false, "error": "Tabel '%s' tidak ditemukan." % tname}
	if not _has_perm(db, user, tname, "DELETE"):
		return {"ok": false, "error": "Izin ditolak: '%s' tidak memiliki hak DELETE pada tabel '%s'." % [user, tname]}

	var tbl: Dictionary = db["tables"][tname]
	var tbl_cols: Array = []
	for c: Dictionary in tbl["columns"]:
		tbl_cols.append(c["name"])

	if tokens.size() == 3:
		tbl["rows"] = []
		return {"ok": true, "op": "DELETE", "columns": tbl_cols, "rows": []}

	if tokens[3]["val"] != "WHERE" or tokens.size() < 5:
		return {"ok": false, "error": "Sintaks DELETE ... WHERE tidak valid."}
	var where_tokens := tokens.slice(4, tokens.size())
	var kept: Array = []
	for r: Dictionary in tbl["rows"]:
		var ev := _eval_where(where_tokens, r, tbl_cols)
		if not ev["ok"]:
			return {"ok": false, "error": ev["error"]}
		if not ev["match"]:
			kept.append(r)
	tbl["rows"] = kept
	return {"ok": true, "op": "DELETE", "columns": tbl_cols, "rows": kept.duplicate(true)}


# =====================================================================
# DCL: GRANT / REVOKE
# =====================================================================
static func _exec_grant_revoke(tokens: Array, db: Dictionary, is_grant: bool) -> Dictionary:
	var on_idx := _find_kw(tokens, "ON", 1)
	var prep := "TO" if is_grant else "FROM"
	var prep_idx := _find_kw(tokens, prep, on_idx + 1 if on_idx >= 0 else 1)
	if on_idx < 2 or prep_idx < on_idx + 2 or prep_idx + 1 >= tokens.size():
		var usage := "GRANT <izin> ON <tabel> TO <user>" if is_grant else "REVOKE <izin> ON <tabel> FROM <user>"
		return {"ok": false, "error": "Sintaks salah. Gunakan: %s" % usage}

	var tname := str(tokens[on_idx + 1]["raw"])
	if not db["tables"].has(tname):
		return {"ok": false, "error": "Tabel '%s' tidak ditemukan." % tname}
	var target_user := str(tokens[prep_idx + 1]["raw"])

	var privs: Array = []
	for p: Array in _split_comma_top(tokens.slice(1, on_idx)):
		if p.size() != 1:
			return {"ok": false, "error": "Daftar hak akses pada DCL tidak valid."}
		privs.append(str(p[0]["val"]))

	var perms: Dictionary = db["permissions"]
	if not perms.has(target_user):
		perms[target_user] = {}
	if not perms[target_user].has(tname):
		perms[target_user][tname] = []

	var user_tbl_perms: Array = perms[target_user][tname]
	if is_grant:
		for pr: String in privs:
			if not pr in user_tbl_perms:
				user_tbl_perms.append(pr)
	else:
		if "ALL" in privs:
			perms[target_user][tname] = []
		else:
			var next_perms: Array = []
			for existing: String in user_tbl_perms:
				if not existing in privs:
					next_perms.append(existing)
			perms[target_user][tname] = next_perms

	return {"ok": true, "op": "GRANT" if is_grant else "REVOKE", "columns": [], "rows": []}


# =====================================================================
# DML: SELECT ... FROM ... WHERE ... ORDER BY ... LIMIT ...
# =====================================================================
static func _exec_select(tokens: Array, db: Dictionary, user: String) -> Dictionary:
	var from_idx := _find_kw(tokens, "FROM", 1)
	if from_idx < 2 or from_idx + 1 >= tokens.size():
		return {"ok": false, "error": "Sintaks SELECT salah: klausa FROM atau nama tabel tidak ditemukan."}

	var tname := str(tokens[from_idx + 1]["raw"])
	if not db["tables"].has(tname):
		return {"ok": false, "error": "Tabel '%s' tidak ditemukan." % tname}
	if not _has_perm(db, user, tname, "SELECT"):
		return {"ok": false, "error": "Izin ditolak: '%s' tidak memiliki hak SELECT pada tabel '%s'." % [user, tname]}

	var tbl: Dictionary = db["tables"][tname]
	var tbl_cols: Array = []
	for c: Dictionary in tbl["columns"]:
		tbl_cols.append(c["name"])

	var cursor := from_idx + 2
	var where_idx := _find_kw(tokens, "WHERE", cursor)
	var order_idx := _find_kw(tokens, "ORDER", cursor)
	var limit_idx := _find_kw(tokens, "LIMIT", cursor)

	# Reject unsupported keywords like JOIN / GROUP / HAVING
	var unsupported := _check_unsupported_clauses(tokens, cursor)
	if not unsupported.is_empty():
		return {"ok": false, "error": unsupported}

	# Validate clause ordering: WHERE < ORDER BY < LIMIT
	if where_idx >= 0 and order_idx >= 0 and where_idx > order_idx:
		return {"ok": false, "error": "Urutan klausa salah: WHERE harus ditulis sebelum ORDER BY."}
	if order_idx >= 0 and limit_idx >= 0 and order_idx > limit_idx:
		return {"ok": false, "error": "Urutan klausa salah: ORDER BY harus ditulis sebelum LIMIT."}
	if where_idx >= 0 and limit_idx >= 0 and where_idx > limit_idx:
		return {"ok": false, "error": "Urutan klausa salah: WHERE harus ditulis sebelum LIMIT."}

	var first_clause := tokens.size()
	for idx_c: int in [where_idx, order_idx, limit_idx]:
		if idx_c >= 0 and idx_c < first_clause:
			first_clause = idx_c
	if first_clause != cursor:
		return {"ok": false, "error": "Sintaks tidak dikenali setelah nama tabel '%s'." % tname}

	var rows: Array = tbl["rows"].duplicate(true)
	if where_idx >= 0:
		var w_end := order_idx if order_idx >= 0 else (limit_idx if limit_idx >= 0 else tokens.size())
		var w_toks := tokens.slice(where_idx + 1, w_end)
		if w_toks.is_empty():
			return {"ok": false, "error": "Klausa WHERE tidak boleh kosong."}
		var filtered: Array = []
		for r: Dictionary in rows:
			var ev := _eval_where(w_toks, r, tbl_cols)
			if not ev["ok"]:
				return {"ok": false, "error": ev["error"]}
			if ev["match"]:
				filtered.append(r)
		rows = filtered

	# Parse SELECT projection list
	var sel_parts := _split_comma_top(tokens.slice(1, from_idx))
	if sel_parts.is_empty():
		return {"ok": false, "error": "Daftar kolom SELECT kosong."}

	var proj_res := _parse_select_items(sel_parts, tbl_cols)
	if not proj_res["ok"]:
		return {"ok": false, "error": proj_res["error"]}

	var items: Array = proj_res["items"]
	var has_agg: bool = proj_res["has_agg"]
	var has_non_agg: bool = proj_res["has_non_agg"]
	if has_agg and has_non_agg:
		return {"ok": false, "error": "Tidak bisa mencampur kolom biasa dan fungsi agregat tanpa GROUP BY."}

	var has_order_by := false
	if order_idx >= 0:
		has_order_by = true
		if order_idx + 1 >= tokens.size() or tokens[order_idx + 1]["val"] != "BY":
			return {"ok": false, "error": "Sintaks ORDER salah: gunakan ORDER BY <kolom> [ASC|DESC]."}
		var o_end := limit_idx if limit_idx >= 0 else tokens.size()
		var o_toks := tokens.slice(order_idx + 2, o_end)
		if o_toks.is_empty() or o_toks.size() > 2:
			return {"ok": false, "error": "Sintaks ORDER BY tidak valid (contoh: ORDER BY id DESC)."}
		var ocol := str(o_toks[0]["raw"])
		if not ocol in tbl_cols and not (has_agg and _has_out_col(items, ocol)):
			return {"ok": false, "error": "Kolom '%s' pada ORDER BY tidak ditemukan." % ocol}
		var desc := false
		if o_toks.size() == 2:
			var dir_kw := str(o_toks[1]["val"])
			if dir_kw == "DESC":
				desc = true
			elif dir_kw != "ASC":
				return {"ok": false, "error": "Arah ORDER BY harus ASC atau DESC, bukan '%s'." % o_toks[1]["raw"]}
		if not has_agg:
			rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var cmp := _compare_vals(a.get(ocol), b.get(ocol))
				return cmp > 0 if desc else cmp < 0
			)

	var limit_val := -1
	if limit_idx >= 0:
		var l_toks := tokens.slice(limit_idx + 1, tokens.size())
		if l_toks.size() != 1 or l_toks[0]["type"] != "NUM" or not (l_toks[0]["val"] is int):
			return {"ok": false, "error": "Nilai LIMIT harus berupa bilangan bulat positif."}
		limit_val = int(l_toks[0]["val"])
		if limit_val < 0:
			return {"ok": false, "error": "Nilai LIMIT tidak boleh negatif."}

	var out_cols: Array = []
	var out_rows: Array = []

	if has_agg:
		var agg_row := {}
		for it: Dictionary in items:
			var out_name: String = it["out_name"]
			out_cols.append(out_name)
			agg_row[out_name] = _compute_aggregate(it["agg"], it["col"], rows)
		out_rows = [agg_row]
	else:
		for it: Dictionary in items:
			if it["is_star"]:
				for cname: String in tbl_cols:
					out_cols.append(cname)
			else:
				out_cols.append(it["out_name"])
		for r: Dictionary in rows:
			var row_dict := {}
			for it: Dictionary in items:
				if it["is_star"]:
					for cname: String in tbl_cols:
						row_dict[cname] = r.get(cname)
				else:
					row_dict[it["out_name"]] = r.get(it["col"])
			out_rows.append(row_dict)

	if limit_val >= 0 and out_rows.size() > limit_val:
		out_rows = out_rows.slice(0, limit_val)

	return {
		"ok": true,
		"op": "SELECT",
		"columns": out_cols,
		"rows": out_rows,
		"has_order_by": has_order_by,
	}


static func _check_unsupported_clauses(tokens: Array, start: int) -> String:
	var bad := ["JOIN", "INNER", "LEFT", "RIGHT", "GROUP", "HAVING", "UNION", "DISTINCT"]
	var i := start
	var n := tokens.size()
	while i < n:
		var t: Dictionary = tokens[i]
		if t["type"] == "WORD" and str(t["val"]) in bad:
			return "Klausa '%s' tidak didukung oleh mesin SQL Vault." % t["raw"]
		i += 1
	return ""


static func _parse_select_items(parts: Array, tbl_cols: Array) -> Dictionary:
	var items: Array = []
	var has_agg := false
	var has_non_agg := false
	for p: Array in parts:
		if p.is_empty():
			return {"ok": false, "error": "Kolom SELECT kosong setelah koma."}
		# Optional AS alias
		var alias := ""
		var expr := p
		if p.size() >= 3 and p[p.size() - 2]["type"] == "WORD" and p[p.size() - 2]["val"] == "AS":
			alias = str(p[p.size() - 1]["raw"])
			expr = p.slice(0, p.size() - 2)

		if expr.size() == 1 and expr[0]["raw"] == "*":
			has_non_agg = true
			items.append({"is_star": true, "agg": "", "col": "*", "out_name": "*"})
		elif expr.size() == 1 and expr[0]["type"] == "WORD":
			var cname := str(expr[0]["raw"])
			if not cname in tbl_cols:
				return {"ok": false, "error": "Kolom '%s' tidak ditemukan." % cname}
			has_non_agg = true
			items.append({"is_star": false, "agg": "", "col": cname, "out_name": alias if not alias.is_empty() else cname})
		elif expr.size() == 4 and expr[0]["type"] == "WORD" and expr[1]["raw"] == "(" and expr[3]["raw"] == ")":
			var fn := str(expr[0]["val"])
			if not fn in ["COUNT", "SUM", "AVG", "MIN", "MAX"]:
				return {"ok": false, "error": "Fungsi agregat '%s' tidak didukung (hanya COUNT, SUM, AVG, MIN, MAX)." % expr[0]["raw"]}
			var arg := str(expr[2]["raw"])
			if arg != "*" and not arg in tbl_cols:
				return {"ok": false, "error": "Kolom '%s' di dalam %s(...) tidak ditemukan." % [arg, fn]}
			if fn != "COUNT" and arg == "*":
				return {"ok": false, "error": "Fungsi %s(*) tidak valid; sebutkan nama kolom numerik." % fn}
			has_agg = true
			var def_name := "%s(%s)" % [fn, arg]
			items.append({"is_star": false, "agg": fn, "col": arg, "out_name": alias if not alias.is_empty() else def_name})
		else:
			return {"ok": false, "error": "Ekspresi SELECT tidak valid."}

	return {"ok": true, "items": items, "has_agg": has_agg, "has_non_agg": has_non_agg}


static func _has_out_col(items: Array, name: String) -> bool:
	for it: Dictionary in items:
		if it["out_name"] == name:
			return true
	return false


static func _compute_aggregate(fn: String, col: String, rows: Array):
	if fn == "COUNT":
		if col == "*":
			return rows.size()
		var cnt := 0
		for r: Dictionary in rows:
			if r.get(col) != null:
				cnt += 1
		return cnt

	var vals: Array = []
	for r: Dictionary in rows:
		var v = r.get(col)
		if v != null:
			vals.append(v)
	if vals.is_empty():
		return 0 if fn == "SUM" or fn == "AVG" else null

	if fn == "SUM" or fn == "AVG":
		var total := 0.0
		for v in vals:
			total += float(v)
		if fn == "SUM":
			return int(total) if is_equal_approx(total, roundf(total)) and vals.all(func(x): return x is int) else total
		return total / float(vals.size())

	if fn == "MIN":
		var best = vals[0]
		for v in vals:
			if _compare_vals(v, best) < 0:
				best = v
		return best

	if fn == "MAX":
		var best = vals[0]
		for v in vals:
			if _compare_vals(v, best) > 0:
				best = v
		return best
	return null


# =====================================================================
# WHERE Recursive Descent Evaluator
# =====================================================================
static func _eval_where(tokens: Array, row: Dictionary, tbl_cols: Array) -> Dictionary:
	var state := {"pos": 0}
	var res := _parse_or(tokens, state, row, tbl_cols)
	if not res["ok"]:
		return res
	if state["pos"] < tokens.size():
		return {"ok": false, "error": "Sintaks WHERE salah di dekat '%s'." % tokens[state["pos"]]["raw"]}
	return res


static func _parse_or(tokens: Array, st: Dictionary, row: Dictionary, tbl_cols: Array) -> Dictionary:
	var left := _parse_and(tokens, st, row, tbl_cols)
	if not left["ok"]:
		return left
	while st["pos"] < tokens.size() and tokens[st["pos"]]["type"] == "WORD" and tokens[st["pos"]]["val"] == "OR":
		st["pos"] += 1
		var right := _parse_and(tokens, st, row, tbl_cols)
		if not right["ok"]:
			return right
		left["match"] = bool(left["match"]) or bool(right["match"])
	return left


static func _parse_and(tokens: Array, st: Dictionary, row: Dictionary, tbl_cols: Array) -> Dictionary:
	var left := _parse_primary(tokens, st, row, tbl_cols)
	if not left["ok"]:
		return left
	while st["pos"] < tokens.size() and tokens[st["pos"]]["type"] == "WORD" and tokens[st["pos"]]["val"] == "AND":
		st["pos"] += 1
		var right := _parse_primary(tokens, st, row, tbl_cols)
		if not right["ok"]:
			return right
		left["match"] = bool(left["match"]) and bool(right["match"])
	return left


static func _parse_primary(tokens: Array, st: Dictionary, row: Dictionary, tbl_cols: Array) -> Dictionary:
	var pos: int = st["pos"]
	if pos >= tokens.size():
		return {"ok": false, "error": "Kondisi WHERE tidak lengkap."}

	if tokens[pos]["raw"] == "(":
		st["pos"] += 1
		var inner := _parse_or(tokens, st, row, tbl_cols)
		if not inner["ok"]:
			return inner
		if st["pos"] >= tokens.size() or tokens[st["pos"]]["raw"] != ")":
			return {"ok": false, "error": "Tanda kurung di klausa WHERE tidak seimbang."}
		st["pos"] += 1
		return inner

	if tokens[pos]["type"] != "WORD":
		return {"ok": false, "error": "Diharapkan nama kolom di WHERE, ditemukan '%s'." % tokens[pos]["raw"]}
	var col := str(tokens[pos]["raw"])
	if not col in tbl_cols:
		return {"ok": false, "error": "Kolom '%s' tidak ditemukan di klausa WHERE." % col}
	st["pos"] += 1
	pos = st["pos"]
	if pos >= tokens.size():
		return {"ok": false, "error": "Kondisi setelah kolom '%s' tidak lengkap." % col}

	var negate := false
	if tokens[pos]["type"] == "WORD" and tokens[pos]["val"] == "NOT":
		negate = true
		st["pos"] += 1
		pos = st["pos"]
		if pos >= tokens.size():
			return {"ok": false, "error": "Operator setelah NOT tidak lengkap."}

	var row_val = row.get(col)
	var tok: Dictionary = tokens[pos]

	# BETWEEN low AND high
	if tok["type"] == "WORD" and tok["val"] == "BETWEEN":
		if pos + 3 >= tokens.size() or tokens[pos + 2]["val"] != "AND":
			return {"ok": false, "error": "Sintaks BETWEEN salah (contoh: harga BETWEEN 10 AND 50)."}
		var lo = _token_literal(tokens[pos + 1])
		var hi = _token_literal(tokens[pos + 3])
		st["pos"] = pos + 4
		var m := row_val != null and _compare_vals(row_val, lo) >= 0 and _compare_vals(row_val, hi) <= 0
		return {"ok": true, "match": (not m) if negate else m}

	# IN (v1, v2, ...)
	if tok["type"] == "WORD" and tok["val"] == "IN":
		if pos + 1 >= tokens.size() or tokens[pos + 1]["raw"] != "(":
			return {"ok": false, "error": "Sintaks IN salah: gunakan IN (val1, val2)."}
		var close_i := _find_matching_paren(tokens, pos + 1)
		var val_parts := _split_comma_top(tokens.slice(pos + 2, close_i))
		if val_parts.is_empty():
			return {"ok": false, "error": "Daftar nilai pada IN (...) tidak boleh kosong."}
		var matched := false
		for vp: Array in val_parts:
			if vp.size() != 1:
				return {"ok": false, "error": "Nilai di dalam IN (...) tidak valid."}
			if _compare_vals(row_val, _token_literal(vp[0])) == 0:
				matched = true
		st["pos"] = close_i + 1
		return {"ok": true, "match": (not matched) if negate else matched}

	# LIKE pattern
	if tok["type"] == "WORD" and tok["val"] == "LIKE":
		if pos + 1 >= tokens.size():
			return {"ok": false, "error": "Pola LIKE tidak ditemukan."}
		var pat_str := str(_token_literal(tokens[pos + 1]))
		st["pos"] = pos + 2
		var m := _match_like(str(row_val), pat_str) if row_val != null else false
		return {"ok": true, "match": (not m) if negate else m}

	# Binary comparison (=, !=, <>, <, <=, >, >=)
	if tok["type"] == "OP" and not negate:
		if pos + 1 >= tokens.size():
			return {"ok": false, "error": "Nilai pembanding setelah '%s' tidak ditemukan." % tok["raw"]}
		var cmp_val = _token_literal(tokens[pos + 1])
		st["pos"] = pos + 2
		return {"ok": true, "match": _eval_op(str(tok["val"]), row_val, cmp_val)}

	return {"ok": false, "error": "Operator '%s' di klausa WHERE tidak valid." % tok["raw"]}


static func _eval_op(op: String, a, b) -> bool:
	if a == null or b == null:
		return false
	var c := _compare_vals(a, b)
	match op:
		"=":
			return c == 0
		"!=", "<>":
			return c != 0
		"<":
			return c < 0
		"<=":
			return c <= 0
		">":
			return c > 0
		">=":
			return c >= 0
	return false


static func _match_like(text: String, pattern: String) -> bool:
	var rx_src := "^"
	for i in pattern.length():
		var ch := pattern[i]
		if ch == "%":
			rx_src += ".*"
		elif ch == "_":
			rx_src += "."
		elif ch in [".", "^", "$", "*", "+", "?", "(", ")", "[", "]", "{", "}", "|", "\\"]:
			rx_src += "\\" + ch
		else:
			rx_src += ch
	rx_src += "$"
	var rx := RegEx.new()
	rx.compile("(?i)" + rx_src)
	return rx.search(text) != null


static func _compare_vals(a, b) -> int:
	if a == null and b == null:
		return 0
	if a == null:
		return -1
	if b == null:
		return 1
	if (a is int or a is float) and (b is int or b is float):
		var fa := float(a)
		var fb := float(b)
		if is_equal_approx(fa, fb):
			return 0
		return -1 if fa < fb else 1
	var sa := str(a)
	var sb := str(b)
	if sa == sb:
		return 0
	return -1 if sa < sb else 1


static func _token_literal(tok: Dictionary):
	if tok["type"] == "NUM":
		return tok["val"]
	if tok["type"] == "STR":
		return tok["val"]
	if tok["val"] == "NULL":
		return null
	if tok["val"] == "TRUE":
		return true
	if tok["val"] == "FALSE":
		return false
	return tok["raw"]


static func _find_kw(tokens: Array, kw: String, start: int = 0) -> int:
	var depth := 0
	for i in range(start, tokens.size()):
		var t: Dictionary = tokens[i]
		if t["raw"] == "(":
			depth += 1
		elif t["raw"] == ")":
			depth -= 1
		elif depth == 0 and t["type"] == "WORD" and t["val"] == kw:
			return i
	return -1


static func _find_sym(tokens: Array, sym: String, start: int = 0) -> int:
	for i in range(start, tokens.size()):
		if tokens[i]["type"] == "SYM" and tokens[i]["raw"] == sym:
			return i
	return -1


static func _find_matching_paren(tokens: Array, open_idx: int) -> int:
	var depth := 0
	for i in range(open_idx, tokens.size()):
		if tokens[i]["raw"] == "(":
			depth += 1
		elif tokens[i]["raw"] == ")":
			depth -= 1
			if depth == 0:
				return i
	return tokens.size() - 1


static func _split_comma_top(tokens: Array) -> Array:
	var out: Array = []
	var cur: Array = []
	var depth := 0
	for t: Dictionary in tokens:
		if t["raw"] == "(":
			depth += 1
		elif t["raw"] == ")":
			depth -= 1
		if depth == 0 and t["type"] == "SYM" and t["raw"] == ",":
			out.append(cur)
			cur = []
		else:
			cur.append(t)
	if not cur.is_empty():
		out.append(cur)
	return out
