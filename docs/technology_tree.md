# 科技树

> 来源：`scripts/technologies/technology_library.gd`

**5 大家族**：通用、龙族、领主（精灵/矮人/兽人）、融合。消耗科技点（TP）研究。

---

## 一、文明起点

| 科技 | TP | 前置 | 效果 |
|:----|:--:|:----|:----|
| 文明起点 `tech.root.civilization` | 0 | — | 根节点，无效果 |

---

## 二、通用科技 (common)

### 探索分支

| 科技 | TP | 前置 | 所需成就 | 效果 |
|:----|:--:|:----|:--------|:----|
| 地图绘制 `tech.common.map_drawing` | 1 | 文明起点 | 工人就位 | 侦察兵视野+1 |
| 地形记录 `tech.common.terrain_record` | 1 | 地图绘制 | — | 单位视野+1 |
| 资源标记 `tech.common.resource_marking` | 1 | 地图绘制 | — | 资源发现奖励+1 |
| 边境测绘 `tech.common.border_survey` | 2 | 地形记录 | 首个仓库 | 前哨视野+1 |

### 锻造分支

| 科技 | TP | 前置 | 所需成就 | 效果 |
|:----|:--:|:----|:--------|:----|
| 基础锻造 `tech.common.basic_forging` | 1 | 文明起点 | 首个采石场 | 驻扎产出+1 |
| 工具锻造 `tech.common.tool_forging` | 1 | 基础锻造 | 工人入驻 | 工人入驻产出+1 |
| 铁矿开采 `tech.common.iron_mining` | 2 | 基础锻造 | 首个铁矿 | 铁矿产出+1 |
| 金属构件 `tech.common.metal_parts` | 2 | 基础锻造 + 铁矿开采 | — | 建筑耐久+2 |

### 军事分支

| 科技 | TP | 前置 | 所需成就 | 效果 |
|:----|:--:|:----|:--------|:----|
| 军粮制度 `tech.common.grain_ration` | 1 | 文明起点 | 首个农场 | 招募食物折扣+1 |
| 招募规程 `tech.common.recruitment_rules` | 1 | 军粮制度 | 首个招募营 | 招募回合缩短+1 |
| 战鼓动员 `tech.common.war_drum_mobilization` | 2 | 招募规程 | 首个招募 | 首次招募AP折扣+1 |

### 仓储与建筑

| 科技 | TP | 前置 | 所需成就 | 效果 |
|:----|:--:|:----|:--------|:----|
| 仓储制度 `tech.common.storage_system` | 1 | 文明起点 | 首个仓库 | 仓储上限+20 |
| 建筑升级 `tech.common.building_upgrade` | 2 | 仓储制度 + 工具锻造 | 工人入驻 | 建筑升级AP折扣+1 |

### 经济分支

| 科技 | TP | 前置 | 所需成就 | 效果 |
|:----|:--:|:----|:--------|:----|
| 金矿开采 `tech.common.gold_mining` | 2 | 资源标记 + 铁矿开采 | 金矿矿井 | 金矿石产出+1 |
| 铸币机械 `tech.common.coin_machinery` | 2 | 金矿开采 + 金属构件 | 首个铸币厂 | 铸币效率+1 |

---

## 三、龙族科技 (dragon)

| 科技 | TP | 前置 | 所需成就 | 效果 |
|:----|:--:|:----|:--------|:----|
| 龙巢勘测 `tech.dragon.nest_survey` | 1 | 资源标记 | 击杀中立单位 | 龙族材料处理+1 |
| 火焰亚龙研究 `tech.dragon.wyvern_fire_research` | 1 | 龙巢勘测 | 火焰龙血成就 | 火焰亚龙装备+1 |
| 冰霜亚龙研究 `tech.dragon.wyvern_frost_research` | 1 | 龙巢勘测 | 冰霜龙血成就 | 冰霜亚龙装备+1 |
| 毒液亚龙研究 `tech.dragon.wyvern_toxic_research` | 1 | 龙巢勘测 | 毒液龙血成就 | 毒液亚龙装备+1 |
| **迷障护盾** `tech.dragon.miasma_shield` | **1** | 龙巢勘测 + 任一亚龙研究 | — | 瘴气免疫+1 |

迷障护盾额外消耗（3 选 1）：火焰龙血×1 / 冰霜龙血×1 / 毒液龙血×1

| 科技 | TP | 前置 | 效果 |
|:----|:--:|:----|:----|
| 火焰涂刃 `tech.dragon.fire_blade` | 2 | 火焰亚龙研究 + 招募规程 | 近战攻击+1 |
| 冰鳞护具 `tech.dragon.frost_scale` | 2 | 冰霜亚龙研究 + 金属构件 | 减伤+1 |
| 腐蚀武器 `tech.dragon.corrosive_weapons` | 2 | 毒液亚龙研究 + 招募规程 | 侦察兵腐蚀虚弱持续 3 回合 |

