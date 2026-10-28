extends RefCounted
## Explicit owner-managed native bank root. Never copies media or grants rights.
const BANKS := ["pc-recorded-effects-v1","pc-world-effects-v1","pc-environment-effects-v1",
	"pc-soviet-effects-v1","pc-t72-effects-v1","pc-tank-fallback-v1",
	"pc-allied-effects-v1","pc-world-detail-v1","pc-missile-flight-v1",
	"pc-supplemental-effects-v1","pc-rocket-effects-v1"]

static func root_directory() -> String:
	if OS.has_feature("web"): return ""
	return select_root(OS.get_environment("ABRAMS_AUDIO_ROOT"),ProjectSettings.globalize_path("res://"),false)

static func select_root(override: String, project: String, web: bool) -> String:
	# Working if: Web cannot read it, explicit invalid/missing roots stay silent,
	# and unset overrides retain checkout behaviour without cwd/fallback search.
	if web: return ""
	if override.is_empty(): return project.trim_suffix("/").get_base_dir().path_join("local-audio")
	if not override.is_absolute_path() or "://" in override or override.begins_with("~"): return ""
	for at: int in override.length():
		if override.unicode_at(at)<32 or override.unicode_at(at)==127: return ""
	if not DirAccess.dir_exists_absolute(override): return ""
	return override

static func bank_directory(root: String, bank: String) -> String:
	if root.is_empty() or bank not in BANKS: return ""
	return root.path_join(bank)
