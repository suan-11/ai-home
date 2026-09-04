# 角色资源格式规范

每个角色一个目录，命名建议 `char_XX`。

```
assets/chars/char_03/
├── persona.json          # 人设（唯一格式来源：系统提示词、性格、语言协议等）
├── interactions.json     # 互动配置（文本/动作/表情/效果/上限，数据驱动，见下）
├── portraits/            # 立绘差分表情（default/happy/low/shy/distracted/surprised 等）
├── portrait.png          # 左侧立绘原图（保持原始分辨率，直接按比例缩放）
├── anim_map.json         # 动画状态 → 帧数/帧率/是否循环
├── Mea人设.md            # （可选）人设原始文稿，保留来源
├── mea原图.png           # （可选）原图源文件
└── sprites/
    ├── idle_0.png        # 待机帧（128×128 源图，透明背景，原图直接像素化）
    ├── idle_1.png
    ├── walk_0.png        # 行走帧（128×128 源图）
    ├── walk_1.png
    ├── walk_2.png
    └── walk_3.png
```

## interactions.json（每个角色可自定义互动）

键为互动 id，值包含：`name`（显示名）、`entry`（入口，`character`=点击角色菜单；`furniture:<交互名>`=家具交互）、`actions`（wave/hop/sad）、`expression`（立绘表情，见 portraits/）、`texts`（随机台词）、`effects`（satiety/mood/fatigue）、`affection`（amount/reason）、`limits`（daily 每日次数 / cooldown 秒）。

```json
{
  "pet": {
    "name": "摸摸头", "entry": "character",
    "actions": ["hop"], "expression": "shy", "expression_duration": 2.5,
    "texts": ["手拿开喵。"], "reply_delay": 0.6,
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
| `name` / `full_name` / `display_name` | 名字 |
| `species` / `origin` | 种族/世界观来源 |
| `appearance` | 外观描述 |
| `personality` | 性格摘要 |
| `greeting` | 开场白 |
| `speech_style` | 说话风格摘要 |
| `speech_protocol` | 语言协议（句尾、字数、禁用项等） |
| `mood_mapping` | 情绪映射 |
| `likes` / `dislikes` | 喜好/厌恶 |
| `forbidden_topics` | 禁止话题 |
| `system_prompt` | 可直接注入 AI 的完整系统提示词 |

## 像素图规范

- 源图尺寸：128×128（直接像素化原图，运行时按 0.25 缩放，显示约 32×32）
- 透明背景
- 至少提供：`idle_0/1`、`walk_0~3`
- 动画配置见 `anim_map.json`
