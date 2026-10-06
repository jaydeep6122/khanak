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
    isGroup: true,
    isActive: true,
  );
  const custom = WorkType(
    id: 'custom',
    name: 'Patthar',
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
  Worker worker(String id, [double? rate]) => Worker(id: id, name: id, isActive: true, brickRate: rate);

  test('rates per 1000, per lakh, per day and per trip', () {
    expect(loading.payFor(22000), isNull);
    expect(loading.payFor(22000, rate: 100), 2200);
    expect(custom.payFor(22000), 2200);
    expect(loading.atOwnRate, isTrue);
    expect(custom.atOwnRate, isFalse);
    expect(
      const WorkType(
        id: 's',
        name: 's',
        payUnit: PayUnit.perLakh,
        rate: 2500,
        isGroup: true,
        isActive: true,
      ).payFor(550000),
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

  test('own rates: each worker paid for the bricks they carried, at their own rate', () {
    final group = GroupDraft(type: loading, workers: [worker('a', 100), worker('b', 120)]);
    expect(group.asksBricks, isTrue);
    expect(group.pay(bricks: 22000), [null, null]);
    group.bricks
      ..['a'] = 15000
      ..['b'] = 7000;
    expect(group.pay(bricks: 22000), [1500, 840]);
    expect(group.total(bricks: 22000, rate: null), 2340);
    expect(group.bricksProblem(22000), isNull);
    expect(group.toJson(bricks: 22000), {
      'work_type_id': 'loading',
      'workers': [
        {'worker_id': 'a', 'bricks': 15000},
        {'worker_id': 'b', 'bricks': 7000},
      ],
    });
  });

  test("own rates: the workers' bricks must add up to the bricks counted", () {
    final group = GroupDraft(type: loading, workers: [worker('a', 100), worker('b', 100)]);
    group.bricks['a'] = 6000;
    expect(group.bricksProblem(10000), 'bricks_of_worker_missing');
    group.bricks['b'] = 3000;
    expect(group.bricksGiven(), 9000);
    expect(group.bricksProblem(10000), 'bricks_do_not_add_up');
    group.bricks['b'] = 4000;
    expect(group.bricksProblem(10000), isNull);
  });

  test('own rates: a lone worker carried all the bricks', () {
    final group = GroupDraft(type: loading, workers: [worker('a', 100)]);
    expect(group.asksBricks, isFalse);
    expect(group.pay(bricks: 10000), [1000]);
    expect(group.bricksProblem(10000), isNull);
    expect(group.toJson(bricks: 10000)['workers'], [
      {'worker_id': 'a'},
    ]);
  });

  test('own rates: an edited entry keeps the rate it was made with', () {
    final group = GroupDraft(type: loading, workers: [worker('a', 100)], savedRates: {'a': 80});
    expect(group.pay(bricks: 10000), [800]);
  });

  test('own rates: a worker whose rate is not known has no pay', () {
    final group = GroupDraft(type: loading, workers: [worker('a', 100), worker('b')]);
    group.bricks
      ..['a'] = 5000
      ..['b'] = 5000;
    expect(group.pay(bricks: 10000), [500, null]);
    expect(group.total(bricks: 10000, rate: null), 500);
  });

  test('own rates: a share set by hand leaves the others as they are', () {
    final group = GroupDraft(type: loading, workers: [worker('a', 100), worker('b', 100)]);
    group.bricks
      ..['a'] = 5000
      ..['b'] = 5000;
    group.amounts['a'] = 700;
    expect(group.pay(bricks: 10000), [700, 500]);
    expect(group.fits(1200), isTrue);
    expect(group.toJson(bricks: 10000), {
      'work_type_id': 'loading',
      'total_amount': '1200.00',
      'workers': [
        {'worker_id': 'a', 'bricks': 5000, 'amount': '700.00'},
        {'worker_id': 'b', 'bricks': 5000, 'amount': '500.00'},
      ],
    });
  });

  test('a kind with its own rate shares the total equally', () {
    final group = GroupDraft(type: custom, workers: [worker('a'), worker('b')]);
    final total = group.total(bricks: 22000, rate: 100);
    expect(total, 2200);
    expect(group.shares(total), [1100, 1100]);
  });

  test('one share set by hand: the others share what is left', () {
    final group = GroupDraft(type: truck, workers: [worker('a'), worker('b'), worker('c')]);
    group.amounts['a'] = 700;
    final total = group.total(bricks: 4000, trips: 1, rate: 1500);
    expect(total, 1500);
    expect(group.shares(total), [700, 400, 400]);
    expect(group.fits(total), isTrue);
    expect(group.toJson(bricks: 4000, trips: 1, rate: 1500)['total_amount'], '1500.00');

    group.amounts['b'] = 1000;
    expect(group.fits(total), isFalse);
  });

  test('every share set by hand makes the total', () {
    final group = GroupDraft(type: custom, workers: [worker('a'), worker('b')]);
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
