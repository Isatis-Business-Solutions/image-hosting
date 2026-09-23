import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spelleider/logic.dart';
import 'package:spelleider/models.dart';
import 'package:spelleider/store.dart';

Player p(String id, {String? email}) => Player(id: id, name: id, email: email);

Photo ph(String id) => Photo(id: id, name: 'Foto $id', path: '/x/$id.jpg');

void main() {
  group('randomPairs', () {
    test('maakt paren en geeft elk team een e-mail als dat kan', () {
      final players = [
        for (var i = 0; i < 11; i++) p('m$i', email: 'm$i@x.nl'),
        for (var i = 0; i < 11; i++) p('k$i'),
      ];
      for (var seed = 0; seed < 50; seed++) {
        final pairs = randomPairs(players, Random(seed));
        expect(pairs, hasLength(11));
        final ids = pairs.expand((e) => e).toList();
        expect(ids.toSet(), hasLength(22));
        for (final pair in pairs) {
          expect(pair, hasLength(2));
          expect(pair.any((id) => id.startsWith('m')), isTrue);
        }
      }
    });

    test('oneven aantal: één speler blijft over', () {
      final pairs = randomPairs(
          [p('a', email: 'a@x.nl'), p('b'), p('c')], Random(1));
      expect(pairs, hasLength(1));
      expect(pairs.first, hasLength(2));
    });
  });

  group('pickPhoto', () {
    test('kiest minst gebruikte foto en slaat de andere kant over', () {
      final photos = [ph('a'), ph('b'), ph('c')];
      for (var seed = 0; seed < 30; seed++) {
        final r = pickPhoto(photos, {'a': 2, 'b': 0, 'c': 0}, Random(seed),
            exclude: {'b'});
        expect(r!.id, 'c');
      }
    });

    test('valt terug op uitgesloten foto als er niets anders is', () {
      expect(pickPhoto([ph('a')], {}, Random(1), exclude: {'a'})!.id, 'a');
      expect(pickPhoto([], {}, Random(1)), isNull);
    });
  });

  GameMatch match(int n,
      {required String a,
      required String b,
      int? pa,
      int? pb,
      int? finished,
      int? time,
      int? winner,
      bool countsA = true,
      bool countsB = true}) {
    final m = GameMatch(id: 'm$n', number: n)
      ..a = Side(
          teamId: a,
          teamLabel: 'Team $a',
          playerNames: ['x'],
          points: pa,
          counts: countsA)
      ..b = Side(
          teamId: b,
          teamLabel: 'Team $b',
          playerNames: ['y'],
          points: pb,
          counts: countsB)
      ..finishedSide = finished
      ..finishTimeMs = time;
    m.winnerSide = winner ?? autoWinner(m);
    return m;
  }

  group('autoWinner', () {
    test('wie klaar is wint, anders meeste punten, gelijk = geen', () {
      expect(autoWinner(match(1, a: '1', b: '2', finished: 1, pa: 9)), 1);
      expect(autoWinner(match(1, a: '1', b: '2', pa: 7, pb: 4)), 0);
      expect(autoWinner(match(1, a: '1', b: '2', pa: 4, pb: 4)), isNull);
      expect(autoWinner(match(1, a: '1', b: '2', pa: 4)), isNull);
    });
  });

  group('scoreboard', () {
    test('sorteert op winst, snelste tijd, meeste punten', () {
      final rows = scoreboard([
        match(1, a: '1', b: '2', finished: 0, time: 200000, pb: 6),
        match(2, a: '3', b: '4', finished: 1, time: 150000, pa: 8),
        match(3, a: '5', b: '6', pa: 9, pb: 3),
      ]);
      expect(rows.map((r) => r.teamId).toList(),
          ['4', '1', '5', '3', '2', '6']);
      expect(rows.first.bestTimeMs, 150000);
    });

    test('"telt niet mee" wordt overgeslagen', () {
      final rows = scoreboard([
        match(1, a: '1', b: '2', pa: 3, pb: 5),
        match(6, a: '1', b: '11', pa: 9, pb: 2, countsA: false),
      ]);
      final t1 = rows.firstWhere((r) => r.teamId == '1');
      expect(t1.played, 1);
      expect(t1.points, 3);
      expect(rows.map((r) => r.teamId), contains('11'));
    });
  });

  test('formatMs', () {
    expect(formatMs(300000), '5:00');
    expect(formatMs(299001), '5:00');
    expect(formatMs(61000), '1:01');
    expect(formatMs(0), '0:00');
  });

  group('AppStore', () {
    late AppStore s;

    setUp(() {
      s = AppStore(rng: Random(3), persist: false);
      for (var i = 0; i < 4; i++) {
        s.addPlayer('P$i', i.isEven ? 'p$i@x.nl' : null);
      }
      s.photos.addAll([ph('a'), ph('b'), ph('c')]);
    });

    test('teams indelen en spelers wisselen', () {
      s.randomizeTeams();
      expect(s.teams, hasLength(2));
      expect(s.teams.every(s.teamHasEmail), isTrue);
      final x = s.teams[0].playerIds[0], y = s.teams[1].playerIds[1];
      s.swapPlayers(x, y);
      expect(s.teams[0].playerIds[0], y);
      expect(s.teams[1].playerIds[1], x);

      s.addPlayer('Nieuw', null);
      expect(s.unassigned, hasLength(1));
      s.swapPlayers(s.unassigned.first.id, x);
      expect(s.unassigned.single.id, x);
    });

    test('speler verwijderen heft team op', () {
      s.randomizeTeams();
      s.removePlayer(s.player(s.teams[0].playerIds[0])!);
      expect(s.teams, hasLength(1));
      expect(s.unassigned, hasLength(1));
    });

    test('volledig potje: foto verschillend, klaar, opslaan', () {
      s.randomizeTeams();
      s.newMatch();
      s.chooseTeams(s.teams[0], s.teams[1]);
      final m = s.current!;
      expect(m.stage, MatchStage.photos);
      expect(m.a!.photoId, isNot(m.b!.photoId));
      s.confirmPhotos();
      expect(m.stage, MatchStage.send);
      expect(s.emailsFor(m.a!), isNotEmpty);
      s.markSent(0, true);
      s.markSent(1, true);
      s.setStage(MatchStage.play);
      s.startTimer();
      s.finishBy(1);
      expect(m.stage, MatchStage.result);
      expect(m.winnerSide, 1);
      expect(m.finishTimeMs, isNotNull);
      s.setPoints(m, 0, 5);
      expect(m.winnerSide, 1, reason: 'wie klaar is blijft winnaar');
      s.saveMatch();
      expect(s.current, isNull);
      expect(s.history, hasLength(1));
      expect(s.timesPlayed(s.teams[0].id), 1);

      // Tweede potje: foto's met voorrang voor de ongebruikte.
      s.newMatch();
      expect(s.current!.number, 2);
      s.chooseTeams(s.teams[0], s.teams[1]);
      final used = {m.a!.photoId, m.b!.photoId};
      final unused = {'a', 'b', 'c'}.difference(used).single;
      expect([s.current!.a!.photoId, s.current!.b!.photoId],
          contains(unused));
    });

    test('timer loopt af', () {
      s.randomizeTeams();
      s.newMatch();
      s.chooseTeams(s.teams[0], s.teams[1]);
      s.confirmPhotos();
      s.setStage(MatchStage.play);
      s.startTimer();
      expect(s.checkTimeUp(), isFalse);
      s.current!.startedAt =
          DateTime.now().subtract(const Duration(minutes: 6));
      expect(s.checkTimeUp(), isTrue);
      expect(s.current!.timeUp, isTrue);
      expect(s.current!.elapsedMs, s.timerMs);
      s.setPoints(s.current!, 0, 4);
      s.setPoints(s.current!, 1, 7);
      expect(s.current!.winnerSide, 1);
    });

    test('pauze en hervatten', () {
      s.randomizeTeams();
      s.newMatch();
      s.chooseTeams(s.teams[0], s.teams[1]);
      s.startTimer();
      s.current!.startedAt =
          DateTime.now().subtract(const Duration(seconds: 30));
      s.pauseTimer();
      final e = s.current!.elapsedMs;
      expect(e, greaterThanOrEqualTo(30000));
      expect(s.current!.elapsedAt(DateTime.now().add(const Duration(minutes: 1))),
          e);
    });

    test('JSON round-trip', () {
      s.randomizeTeams();
      s.newMatch();
      s.chooseTeams(s.teams[0], s.teams[1]);
      final j = s.current!.toJson();
      final back = GameMatch.fromJson(j);
      expect(back.a!.photoId, s.current!.a!.photoId);
      expect(back.stage, MatchStage.photos);
    });
  });
}
