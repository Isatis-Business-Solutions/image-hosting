import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spelleider/main.dart';
import 'package:spelleider/relay/relay_models.dart';
import 'package:spelleider/relay/relay_store.dart';

void main() {
  group('groepsindeling', () {
    test('zoveel mogelijk groepen van 4, anders 3 of 5', () {
      expect(groupCountFor(24), 6);
      expect(groupCountFor(23), 6); // 5x4 + 1x3
      expect(groupCountFor(25), 6); // 5x4 + 1x5
      expect(groupCountFor(26), 6); // 4x4 + 2x5
      expect(groupCountFor(22), 5); // 3x4 + 2x5
      expect(groupCountFor(6), 2);
      expect(groupCountFor(4), 1);
      expect(groupCountFor(2), 1);
      for (var n = 3; n <= 40; n++) {
        final g = groupCountFor(n);
        final small = n ~/ g, big = (n / g).ceil();
        expect(small, greaterThanOrEqualTo(n < 6 ? 2 : 3), reason: 'n=$n');
        expect(big, lessThanOrEqualTo(5), reason: 'n=$n');
      }
    });

    test('store verdeelt 23 spelers eerlijk', () {
      final s = RelayStore(rng: Random(1), persist: false);
      for (var i = 0; i < 23; i++) {
        s.addPlayer('P$i');
      }
      s.randomizeGroups();
      final sizes = s.groups.map((g) => g.playerIds.length).toList()..sort();
      expect(sizes, [3, 4, 4, 4, 4, 4]);
      expect(s.sortedGroups.first.label, 'Groep A');
      expect(s.unassigned, isEmpty);
    });

    test('wisselen, verplaatsen en lege groep verdwijnt', () {
      final s = RelayStore(rng: Random(2), persist: false);
      for (var i = 0; i < 8; i++) {
        s.addPlayer('P$i');
      }
      s.randomizeGroups();
      final a = s.sortedGroups[0], b = s.sortedGroups[1];
      final pa = a.playerIds.first, pb = b.playerIds.first;
      s.swapPlayers(pa, pb);
      expect(s.groupOf(pa), b);
      s.movePlayer(pa, a);
      expect(a.playerIds, hasLength(5));
      expect(b.playerIds, hasLength(3));
      for (final id in [...b.playerIds]) {
        s.movePlayer(id, a);
      }
      expect(s.groups, hasLength(1));
    });

    test('namen overnemen slaat dubbele over', () {
      final s = RelayStore(persist: false)..addPlayer('Emma');
      expect(s.importNames(['emma', 'Noah', ' ', 'Noah']), 1);
      expect(s.players.map((p) => p.name), ['Emma', 'Noah']);
    });

    test('groepslabels', () {
      expect(groupLabel(0), 'Groep A');
      expect(groupLabel(25), 'Groep Z');
      expect(groupLabel(26), 'Groep AA');
    });
  });

  group('tijden', () {
    test('formatTenths en parseTenths', () {
      expect(formatTenths(83456), '1:23,4');
      expect(formatTenths(0), '0:00,0');
      expect(parseTenths('1:23,4'), 83400);
      expect(parseTenths('1:23.4'), 83400);
      expect(parseTenths('83,4'), 83400);
      expect(parseTenths('2:05'), 125000);
      expect(parseTenths('1:75'), isNull);
      expect(parseTenths('abc'), isNull);
    });
  });

  group('ronde en finale', () {
    late RelayStore s;

    setUp(() {
      s = RelayStore(rng: Random(3), persist: false);
      for (var i = 0; i < 16; i++) {
        s.addPlayer('P$i');
      }
      s.randomizeGroups();
    });

    test('twee groepen tegelijk, los stoppen, oeps, opslaan', () {
      final g = s.sortedGroups;
      s.prepareRun([g[0], g[1]]);
      s.startRun();
      final r = s.current!;
      r.startedAt = DateTime.now().subtract(const Duration(seconds: 90));
      s.stopEntry(1);
      expect(r.entries[1].timeMs, greaterThanOrEqualTo(90000));
      expect(r.entries[0].timeMs, isNull);
      expect(r.allStopped, isFalse);
      s.resumeEntry(1);
      expect(r.entries[1].timeMs, isNull);
      s.stopEntry(1);
      r.startedAt = r.startedAt!.subtract(const Duration(seconds: 30));
      s.stopEntry(0);
      expect(r.allStopped, isTrue);
      expect(r.entries[0].timeMs! > r.entries[1].timeMs!, isTrue);
      s.saveRun();
      expect(s.current, isNull);
      expect(s.ranking.first.groupId, g[1].id);
    });

    test('resetten wist tijden en start', () {
      s.prepareRun(s.sortedGroups.take(2).toList());
      s.startRun();
      s.stopEntry(0);
      s.resetRun();
      expect(s.current!.started, isFalse);
      expect(s.current!.entries.every((e) => e.timeMs == null), isTrue);
    });

    test('klassement: snelste eerst, laatste ronde telt; finale', () {
      final g = s.sortedGroups; // 4 groepen
      void run(List<int> idx, List<int> secs) {
        s.prepareRun([for (final i in idx) g[i]]);
        s.startRun();
        for (var k = 0; k < idx.length; k++) {
          s.setEntryTime(s.current!.entries[k], secs[k] * 1000);
        }
        s.saveRun();
      }

      run([0, 1], [200, 180]);
      run([2, 3], [170, 250]);
      run([0, 3], [160, 240]); // groep A opnieuw: 160 telt
      final ids = s.ranking.map((r) => r.groupId).toList();
      expect(ids, [g[0].id, g[2].id, g[1].id, g[3].id]);

      s.startFinale();
      expect(s.finale!.a.groupId, g[0].id);
      expect(s.finale!.b.groupId, g[2].id);
      s.setFinaleWinner(g[2].id);
      expect(s.finale!.winner!.label, g[2].label);

      final back = RelayFinal.fromJson(s.finale!.toJson());
      expect(back.winner!.groupId, g[2].id);
      final runBack = RelayRun.fromJson(s.runs.first.toJson());
      expect(runBack.entries.first.timeMs, 200000);
    });
  });

  testWidgets('estafette-scherm: kiezen, starten, stoppen, scorebord',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    for (var i = 0; i < 8; i++) {
      relay.addPlayer('Loper $i');
    }
    relay.randomizeGroups();

    await tester.pumpWidget(const SpelleiderApp());
    await tester.pump();
    await tester.tap(find.text('Estafette'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Groepen'), findsWidgets);

    await tester.tap(find.text('Ronde').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Groep A').last);
    await tester.tap(find.text('Groep B').last);
    await tester.pump();
    await tester.tap(find.text('Start de timer'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('STOP'), findsNWidgets(2));

    await tester.tap(find.text('STOP').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('STOP').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(find.text('Ronde opslaan'), 300,
        scrollable: find.byType(Scrollable).hitTestable().first);
    await tester.drag(
        find.byType(Scrollable).hitTestable().first, const Offset(0, -200));
    await tester.pump();
    await tester.tap(find.text('Ronde opslaan'));
    await tester.pump();
    expect(relay.runs, hasLength(1));

    await tester.tap(find.text('Scores').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Start touwtrekfinale'), findsOneWidget);

    await tester.tap(find.text('Fotospel'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Potje'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
