# 第三方素材与许可声明

> 最后更新：2026-09-13
> 本文件说明仓库 / 发布包中非本项目原创内容及其授权状态。角色替换计划见 [`doc/正式角色计划.md`](doc/正式角色计划.md)。

## 1. 引擎与依赖

| 组件 | 版本 | 许可 | 说明 |
|---|---|---|---|
| Godot Engine | 4.7.2 stable | MIT | 游戏引擎；导出包内含引擎二进制，版权归 Godot Engine contributors |

本项目未使用第三方 GDScript 插件或运行库。

## 2. 角色素材

### char_03「梅尔」— ⚠️ 未获授权，仅开发 / 预览

- 涉及文件：`assets/chars/char_03/` 全部（含 `mea原图.png`、`portrait.png`、`portraits/`、`sprites/`、`Mea人设.md`、`persona.json` 等）
- 来源：外部作品《霞流宝石心》世界观角色（见 `assets/chars/char_03/persona.json` 的 `origin` 字段）
- 授权状态：**未取得授权**，不属于本项目可分发素材；不因收录于本仓库而获得任何授权
- 处理计划：替换为原创正式角色后，从仓库、发布包与后续版本中移除
- 已知风险：v0.1.0 发布包（`AIHome-win64.zip` / `AIHome.pck`）内包含该素材，**请勿再分发**；后续版本将移除

### char_01「小灯」

- 授权状态：来源未记录（`persona.json` 无 `origin` 字段）
- 处理：补充来源说明，或一并替换

## 3. 其他资源

| 资源 | 状态 |
|---|---|
| `assets/ui/*.svg`、`icon.svg` | 项目内制作（待最终确认） |
| `theme/ui_theme.tres` | 项目内制作（代码资源，适用 MIT） |
| `assets/sfx/notify.wav` | 来源未记录，待补充授权信息 |
| `assets/bgm/` | 仓库不含音频文件；玩家自备，不随发布包分发 |
| `tools/gen_bgm.py` | 项目内代码（适用 MIT） |

## 4. 授权边界

- 代码（`scripts/`、`tools/`、`project.godot`、`export_presets.cfg` 等）：MIT，见 [`LICENSE`](LICENSE)
- 美术 / 音频 / 图标 / 主题 / 示例数据等素材：除本文件另有说明外，保留所有权利
- 上述未授权第三方素材不属于本项目可分发内容

## 5. 待办

- [ ] `char_03` 移除（正式角色替换完成后）
- [ ] `char_01` 来源确认或替换
- [ ] `assets/sfx/notify.wav` 来源确认
- [ ] 每次发布前扫描导出包，确认不含 `char_03` / `mea` 相关素材
