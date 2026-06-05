import 'dart:convert';

import 'bigmodel_service.dart';

class AiActionParser {
  AiActionParser._();

  static final instance = AiActionParser._();

  Future<AiPendingAction?> parse(String userMessage, DateTime now) async {
    final prompt = _buildPrompt(userMessage, now);
    final raw = await BigModelService.instance.chat(prompt);
    final decoded = _decodeJsonObject(raw);
    if (decoded == null) {
      return null;
    }
    final type = decoded['type'] as String?;
    if (type != 'create_money_record') {
      return null;
    }
    final record = decoded['record'];
    if (record is! Map<String, dynamic>) {
      return null;
    }
    return _parseMoneyRecord(record, decoded, now);
  }

  String _buildPrompt(String userMessage, DateTime now) {
    final today = _dateOnly(now);
    return '''
你是 App 的动作识别器，只负责把用户自然语言转换成 JSON。
当前日期：$today。

只支持识别记账动作。用户不是明确要记账、支出、花费、收入、到账时，输出：
{"type":"none"}

如果用户要记账，输出严格 JSON，不要 Markdown，不要解释：
{
  "type": "create_money_record",
  "record": {
    "moneyType": "expense 或 income",
    "title": "账目名称，尽量短",
    "amountYuan": 数字,
    "category": "餐饮/交通/购物/约会/居家/工资/奖金/报销/礼物/其他",
    "date": "YYYY-MM-DD",
    "note": "可为空"
  },
  "speech": "已识别：今天午饭花了30元，请查看并确认。"
}

规则：
- “花了、花费、支出、买、吃、午饭、晚餐、打车”通常是 expense。
- “收入、工资、到账、报销、奖金”通常是 income。
- 不确定分类时用“其他”。
- 日期缺失时用当前日期 $today。
- 金额必须转成元，不要带单位。

用户原话：
$userMessage
''';
  }

  AiPendingAction? _parseMoneyRecord(
    Map<String, dynamic> record,
    Map<String, dynamic> root,
    DateTime now,
  ) {
    final moneyType = record['moneyType'] as String?;
    final type = moneyType == 'income' ? 'income' : 'expense';
    final amount = record['amountYuan'];
    final amountYuan = amount is num
        ? amount.toDouble()
        : double.tryParse('${amount ?? ''}');
    if (amountYuan == null || amountYuan <= 0) {
      return null;
    }
    final title = _cleanText(record['title'] as String?);
    if (title.isEmpty) {
      return null;
    }
    final category = _normalizeCategory(
      _cleanText(record['category'] as String?),
      type,
    );
    final happenedAt = _parseDate(record['date'] as String?, now);
    final amountCents = (amountYuan * 100).round();
    if (amountCents <= 0) {
      return null;
    }
    final note = _cleanText(record['note'] as String?);
    final speech = _cleanText(root['speech'] as String?);
    return AiCreateMoneyRecordAction(
      type: type,
      title: title,
      amountCents: amountCents,
      category: category,
      happenedAt: happenedAt,
      note: note,
      speech: speech.isEmpty
          ? '已识别：${_dateLabel(happenedAt, now)}$title${type == 'income' ? '收入' : '花了'}${_formatMoney(amountCents)}，请查看并确认。'
          : speech,
    );
  }

  Map<String, dynamic>? _decodeJsonObject(String raw) {
    final trimmed = raw.trim();
    for (final candidate in [
      trimmed,
      _between(trimmed, '```json', '```'),
      _between(trimmed, '```', '```'),
      _between(trimmed, '{', '}'),
    ]) {
      if (candidate == null || candidate.trim().isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(candidate.trim());
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  String? _between(String value, String start, String end) {
    final startIndex = value.indexOf(start);
    if (startIndex == -1) {
      return null;
    }
    final contentStart = startIndex + start.length;
    final endIndex = value.lastIndexOf(end);
    if (endIndex <= contentStart) {
      return null;
    }
    final candidate = value.substring(contentStart, endIndex);
    if (start == '{') {
      return '{$candidate}';
    }
    return candidate;
  }

  String _cleanText(String? value) {
    return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeCategory(String value, String type) {
    final incomeCategories = {'工资', '奖金', '报销', '礼物', '其他'};
    final expenseCategories = {'餐饮', '交通', '购物', '约会', '居家', '其他'};
    final categories = type == 'income' ? incomeCategories : expenseCategories;
    if (categories.contains(value)) {
      return value;
    }
    return '其他';
  }

  DateTime _parseDate(String? value, DateTime now) {
    if (value == null || value.trim().isEmpty) {
      return now;
    }
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return now;
    }
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      now.hour,
      now.minute,
    );
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _dateLabel(DateTime value, DateTime now) {
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return '今天';
    }
    return '${value.month}月${value.day}日';
  }

  String _formatMoney(int cents) {
    final yuan = cents ~/ 100;
    final cent = cents % 100;
    if (cent == 0) {
      return '$yuan元';
    }
    return '$yuan.${cent.toString().padLeft(2, '0')}元';
  }
}

sealed class AiPendingAction {
  const AiPendingAction({required this.speech});

  final String speech;
}

class AiCreateMoneyRecordAction extends AiPendingAction {
  const AiCreateMoneyRecordAction({
    required this.type,
    required this.title,
    required this.amountCents,
    required this.category,
    required this.happenedAt,
    required this.note,
    required super.speech,
  });

  final String type;
  final String title;
  final int amountCents;
  final String category;
  final DateTime happenedAt;
  final String note;

  bool get isIncome => type == 'income';
}
