import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:khanak/components/errorWidget.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/components/saveBar.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/core/components/getters.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/toastNotifications.dart';
import 'package:khanak/types/factory.dart';
import 'package:khanak/types/work.dart';
import 'package:khanak/types/worker.dart';

/// How a statement is laid out on A4 paper, in PDF points. Every row has the
/// same height, so the lines can be split into pages before anything is drawn.
class StatementLayout {
  StatementLayout._();

  static const pageWidth = 595.0;
  static const pageHeight = 842.0;
  static const margin = 32.0;
  static const firstHeader = 236.0;
  static const laterHeader = 40.0;
  static const tableHeader = 26.0;
  static const footer = 24.0;
  static const row = 32.0;

  static const _body = pageHeight - 2 * margin - footer - tableHeader;
  static final firstPageRows = ((_body - firstHeader) / row).floor();
  static final laterPageRows = ((_body - laterHeader) / row).floor();

  /// [rows] split into pages: how many go on each. Always at least one page,
  /// so a worker with nothing yet still gets their summary.
  static List<int> pages(int rows) {
    final pages = <int>[];
    var left = rows;
    var room = firstPageRows;
    do {
      final take = left < room ? left : room;
      pages.add(take);
      left -= take;
      room = laterPageRows;
    } while (left > 0);
    return pages;
  }
}

/// One row of the table: a line of the account, the balance carried in, or
/// the balance at the end.
class StatementRow {
  final DateTime? date;
  final String title;
  final String? detail;
  final double plus;
  final double minus;
  final double balance;
  final bool strong;

  const StatementRow({
    this.date,
    required this.title,
    this.detail,
    this.plus = 0,
    this.minus = 0,
    required this.balance,
    this.strong = false,
  });
}

/// The table for [statement]: the balance carried in (for a season), every
/// line with the balance after it, and the balance now.
List<StatementRow> statementRows(WorkerStatement statement) {
  final rows = <StatementRow>[];
  var running = statement.opening;
  if (statement.from != null && running.abs() >= 0.005) {
    rows.add(StatementRow(date: statement.from, title: 'statement_brought_forward'.tr(), balance: running));
  }
  for (final line in statement.lines) {
    running += line.amount;
    rows.add(
      StatementRow(
        date: line.date,
        title: line.title,
        detail: line.detail,
        plus: line.credit,
        minus: line.debit,
        balance: running,
      ),
    );
  }
  rows.add(StatementRow(title: 'statement_balance_now'.tr(), balance: statement.balance, strong: true));
  return rows;
}

/// A worker's account as pages of paper, to look over and then share as a
/// PDF. The pages are drawn by Flutter and saved as pictures, because the
/// PDF library cannot shape Gujarati or Hindi text.
class StatementScreen extends StatefulWidget {
  final Worker worker;

  /// Only this season, or the whole account when null.
  final Period? period;

