# 首页 UI 接口与素材预留记录

本文件记录首页聚合数据契约。当前首页不再展示内置样例记录；所有卡片内容来自本地数据库 / 同步数据，接口无数据时展示空状态。

## 聚合接口预留

建议新增 `GET /api/v1/home/overview`，一次返回首页所需聚合数据，避免首页多接口串行加载。

```json
{
  "profile": {
    "displayName": "用户昵称",
    "greeting": "问候语"
  },
  "latestDiary": {
    "title": "日记标题",
    "summary": "日记摘要",
    "imageUrl": "https://...",
    "createdAt": "2026-06-03T10:00:00+08:00"
  },
  "todayReminders": [
    { "remindAt": "2026-06-03T10:00:00+08:00", "title": "提醒标题" }
  ],
  "anniversary": {
    "title": "纪念日标题",
    "days": 0,
    "date": "2026-06-03"
  },
  "weather": {
    "temp": "25",
    "text": "多云",
    "rangeText": "",
    "airText": "",
    "locationText": ""
  },
  "weeklyGoals": [
    { "icon": "goal", "title": "目标标题", "progress": 0.75, "valueText": "6/8" }
  ],
  "moodCalendar": {
    "monthText": "2026年6月",
    "cells": []
  }
}
```

## 当前数据策略

- 首页姓名、日记、提醒、纪念日、心情日历、小目标均读取本地数据库 / 同步数据。
- 天气卡保留已有 `QWeatherService`；接口无数据时展示中性空态，不使用设计图固定值。
- 小目标首页卡片只展示真实 `AppWeeklyGoal`；无目标时展示添加入口，不自动创建默认目标。
- 心情日历按当前月份和真实备忘录心情数据生成。
- 本周小结模块已按最新 UI 要求移除。

## 素材预留

- 首页顶部吉祥物按主题读取 `AppThemeAssets.homeMascot`：默认主题为 `assets/themes/default/home_mascot.png`，其他主题已有独立占位路径。
- 纪念日爱心、天气云朵目前用 Flutter `CustomPainter` 绘制占位。
- 快捷入口和底部导航图标当前使用 Material Icons，占位替代 iconfont。
- 后续如从 iconfont.cn 下载图标，建议统一放入 `assets/icons/home/`，并在 `pubspec.yaml` 注册。
- 最近日记缩略图仅在记录存在真实图片时展示。
