class_name Dialogue
extends RefCounted
## Builds each visit's conversation from the customer's text file in
## res://data/dialogue/<customer id>.txt (format: data/dialogue/README.md):
## a random [opener], hint lines for HINTS_PER_VISIT of the recipe's ingredients
## (random ones, random wording) with a shrimp [followup] between them, then an
## optional [closer].

const DIR := "res://data/dialogue/"
## Default shrimp lines (its [followup] is used when a customer has none).
const SHARED_FILE := "_shrimp"
const HINTS_PER_VISIT := 2
const SPECIAL_SECTIONS := ["opener", "followup", "closer"]

## customer id -> parsed file (see parse()).
static var _cache: Dictionary = {}


## The whole conversation for one visit, one line per row ("shrimp: " rows are
## the shrimp's), ready for Main to play.
static func build(customer: CustomerData, required: PackedStringArray) -> String:
	var data := load_file(customer.id)
	var sections: Dictionary = data.sections
	var rows: PackedStringArray = []
	rows.append_array(_pick(sections.get("opener", [])))
	if not customer.hidden_recipe:
		var followups: Array = sections.get("followup", [])
		if followups.is_empty():
			followups = load_file(SHARED_FILE).sections.get("followup", [])
		var hinted := pick_hinted(customer, required)
		for i in hinted.size():
			if i > 0:
				rows.append_array(_pick(followups))
			rows.append_array(_pick(sections.get(hinted[i], [])))
	rows.append_array(_pick(sections.get("closer", [])))
	if rows.is_empty():
		rows.append("...")
	return "\n".join(rows)


## Which ingredients get hinted this visit: HINTS_PER_VISIT random ones from the
## recipe, never the customer's signature, and only ones that have hint lines.
static func pick_hinted(customer: CustomerData, required: PackedStringArray) -> PackedStringArray:
	var data := load_file(customer.id)
	var signature: String = data.settings.get("signature", "")
	var pool: Array = []
	for id in required:
		if id != signature and data.sections.has(id):
			pool.append(id)
	pool.shuffle()
	return PackedStringArray(pool.slice(0, HINTS_PER_VISIT))


## { "settings": { "signature": "sugar" }, "sections": { "opener": [option, ...] } }
## where each option is a PackedStringArray of rows. Empty if the file is missing.
static func load_file(id: String) -> Dictionary:
	if not _cache.has(id):
		var path := DIR + id + ".txt"
		var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		_cache[id] = parse(text)
	return _cache[id]


static func has_file(id: String) -> bool:
	return FileAccess.file_exists(DIR + id + ".txt")


static func parse(text: String) -> Dictionary:
	var settings := {}
	var sections := {}
	var section := ""
	var option: PackedStringArray = []
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			_add_option(sections, section, option)
			option = []
			section = line.substr(1, line.length() - 2).strip_edges().to_lower()
			if not sections.has(section):
				sections[section] = []
			continue
		if line == "---":
			_add_option(sections, section, option)
			option = []
			continue
		if section.is_empty():
			# Settings go above the first section: "key: value".
			var colon := line.find(":")
			if colon > 0:
				settings[line.left(colon).strip_edges().to_lower()] = line.substr(colon + 1).strip_edges()
			continue
		option.append(line)
	_add_option(sections, section, option)
	return {"settings": settings, "sections": sections}


## Problems worth a warning at startup (typos, missing hints...). Empty = all good.
static func problems(customer: CustomerData) -> PackedStringArray:
	var out: PackedStringArray = []
	if not has_file(customer.id):
		out.append("no dialogue file (expected %s%s.txt)" % [DIR, customer.id])
		return out
	var data := load_file(customer.id)
	var sections: Dictionary = data.sections
	if (sections.get("opener", []) as Array).is_empty():
		out.append("no [opener] lines")
	for name: String in sections:
		if name not in SPECIAL_SECTIONS and Database.ingredient(name) == null:
			out.append("[%s] isn't an ingredient id or opener/followup/closer (typo?)" % name)
		elif name not in SPECIAL_SECTIONS and not customer.hidden_recipe and name not in customer.required:
			out.append("[%s] has hints but isn't in the recipe, so it's never used" % name)
	if customer.hidden_recipe:
		return out
	var signature: String = data.settings.get("signature", "")
	if not signature.is_empty() and signature not in customer.required:
		out.append("signature '%s' isn't in the recipe" % signature)
	for id in customer.required:
		if id != signature and (sections.get(id, []) as Array).is_empty():
			out.append("no hint lines for [%s]" % id)
	return out


static func _add_option(sections: Dictionary, section: String, option: PackedStringArray) -> void:
	if section.is_empty() or option.is_empty():
		return
	(sections[section] as Array).append(option)


static func _pick(options: Array) -> PackedStringArray:
	if options.is_empty():
		return PackedStringArray()
	return options[randi() % options.size()]
