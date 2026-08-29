# 角色资源格式规范

每个角色一个目录，命名建议 `char_XX`。

```
assets/chars/char_03/
├── persona.json          # 人设（唯一格式来源：系统提示词、性格、语言协议等）
├── portrait.png          # 左侧立绘原图（透明背景，建议长宽比接近 0.5）
├── anim_map.json         # 动画状态 → 帧数/帧率/是否循环
├── Mea人设.md            # （可选）人设原始文稿，保留来源
├── mea原图.png           # （可选）原图源文件
└── sprites/
    ├── idle_0.png        # 待机帧（32×32 源图，透明背景）
    ├── idle_1.png
    ├── walk_0.png        # 行走帧（32×32 源图）
    ├── walk_1.png
    ├── walk_2.png
    └── walk_3.png
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

- 源图尺寸：32×32（运行时按 0.5 缩放显示，与 16×16 网格对齐）
- 透明背景
- 至少提供：`idle_0/1`、`walk_0~3`
- 动画配置见 `anim_map.json`
