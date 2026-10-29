class_name WordRules
extends RefCounted

## Surface forms are authored per link, never guessed by removing arbitrary
## Turkish suffixes. This keeps bardağı → bardak and kaşığı → kaşık unambiguous.
static func form(level: Dictionary, index: int) -> String:
	if level.has("forms") and index < level.forms.size():
		return str(level.forms[index])
	return str(level.words[index])

static func typed(value: String) -> String:
	return GameState.upper_tr(value).replace("’", "'")

static func candidates(value: String, stem: String, surface: String, revealed: Array = [0]) -> Array:
	var raw = typed(value)
	if raw.is_empty(): return []
	if " " in raw:
		# A whole phrase is accepted only by matches(), not by its last token.
		return [raw]
	var possible: Array = [raw, surface[0] + raw]
	for target in [surface,stem]:
		var built = ""
		var used = 0
		for i in range(target.length()):
			if i in revealed:
				built += target[i]
			elif used < raw.length():
				built += raw[used]
				used += 1
		if used == raw.length(): possible.append(built)
	return possible

static func matches(value: String, level: Dictionary, index: int, revealed: Array = [0]) -> bool:
	var stem = str(level.words[index])
	var surface = form(level,index)
	var raw = typed(value)
	if raw == GameState.upper_tr(str(level.links[index-1])): return true
	for candidate in candidates(value,stem,surface,revealed):
		if candidate == stem or candidate == surface: return true
	return false

static func display(value: String, surface: String, revealed: Array) -> String:
	var raw = typed(value)
	if " " in raw: raw = raw.get_slice(" ",raw.get_slice_count(" ")-1)
	var expanded = raw if raw.begins_with(surface[0]) else surface[0] + raw
	var out = ""
	for i in range(surface.length()):
		out += surface[i] if i in revealed else expanded[i] if i < expanded.length() else " "
	return out
