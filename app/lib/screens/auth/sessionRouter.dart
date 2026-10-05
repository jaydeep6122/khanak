import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khanak/core/Core.dart';
import 'package:khanak/helpers/navigation.dart';
import 'package:khanak/screens/factory/form.dart';
import 'package:khanak/screens/factory/list.dart';
import 'package:khanak/screens/home/home.dart';

/// After signing in: set up a first factory, pick one, or open the app.
Future<void> openAfterSignIn(BuildContext context) async {
  final factory = context.read<Core>().factory;
  final navigator = Navigator.of(context);

  await factory.fetchFactories();

  final Widget next;
  if (factory.factories.isEmpty) {
    next = const FactoryFormScreen(isOnboarding: true);
  } else if (factory.selected != null) {
    next = const HomeScreen();
  } else {
    next = const FactoryListScreen(isRoot: true);
  }
  navigator.pushAndRemoveUntil(getPageRoute(next), (_) => false);
}
