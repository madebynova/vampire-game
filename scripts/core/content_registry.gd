extends Node
## Autoload: finds and indexes all ContentDef resources.
##   res://content/**            core content
##   user://mods/<mod>/content/** mod content (loaded after core; same id + same type = replaces)
## Content is looked up by (class name, id): ContentRegistry.get_def(&"FormData", &"vampire").

signal reloaded

const CORE_ROOT := "res://content"
const MOD_ROOT := "user://mods"

var _by_type: Dictionary = {}
var mods: PackedStringArray = PackedStringArray()


func _ready() -> void:
	reload()


func reload() -> void:
	_by_type.clear()
	mods = PackedStringArray()
	_scan(CORE_ROOT, "core")
	var dir := DirAccess.open(MOD_ROOT)
	if dir != null:
		for mod_name in dir.get_directories():
			mods.append(mod_name)
			_scan("%s/%s/content" % [MOD_ROOT, mod_name], mod_name)
	reloaded.emit()


func get_def(type: StringName, id: StringName) -> Resource:
	var bucket: Dictionary = _by_type.get(type, {})
	return bucket.get(id)


## All definitions of a class ("FormData", "NpcProfile", ...), in id order.
func list(type: StringName) -> Array:
	var bucket: Dictionary = _by_type.get(type, {})
	var ids := bucket.keys()
	ids.sort()
	var out: Array = []
	for i in ids:
		out.append(bucket[i])
	return out


func form(id: StringName) -> FormData:
	return get_def(&"FormData", id) as FormData


func npc(id: StringName) -> NpcProfile:
	return get_def(&"NpcProfile", id) as NpcProfile


func _scan(path: String, source: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan("%s/%s" % [path, sub], source)
	for file in dir.get_files():
		# Exported builds list resources as "name.tres.remap".
		var f := file.trim_suffix(".remap")
		if not (f.ends_with(".tres") or f.ends_with(".res")):
			continue
		_register("%s/%s" % [path, f], source)


func _register(path: String, source: String) -> void:
	var res := ResourceLoader.load(path)
	if res == null or not (res is ContentDef):
		return
	var def := res as ContentDef
	if def.id == &"":
		push_warning("ContentRegistry: %s has no id, skipped" % path)
		return
	var type: StringName = def.get_script().get_global_name()
	if not _by_type.has(type):
		_by_type[type] = {}
	var bucket: Dictionary = _by_type[type]
	if bucket.has(def.id):
		print("ContentRegistry: %s '%s' replaced by %s" % [type, def.id, source])
	def.source = source
	bucket[def.id] = def
