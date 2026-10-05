import 'package:flutter/cupertino.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

PageRoute<T> getPageRoute<T>(Widget child, {RouteSettings? settings}) {
  return CupertinoPageRoute(builder: (context) => child, settings: settings);
}
