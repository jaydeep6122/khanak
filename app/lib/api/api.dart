import 'package:dio/dio.dart';
import 'package:khanak/api/modules/app.dart';
import 'package:khanak/api/modules/auth.dart';
import 'package:khanak/api/modules/entry.dart';
import 'package:khanak/api/modules/factory.dart';
import 'package:khanak/api/modules/report.dart';
import 'package:khanak/api/modules/trade.dart';
import 'package:khanak/api/modules/worker.dart';

class Api {
  static late final Api _instance;
  static Api get instance => _instance;

  late final AppApi app;
  late final AuthApi auth;
  late final FactoryApi factory;
  late final WorkerApi worker;
  late final EntryApi entry;
  late final ReportApi report;
  late final TradeApi trade;

  Api._internal(Dio dio) {
    app = AppApi(dio);
    auth = AuthApi(dio);
    factory = FactoryApi(dio);
    worker = WorkerApi(dio);
    entry = EntryApi(dio);
    report = ReportApi(dio);
    trade = TradeApi(dio);
  }

  static void initialize(Dio dio) {
    _instance = Api._internal(dio);
  }
}
