import sys

# === 1. building_data.gd ===
path = "E:/ClaudeProjects/three-against-one/scripts/building_data.gd"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

old_func = (
    'static func barracks_lv1() -> BuildingData:\n'
    '\tvar b := BuildingData.new(\n'
    '\t\t"兵营", BuildingCategory.RECRUITMENT, Vector2i(1, 1),\n'
    '\t\t0, 40, 25, 0, 10,\n'
    '\t\t8, {},\n'
    '\t\t[TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,\n'
    '\t\t TerrainData.Terrain.GLADE_ELF, TerrainData.Terrain.WASTELAND_ORC],\n'
    '\t\t99, "Lv1 可招募守卫、斥候"\n'
    '\t)\n'
    '\tb.tech_tier = 1\n'
    '\tb.garrison_capacity = 2\n'
    '\tb.tags = ["recruit", "military", "barracks"]\n'
    '\treturn b\n\n'
)
if old_func in content:
    content = content.replace(old_func, "")
    print("1a: removed barracks_lv1() function")
else:
    print("1a: WARNING - barracks_lv1() function not found")

content = content.replace(
    "BuildingCategory.RECRUITMENT: [recruit_camp(), barracks_lv1()],",
    "BuildingCategory.RECRUITMENT: [recruit_camp()],"
)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("1b: removed barracks_lv1() from template list")

# === 2. default_template_library.gd ===
path = "E:/ClaudeProjects/three-against-one/scripts/templates/default_template_library.gd"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace(
    'recruit_camp.recruit_options = [unit_templates["unit.worker"]]',
    'recruit_camp.recruit_options = [unit_templates["unit.worker"], unit_templates["unit.guard"], unit_templates["unit.scout"]]'
)

old_barracks = (
    '\tvar barracks = BuildingTemplateScript.new()\n'
    '\tbarracks.id = "building.barracks_lv1"\n'
    '\tbarracks.display_name = "兵营"\n'
    '\tbarracks.role = BuildingTemplateScript.BuildingRole.MILITARY\n'
    '\tbarracks.hp_max = 8\n'
    '\tbarracks.build_cost = [_amount("gold", 100), _amount("wood", 50), _amount("stone", 30)]\n'
    '\tbarracks.max_per_faction = 99\n'
    '\tbarracks.recruit_options = [unit_templates["unit.guard"], unit_templates["unit.scout"]]\n'
    '\tbarracks.tags = ["military", "recruit"]\n\n'
)
if old_barracks in content:
    content = content.replace(old_barracks, "")
    print("2a: removed barracks template")
else:
    print("2a: WARNING - barracks template not found")

content = content.replace('\t\t\tbarracks.id: barracks,\n', '')

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("2b: updated recruit_camp options, removed barracks from return dict")

# === 3. building_rules.gd ===
path = "E:/ClaudeProjects/three-against-one/scripts/rules/building_rules.gd"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace(
    '\tconst TEMPLATE_BARRACKS_LV1 := "building.barracks_lv1"\n',
    ''
)
print("3a: removed TEMPLATE_BARRACKS_LV1")

# Replace recruit_camp branch to include combat units
old_recruit_branch = '\tif "recruit_camp" in data.tags:\n\t\treturn ["%s.worker" % prefix]\n'
new_recruit_branch = (
    '\tif "recruit_camp" in data.tags:\n'
    '\t\tvar result: Array = ["%s.worker" % prefix]\n'
    '\t\tmatch faction:\n'
    '\t\t\t0:\n'
    '\t\t\t\tresult += ["%s.guard" % prefix, "%s.scout" % prefix, "%s.ranger" % prefix, "%s.blade_dancer" % prefix, "%s.root_guard" % prefix]\n'
    '\t\t\t1:\n'
    '\t\t\t\tresult += ["%s.guard" % prefix, "%s.scout" % prefix, "%s.shieldbearer" % prefix, "%s.crossbow" % prefix, "%s.sapper" % prefix]\n'
    '\t\t\t2:\n'
    '\t\t\t\tresult += ["%s.mob" % prefix, "%s.guard" % prefix, "%s.bone_shield" % prefix, "%s.hide_tower" % prefix, "%s.scout" % prefix, "%s.slinger" % prefix]\n'
    '\t\treturn result\n'
)
# Escape % signs for the replace
old_recruit_branch_escaped = old_recruit_branch.replace("%", "%%")
new_recruit_branch_escaped = new_recruit_branch.replace("%", "%%")
content = content.replace(old_recruit_branch_escaped, new_recruit_branch_escaped)
print("3b: merged combat units into recruit_camp branch")

