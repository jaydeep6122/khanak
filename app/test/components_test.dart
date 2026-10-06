import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:khanak/components/amountDialog.dart';
import 'package:khanak/components/bigNumberField.dart';
import 'package:khanak/components/floatingTabBar.dart';
import 'package:khanak/components/groupedSection.dart';
import 'package:khanak/components/saveBar.dart';
import 'package:khanak/components/segmentedControl.dart';
import 'package:khanak/components/tint.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/global/themes.dart';
import 'package:khanak/helpers/formatters.dart';

// The shared pieces must fit a small phone with long Gujarati labels.
void main() {
  // Fonts are fetched on a phone, not in tests; the fallback font is enough
  // to measure layout.
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(WidgetTester tester, Widget child, {Widget? bottom}) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(extendBody: true, body: child, bottomNavigationBar: bottom),
      ),
    );
    await tester.pump();
  }

  // Unloaded fonts are reported as errors; only layout errors matter here.
  void ignoreFontErrors() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('GoogleFonts')) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  test('counts are grouped the Indian way', () {
    expect(Formatters.formatCount(245000), '2,45,000');
    expect(Formatters.formatCount(22000), '22,000');
    expect(Formatters.formatCount(12.5), '12.5');
  });

  test('a count reason is where the bricks went and how', () {
    expect(CountReason.of(CountPlace.drying, byTruck: true), CountReason.dryingByTruck);
    expect(CountReason.of(CountPlace.kiln, byTruck: false), CountReason.kilnByWorkers);
    expect(CountReason.of(CountPlace.last, byTruck: true), CountReason.finalCount);
    expect(CountReason.dryingByWorkers.carried, isTrue);
    expect(CountReason.finalCount.carried, isFalse);
    expect(CountReason.dryingByTruck.intoKiln, isFalse);
    expect(CountReason.fromString('drying_by_truck').byTruck, isTrue);
  });

  testWidgets('tab bar with five long labels fits', (tester) async {
    ignoreFontErrors();
    var opened = false;
    await pump(
      tester,
      const SizedBox(),
      bottom: FloatingTabBar(
        selected: 0,
        onSelected: (_) {},
        centerLabel: 'નવી એન્ટ્રી',
        onCenter: () => opened = true,
        tabs: const [
          FloatingTab(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'હોમ'),
          FloatingTab(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'મજૂર'),
          FloatingTab(icon: Icons.wallet_outlined, selectedIcon: Icons.wallet, label: 'ઉધાર'),
          FloatingTab(icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view, label: 'વધુ'),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.add_rounded));
    expect(opened, isTrue);
  });

  testWidgets('form pieces lay out and the quick buttons add', (tester) async {
    ignoreFontErrors();
    final controller = TextEditingController();
    var reason = 'a';
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedControl<String>(
              options: const ['a', 'b', 'c', 'd'],
              selected: reason,
              label: (o) => 'ભઠ્ઠામાં નાખી $o',
              onChanged: (o) => setState(() => reason = o),
            ),
            BigNumberField(controller: controller, label: 'કેટલી ઈંટ', quickAdds: const [1000, 5000, 10000]),
            const GroupedSection(
              caption: 'મજૂરી',
              children: [
                GroupedRow(
                  leading: TintIcon(tint: Tint.bricks),
                  label: 'પાથરા',
                  title: 'રમેશ ભાઈ પટેલ · ₹550 / 1000',
                  value: '₹12,100',
                  chevron: true,
                ),
              ],
            ),
          ],
        ),
      ),
      bottom: const SaveBar(label: 'સેવ કરો', trailing: '₹14,300'),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('+1,000'));
    await tester.tap(find.text('+5,000'));
    expect(controller.text, '6000');

    await tester.tap(find.text('ભઠ્ઠામાં નાખી c'));
    await tester.pump();
    expect(reason, 'c');
  });

  // The rate and share dialogs were closed with back while their text field
  // still used a controller the caller had already disposed.
  testWidgets('the amount dialog closes with back without errors', (tester) async {
    ignoreFontErrors();
    final results = <String?>[];
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(await showAmountDialog(context, title: 'Rate', initialValue: '100')),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '250');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(results, [null]);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '250');
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(results.last, '250');
  });
}
