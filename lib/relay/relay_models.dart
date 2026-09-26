/// Datamodellen van deel 2: de estafette. Staat los van het fotospel.
library;

import '../models.dart';

/// Een groep (meestal 4 spelers). Label: Groep A, B, C…
class RelayGroup {
  RelayGroup({required this.id, required this.index, required this.playerIds});

  final String id;
  final int index;
  final List<String> playerIds;

  String get label => groupLabel(index);

  Map<String, dynamic> toJson() =>
      {'id': id, 'index': index, 'playerIds': playerIds};

  factory RelayGroup.fromJson(Map<String, dynamic> j) => RelayGroup(
        id: j['id'],
        index: j['index'],
        playerIds: List<String>.from(j['playerIds']),
      );
}

/// A, B, … Z, AA, AB, …
String groupLabel(int index) {
  var n = index, s = '';
  do {
    s = String.fromCharCode(65 + n % 26) + s;
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return 'Groep $s';
}

/// Eén groep binnen een ronde, met momentopname van de namen.
class RelayEntry {
  RelayEntry({
    required this.groupId,
    required this.label,
    required this.playerNames,
    this.timeMs,
  });

  final String groupId;
  final String label;
  final List<String> playerNames;

  /// Eindtijd; null = nog niet gestopt.
  int? timeMs;

  String get playersText => playerNames.join(', ');

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'label': label,
        'playerNames': playerNames,
        'timeMs': timeMs,
      };

  factory RelayEntry.fromJson(Map<String, dynamic> j) => RelayEntry(
        groupId: j['groupId'],
        label: j['label'],
        playerNames: List<String>.from(j['playerNames']),
        timeMs: j['timeMs'],
      );
}

/// Een ronde: een aantal groepen dat tegelijk start.
class RelayRun {
  RelayRun({
    required this.id,
    required this.number,
    required this.entries,
    this.startedAt,
  });

  final String id;
  final int number;
  final List<RelayEntry> entries;
  DateTime? startedAt;

  bool get started => startedAt != null;
  bool get allStopped => entries.every((e) => e.timeMs != null);

  int elapsedAt(DateTime now) =>
      startedAt == null ? 0 : now.difference(startedAt!).inMilliseconds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'entries': entries.map((e) => e.toJson()).toList(),
        'startedAt': startedAt?.toIso8601String(),
      };

  factory RelayRun.fromJson(Map<String, dynamic> j) => RelayRun(
        id: j['id'],
        number: j['number'],
        entries: (j['entries'] as List)
            .map((e) => RelayEntry.fromJson(e))
            .toList(),
        startedAt:
            j['startedAt'] == null ? null : DateTime.parse(j['startedAt']),
      );
}

/// De touwtrekfinale tussen de twee snelste groepen.
class RelayFinal {
  RelayFinal({required this.a, required this.b, this.winnerGroupId});

  final RelayEntry a;
  final RelayEntry b;
  String? winnerGroupId;

  RelayEntry? get winner => winnerGroupId == null
      ? null
      : (winnerGroupId == a.groupId ? a : b);

  Map<String, dynamic> toJson() =>
      {'a': a.toJson(), 'b': b.toJson(), 'winnerGroupId': winnerGroupId};

  factory RelayFinal.fromJson(Map<String, dynamic> j) => RelayFinal(
        a: RelayEntry.fromJson(j['a']),
        b: RelayEntry.fromJson(j['b']),
        winnerGroupId: j['winnerGroupId'],
      );
}

/// Aantal groepen: zoveel mogelijk groepen van 4, restant verdeeld (3 of 5).
int groupCountFor(int players) {
  var g = ((players + 1) ~/ 4).clamp(1, players < 1 ? 1 : players);
  while (players > g * 5) {
    g++;
  }
  return g;
}

/// Verdeelt spelers willekeurig over [groupCount] groepen van gelijke grootte
/// (verschil hooguit 1).
List<List<String>> splitIntoGroups(
    List<Player> players, int groupCount, void Function(List<Player>) shuffle) {
  final list = List.of(players);
  shuffle(list);
  final groups = List.generate(groupCount, (_) => <String>[]);
  for (var i = 0; i < list.length; i++) {
    groups[i % groupCount].add(list[i].id);
  }
  return groups;
}

class RelayRow {
  RelayRow(this.groupId, this.label, this.players, this.timeMs, this.runNumber);

  final String groupId;
  final String label;
  final String players;
  final int timeMs;
  final int runNumber;
}

/// Klassement: per groep de tijd uit de meest recente ronde waarin de groep
/// een tijd heeft; snelste bovenaan.
List<RelayRow> relayRanking(List<RelayRun> runs) {
  final latest = <String, RelayRow>{};
  for (final r in [...runs]..sort((a, b) => a.number.compareTo(b.number))) {
    for (final e in r.entries) {
      if (e.timeMs == null) continue;
      latest[e.groupId] =
          RelayRow(e.groupId, e.label, e.playersText, e.timeMs!, r.number);
    }
  }
  final rows = latest.values.toList()
    ..sort((a, b) {
      final c = a.timeMs.compareTo(b.timeMs);
      return c != 0 ? c : a.label.compareTo(b.label);
    });
  return rows;
}

/// 1:23,4
String formatTenths(int ms) {
  final t = (ms < 0 ? 0 : ms) ~/ 100;
  final tenths = t % 10;
  final totalSec = t ~/ 10;
  final m = totalSec ~/ 60, s = totalSec % 60;
  return '$m:${s.toString().padLeft(2, '0')},$tenths';
}

/// Leest "1:23,4", "1:23.4", "83,4" of "83" als milliseconden.
int? parseTenths(String input) {
  final v = input.trim().replaceAll(',', '.');
  final m = RegExp(r'^(?:(\d+):)?(\d+(?:\.\d)?)$').firstMatch(v);
  if (m == null) return null;
  final min = int.parse(m.group(1) ?? '0');
  final sec = double.parse(m.group(2)!);
  if (m.group(1) != null && sec >= 60) return null;
  return ((min * 60 + sec) * 1000).round();
}