# Remove barracks branch from get_faction_recruit_template_ids
old_barracks_branch = (
    '\tif "barracks" in data.tags:\n'
    '\t\tif faction == 0:\n'
    '\t\t\treturn ["%s.guard" % prefix, "%s.scout" % prefix, "%s.ranger" % prefix, "%s.blade_dancer" % prefix, "%s.root_guard" % prefix]\n'
    '\t\tif faction == 1:\n'
    '\t\t\treturn ["%s.guard" % prefix, "%s.scout" % prefix, "%s.shieldbearer" % prefix, "%s.crossbow" % prefix, "%s.sapper" % prefix]\n'
    '\t\tif faction == 2:\n'
    '\t\t\treturn ["%s.mob" % prefix, "%s.guard" % prefix, "%s.bone_shield" % prefix, "%s.hide_tower" % prefix, "%s.scout" % prefix, "%s.slinger" % prefix]\n'
    '\t\treturn ["%s.guard" % prefix, "%s.scout" % prefix]\n'
)
old_barracks_branch_escaped = old_barracks_branch.replace("%", "%%")
if old_barracks_branch_escaped in content:
    content = content.replace(old_barracks_branch_escaped, "")
    print("3c: removed barracks branch from get_faction_recruit_template_ids")
else:
    print("3c: WARNING - barracks branch not found in get_faction_recruit_template_ids")

# Remove barracks from get_building_template_id
old_template_check = '\tif "barracks" in data.tags:\n\t\treturn TEMPLATE_BARRACKS_LV1\n'
if old_template_check in content:
    content = content.replace(old_template_check, "")
    print("3d: removed barracks from get_building_template_id")
else:
    print("3d: WARNING - barracks reference in get_building_template_id not found")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

# === 4. building_manager_2d.gd ===
path = "E:/ClaudeProjects/three-against-one/scripts/building_manager_2d.gd"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

old_tag_check = '\t\tif data.tags.has("barracks"):\n\t\t\treturn "barracks"\n'
if old_tag_check in content:
    content = content.replace(old_tag_check, "")
    print("4a: removed barracks tag check from _get_building_texture_key")
else:
    print("4a: WARNING - barracks tag check not found")

old_alias = '\t\t\t"barracks": "barracks_lv1",\n'
if old_alias in content:
    content = content.replace(old_alias, "")
    print("4b: removed barracks alias")
else:
    print("4b: WARNING - barracks alias not found")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

# === 5. recruitment_service.gd ===
path = "E:/ClaudeProjects/three-against-one/scripts/services/recruitment_service.gd"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

old_recruit = (
    '\tif "recruit_camp" in data.tags:\n'
    '\t\treturn ["unit.worker"]\n'
    '\tif "barracks" in data.tags:\n'
    '\t\treturn ["unit.guard", "unit.scout"]'
)
new_recruit = (
    '\tif "recruit_camp" in data.tags:\n'
    '\t\treturn ["unit.worker", "unit.guard", "unit.scout"]'
)
if old_recruit in content:
    content = content.replace(old_recruit, new_recruit)
    print("5: merged barracks units into recruit_camp in recruitment_service")
else:
    print("5: WARNING - recruitment_service barracks reference not found")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

# === 6. victory_service.gd ===
path = "E:/ClaudeProjects/three-against-one/scripts/services/victory_service.gd"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

if 'base = 15 if "barracks" in data.tags else 10' in content:
    content = content.replace(
        'base = 15 if "barracks" in data.tags else 10',
        "base = 10"
    )
    print("6: normalized RECRUITMENT scoring")
else:
    print("6: WARNING - barracks scoring not found")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

# === 7. grid_manager_2d.gd ===
path = "E:/ClaudeProjects/three-against-one/scripts/grid_manager_2d.gd"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace(
    '"Iron Mine", "Forge", "Barracks", "Recruit Camp"',
    '"Iron Mine", "Forge", "Recruit Camp"'
)
print("7a: removed Barracks from enum")

old_switch = '\t\t11:\n\t\t\treturn "barracks"\n'
if old_switch in content:
    content = content.replace(old_switch, "")
    print("7b: removed barracks from switch case")
else:
    print("7b: WARNING - barracks switch case not found")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

# === 8. building_texture_fit_tool.gd ===
path = "E:/ClaudeProjects/three-against-one/scripts/tools/building_texture_fit_tool.gd"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

old_entry = '\t{"key": "barracks", "name": "Barracks", "path": "", "footprint": Vector2i(1, 1), "scale": 1.0},\n'
if old_entry in content:
    content = content.replace(old_entry, "")
    print("8: removed barracks from texture fit tool")
else:
    print("8: WARNING - barracks texture fit entry not found")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("\n=== All done ===")