  const StatementScreen({super.key, required this.worker, this.period});

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  WorkerStatement? _statement;
  String? _error;
  bool _sharing = false;
  final List<GlobalKey> _pageKeys = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final module = context.read<Core>().worker;
    setState(() => _error = null);
    final statement = await module.fetchStatement(widget.worker.id, period: widget.period);
    if (!mounted) return;
    setState(() {
      _statement = statement;
      _error = statement == null ? (module.error ?? 'error_generic'.tr()) : null;
    });
  }

  Future<void> _share() async {
    final factory = context.read<Core>().openFactory?.name ?? '';
    setState(() => _sharing = true);
    try {
      final document = pw.Document(title: 'statement_title'.tr(), creator: 'Khanak');
      for (final key in _pageKeys) {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        // 2.5 pixels a point: sharp when zoomed on a phone, small enough for WhatsApp.
        final image = await boundary.toImage(pixelRatio: 2.5);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(pw.MemoryImage(png!.buffer.asUint8List()), fit: pw.BoxFit.fill),
          ),
        );
      }
      final bytes = await document.save();
      // Names may be in Gujarati or Hindi; only what file names cannot hold goes.
      final cleanName = widget.worker.name
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '-');
      final name = '$cleanName-${Formatters.apiDateFormat(DateTime.now())}.pdf';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: name)],
          fileNameOverrides: [name],
          text: 'statement_message'.tr(namedArgs: {'name': widget.worker.name, 'factory': factory}),
        ),
      );
    } catch (_) {
      showErrorToast('statement_share_failed'.tr());
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statement = _statement;
    final colors = context.colors;
    final factory = context.read<Core>().openFactory;

    Widget body;
    if (_error != null) {
      body = AppErrorWidget(errorMessage: _error!, onRetry: _load);
    } else if (statement == null) {
      body = const LoadingIndicator();
    } else {
      final rows = statementRows(statement);
      final pages = StatementLayout.pages(rows.length);
      while (_pageKeys.length < pages.length) {
        _pageKeys.add(GlobalKey());
      }
      _pageKeys.length = pages.length;
      var start = 0;
      final pageWidgets = <Widget>[];
      for (var i = 0; i < pages.length; i++) {
        pageWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceLg),
            child: DecoratedBox(
              decoration: BoxDecoration(boxShadow: context.cardShadow),
              // The page keeps its paper size; it is only shown smaller.
              child: FittedBox(
                child: RepaintBoundary(
                  key: _pageKeys[i],
                  child: StatementPage(
                    factory: factory,
                    worker: widget.worker,
                    statement: statement,
                    period: widget.period,
                    rows: rows.sublist(start, start + pages[i]),
                    number: i + 1,
                    count: pages.length,
                  ),
                ),
              ),
            ),
          ),
        );
        start += pages[i];
      }
      body = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppTheme.spaceXl, AppTheme.spaceSm, AppTheme.spaceXl, AppTheme.fabClearance),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: pageWidgets),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: colors.background,
      appBar: AppBar(title: Text('statement'.tr())),
      bottomNavigationBar: statement == null
          ? null
          : SaveBar(label: 'statement_share'.tr(), isLoading: _sharing, onPressed: _share),
      body: body,
    );
  }
}

// Paper is white with dark ink whatever the phone's theme.
const _ink = Color(0xFF1C1917);
const _muted = Color(0xFF6B6560);
const _rule = Color(0xFFE7E2DC);
const _shade = Color(0xFFF6F3EF);
const _green = AppTheme.success;
const _red = AppTheme.error;
const _brick = AppTheme.primary;

/// One sheet of A4, laid out in points.
class StatementPage extends StatelessWidget {
  final Factory? factory;
  final Worker worker;
  final WorkerStatement statement;
  final Period? period;
  final List<StatementRow> rows;
  final int number;
  final int count;

