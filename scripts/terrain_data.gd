class_name TerrainData
## 地形数据定义：枚举、颜色、高度
## 与三人竞技棋 3D 版本共享数据结构

enum Terrain {
	VOID,          # 不可到达（黑色）
	WATER,         # 水域（蓝色）
	PLAIN_DWARF,   # 平原·矮人（土黄）
	MOUNTAIN_DWARF,# 山地·矮人（灰褐）
	FOREST_ELF,    # 森林·精灵（深绿）
	GLADE_ELF,     # 林间草地·精灵（浅绿）
	WASTELAND_ORC, # 荒原·兽人（赭石）
	SWAMP_ORC,     # 沼泽·兽人（暗绿）
	DRAGON_MOUNT,  # 巨龙高山（深灰）
	DRAGON_NEST,   # 巨龙巢穴（暗红）
	CORRIDOR,      # 通道（浅棕）
	RUINS,         # 遗迹（紫色）
}

static func get_color(t: Terrain) -> Color:
	match t:
		Terrain.VOID:           return Color(0.10, 0.10, 0.12)
		Terrain.WATER:          return Color(0.12, 0.45, 0.78, 0.75)
		Terrain.PLAIN_DWARF:    return Color(0.78, 0.71, 0.38)
		Terrain.MOUNTAIN_DWARF: return Color(0.55, 0.45, 0.33)
		Terrain.FOREST_ELF:     return Color(0.18, 0.35, 0.15)
		Terrain.GLADE_ELF:      return Color(0.35, 0.55, 0.25)
		Terrain.WASTELAND_ORC:  return Color(0.72, 0.53, 0.04)
		Terrain.SWAMP_ORC:      return Color(0.23, 0.33, 0.14)
		Terrain.DRAGON_MOUNT:   return Color(0.29, 0.29, 0.29)
		Terrain.DRAGON_NEST:    return Color(0.55, 0.0, 0.0)
		Terrain.CORRIDOR:       return Color(0.82, 0.71, 0.55)
		Terrain.RUINS:          return Color(0.50, 0.35, 0.60)
	return Color.WHITE

static func get_terrain_name(t: Terrain) -> String:
	match t:
		Terrain.VOID:           return "不可到达"
		Terrain.WATER:          return "水域"
		Terrain.PLAIN_DWARF:    return "矮人·平原"
		Terrain.MOUNTAIN_DWARF: return "矮人·山地"
		Terrain.FOREST_ELF:     return "精灵·森林"
		Terrain.GLADE_ELF:      return "精灵·林间草地"
		Terrain.WASTELAND_ORC:  return "兽人·荒原"
		Terrain.SWAMP_ORC:      return "兽人·沼泽"
		Terrain.DRAGON_MOUNT:   return "巨龙高山"
		Terrain.DRAGON_NEST:    return "巨龙巢穴"
		Terrain.CORRIDOR:       return "通道"
		Terrain.RUINS:          return "遗迹"
	return "未知"

static func is_passable(t: Terrain) -> bool:
	return t != Terrain.VOID and t != Terrain.WATER and t != Terrain.DRAGON_NEST and t != Terrain.DRAGON_MOUNT

static func is_buildable(t: Terrain) -> bool:
	return t == Terrain.PLAIN_DWARF or t == Terrain.FOREST_ELF or \
		   t == Terrain.MOUNTAIN_DWARF or t == Terrain.GLADE_ELF or \
		   t == Terrain.WASTELAND_ORC or t == Terrain.CORRIDOR or \
		   t == Terrain.RUINS
