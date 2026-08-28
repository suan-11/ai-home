# 🏠 AIHome — 详细实现方案


---

## 一、技术选型决策

| 维度 | 结论 | 理由 |
|---|---|---|
| **引擎** | **Godot 4.x（GDScript）** | 像素2D动画、TileMap寻路、场景树层级是核心需求，Godot开箱即用；GDScript语法≈Python，您有基础；AI对GDScript生成质量在4.x后大幅提升 |
| **AI对话** | HTTP POST → OpenAI兼容接口 | 用户在设置面板填 `api_base` / `api_key` / `model`，GDScript 内置 `HTTPRequest` 即可 |
| **语音（后期）** | 预留接口，MVP不做 | 您选了A：先文字+表情动画 |
| **美术** | AI生成底稿 → 手动精修 → Aseprite/Pixelorama 切帧 | 您选了b |
| **打包** | Godot 一键导出 Windows .exe | 无需PyInstaller，体积小（~50MB） |
| **存档/配置** | JSON 文件，存于 `user://`（Godot沙盒路径） | 对应您结构中的 `log/` |

> **备选路径**：若开发中GDScript的AI生成质量严重不足，可将AI对话模块拆为Python微服务（localhost:8000），Godot通过HTTP调用。但优先不拆，保持单体。

---

## 二、开发环境搭建（您需要手动做的）

```
1. 下载安装 Godot 4.3+（标准版，非.NET版）
   → https://godotengine.org/download

2. 安装 Aseprite（或免费替代 Pixelorama）
   → 用于精修AI生成的像素图、切动画帧

3. 安装 VS Code + Godot Tools 扩展（可选）
   → 方便用AI助手编辑GDScript

4. 准备AI编码助手
   → Cursor / Windsurf / 本对话，均可

5. 创建Godot项目 → 选择"2D" → 项目名 aihome
```

> 后续所有代码均可由AI生成，您只需**粘贴到Godot编辑器对应节点**即可。

---

## 三、项目目录结构（Godot适配版）

基于您原始结构，映射到Godot的 `res://` 体系：

```
res://                          ← Godot项目根目录
├── assets/
│   ├── chars/                  ← 角色资源（多角色）
│   │   ├── char_01/
│   │   │   ├── sprites/        ← 像素动画帧（idle_0.png, walk_0.png...）
│   │   │   ├── portrait.png    ← 对话框立绘
│   │   │   ├── persona.json    ← 人设/性格/称呼/说话风格
│   │   │   └── anim_map.json   ← 动画状态→帧序列映射
│   │   ├── char_02/
│   │   │   └── ...
│   │   └── _template/          ← 新角色模板
│   ├── room/
│   │   ├── wall/               ← 墙壁背景
│   │   ├── floor/              ← 地板TileSet
│   │   └── obj/                ← 可交互物体（床、桌、椅...）
│   │       ├── bed/
│   │       │   ├── sprite.png
│   │       │   └── obj.json    ← 交互类型、状态影响、位置
│   │       └── desk/
│   ├── bgm/                    ← 背景音乐/音效
│   └── ui/                     ← UI素材（对话框、按钮、设置面板）
│
├── scenes/                     ← Godot场景文件（.tscn）
│   ├── main.tscn               ← 主场景（窗口根节点）
│   ├── room.tscn               ← 房间场景（可自定义）
│   ├── char_actor.tscn         ← 角色实例场景
│   ├── ui/
│   │   ├── chat_panel.tscn     ← 对话面板
│   │   ├── setting_panel.tscn  ← 设置面板
│   │   └── bubble.tscn         ← 文字气泡
│   └── editor/
│       └── room_editor.tscn    ← 房间自定义编辑器
│
├── scripts/                    ← GDScript脚本
│   ├── autoload/               ← 全局单例（自动加载）
│   │   ├── GameManager.gd      ← 全局状态管理
│   │   ├── ConfigManager.gd    ← 配置读写（config.json）
│   │   ├── MemoryManager.gd    ← 记忆读写（memory.json）
│   │   └── AIConnector.gd      ← AI对话HTTP客户端
│   ├── logic/
│   │   ├── state_machine.gd    ← 角色状态机（饿/困/无聊/开心）
│   │   ├── pathfinding.gd      ← 权重寻路（A*扩展）
│   │   ├── behavior_tree.gd    ← 行为决策
│   │   └── room_manager.gd     ← 房间加载/切换/自定义
│   ├── char/
│   │   ├── char_controller.gd  ← 角色控制（动画切换、移动）
│   │   ├── char_registry.gd    ← 多角色注册表
│   │   └── emotion.gd          ← 表情系统
│   └── ui/
│       ├── chat_ui.gd
│       ├── setting_ui.gd
│       └── bubble_ui.gd
│
├── data/                       ← 运行时数据（对应您的log/）
│   ├── config.json             ← 全局设置（API地址、模型名、音量等）
│   ├── memory.json             ← 对话记忆
│   ├── save_slot_1.json        ← 存档（角色状态、房间布局）
│   └── room_custom/            ← 用户自定义房间配置
│       └── my_room.json
│
├── setting/
│   └── map.json                ← 默认地图权重配置
│
└── project.godot               ← Godot项目文件
```

