class_name WordRules
extends RefCounted

## Rendering and acceptance consume this same resolved tile state. A hint
## cannot hide an error on screen while a different raw string is rejected.
static func form(level: Dictionary, index: int) -> String:
	if level.has("forms") and index < level.forms.size():
		return str(level.forms[index])
	return str(level.words[index])

static func typed(value: String) -> String:
	return GameState.upper_tr(value).replace("’", "'").replace("\u0307", "").replace("\u200b", "").replace("\ufeff", "")

static func comparable(value: String) -> String:
	# Device keyboards can send i/ı or decomposed dotted I. These variations
	# must not reject the single authored answer; other letters remain exact.
	return typed(value).replace("İ", "I")

static func same(a: String, b: String) -> bool:
	return comparable(a) == comparable(b)

static func resolve_surface(value: String, surface: String, revealed: Array) -> Dictionary:
	var raw = typed(value)
	var locked: Array = [0]
	for at in revealed:
		var i = int(at)
		if i >= 0 and i < surface.length() and not i in locked: locked.append(i)
	var editable: Array = []
	for i in range(surface.length()):
		if not i in locked: editable.append(i)
	if editable.is_empty(): return {"letters":surface,"accepted":true,"reason":""}
	var letters = []
	for i in range(surface.length()): letters.append(surface[i] if i in locked else " ")
	var input = raw
	# Both a full answer/rest of word and just the still-empty cells work.
	var compact = input.length() <= editable.size()
	if input.length() == editable.size()+1 and same(input.substr(0,1),surface[0]):
		input = input.substr(1)
		compact = true
	var overflow = false
	if compact:
		for j in range(mini(input.length(),editable.size())): letters[editable[j]] = input[j]
	else:
		var expanded = raw if same(raw.substr(0,1),surface[0]) else surface[0]+raw
		overflow = expanded.length() > surface.length()
		for i in editable:
			if i < expanded.length(): letters[i] = expanded[i]
	if overflow:
		# Never truncate an invisible extra letter and display a false success.
		letters[editable.back()] = "…"
	var shown = "".join(letters)
	var accepted = not overflow and same(shown,surface)
	return {"letters":surface if accepted else shown,"accepted":accepted,
		"reason":"overflow" if overflow else "incomplete" if " " in shown else "wrong"}

static func resolve(value: String, level: Dictionary, index: int, revealed: Array = [0]) -> Dictionary:
	var surface = form(level,index)
	var raw = typed(value)
	var stem = str(level.words[index])
	if not raw.is_empty() and (same(raw,surface) or same(raw,stem) or same(raw,surface.substr(1)) or same(raw,stem.substr(1)) or same(raw,str(level.links[index-1]))):
		return {"letters":surface,"accepted":true,"reason":""}
	var result = resolve_surface(raw,surface,revealed)
	if not result.accepted and " " in raw:
		result.reason = "phrase"
	return result

static func matches(value: String, level: Dictionary, index: int, revealed: Array = [0]) -> bool:
	return bool(resolve(value,level,index,revealed).accepted)

static func display(value: String, surface: String, revealed: Array) -> String:
	return str(resolve_surface(value,surface,revealed).letters)