---

## 四、领主科技 (lord)

### 精灵领主 — 风见者路线 (wind_seer)

| 科技 | TP | 前置 | 所需成就 | 所需领主 | 效果 |
|:----|:--:|:----|:--------|:--------|:----|
| 风语视野 `tech.lord.elf.wind_sight` | 2 | 边境测绘 | 首个精灵领主 | 风见者 | 精灵领主建筑范围+1 |
| 森林通感 `tech.lord.elf.forest_sense` | 2 | 风语视野 + 资源标记 | 首个稀有资源 | 风见者 | 古木产出+1 |
| 隐秘行军 `tech.lord.elf.hidden_march` | 3 | 风语视野 + 地形记录 | — | 风见者 | 林地侦察行动力折扣+1 |

### 矮人领主 — 石卫路线 (stone_warden)

| 科技 | TP | 前置 | 所需成就 | 所需领主 | 效果 |
|:----|:--:|:----|:--------|:--------|:----|
| 深炉工艺 `tech.lord.dwarf.deep_forge` | 2 | 金属构件 | 首个矮人领主 | 石卫 | 矮人工业加成+1 |
| 矿脉回响 `tech.lord.dwarf.vein_echo` | 2 | 深炉工艺 + 铁矿开采 | — | 石卫 | 铁矿产出+1 |
| 石誓加固 `tech.lord.dwarf.stone_oath` | 3 | 深炉工艺 + 建筑升级 | — | 石卫 | 建筑耐久+3、减伤+1 |

### 兽人领主 — 血颅路线 (blood_chief)

| 科技 | TP | 前置 | 所需成就 | 所需领主 | 效果 |
|:----|:--:|:----|:--------|:--------|:----|
| 血鼓号令 `tech.lord.orc.blood_drum` | 2 | 战鼓动员 | 首个兽人领主 | 血颅 | 兽人军事加成+1 |
| 掠食军粮 `tech.lord.orc.raid_ration` | 2 | 血鼓号令 + 军粮制度 | 击杀中立单位 | 血颅 | 击杀食物奖励+1 |
| 狂战训练 `tech.lord.orc.berserker_training` | 3 | 血鼓号令 + 招募规程 | — | 血颅 | 近战攻击+1 |

#### 兽人龙战分支

| 科技 | TP | 前置 | 条件 | 所需领主 | 效果 |
|:----|:--:|:----|:----|:--------|:----|
| 龙血战争认知 `tech.lord.orc.dragon_war_lore` | 2 | 血鼓号令 | 任一亚龙研究 | 血颅 | 解锁龙战路线 |
| 屠龙战士 `tech.lord.orc.dragon_slayer` | 3 | 龙血战争认知 + 狂战训练 | 击杀中立单位 | 血颅 | 解锁屠龙战士 |
| 龙骨巨盾兵 `tech.lord.orc.dragonbone_shield` | 3 | 龙血战争认知 + 金属构件 | — | 血颅 | 解锁龙骨巨盾兵 |
| 龙血狂战士 `tech.lord.orc.dragon_blood_berserker` | 4 | 龙血战争认知 + 狂战训练 | — | 血颅 | 解锁龙血狂战士 |
| 巨龙骑士前置 `tech.lord.orc.dragon_rider_path` | 4 | 龙血战争认知 | — | 血颅 | 开启巨龙骑士路线 |

---

## 五、融合科技 (hybrid)

需要至少两个阵营的领主在场才能研究。

| 科技 | TP | 前置 | 所需领主 | 效果 |
|:----|:--:|:----|:--------|:----|
| 远古铁枝 `tech.hybrid.ancient_iron_branch` | 3 | 森林通感 + 矿脉回响 | 风见者 + 石卫 | 古木产出+1、铁矿产出+1 |
| 熔炉战鼓 `tech.hybrid.forge_war_drum` | 3 | 矿脉回响 + 血鼓号令 | 石卫 + 血颅 | 铁矿产出+1、招募回合折扣+1 |
| 林间突袭 `tech.hybrid.forest_raid` | 3 | 隐秘行军 + 狂战训练 | 风见者 + 血颅 | 轻装攻击+1、侦察兵视野+1 |
| **三族议约** `tech.hybrid.tri_lord_pact` | **4** | 远古铁枝 + 熔炉战鼓 + 林间突袭 | 风见者 + 石卫 + 血颅 | 领主建筑范围+1、融合科技折扣+1 |

---

## 六、科技家族色

| 家族 | 颜色 | 色值 |
|:----|:----|:----:|
| 起点 (root) | 金色 | `#F5E170` |
| 通用 (common) | 蓝色 | `#73A8F2` |
| 龙族 (dragon) | 绿色 | `#5CDBA3` |
| 领主 (lord) | 紫色 | `#B88AFF` |
| 融合 (hybrid) | 橙色 | `#FF9259` |