---

## 四、核心系统架构

```
┌─────────────────────────────────────────────────────┐
│                    main.tscn                         │
│  ┌───────────┐  ┌──────────┐  ┌─────────────────┐  │
│  │ RoomScene │  │ CharActor│  │   UI Layer      │  │
│  │ (房间+物体)│  │ (角色)   │  │ (对话/设置/气泡) │  │
│  └─────┬─────┘  └────┬─────┘  └────────┬────────┘  │
│        │              │                  │           │
│  ┌─────▼──────────────▼──────────────────▼────────┐  │
│  │              GameManager (Autoload)             │  │
│  │  ┌──────────┐ ┌──────────┐ ┌────────────────┐ │  │
│  │  │StateMachine│ │Pathfind │ │ BehaviorTree   │ │  │
│  │  │(饿/困/玩) │ │(权重A*) │ │(决策引擎)     │ │  │
│  │  └──────────┘ └──────────┘ └────────────────┘ │  │
│  └────────────────────────────────────────────────┘  │
│        │              │                  │           │
│  ┌─────▼─────┐ ┌─────▼─────┐  ┌────────▼────────┐  │
│  │ConfigMgr  │ │MemoryMgr  │  │  AIConnector    │  │
│  │(config.   │ │(memory.   │  │  (HTTP→LLM)     │  │
│  │ json)     │ │ json)     │  │                 │  │
│  └───────────┘ └───────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────┘
```

**Autoload（全局单例）** 在 `project.godot` 中注册，全局可访问：
- `GameManager` — 游戏主循环、场景切换
- `ConfigManager` — 读写 `config.json`
- `MemoryManager` — 读写 `memory.json`、构建对话上下文
- `AIConnector` — 封装HTTP请求、流式/非流式响应

---

## 五、各模块详细设计

### 5.1 配置系统（ConfigManager）

**`data/config.json` 结构：**
```json
{
  "ai": {
    "api_base": "https://api.deepseek.com/v1",
    "api_key": "sk-xxxxx",
    "model": "deepseek-v4-flash",
    "max_tokens": 512,
    "temperature": 0.8
  },
  "display": {
    "window_size": [480, 360],
    "pixel_scale": 2,
    "fps": 30
  },
  "audio": {
    "bgm_volume": 0.6,
    "sfx_volume": 0.8,
    "tts_enabled": false
  },
  "gameplay": {
    "active_char": "char_01",
    "active_room": "default",
    "state_tick_interval": 5.0
  }
}
```

**GDScript接口（AI生成时的目标）：**
```gdscript
# ConfigManager.gd (Autoload)
func load_config() -> void
func save_config() -> void
func get_value(section: String, key: String, default = null) -> Variant
func set_value(section: String, key: String, value: Variant) -> void
```

---

### 5.2 角色系统

#### 5.2.1 多角色注册（CharRegistry）

```
assets/chars/char_01/persona.json 示例：
```
```json
{
  "id": "char_01",
  "name": "小灯",
  "personality": "温柔、有点迷糊、喜欢深夜讲故事",
  "greeting": "你回来啦～今天过得怎么样？",
  "speech_style": "语气轻柔，偶尔用'嗯...'开头，喜欢用比喻",
  "forbidden_topics": [],
  "system_prompt_extra": ""
}
```

**切换角色 = 切换 `active_char` + 重新加载 `persona.json` + 换立绘/像素动画。**

#### 5.2.2 动画状态映射（anim_map.json）

