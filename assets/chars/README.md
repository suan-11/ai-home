# 角色资源格式规范

> 正式角色制作计划见 [`../../doc/正式角色计划.md`](../../doc/正式角色计划.md)；替换 / 新增角色时按该计划的清单执行。
> ⚠️ 版权提醒：请只提交**原创或已获授权**的角色素材。当前 `char_03`（梅尔）为外部作品素材，仅开发 / 预览用，将被原创角色替换。

每个角色一个目录，命名建议 `char_XX`。

## 当前角色

| 目录 | 角色 | 状态 |
|---|---|---|
| `char_02` | （未使用，预留） | 建议作为原创正式角色目录 |
| `char_01` | 小灯 | 临时占位（基础素材；无差分立绘 / 互动，运行时降级） |
| `char_03` | 梅尔 | 完整素材（**外部作品素材，将移除**） |
| `_template` | （空） | 新角色起步用占位目录 |

## 目录结构（以完整角色为例）

```
assets/chars/char_XX/
 persona.json          # 人设（系统提示词、性格、语言协议等，唯一格式来源）
 interactions.json     # 互动配置（文本/动作/表情/效果/上限，数据驱动）
 anim_map.json         # 动画状态 → 帧数/帧率/是否循环
 portrait.png          # 左侧立绘原图（保持原始分辨率，按比例缩放）
 portraits/            # 立绘差分表情（default/happy/low/shy/distracted/surprised 等）
    default.png
    ...
 sprites/
     idle_0.png        # 待机帧（128×128 源图，透明背景）
     idle_1.png
     walk_0.png        # 行走帧（128×128 源图）
     walk_1.png
     walk_2.png
     walk_3.png
```

- 可选：人设原始文稿 / 原图源文件可一并放入角色目录（如 `人设.md`、`原图.png`）

## 多角色可用性（P4 多角色切换）

- 角色目录只要同时具备 `persona.json` + `portrait.png` + `sprites/`（至少 `idle_0.png` 或 `walk_0.png` 之一），就会自动出现在主界面「角色」按钮的切换列表
- `portraits/`（差分立绘）与 `interactions.json`（互动）为**可选**：缺失时运行时降级（立绘用单张原图；点击角色无互动菜单）
- 每个角色的好感度 / 记忆 / 日记 / 状态 **完全独立**（GameManager / MemoryManager / StatusManager 均按 char_id 存取）
- `persona.json` 可选 `order`（数字，越小越靠前；默认 99）控制切换列表排序
- 切换后**原地换人**：小人动画、立绘、名字、互动菜单、状态均按新角色加载
- 替换默认角色时还需同步代码中的 `DEFAULT_CHAR_ID` 与若干 fallback 文案，清单见 [`../../doc/正式角色计划.md`](../../doc/正式角色计划.md) 第 5 节

## interactions.json（每个角色可自定义互动）

键为互动 id，值包含：`name`（显示名）、`entry`（入口，`character`=点击角色菜单；`furniture:<交互名>`=家具交互）、`actions`（wave/hop/sad）、`expression`（立绘表情，见 `portraits/`）、`expression_duration`（表情持续秒数）、`texts`（随机台词）、`reply_delay`（气泡延迟）、`effects`（satiety/mood/fatigue）、`affection`（amount/reason）、`limits`（daily 每日次数 / cooldown 秒）。

```json
{
  "pet": {
    "name": "摸摸头",
    "entry": "character",
    "actions": ["hop"],
    "expression": "shy",
    "expression_duration": 2.5,
    "texts": ["手拿开喵。"],
    "reply_delay": 0.6,
    "effects": {"mood": 3},
    "affection": {"amount": 1, "reason": "摸摸头"},
    "limits": {"daily": 5}
  }
}
```

## persona.json 字段

| 字段 | 说明 |
|---|---|
| `id` | 角色 ID，与目录名一致 |
| `name` / `full_name` / `display_name` | 名字 / 全名 / 显示名 |
| `species` / `origin` | 种族 / 世界观来源 |
| `appearance` | 外观描述 |
| `personality` | 性格摘要 |
| `greeting` | 开场白 |
| `speech_style` | 说话风格摘要 |
| `speech_protocol` | 语言协议（句尾、字数、禁用项等） |
| `mood_mapping` | 情绪映射 |
| `likes` / `dislikes` | 喜好 / 厌恶 |
| `forbidden_topics` | 禁止话题 |
| `system_prompt` | 可直接注入 AI 的完整系统提示词 |
| `order`（可选） | 角色列表排序，越小越靠前（默认 99） |

## 像素图规范

- 源图尺寸：128×128（直接像素化原图，运行时按 0.25 缩放，显示约 32×32）
- 透明背景；至少提供 `idle_0/1`、`walk_0~3`
- 动画配置见角色目录内 `anim_map.json`