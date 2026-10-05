import 'package:flutter_test/flutter_test.dart';
import 'package:khanak/global/constants.dart';
import 'package:khanak/screens/entries/groupDraft.dart';
import 'package:khanak/types/work.dart';
import 'package:khanak/types/worker.dart';

// The pay previews on the forms must match what the server will save.
void main() {
  const loading = WorkType(
    id: 'loading',
    code: 'kiln_loading',
    name: 'Kiln loading',
    payUnit: PayUnit.per1000,
    rate: 100,
    isGroup: true,
    isActive: true,
  );
  const truck = WorkType(
    id: 'truck',
    code: 'truck_loading',
    name: 'Truck loading',
    payUnit: PayUnit.perTrip,
    rate: 1500,
    isGroup: true,
    isActive: true,
  );
  Worker worker(String id) => Worker(id: id, name: id, isActive: true);

  test('rates per 1000, per lakh, per day and per trip', () {
    expect(loading.payFor(22000), 2200);
    expect(
      const WorkType(id: 's', name: 's', payUnit: PayUnit.perLakh, rate: 2500, isGroup: true, isActive: true).payFor(550000),
      13750,
    );
    expect(
      const WorkType(id: 'd', name: 'd', payUnit: PayUnit.perDay, rate: 400, isGroup: false, isActive: true).payFor(6),
      2400,
    );
    expect(truck.payFor(1), 1500);
    expect(
      const WorkType(id: 'l', name: 'l', payUnit: PayUnit.lumpsum, isGroup: false, isActive: true).payFor(1),
      isNull,
    );
  });

  test('equal shares add up to the paisa, like the server', () {
    expect(splitEqually(1000, 3), [333.34, 333.33, 333.33]);
    expect(splitEqually(2200, 2), [1100, 1100]);
    expect(splitEqually(0.05, 3), [0.02, 0.02, 0.01]);
  });

  test('a group shares the rate total equally', () {
    final group = GroupDraft(type: loading, workers: [worker('a'), worker('b')]);
    final total = group.total(bricks: 22000, rate: 100);
    expect(total, 2200);
    expect(group.shares(total), [1100, 1100]);
    expect(group.toJson(total), {
      'work_type_id': 'loading',
      'workers': [
        {'worker_id': 'a'},
        {'worker_id': 'b'},
      ],
    });
  });

  test('one share set by hand: the others share what is left', () {
    final group = GroupDraft(type: truck, workers: [worker('a'), worker('b'), worker('c')]);
    group.amounts['a'] = 700;
    final total = group.total(bricks: 4000, trips: 1, rate: 1500);
    expect(total, 1500);
    expect(group.shares(total), [700, 400, 400]);
    expect(group.fits(total), isTrue);
    expect(group.toJson(total)['total_amount'], '1500.00');

    group.amounts['b'] = 1000;
    expect(group.fits(total), isFalse);
  });

  test('every share set by hand makes the total', () {
    final group = GroupDraft(type: loading, workers: [worker('a'), worker('b')]);
    group.amounts
      ..['a'] = 1300
      ..['b'] = 900;
    expect(group.total(bricks: 22000, rate: 100), 2200);
  });

  test('a worker shown by nickname and village', () {
    const ramesh = Worker(id: 'r', name: 'Ramesh', nickname: 'Moto', village: 'Bihar', isActive: true);
    expect(ramesh.displayName, 'Ramesh · Moto · Bihar');
    expect(ramesh.initial, 'R');
    expect(const Worker(id: 'k', name: 'કિશન', isActive: true).initial, 'ક');
  });
}