```json
{
  "idle":    { "frames": 8,  "fps": 6,  "loop": true },
  "walk":    { "frames": 6,  "fps": 10, "loop": true },
  "sit":     { "frames": 4,  "fps": 4,  "loop": true },
  "sleep":   { "frames": 6,  "fps": 3,  "loop": true },
  "talk":    { "frames": 4,  "fps": 8,  "loop": true },
  "happy":   { "frames": 6,  "fps": 10, "loop": false },
  "sad":     { "frames": 4,  "fps": 5,  "loop": true }
}
```

> **美术规格建议**：单帧 **32×32** 或 **48×48** 像素，窗口内放大2~3倍渲染（`pixel_scale`）。AI生成底稿时用关键词：`pixel art, 32x32, chibi character, 4-direction, sprite sheet, transparent background`。

#### 5.2.3 状态机（StateMachine）

```
        ┌─────────┐
   ┌───▶│  IDLE   │◀───┐
   │    └────┬────┘    │
   │         │ 行为树   │ 需求满足
   │         ▼ 触发    │
   │    ┌─────────┐    │
   │    │ WALK_TO │────┘
   │    └────┬────┘
   │         │ 到达目标
   │         ▼
   │    ┌─────────┐
   └────│INTERACT │ (坐/睡/吃/看书...)
        └────┬────┘
             │ 被打断(用户点击)
             ▼
        ┌─────────┐
        │  TALK   │ ← AI对话中
        └─────────┘
```

**状态数值模型（默认值，可在config中调）：**

| 状态 | 初始值 | 衰减速率 | 恢复方式 | 阈值触发 |
|---|---|---|---|---|
| 饱食 | 100 | -1/30s | 交互"桌子"→+40 | <30 → 寻找食物 |
| 精力 | 100 | -1/60s | 交互"床"→+2/秒 | <20 → 寻找床 |
| 心情 | 80 | -1/120s | 用户对话→+10 | <25 → 表现出低落动画 |
| 好奇 | 50 | -1/90s | 交互"书架/窗"→+30 | <20 → 闲逛探索 |

---

### 5.3 权重寻路系统

**`setting/map.json` 结构：**
```json
{
  "grid_size": [16, 12],
  "cell_size": 16,
  "default_weight": 1.0,
  "zones": {
    "bed_area":    { "cells": [[10,1],[10,2],[11,1],[11,2]], "base_weight": 1.0 },
    "desk_area":   { "cells": [[3,4],[3,5],[4,4],[4,5]],     "base_weight": 1.0 },
    "window_area": { "cells": [[0,6],[0,7],[1,6],[1,7]],     "base_weight": 1.0 }
  },
  "state_weight_modifiers": {
    "hungry":  { "desk_area": 3.0 },
    "sleepy":  { "bed_area": 5.0 },
    "bored":   { "window_area": 2.5, "desk_area": 1.5 },
    "happy":   { "default": 1.2 }
  },
  "time_weight_modifiers": {
    "night_22_06": { "bed_area": 4.0, "desk_area": 0.3 },
    "morning_06_12": { "window_area": 2.0 },
    "afternoon_12_18": { "desk_area": 2.0 }
  }
}
```

**寻路逻辑：**
1. 行为树根据当前状态数值 → 决定"想去哪类区域"
2. 计算目标区域所有格子的**综合权重** = `base_weight × state_modifier × time_modifier`
3. 选择权重最高的格子作为终点
4. A*寻路（Godot的 `NavigationAgent2D` 或自写网格A*）
5. 角色沿路径移动，播放 `walk` 动画

---

### 5.4 AI对话系统（AIConnector）

**核心流程：**
```
用户输入 → MemoryManager构建上下文 → AIConnector.POST → 解析响应 → 角色播放talk动画 → 显示文字气泡
```

**Prompt拼接逻辑：**
```
[System]
你是{name}，{personality}。
说话风格：{speech_style}
当前你的状态：饱食{hunger}/100，精力{energy}/100，心情{mood}/100
当前时间：{real_time}，你在{current_room}里。
{memory_summary}

[历史对话最近10轮]
[用户当前输入]
```

**`data/memory.json` 结构：**
```json
{
  "char_01": {
    "short_term": [
      { "role": "user", "content": "...", "ts": "2026-08-28T17:00:00" },
      { "role": "assistant", "content": "...", "ts": "2026-08-28T17:00:05" }
    ],
    "long_term_summary": "用户喜欢猫，工作很忙，经常深夜才打开应用。",
    "key_facts": [
      { "fact": "用户养了一只叫团子的猫", "ts": "2026-08-20T22:00:00" }
    ],
    "last_summary_update": "2026-08-25T23:00:00"
  }
}
```

