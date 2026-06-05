# 本周目标 UI 接口与字段预留记录

## 已完成 UI

- 目标列表页：本周目标标题、进度总览、目标卡片列表、添加目标入口、管理入口。
- 添加 / 编辑目标页：图标占位、目标名称、目标值、单位、当前进度、颜色选择、顶部保存。
- 目标详情 / 进度页：目标小卡、环形进度、目标值/已完成/剩余统计、每日完成情况图表、进度加减入口。
- 首页快捷打卡卡片：同步为本周目标样式，已接入本地 `AppWeeklyGoal`，无真实目标时展示添加入口。
- 管理 / 删除页：多选目标、拖拽排序入口、删除确认区。

## 字段与接口预留

- `iconImagePath`: 添加页“点击选择图标”目前为 UI 预留，当前 `AppWeeklyGoal` 只保存 `iconName`。
- `dailyProgressHistory`: 详情页每日完成柱状图目前为展示占位，后续需要按日期记录每日进度。
- `sortIndex`: 管理页拖拽排序入口已预留，当前模型暂无排序字段。
- `quickCheckInSource`: 首页快捷打卡已接入本地目标数据，后续聚合接口只需返回首页展示优先级。
- `unitPreset`: 单位区域按参考图展示，后续可接入单位下拉选项。
- `deleteConfirmation`: 目标支持删除确认。

## 建议后续模型扩展

```json
{
  "iconImagePath": "local://goal-icons/water.png",
  "dailyProgressHistory": [
    { "date": "2026-06-01", "targetValue": 8, "currentValue": 6 }
  ],
  "sortIndex": 1,
  "unitPreset": "cup",
  "quickCheckInSource": "weekly_goals"
}
```
