extends Control
## SQL Sandbox dev harness + 25-case automated test suite for QueryEngine & QueryJudge.

const QueryEngineScript := preload("res://scripts/sql/query_engine.gd")
const QueryJudgeScript := preload("res://scripts/sql/query_judge.gd")

const SAMPLE_DB := {
	"tables": {
		"produk": {
			"columns": [
				{"name": "id", "type": "INT"},
				{"name": "nama", "type": "VARCHAR"},
				{"name": "kategori", "type": "VARCHAR"},
				{"name": "harga", "type": "INT"},
				{"name": "stok", "type": "INT"},
			],
			"rows": [
				{"id": 1, "nama": "Pedang Besi", "kategori": "senjata", "harga": 30, "stok": 4},
				{"id": 2, "nama": "Ramuan Merah", "kategori": "ramuan", "harga": 10, "stok": 12},
				{"id": 3, "nama": "Kunci Emas", "kategori": "kunci", "harga": 25, "stok": 3},
				{"id": 4, "nama": "Pedang Kristal", "kategori": "senjata", "harga": 80, "stok": 1},
				{"id": 5, "nama": "Ramuan Biru", "kategori": "ramuan", "harga": 15, "stok": 8},
			]
		}
	},
	"permissions": {"pemain": {"*": ["ALL"]}}
}

@onready var query_edit: TextEdit = $Panel/Margin/VBox/QueryEdit
@onready var result_label: RichTextLabel = $Panel/Margin/VBox/ResultLabel


func _ready() -> void:
	if $Panel/Margin/VBox/BtnRow/RunBtn:
		$Panel/Margin/VBox/BtnRow/RunBtn.pressed.connect(_on_run_pressed)
	if $Panel/Margin/VBox/BtnRow/TestSuiteBtn:
		$Panel/Margin/VBox/BtnRow/TestSuiteBtn.pressed.connect(_on_suite_pressed)


func _on_run_pressed() -> void:
	var res: Dictionary = QueryEngineScript.execute(query_edit.text, SAMPLE_DB)
	if not res["ok"]:
		result_label.text = "[ERROR] %s" % res["error"]
		return
	var lines: Array[String] = ["OK (%s) | Kolom: %s" % [res["last_op"], ", ".join(res["columns"])]]
	for r: Dictionary in res["rows"]:
		lines.append(str(r))
	result_label.text = "\n".join(lines)


func _on_suite_pressed() -> void:
	var rep := run_test_suite()
	result_label.text = "\n".join(rep["lines"])


static func run_test_suite() -> Dictionary:
	var lines: Array[String] = []
	var passed := 0
	var cases := _build_25_cases()
	for i in cases.size():
		var c: Dictionary = cases[i]
		var db: Dictionary = c.get("db", SAMPLE_DB)
		var res: Dictionary = QueryEngineScript.execute(str(c["sql"]), db)
		var ok := false
		var detail := ""
		match str(c["expect"]):
			"error":
				ok = not res["ok"]
				detail = "got_err='%s'" % res["error"] if ok else "unexpectedly succeeded"
			"wrong_select":
				var jr: Dictionary = QueryJudgeScript.judge_select(res, c["exp_cols"], c["exp_rows"], bool(c.get("order", false)))
				ok = res["ok"] and not jr["ok"]
				detail = "detected_mismatch='%s'" % jr["error"] if ok else "failed to detect wrong result"
			"select_ok":
				var jr: Dictionary = QueryJudgeScript.judge_select(res, c["exp_cols"], c["exp_rows"], bool(c.get("order", false)))
				ok = res["ok"] and jr["ok"]
				detail = "rows=%d" % res["rows"].size() if ok else "err='%s' judge='%s'" % [res["error"], jr["error"]]
			"cond_ok":
				var jc: Dictionary = QueryJudgeScript.judge_terminal(res, c["conditions"])
				ok = res["ok"] and jc["ok"]
				detail = "conditions=%d" % c["conditions"].size() if ok else "err='%s' judge='%s'" % [res["error"], jc["error"]]
		if ok:
			passed += 1
		lines.append("%s [%02d/25] %s (%s)" % ["PASS" if ok else "FAIL", i + 1, str(c["name"]), detail])
	return {"passed": passed, "total": cases.size(), "all_pass": passed == cases.size(), "lines": lines}


