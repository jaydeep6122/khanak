import 'package:flutter/material.dart';
import 'package:khanak/core/modules/authModule.dart';
import 'package:khanak/core/modules/entryModule.dart';
import 'package:khanak/core/modules/factoryModule.dart';
import 'package:khanak/core/modules/reportModule.dart';
import 'package:khanak/core/modules/settingsModule.dart';
import 'package:khanak/core/modules/tradeModule.dart';
import 'package:khanak/core/modules/workerModule.dart';

class Core extends ChangeNotifier {
  late final AuthModule auth;
  late final FactoryModule factory;
  late final WorkerModule worker;
  late final EntryModule entry;
  late final ReportModule report;
  late final TradeModule trade;
  late final SettingsModule settings;

  static Core? _instance;
  static Core get() => _instance!;

  Core._() {
    _instance = this;
    auth = AuthModule(this);
    factory = FactoryModule(this);
    worker = WorkerModule(this);
    entry = EntryModule(this);
    report = ReportModule(this);
    trade = TradeModule(this);
    settings = SettingsModule(this);
  }

  factory Core() => _instance ?? Core._();

  void notify() => notifyListeners();

  /// Drops everything loaded for the open factory (on switching factory or
  /// signing out).
  void resetFactoryData() {
    worker.clear();
    entry.clear();
    report.clear();
    trade.clear();
    notify();
  }

  /// Pay, advances or stock changed on the server: balances, lists and
  /// totals reload the next time they are shown.
  void markBooksChanged() {
    worker.markStale();
    entry.markStale();
    report.markStale();
    trade.markStale();
  }
}