  const StatementPage({
    super.key,
    required this.factory,
    required this.worker,
    required this.statement,
    required this.period,
    required this.rows,
    required this.number,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(color: _ink, fontSize: 10, height: 1.25);

    return MediaQuery(
      // The layout is counted in points; the phone's text size must not move it.
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: DefaultTextStyle(
        style: base,
        child: Container(
          width: StatementLayout.pageWidth,
          height: StatementLayout.pageHeight,
          color: Colors.white,
          padding: const EdgeInsets.all(StatementLayout.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (number == 1)
                SizedBox(
                  height: StatementLayout.firstHeader,
                  child: _FirstHeader(worker: worker, statement: statement, period: period, factory: factory),
                )
              else
                SizedBox(
                  height: StatementLayout.laterHeader,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      '${worker.name} · ${'statement_title'.tr()}',
                      style: base.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              const _TableHeader(),
              for (final row in rows) _TableRow(row: row),
              const Spacer(),
              SizedBox(
                height: StatementLayout.footer,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'statement_made_by'.tr(namedArgs: {'factory': factory?.name ?? ''}),
                        style: base.copyWith(fontSize: 8, color: _muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'statement_page'.tr(namedArgs: {'page': '$number', 'pages': '$count'}),
                      style: base.copyWith(fontSize: 8, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstHeader extends StatelessWidget {
  final Worker worker;
  final WorkerStatement statement;
  final Period? period;
  final Factory? factory;

  const _FirstHeader({required this.worker, required this.statement, required this.period, required this.factory});

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    final totals = statement.totals;
    final balance = statement.balance;
    final (balanceLabel, balanceColor) = balance > 0.004
        ? ('statement_due_to'.tr(namedArgs: {'name': worker.name}), _red)
        : balance < -0.004
        ? ('statement_due_from'.tr(namedArgs: {'name': worker.name}), _green)
        : ('settled_up'.tr(), _muted);
    final range = period == null
        ? 'statement_whole'.tr()
        : '${period!.name ?? 'statement_this_season'.tr()}: ${Formatters.formatDate(period!.startedOn)} – '
              '${Formatters.formatDate(period!.endedOn ?? DateTime.now())}';

    Widget box(String label, double amount) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: _shade, borderRadius: BorderRadius.circular(6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: base.copyWith(fontSize: 8, color: _muted),
            ),
            Text(
              Formatters.formatCurrency(amount),
              maxLines: 1,
              style: base.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    factory?.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (factory?.city != null) Text(factory!.city!, style: base.copyWith(fontSize: 9, color: _muted)),
                ],
              ),
            ),
            Text(
              'statement_title'.tr(),
              style: base.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: _brick),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          worker.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        Text(
          [worker.mainWork.displayName, ?worker.village, ?worker.phone].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(color: _muted),
        ),
        const SizedBox(height: 8),
        Text(range, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          'statement_made_on'.tr(namedArgs: {'date': Formatters.formatDate(DateTime.now())}),
          style: base.copyWith(fontSize: 8, color: _muted),
        ),
        const SizedBox(height: 12),
        Row(
          spacing: 6,
          children: [
            box('earned'.tr(), totals.earned),
            box('advances_given'.tr(), totals.advances),
            box('settled'.tr(), totals.settled),
            if (totals.recovered >= 0.005) box('txn_recovery'.tr(), totals.recovered),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: balanceColor.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  balanceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: base.copyWith(fontSize: 11, color: balanceColor, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                Formatters.formatCurrency(balance.abs()),
                style: base.copyWith(fontSize: 16, color: balanceColor, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          'statement_sign_note'.tr(namedArgs: {'name': worker.name}),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(fontSize: 8, color: _muted),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// Column widths in points; the detail takes what is left.
const _dateWidth = 72.0;
const _amountWidth = 76.0;
const _balanceWidth = 84.0;

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(
      context,
    ).style.copyWith(fontSize: 8.5, color: _muted, fontWeight: FontWeight.w600);
    Widget cell(String text, double? width, {TextAlign align = TextAlign.right}) {
      final child = Text(text, style: style, textAlign: align, maxLines: 1, overflow: TextOverflow.ellipsis);
      return width == null ? Expanded(child: child) : SizedBox(width: width, child: child);
    }

    return Container(
      height: StatementLayout.tableHeader,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _ink, width: 0.8)),
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          cell('statement_col_date'.tr(), _dateWidth, align: TextAlign.left),
          cell('statement_col_detail'.tr(), null, align: TextAlign.left),
          cell('statement_col_plus'.tr(), _amountWidth),
          cell('statement_col_minus'.tr(), _amountWidth),
          cell('statement_col_balance'.tr(), _balanceWidth),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final StatementRow row;

  const _TableRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    final weight = row.strong ? FontWeight.w700 : FontWeight.w400;
    String amount(double value) => value >= 0.005 ? Formatters.formatCurrency(value) : '';
    final balanceText = '${row.balance < -0.004 ? '−' : ''}${Formatters.formatCurrency(row.balance.abs())}';

    Widget amountCell(String text, double width, Color color) => SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.right,
        maxLines: 1,
        style: base.copyWith(color: color, fontWeight: weight),
      ),
    );

    return Container(
      height: StatementLayout.row,
      decoration: BoxDecoration(
        color: row.strong ? _shade : null,
        border: const Border(bottom: BorderSide(color: _rule, width: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _dateWidth,
            child: Text(
              // With the year: a whole account can run over several.
              row.date == null ? '' : Formatters.formatDate(row.date!),
              maxLines: 1,
              style: base.copyWith(color: _muted),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: base.copyWith(fontWeight: row.strong ? FontWeight.w700 : FontWeight.w600),
                ),
                if (row.detail != null)
                  Text(
                    row.detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: base.copyWith(fontSize: 8, color: _muted),
                  ),
              ],
            ),
          ),
          amountCell(amount(row.plus), _amountWidth, _green),
          amountCell(amount(row.minus), _amountWidth, _red),
          amountCell(balanceText, _balanceWidth, _ink),
        ],
      ),
    );
  }
}
