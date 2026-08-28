# AIHome / AI-Character-home

一个使用 **Godot 4.x / GDScript** 制作的 2D 像素风桌面陪伴项目。

当前阶段：可运行的温馨小屋原型，包含网格寻路、家具交互和电脑四宫格界面。

---

## 运行方式

1. 安装 [Godot](https://godotengine.org/download) 4.3+（推荐 4.7+）
2. 用 Godot 打开本项目根目录的 `project.godot`
3. 按 **F5** 运行

## 操作

| 操作 | 效果 |
|---|---|
| 鼠标左键点击地板 | 角色 A* 寻路走到目标格子 |
| 点击家具 | 已在旁边则触发交互；否则走到旁边空位 |
| 点击电脑 | 打开屏幕中央的电脑四宫格面板 |
| 电脑内点击 游戏/聊天/日记 | 打开对应模块，其中游戏为 AI 五子棋 |
| F11 | 切换全屏 |

## 当前功能

- 温馨配色房间：墙体、木地板、窗户、地毯
- 家具：
  - 床 `sleep`
  - 电脑桌 `computer`
  - 书架 `read`
  - 椅子 `sit`
  - 电视柜 `watch`
  - 沙发 `rest`
  - 落地灯 `light`
  - 盆栽 `water`
- 网格 A* 寻路
- 家具碰撞和“先走到旁边再交互”的交互系统
- 电脑四宫格界面：
  - 游戏（AI 五子棋对战）
  - 聊天（AI 对话 API 接口已预留）
  - 日记（好感度/记忆，占位）
  - 右下角空位
- 全屏切换与窗口自适应

## 目录结构

```
ai-home/
├── project.godot
├── assets/                 # 像素素材/角色资源
├── scenes/
│   ├── main.tscn           # 主场景
│   └── ui/
│       ├── computer_panel.tscn
│       └── gomoku_game.tscn
├── scripts/
│   ├── GameMain.gd
│   ├── autoload/           # 全局单例：Game/Config/Memory/AI
│   ├── char/               # 角色控制
│   ├── logic/              # 寻路/状态机/行为
│   └── ui/                 # UI 脚本（电脑面板、五子棋）
├── data/                   # 配置与运行数据
├── setting/                # 地图/权重配置
├── doc/                    # 设计文档
└── README.md
```

## 后续计划

- 接入 AI 对话 API（`AIConnector.send_chat` 接口已预留）
- 继续扩展游戏模块（更多 AI 小游戏）
- 完善日记/好感度系统
- 多角色、房间编辑、TTS 等