static func _build_25_cases() -> Array:
	return [
		# 1-14: Valid SELECT + WHERE + Aggregates + ORDER BY + LIMIT
		{
			"name": "SELECT semua kolom *",
			"sql": "SELECT * FROM produk;",
			"expect": "select_ok",
			"exp_cols": ["id", "nama", "kategori", "harga", "stok"],
			"exp_rows": SAMPLE_DB["tables"]["produk"]["rows"],
		},
		{
			"name": "SELECT beberapa kolom + WHERE =",
			"sql": "SELECT nama, harga FROM produk WHERE kategori = 'kunci';",
			"expect": "select_ok",
			"exp_cols": ["nama", "harga"],
			"exp_rows": [{"nama": "Kunci Emas", "harga": 25}],
		},
		{
			"name": "WHERE != dan >=",
			"sql": "SELECT nama FROM produk WHERE kategori != 'ramuan' AND harga >= 30;",
			"expect": "select_ok",
			"exp_cols": ["nama"],
			"exp_rows": [{"nama": "Pedang Besi"}, {"nama": "Pedang Kristal"}],
		},
		{
			"name": "WHERE dengan AND dan OR",
			"sql": "SELECT id FROM produk WHERE kategori = 'kunci' OR (kategori = 'ramuan' AND harga < 12);",
			"expect": "select_ok",
			"exp_cols": ["id"],
			"exp_rows": [{"id": 2}, {"id": 3}],
		},
		{
			"name": "WHERE LIKE wildcard %",
			"sql": "SELECT nama FROM produk WHERE nama LIKE 'Pedang%';",
			"expect": "select_ok",
			"exp_cols": ["nama"],
			"exp_rows": [{"nama": "Pedang Besi"}, {"nama": "Pedang Kristal"}],
		},
		{
			"name": "WHERE BETWEEN ... AND ...",
			"sql": "SELECT id, nama FROM produk WHERE harga BETWEEN 15 AND 30;",
			"expect": "select_ok",
			"exp_cols": ["id", "nama"],
			"exp_rows": [{"id": 1, "nama": "Pedang Besi"}, {"id": 3, "nama": "Kunci Emas"}, {"id": 5, "nama": "Ramuan Biru"}],
		},
		{
			"name": "WHERE IN (...)",
			"sql": "SELECT id FROM produk WHERE id IN (2, 4, 99);",
			"expect": "select_ok",
			"exp_cols": ["id"],
			"exp_rows": [{"id": 2}, {"id": 4}],
		},
		{
			"name": "ORDER BY ASC + LIMIT",
			"sql": "SELECT id, harga FROM produk ORDER BY harga ASC LIMIT 2;",
			"expect": "select_ok",
			"exp_cols": ["id", "harga"],
			"exp_rows": [{"id": 2, "harga": 10}, {"id": 5, "harga": 15}],
			"order": true,
		},
		{
			"name": "ORDER BY DESC + LIMIT",
			"sql": "SELECT id FROM produk WHERE kategori = 'senjata' ORDER BY harga DESC LIMIT 1;",
			"expect": "select_ok",
			"exp_cols": ["id"],
			"exp_rows": [{"id": 4}],
			"order": true,
		},
		{
			"name": "Agregat COUNT(*)",
			"sql": "SELECT COUNT(*) FROM produk WHERE kategori = 'ramuan';",
			"expect": "select_ok",
			"exp_cols": ["COUNT(*)"],
			"exp_rows": [{"COUNT(*)": 2}],
		},
		{
			"name": "Agregat SUM(harga) & AVG(harga)",
			"sql": "SELECT SUM(harga), AVG(harga) FROM produk WHERE kategori = 'ramuan';",
			"expect": "select_ok",
			"exp_cols": ["SUM(harga)", "AVG(harga)"],
			"exp_rows": [{"SUM(harga)": 25, "AVG(harga)": 12.5}],
		},
		{
			"name": "Agregat MIN(harga) & MAX(harga)",
			"sql": "SELECT MIN(harga), MAX(harga) FROM produk;",
			"expect": "select_ok",
			"exp_cols": ["MIN(harga)", "MAX(harga)"],
			"exp_rows": [{"MIN(harga)": 10, "MAX(harga)": 80}],
		},
		# 13-17: Valid DDL / DML / DCL state mutations
		{
			"name": "DDL CREATE TABLE + DML INSERT INTO",
			"sql": "CREATE TABLE kotak (ukuran VARCHAR, warna VARCHAR); INSERT INTO kotak (ukuran, warna) VALUES ('besar', 'merah');",
			"db": {"tables": {}, "permissions": {"pemain": {"*": ["ALL"]}}},
			"expect": "cond_ok",
			"conditions": [
				{"type": "table_exists", "table": "kotak"},
				{"type": "columns", "table": "kotak", "columns": ["ukuran", "warna"]},
				{"type": "row", "table": "kotak", "row": {"ukuran": "besar", "warna": "merah"}},
			],
		},
		{
			"name": "DDL ALTER TABLE ADD",
			"sql": "ALTER TABLE produk ADD asal VARCHAR;",
			"expect": "cond_ok",
			"conditions": [
				{"type": "columns", "table": "produk", "columns": ["id", "nama", "asal"]},
				{"type": "column_type", "table": "produk", "column": "asal", "value": "VARCHAR"},
			],
		},
		{
			"name": "DML UPDATE SET WHERE",
			"sql": "UPDATE produk SET harga = 99 WHERE id = 2;",
			"expect": "cond_ok",
			"conditions": [
				{"type": "row", "table": "produk", "row": {"id": 2, "harga": 99}},
				{"type": "no_row", "table": "produk", "row": {"id": 2, "harga": 10}},
			],
		},
		{
			"name": "DML DELETE FROM WHERE",
			"sql": "DELETE FROM produk WHERE kategori = 'ramuan';",
			"expect": "cond_ok",
			"conditions": [
				{"type": "no_row", "table": "produk", "row": {"kategori": "ramuan"}},
				{"type": "row_count", "table": "produk", "count": 3},
			],
		},
		{
			"name": "DCL REVOKE & GRANT",
			"sql": "REVOKE ALL ON tabung FROM boss; GRANT INSERT, SELECT ON tabung TO pemain;",
			"db": {
				"tables": {"tabung": {"columns": [{"name": "ukuran", "type": "VARCHAR"}], "rows": []}},
				"permissions": {"boss": {"tabung": ["ALL"]}, "pemain": {"tabung": []}},
			},
			"expect": "cond_ok",
			"conditions": [
				{"type": "no_permissions", "user": "boss", "table": "tabung", "privs": ["ALL"]},
				{"type": "permissions", "user": "pemain", "table": "tabung", "privs": ["INSERT", "SELECT"]},
			],
		},
		# 18-20: Wrong-result judge tests
		{
			"name": "Salah hasil: jumlah baris tidak cocok",
			"sql": "SELECT nama FROM produk;",
			"expect": "wrong_select",
			"exp_cols": ["nama"],
			"exp_rows": [{"nama": "Kunci Emas"}],
		},
		{
			"name": "Salah hasil: urutan ORDER BY terbalik",
			"sql": "SELECT id FROM produk WHERE kategori = 'ramuan' ORDER BY id DESC;",
			"expect": "wrong_select",
			"exp_cols": ["id"],
			"exp_rows": [{"id": 2}, {"id": 5}],
			"order": true,
		},
		{
			"name": "Salah hasil: nama kolom berbeda",
			"sql": "SELECT nama FROM produk WHERE id = 1;",
			"expect": "wrong_select",
			"exp_cols": ["kategori"],
			"exp_rows": [{"kategori": "senjata"}],
		},
		# 21-25: Syntax errors & invalid queries rejected in Indonesian
		{
			"name": "Syntax error: query kosong",
			"sql": "   ",
			"expect": "error",
		},
		{
			"name": "Syntax error: tabel tidak ada",
			"sql": "SELECT * FROM tabel_hantu;",
			"expect": "error",
		},
		{
			"name": "Syntax error: kolom tidak dikenal",
			"sql": "SELECT warna_ajaib FROM produk;",
			"expect": "error",
		},
		{
			"name": "Syntax error: tanda kutip belum ditutup",
			"sql": "SELECT nama FROM produk WHERE kategori = 'kunci;",
			"expect": "error",
		},
		{
			"name": "Syntax error: klausa JOIN tidak didukung",
			"sql": "SELECT * FROM produk JOIN lain;",
			"expect": "error",
		},
	]
