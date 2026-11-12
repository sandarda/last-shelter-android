#!/usr/bin/env python3
"""Static integrity checks for the Last Shelter Godot prototype.
Does not replace opening/running the project in Godot.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
notes = []

def require(condition, message):
    (notes if condition else errors).append(("OK" if condition else "ERROR", message))

project = ROOT / "project.godot"
scene = ROOT / "scenes/main.tscn"
script = ROOT / "scripts/game.gd"
require(project.is_file(), "project.godot exists")
require(scene.is_file(), "main scene exists")
require(script.is_file(), "main GDScript exists")

if project.exists():
    p = project.read_text(encoding="utf-8")
    require('run/main_scene="res://scenes/main.tscn"' in p, "main scene path matches project settings")
    require('config/name="Последнее убежище"' in p, "project title is configured")
if scene.exists():
    s = scene.read_text(encoding="utf-8")
    require('res://scripts/game.gd' in s, "main scene references game.gd")
if script.exists():
    g = script.read_text(encoding="utf-8")
    required_functions = ["_ready", "_process", "_draw", "_save_game", "_load_game",
                          "_use_stairs_up", "_use_stairs_down", "_validate_room_connectivity"]
    for fn in required_functions:
        require(re.search(r"^func\s+" + re.escape(fn) + r"\s*\(", g, re.M) is not None,
                f"required function {fn} exists")
    # Check declared room identifiers and graph links for each floor.
    expected = {"guest1", "arsenal", "guest2", "bedroom", "living", "kitchen", "workshop", "storage"}
    found = set(re.findall(r'\{"id":"([a-z0-9_]+)"', g))
    require(expected.issubset(found), "all eight planned rooms are declared")
    require('"links"' in g and '"rooms"' in g, "room connectivity data is present")
    require('SAVE_PATH := "user://last_shelter_save.cfg"' in g, "save path uses Godot user data")

concept = ROOT / "art/reference/cliffside_shelter_concept.png"
require(concept.is_file() and concept.stat().st_size > 100_000, "cliffside concept reference is included")
for room_id in ["bedroom", "living", "kitchen", "workshop", "storage", "arsenal", "guest1", "guest2"]:
    asset = ROOT / "art/rooms" / f"{room_id}.png"
    require(asset.is_file() and asset.stat().st_size > 5_000, f"illustrated room asset exists: {room_id}")
survivor = ROOT / "art/characters/survivor_sheet.png"
require(survivor.is_file() and survivor.stat().st_size > 2_000, "animated survivor sprite sheet exists")
if script.exists():
    g = script.read_text(encoding="utf-8")
    require("_load_art_assets" in g and "draw_texture_rect(room_textures" in g, "room illustrations are loaded and rendered")
    require("_update_facing" in g and "animation_frame" in g, "survivor directional walk animation is wired")
    require("_try_furniture_interaction" in g and "_interact_with_furniture" in g, "furniture hotspots trigger contextual interactions")
    require("_try_stair_navigation" in g and "pending_stair_floor" in g, "stairwell tap navigation is implemented")
    require("target_pos = Vector2(640.0, 555.0)" in g and "_change_floor(pending_stair_floor)" in g, "stair navigation walks to landing before floor change")

# v0.20 feature wiring checks (static only)
if script.exists():
    g = script.read_text(encoding="utf-8")
    for fn in ["_walkable_rectangles", "_can_stand_at", "_craft_medkit", "_use_medkit"]:
        require(re.search(r"^func\s+" + re.escape(fn) + r"\s*\(", g, re.M) is not None,
                f"v0.20 function {fn} exists")
    require("if _can_stand_at(axis_candidate)" in g, "movement checks room/corridor collision geometry")
    require("ProgressBar.new()" in g and "needs_bars" in g, "survival meters are displayed as progress bars")
    require('cfg.set_value("inventory", "medkits", medkits)' in g, "medkits are persisted in saves")
    require('medkits = maxi(medkits, 0)' in g, "loaded inventory values are sanitized")
    require("ПРОРЫВ!" in g, "breached shelter has a player health consequence")

# v0.21 ten-stage feature checks (static only)
if script.exists():
    g = script.read_text(encoding="utf-8")
    for fn in ["_fish", "_scavenge", "_purify_water", "_upgrade_barricades", "_journal_update"]:
        require(re.search(r"^func\s+" + re.escape(fn) + r"\s*\(", g, re.M) is not None,
                f"v0.21 gameplay action {fn} exists")
    require('weather = ["ЯСНО", "ТУМАН", "ДОЖДЬ", "ВЕТЕР"]' in g, "daily weather variation exists")
    require('night_strength' in g and 'weather == "ТУМАН"' in g and 'weather == "ДОЖДЬ"' in g, "day/night and weather visuals are wired")
    require('noise_level' in g and 'Шум:' in g, "noise attracts threats and is shown in HUD")
    require('purified_water' in g and 'Очистить воду' in g, "water purification and clean-water inventory exist")
    require('barricade_level' in g and 'Улучшить баррикады' in g, "barricade upgrade progression exists")
    require('journal_step' in g and 'Записать в журнал' in g, "survivor journal progression exists")
    require('morale' in g and 'Боевой дух' in g, "morale stat is implemented")
    require('cfg.set_value("world", "weather", weather)' in g and 'cfg.set_value("world", "journal_step", journal_step)' in g, "new survival systems are saved")

# v0.22 ten-stage island-survival systems (static wiring only)
if script.exists():
    g = script.read_text(encoding="utf-8")
    v022_functions = ["_explore_island", "_forage", "_tend_garden", "_craft_spear", "_hunt", "_collect_rainwater", "_use_radio", "_upgrade_workshop", "_treat_injury", "_process_salvage"]
    for fn in v022_functions:
        require(re.search(r"^func\s+" + re.escape(fn) + r"\s*\(", g, re.M) is not None, f"v0.22 system {fn} exists")
    require('cfg.set_value("island", "location", island_location)' in g, "island location is persisted")
    require('cfg.set_value("island", "garden_progress", garden_progress)' in g, "garden progression is persisted")
    require('cfg.set_value("island", "spear_durability", spear_durability)' in g, "weapon durability is persisted")
    require('cfg.set_value("island", "radio_battery", radio_battery)' in g, "radio batteries are persisted")
    require('inventory_label.text = "Дерево %d' in g and 'Ягоды %d' in g, "new resources are visible in inventory HUD")

# v0.23 Android build preparation checks
preset = ROOT / "export_presets.cfg"
workflow = ROOT / ".github/workflows/main.yml"
icon = ROOT / "art/app_icon.png"
build_doc = ROOT / "docs/ANDROID_BUILD.md"
require(preset.is_file() and 'name="Android"' in preset.read_text(encoding="utf-8"), "Android export preset exists")
require(preset.is_file() and 'architectures/arm64-v8a=true' in preset.read_text(encoding="utf-8"), "Android preset targets ARM64")
require(workflow.is_file() and 'godot --headless --path . --export-debug "Android"' in workflow.read_text(encoding="utf-8"), "GitHub Actions Android export workflow exists")
require(icon.is_file() and icon.stat().st_size > 1000, "application icon asset exists")
require(build_doc.is_file() and "GitHub build" in build_doc.read_text(encoding="utf-8"), "Android build instructions exist")
if project.exists():
    ptxt = project.read_text(encoding="utf-8")
    require('window/handheld/orientation=4' in ptxt, "mobile landscape orientation configured")
    require('window/stretch/aspect="expand"' in ptxt, "responsive canvas stretch configured")
if script.exists():
    g = script.read_text(encoding="utf-8")
    require("AUTOSAVE_INTERVAL := 60.0" in g and "_save_game_silent()" in g, "periodic autosave is wired")
    require("NOTIFICATION_APPLICATION_PAUSED" in g and "NOTIFICATION_APPLICATION_RESUMED" in g, "mobile pause/resume lifecycle is handled")

print("LAST SHELTER — STATIC PROJECT CHECK")
for status, message in notes + errors:
    print(f"[{status}] {message}")
print(f"\n{len(notes)} passed, {len(errors)} failed")
if errors:
    sys.exit(1)
print("NOTE: Static checks do not validate GDScript parsing, runtime behavior, rendering, or Android export.")