> **记忆策略**：`short_term` 保留最近20轮；超过后，用一次AI调用将旧对话总结为 `long_term_summary`，并提取 `key_facts`。每次对话时，system prompt 中注入 summary + facts。

**HTTP请求（GDScript核心代码骨架）：**
```gdscript
# AIConnector.gd
func send_chat(messages: Array) -> void:
    var url = config.get_value("ai", "api_base") + "/chat/completions"
    var body = JSON.stringify({
        "model": config.get_value("ai", "model"),
        "messages": messages,
        "max_tokens": config.get_value("ai", "max_tokens"),
        "temperature": config.get_value("ai", "temperature")
    })
    http_request.request(url, [
        "Content-Type: application/json",
        "Authorization: Bearer " + config.get_value("ai", "api_key")
    ], HTTPClient.METHOD_POST, body)
```

---

### 5.5 房间自定义系统

**房间配置（`room_custom/my_room.json`）：**
```json
{
  "name": "我的房间",
  "size": [16, 12],
  "wall_sprite": "res://assets/room/wall/wall_02.png",
  "floor_tileset": "res://assets/room/floor/floor_wood.png",
  "objects": [
    { "type": "bed",  "pos": [10, 1], "rotation": 0 },
    { "type": "desk", "pos": [3, 4],  "rotation": 0 },
    { "type": "lamp", "pos": [12, 8], "rotation": 0 }
  ],
  "bgm": "res://assets/bgm/room_night.ogg"
}
```

**编辑器功能（`room_editor.tscn`）：**
- 网格视图，点击放置/删除物体
- 从 `assets/room/obj/` 拖拽物体
- 保存为 `room_custom/xxx.json`
- MVP阶段可简化为"列表编辑"（下拉选物体+输入坐标），后期再做可视化拖拽

---

### 5.6 文字气泡与对话UI

```
┌──────────────────────────────┐
│  [立绘]  小灯                │
│  ┌─────────────────────┐     │
│  │ 你回来啦～今天过得  │     │
│  │ 怎么样？            │     │
│  └─────────────────────┘     │
│  ┌─────────────────────────┐ │
│  │ [用户输入框]    [发送]  │ │
│  └─────────────────────────┘ │
│  [逐字显示，速度可在设置调]   │
└──────────────────────────────┘
```

- 逐字打印效果（`Timer` + `visible_characters`）
- 角色同步播放 `talk` 动画
- 气泡内支持简单换行，不做富文本

---

## 六、分阶段里程碑

### 🟢 Phase 1 — 骨架可跑（目标：1~2周）

> **交付物**：窗口中显示一个像素角色，能idle动画循环，能在房间内A*寻路走动。

| # | 任务 | 说明 |
|---|---|---|
| 1.1 | 创建Godot项目，配置窗口大小480×360，像素渲染模式 | `stretch/mode=viewport` |
| 1.2 | 用AI生成一套32×32像素角色（idle 8帧 + walk 6帧） | 关键词见5.2.2 |
| 1.3 | 搭建 `main.tscn`：TileMap地板 + 角色节点 | 用占位色块即可 |
| 1.4 | 实现 `char_controller.gd`：动画播放 + 网格移动 | 先硬编码路径 |
| 1.5 | 实现基础A*寻路（网格版） | 可让AI直接生成 |
| 1.6 | 实现 `state_machine.gd`：IDLE ↔ WALK_TO 两个状态 | 最简状态机 |
| 1.7 | 打包测试：导出exe，确认能跑 | |

> **AI提示词模板（给Cursor/本对话）**：
> *"用Godot 4 GDScript，写一个32x32像素角色控制脚本。角色在16x12的网格上，支持A*寻路，播放AnimatedSprite2D动画（idle/walk），到达目标后切换为idle。动画帧映射从anim_map.json读取。"*

---

### 🟡 Phase 2 — AI对话 + 状态系统（目标：2~3周）

> **交付物**：能和角色对话，角色有饿/困等状态，会自主寻路去交互物体。

