# P1 本周目标每日进度历史完成记录

日期：2026-06-03

## 范围

本轮继续完善 P1 结构化闭环，优先处理已经具备同步类型的「本周目标」。目标是把详情页里原本固定/预留的每日趋势，改为真实可保存、可同步、可回放的数据。

## 已完成

- `AppWeeklyGoal` 新增 `dailyProgress` 字段，结构为 `dateKey -> currentValue`。
- `AppWeeklyGoal.toJson` / `fromJson` 已覆盖 `dailyProgress`，字段会进入本地 JSON 和 `weekly_goal` 同步 data。
- 旧目标数据没有 `dailyProgress` 时保持兼容，默认空历史。
- 新增 `recordProgressForDate` 和 `progressForDate`，统一写入/读取每日进度。
- 首页目标打卡会记录当天进度历史。
- 本周目标页加减进度会记录当天进度历史。
- 本周目标页新增/编辑目标时会记录当天初始进度。
- 本周目标卡片展示最近 7 天真实柱状趋势；点击趋势可查看最近 7 天明细。
- `life_detail_pages.dart` 已替换为干净 UTF-8 实现，避免历史编码文件继续破坏构建。
- 新增 `test/weekly_goal_model_test.dart`，覆盖每日进度历史序列化、旧数据兼容和指定日期记录。

## 验证

- `flutter analyze`：通过，No issues found。
- `flutter test`：通过，27 tests。

## 剩余边界

- 本周目标仍按默认排序展示，拖拽排序尚未实现。
- 图标选择仍使用默认/编辑保留值，尚未做完整图标选择器。
- 管理端尚未增加 `weekly_goal` 的专门结构化展示页。
