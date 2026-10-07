import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/screens/workers/statement.dart';
import 'package:khanak/types/factory.dart';
import 'package:khanak/types/work.dart';
import 'package:khanak/types/worker.dart';

LedgerLine _line(String date, {double credit = 0, double debit = 0, String kind = 'work'}) => LedgerLine(
  entryKind: kind,
  entryId: date,
  date: DateTime.parse(date),
  workTypeCode: 'molding',
  workTypeName: 'Molding',
  payUnit: PayUnit.per1000,
  quantity: 22000,
  rate: 550,
  credit: credit,
  debit: debit,
  note: 'A rather long note that has to be cut short so the row keeps its height on the page',
);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('pages', () {
    final first = StatementLayout.firstPageRows;
    final later = StatementLayout.laterPageRows;

    test('fit a full first page, then fuller later pages', () {
      expect(first, greaterThan(10));
      expect(later, greaterThan(first));
      expect(StatementLayout.pages(1), [1]);
      expect(StatementLayout.pages(first), [first]);
      expect(StatementLayout.pages(first + 1), [first, 1]);
      expect(StatementLayout.pages(first + later + 5), [first, later, 5]);
    });

    test('lose no rows', () {
      for (var rows = 1; rows < 200; rows++) {
        expect(StatementLayout.pages(rows).fold(0, (a, b) => a + b), rows);
      }
    });
  });

  group('rows', () {
    test('a season carries in what was owed before it, and ends at the balance', () {
      final statement = WorkerStatement(
        lines: [
          _line('2026-09-01', credit: 12100),
          _line('2026-09-05', debit: 5000, kind: 'advance'),
        ],
        totals: LedgerTotals.empty,
        // 3,000 owed from last season, plus 12,100 earned, less 5,000 given.
        balance: 10100,
        from: DateTime(2026, 8, 15),
      );
      expect(statement.opening, 3000);
      final rows = statementRows(statement);
      expect(rows.map((r) => r.balance), [3000, 15100, 10100, 10100]);
      expect(rows.last.strong, isTrue);
    });

    test('the whole account starts from nothing, with no row carried in', () {
      final statement = WorkerStatement(
        lines: [_line('2026-09-01', debit: 2000, kind: 'advance')],
        totals: LedgerTotals.empty,
        balance: -2000,
      );
      final rows = statementRows(statement);
      expect(rows.map((r) => r.balance), [-2000, -2000]);
    });
  });

  testWidgets('a full page of long rows fits on its paper', (tester) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('GoogleFonts')) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    tester.view.physicalSize = const Size(StatementLayout.pageWidth, StatementLayout.pageHeight * 2.2);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final lines = [for (var i = 0; i < 60; i++) _line('2026-09-01', credit: 1234567.5)];
    final statement = WorkerStatement(
      lines: lines,
      totals: const LedgerTotals(earned: 9876543, advances: 1234567, settled: 765432, recovered: 1000),
      balance: 7876544,
      from: DateTime(2026, 8, 15),
    );
    final rows = statementRows(statement);
    final pages = StatementLayout.pages(rows.length);
    const worker = Worker(
      id: 'w',
      name: 'Rameshbhai Somabhai Vasava with a very long name',
      village: 'Kalol, a village far away',
      phone: '9876543210',
      isActive: true,
    );
    final factory = Factory.fromJson({
      'id': 'f',
      'name': 'Shree Ambika Brick Works and Trading Company',
      'city': 'Surat',
      'role': 'owner',
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: SingleChildScrollView(
          child: Column(
            children: [
              StatementPage(
                factory: factory,
                worker: worker,
                statement: statement,
                period: null,
                rows: rows.sublist(0, pages[0]),
                number: 1,
                count: pages.length,
              ),
              StatementPage(
                factory: factory,
                worker: worker,
                statement: statement,
                period: null,
                rows: rows.sublist(pages[0], pages[0] + pages[1]),
                number: 2,
                count: pages.length,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(StatementPage), findsNWidgets(2));
  });
}
