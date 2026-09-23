/// Pure spellogica, los van de UI zodat hij te testen is.
library;

import 'dart:math';

import 'models.dart';

/// Deelt spelers willekeurig in paren in. Spelers met e-mail worden zoveel
/// mogelijk verspreid, zodat elk team een e-mailadres heeft.
List<List<String>> randomPairs(List<Player> players, Random rng) {
  final withMail = players.where((p) => p.hasEmail).toList()..shuffle(rng);
  final withoutMail = players.where((p) => !p.hasEmail).toList()
    ..shuffle(rng);
  final teamCount = players.length ~/ 2;
  final pairs = List.generate(teamCount, (_) => <String>[]);
  // Eerst één speler met e-mail per team, dan de rest willekeurig aanvullen.
  final rest = <Player>[];
  for (var i = 0; i < withMail.length; i++) {
    if (i < teamCount) {
      pairs[i].add(withMail[i].id);
    } else {
      rest.add(withMail[i]);
    }
  }
  rest
    ..addAll(withoutMail)
    ..shuffle(rng);
  var r = 0;
  for (final pair in pairs) {
    while (pair.length < 2 && r < rest.length) {
      pair.add(rest[r++].id);
    }
  }
  for (final pair in pairs) {
    pair.shuffle(rng);
  }
  pairs.shuffle(rng);
  return pairs;
}

/// Kiest een foto, met voorrang voor foto's die het minst gebruikt zijn.
/// [exclude] wordt overgeslagen zolang er een alternatief is.
Photo? pickPhoto(
  List<Photo> photos,
  Map<String, int> usage,
  Random rng, {
  Set<String> exclude = const {},
}) {
  if (photos.isEmpty) return null;
  var pool = photos.where((p) => !exclude.contains(p.id)).toList();
  if (pool.isEmpty) pool = List.of(photos);
  final minUse =
      pool.map((p) => usage[p.id] ?? 0).reduce((a, b) => a < b ? a : b);
  final least = pool.where((p) => (usage[p.id] ?? 0) == minUse).toList();
  return least[rng.nextInt(least.length)];
}

/// Bepaalt de winnaar automatisch: wie eerder klaar was, anders de meeste
/// punten. Bij gelijkspel of ontbrekende punten: null.
int? autoWinner(GameMatch m) {
  if (m.finishedSide != null) return m.finishedSide;
  final pa = m.a?.points, pb = m.b?.points;
  if (pa == null || pb == null || pa == pb) return null;
  return pa > pb ? 0 : 1;
}

class ScoreRow {
  ScoreRow(this.teamId, this.teamLabel, this.players);

  final String teamId;
  final String teamLabel;
  final String players;
  int played = 0;
  int wins = 0;
  int? bestTimeMs;
  int points = 0;

  bool get won => wins > 0;
}

/// Klassement over alle afgeronde potjes. Alleen kanten met het vinkje
/// "telt mee" tellen. Sortering: winst, dan kortste tijd, dan meeste punten.
List<ScoreRow> scoreboard(List<GameMatch> history) {
  final rows = <String, ScoreRow>{};
  for (final m in history) {
    for (var i = 0; i < 2; i++) {
      final s = m.side(i);
      if (!s.counts) continue;
      final row = rows.putIfAbsent(
          s.teamId, () => ScoreRow(s.teamId, s.teamLabel, s.playersText));
      row.played++;
      row.points += s.points ?? 0;
      if (m.winnerSide == i) {
        row.wins++;
        if (m.finishedSide == i && m.finishTimeMs != null) {
          final t = m.finishTimeMs!;
          if (row.bestTimeMs == null || t < row.bestTimeMs!) row.bestTimeMs = t;
        }
      }
    }
  }
  final list = rows.values.toList();
  list.sort((x, y) {
    if (x.wins != y.wins) return y.wins.compareTo(x.wins);
    final tx = x.bestTimeMs, ty = y.bestTimeMs;
    if (tx != ty) {
      if (tx == null) return 1;
      if (ty == null) return -1;
      return tx.compareTo(ty);
    }
    if (x.points != y.points) return y.points.compareTo(x.points);
    return x.teamLabel.compareTo(y.teamLabel);
  });
  return list;
}

String formatMs(int ms) {
  final totalSec = (ms / 1000).ceil().clamp(0, 99 * 60);
  final m = totalSec ~/ 60, s = totalSec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

bool isValidEmail(String v) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