| # | 任务 | 说明 |
|---|---|---|
| 2.1 | 实现 `ConfigManager`：读写config.json，设置面板UI | 用户填API地址/密钥/模型 |
| 2.2 | 实现 `AIConnector`：HTTP POST到OpenAI兼容接口 | 含错误处理、超时 |
| 2.3 | 实现 `MemoryManager`：短期对话 + 长期摘要 | memory.json |
| 2.4 | 实现对话UI：输入框 + 气泡 + 逐字显示 | `chat_panel.tscn` |
| 2.5 | 实现 `persona.json` 加载 → 注入System Prompt | 角色人设 |
| 2.6 | 实现状态数值系统：饱食/精力/心情/好奇 + 衰减 | `state_machine.gd` 扩展 |
| 2.7 | 实现 `map.json` 权重寻路 | 状态→权重→选目标→A* |
| 2.8 | 实现交互物体：到达后触发交互（坐/睡/吃） | 状态恢复 |
| 2.9 | 行为树基础版：状态阈值→决策→触发寻路 | 简单if-else即可 |

---

### 🔵 Phase 3 — 多角色 + 自定义房间 + 打磨（目标：3~4周）

> **交付物**：可切换角色，可自定义房间布局，体验完整。

| # | 任务 | 说明 |
|---|---|---|
| 3.1 | 实现 `CharRegistry`：扫描 `assets/chars/` 下所有角色 | 多角色注册 |
| 3.2 | 角色切换UI + 热切换逻辑 | 换立绘/动画/人设 |
| 3.3 | 房间自定义编辑器（MVP：列表式） | 放置/移除物体 |
| 3.4 | 房间保存/加载 | `room_custom/*.json` |
| 3.5 | 存档系统：保存角色状态+房间布局+记忆 | `save_slot_*.json` |
| 3.6 | BGM/音效播放 | `AudioStreamPlayer` |
| 3.7 | 时间系统：读取系统时间→影响权重+角色行为 | 夜晚→想睡觉 |
| 3.8 | 设置面板完善：音量、窗口大小、API配置 | |
| 3.9 | 整体打磨：动画过渡、音效、细节 | |
| 3.10 | 打包发布：导出exe + 图标 + 版本号 | |

---

### ⚪ Phase 4 — 后期扩展（可选）

| 功能 | 说明 |
|---|---|
| TTS语音 | 接入Edge-TTS API，播放音频，口型按音量开合 |
| 可视化房间编辑器 | 拖拽式，替代列表式 |
| 多房间 | 角色可在不同房间间移动 |
| Mod支持 | 用户放入`assets/chars/`即可加载新角色 |
| 本地小模型 | Ollama API，离线可用 |

---

## 七、风险预案

| 风险 | 概率 | 应对 |
|---|---|---|
| AI生成GDScript有bug，调试困难 | 高 | 每个脚本控制在100行内；报错信息完整复制给AI；Godot的`print()`调试 |
| AI对话延迟过高（>5s） | 中 | 加loading动画（角色思考姿态）；设置超时10s；失败时显示预设回复 |
| 像素动画AI生成质量差 | 中 | 多生成几版选最好的；用Aseprite手动修1~2帧关键帧；实在不行用免费素材包（itch.io） |
| 权重寻路行为不自然 | 中 | 加随机扰动（±20%权重）；加冷却时间（同一目标不连续去两次） |
| memory.json越来越大 | 低 | 短期对话上限20轮；长期摘要上限500字；定期压缩 |
| Godot打包后文件找不到 | 低 | 数据文件用`user://`路径；打包前在导出设置中排除`data/` |

---

## 八、给AI编码时的通用提示词模板

每次让AI写代码时，建议附带以下上下文：

```
【项目】Godot 4.x, GDScript, 2D像素桌面宠物应用
【窗口】480×360，像素渲染
【当前任务】（描述具体功能）
【已有模块】（列出已完成的脚本及其接口）
【约束】
- 使用Autoload单例访问全局管理器
- 数据文件用user://路径
- 动画用AnimatedSprite2D
- 寻路用自写网格A*（不用NavigationRegion）
- 所有可配置项读config.json
【输出】完整可运行的.gd文件，含注释
```

---

## 九、立即可执行的第一步

如果您准备开始，**现在就做这一件事**：

> 打开Godot → 新建2D项目 → 创建一个场景 → 添加一个 `AnimatedSprite2D` 节点 → 用AI生成8帧32×32的idle动画（提示词：`pixel art, 32x32, chibi girl, idle animation, 8 frames, sprite sheet, transparent background, retro game style`）→ 导入Godot → 播放。

看到角色在窗口里动起来的那一刻，Phase 1就正式开始了。

---

如果方案中任何模块您想**调整、补充或砍掉**，随时告诉我，我会更新方案。也可以直接说"开始Phase 1"，我来逐步给出每一步的AI提示词和代码。