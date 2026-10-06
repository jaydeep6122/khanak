import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/components/appCard.dart';
import 'package:khanak/components/errorWidget.dart';
import 'package:khanak/components/formBits.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/components/sectionHeader.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';
import 'package:khanak/helpers/json.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/trade/expenseForm.dart';
import 'package:khanak/types/factory.dart';
import 'package:khanak/types/trade.dart';

enum _Range { month, thirtyDays, season, all }

/// Whether the truck earns its keep: trips, delivery charges billed (and
/// trips that billed none), diesel, upkeep and loaders' pay, and what each
/// full tank gave. An average well below the usual is flagged.
class TruckReportScreen extends StatefulWidget {
  final Truck truck;

  const TruckReportScreen({super.key, required this.truck});

  @override
  State<TruckReportScreen> createState() => _TruckReportScreenState();
}

class _TruckReportScreenState extends State<TruckReportScreen> {
  _Range _range = _Range.month;
  TruckReport? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  DateTime? get _from {
    final now = DateTime.now();
    return switch (_range) {
      _Range.month => DateTime(now.year, now.month, 1),
      _Range.thirtyDays => now.subtract(const Duration(days: 30)),
      _Range.season => context.read<Core>().factory.selected?.period?.startedOn,
      _Range.all => null,
    };
  }

  Future<void> _load() async {
    setState(() {
      _report = null;
      _error = null;
    });
    final trade = context.read<Core>().trade;
    final from = _from;
    final report = await trade.truckReport(widget.truck.id, from: from == null ? null : apiDate(from));
    if (!mounted) return;
    setState(() {
      _report = report;
      _error = report == null ? (trade.error ?? 'error_generic'.tr()) : null;
    });
  }

  Future<void> _addDiesel() async {
    final changed = await Navigator.of(context).push(
      getPageRoute(ExpenseFormScreen(category: ExpenseCategory.diesel, truck: widget.truck)),
    );
    if (changed != null && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(widget.truck.label)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDiesel,
        icon: const Icon(Icons.local_gas_station_rounded),
        label: Text('add_diesel'.tr()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceSm),
            child: ChoiceRow<_Range>(
              options: _Range.values,
              selected: _range,
              label: (r) => 'range_${r.name}'.tr(),
              onSelected: (r) {
                setState(() => _range = r);
                _load();
              },
            ),
          ),
          Expanded(
            child: _error != null
                ? AppErrorWidget(errorMessage: _error!, onRetry: _load)
                : report == null
                ? const LoadingIndicator()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.fabClearance),
                      children: [
                        AppCard(
                          color: report.profit >= 0 ? colors.successSoft : colors.dangerSoft,
                          borderColor: report.profit >= 0 ? colors.successSoft : colors.dangerSoft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(report.profit >= 0 ? 'truck_profit'.tr() : 'truck_loss'.tr(), style: context.text.bodyLarge),
                              Text(
                                Formatters.formatCurrency(report.profit.abs()),
                                style: context.text.headlineMedium?.copyWith(
                                  color: report.profit >= 0 ? colors.success : colors.danger,
                                ),
                              ),
                              if (report.profitPerTrip != null)
                                Text(
                                  'per_trip_line'.tr(namedArgs: {'amount': Formatters.formatCurrency(report.profitPerTrip!)}),
                                  style: context.text.bodyMedium,
                                ),
                              Text('driver_salary_not_included'.tr(), style: context.text.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        AppCard(
                          child: Column(
                            children: [
                              _Line('trips_total'.tr(), '${report.totalTrips}'),
                              _Line('trips_sales'.tr(), '${report.salesTrips}'),
                              _Line('trips_kiln'.tr(), '${report.kilnTrips}'),
                              _Line(
                                'trips_without_bhadu'.tr(),
                                '${report.tripsWithoutBhadu}',
                                color: report.tripsWithoutBhadu > 0 ? colors.warning : null,
                              ),
                              const Divider(height: AppTheme.spaceLg),
                              _Line('bhadu_earned'.tr(), Formatters.formatCurrency(report.bhadu), color: colors.success),
                              _Line(
                                'diesel_cost'.tr(),
                                '${Formatters.formatCurrency(report.diesel)} · ${Formatters.formatCount(report.litres)} L',
                              ),
                              _Line('upkeep_cost'.tr(), Formatters.formatCurrency(report.upkeep)),
                              _Line('loaders_cost'.tr(), Formatters.formatCurrency(report.loaders)),
                            ],
                          ),
                        ),
                        SectionHeader(title: 'diesel_fills'.tr(), padding: const EdgeInsets.only(top: AppTheme.spaceLg)),
                        if (report.fuel.isEmpty) Text('no_diesel_yet'.tr(), style: context.text.bodyMedium),
                        for (final fill in report.fuel.reversed) ...[
                          AppCard(
                            borderColor: fill.lowAverage ? colors.danger : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(Formatters.formatDate(fill.date), style: context.text.titleSmall)),
                                    Text(Formatters.formatCurrency(fill.amount), style: context.text.titleSmall),
                                  ],
                                ),
                                Text(
                                  [
                                    if (fill.litres != null) '${Formatters.formatCount(fill.litres!)} L',
                                    if (fill.odometer != null) 'odometer_line'.tr(namedArgs: {'km': '${fill.odometer}'}),
                                  ].join(' · '),
                                  style: context.text.bodySmall,
                                ),
                                if (fill.trips != null)
                                  Text(
                                    [
                                      'fill_trips'.tr(namedArgs: {'count': '${fill.trips}'}),
                                      if (fill.km != null) '${fill.km} km',
                                      if (fill.kmPerLitre != null) '${Formatters.formatCount(fill.kmPerLitre!)} km/L',
                                      if (fill.perTrip != null)
                                        'per_trip_line'.tr(namedArgs: {'amount': Formatters.formatCurrency(fill.perTrip!)}),
                                    ].join(' · '),
                                    style: context.text.bodyMedium,
                                  ),
                                if (fill.lowAverage)
                                  Text(
                                    'low_average_warning'.tr(),
                                    style: context.text.bodyMedium?.copyWith(color: colors.danger, fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.spaceSm),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Line(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodyLarge)),
          Text(value, style: context.text.titleSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}
