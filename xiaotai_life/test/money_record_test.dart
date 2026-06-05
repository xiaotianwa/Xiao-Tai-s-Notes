import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/data/app_models.dart';
import 'package:xiaotai_life/features/life/presentation/money_page.dart';

void main() {
  test('AppMoneyRecord serializes amount as integer cents', () {
    final now = DateTime(2026, 5, 27, 10, 30);
    final record = AppMoneyRecord(
      id: 'money_1',
      type: 'expense',
      title: '晚餐',
      amountCents: 3280,
      category: '餐饮',
      happenedAt: now,
      createdAt: now,
      updatedAt: now,
      note: '两个人一起吃饭',
      owner: 'shared',
      paymentMethod: '微信',
    );

    final decoded = AppMoneyRecord.fromJson(record.toJson());

    expect(decoded.id, 'money_1');
    expect(decoded.amountCents, 3280);
    expect(decoded.signedAmountCents, -3280);
    expect(decoded.category, '餐饮');
    expect(decoded.owner, 'shared');
    expect(decoded.paymentMethod, '微信');
  });

  test('summarizeMoneyRecords only counts records in selected month', () {
    final records = [
      _record(
        id: 'expense_1',
        type: 'expense',
        cents: 1200,
        happenedAt: DateTime(2026, 5, 1),
      ),
      _record(
        id: 'income_1',
        type: 'income',
        cents: 50000,
        happenedAt: DateTime(2026, 5, 2),
      ),
      _record(
        id: 'expense_2',
        type: 'expense',
        cents: 900,
        happenedAt: DateTime(2026, 6, 1),
      ),
    ];

    final summary = summarizeMoneyRecords(records, month: DateTime(2026, 5));

    expect(summary.recordCount, 2);
    expect(summary.expenseCents, 1200);
    expect(summary.incomeCents, 50000);
    expect(summary.balanceCents, 48800);
  });

  test('AppMoneyRecord accepts legacy decimal amount payloads', () {
    final decoded = AppMoneyRecord.fromJson({
      'id': 'legacy_1',
      'type': 'income',
      'title': '报销',
      'amount': 12.35,
      'category': '报销',
      'happenedAt': '2026-05-27T00:00:00.000',
    });

    expect(decoded.amountCents, 1235);
    expect(decoded.signedAmountCents, 1235);
    expect(decoded.paymentMethod, '现金');
  });
  test('formatMoneySignedPlain keeps balance direction visible', () {
    expect(formatMoneySignedPlain(-1250), '-12.50');
    expect(formatMoneySignedPlain(1250), '+12.50');
    expect(formatMoneySignedPlain(0), '0.00');
  });
}

AppMoneyRecord _record({
  required String id,
  required String type,
  required int cents,
  required DateTime happenedAt,
}) {
  return AppMoneyRecord(
    id: id,
    type: type,
    title: id,
    amountCents: cents,
    category: type == 'income' ? '工资' : '餐饮',
    happenedAt: happenedAt,
    createdAt: happenedAt,
    updatedAt: happenedAt,
  );
}
