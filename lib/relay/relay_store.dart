import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import 'relay_models.dart';

const _uuid = Uuid();

/// Welk deel van de app actief is.
enum AppMode { photo, relay }

/// Status van deel 2 (estafette). Eigen opslagbestand, los van het fotospel.
class RelayStore extends ChangeNotifier {
  RelayStore({Random? rng, this.persist = true}) : rng = rng ?? Random();

  final Random rng;
  final bool persist;
  Directory? _dir;

  AppMode mode = AppMode.photo;
  final List<Player> players = [];
  final List<RelayGroup> groups = [];
  final List<RelayRun> runs = [];
  RelayRun? current;
  RelayFinal? finale;
  int groupsPerRun = 2;

  // ---------------------------------------------------------------- opslag

  Future<void> load() async {
    _dir = await getApplicationDocumentsDirectory();
    final f = File('${_dir!.path}/relay.json');
    if (!await f.exists()) return;
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      mode = AppMode.values.byName(j['mode'] ?? 'photo');
      players.addAll((j['players'] as List).map((e) => Player.fromJson(e)));
      groups.addAll((j['groups'] as List).map((e) => RelayGroup.fromJson(e)));
      runs.addAll((j['runs'] as List).map((e) => RelayRun.fromJson(e)));
      current = j['current'] == null ? null : RelayRun.fromJson(j['current']);
      finale = j['finale'] == null ? null : RelayFinal.fromJson(j['finale']);
      groupsPerRun = j['groupsPerRun'] ?? 2;
    } catch (e) {
      debugPrint('Kon estafettegegevens niet lezen: $e');
    }
  }

  void _changed() {
    notifyListeners();
    if (persist) _save();
  }

  Future<void> _saving = Future.value();

  void _save() {
    final data = jsonEncode({
      'mode': mode.name,
      'players': players.map((e) => e.toJson()).toList(),
      'groups': groups.map((e) => e.toJson()).toList(),
      'runs': runs.map((e) => e.toJson()).toList(),
      'current': current?.toJson(),
      'finale': finale?.toJson(),
      'groupsPerRun': groupsPerRun,
    });
    _saving = _saving.then((_) async {
      _dir ??= await getApplicationDocumentsDirectory();
      final tmp = File('${_dir!.path}/relay.json.tmp');
      await tmp.writeAsString(data, flush: true);
      await tmp.rename('${_dir!.path}/relay.json');
    }).catchError((e) => debugPrint('Opslaan mislukt: $e'));
  }

  void setMode(AppMode m) {
    mode = m;
    _changed();
  }

  // --------------------------------------------------------------- spelers

  Player? player(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  void addPlayer(String name) {
    players.add(Player(id: _uuid.v4(), name: name.trim()));
    _changed();
  }

  void renamePlayer(Player p, String name) {
    p.name = name.trim();
    _changed();
  }

  /// Verwijdert een speler, ook uit zijn groep. Een lege groep verdwijnt.
  void removePlayer(Player p) {
    for (final g in groups) {
      g.playerIds.remove(p.id);
    }
    groups.removeWhere((g) => g.playerIds.isEmpty);
    players.remove(p);
    _changed();
  }

  /// Neemt namen over die nog niet in de lijst staan. Geeft het aantal terug.
  int importNames(Iterable<String> names) {
    final existing = players.map((p) => p.name.trim().toLowerCase()).toSet();
    var added = 0;
    for (final n in names) {
      final key = n.trim().toLowerCase();
      if (key.isEmpty || existing.contains(key)) continue;
      existing.add(key);
      players.add(Player(id: _uuid.v4(), name: n.trim()));
      added++;
    }
    if (added > 0) _changed();
    return added;
  }

  void clearPlayers() {
    players.clear();
    groups.clear();
    _changed();
  }

  // --------------------------------------------------------------- groepen

  RelayGroup? group(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  RelayGroup? groupOf(String playerId) {
    for (final g in groups) {
      if (g.playerIds.contains(playerId)) return g;
    }
    return null;
  }

  List<Player> groupPlayers(RelayGroup g) =>
      g.playerIds.map(player).whereType<Player>().toList();

  List<Player> get unassigned =>
      players.where((p) => groupOf(p.id) == null).toList();

  List<RelayGroup> get sortedGroups =>
      [...groups]..sort((a, b) => a.index.compareTo(b.index));

  void randomizeGroups() {
    groups.clear();
    final split = splitIntoGroups(
        players, groupCountFor(players.length), (l) => l.shuffle(rng));
    for (var i = 0; i < split.length; i++) {
      groups.add(RelayGroup(id: _uuid.v4(), index: i, playerIds: split[i]));
    }
    _changed();
  }

  /// Verdeelt nieuwe (niet ingedeelde) spelers over de kleinste groepen.
  void assignRemaining() {
    final rest = unassigned..shuffle(rng);
    if (groups.isEmpty) {
      randomizeGroups();
      return;
    }
    for (final p in rest) {
      final g = groups.reduce(
          (a, b) => a.playerIds.length <= b.playerIds.length ? a : b);
      g.playerIds.add(p.id);
    }
    _changed();
  }

  void swapPlayers(String p1, String p2) {
    if (p1 == p2) return;
    final g1 = groupOf(p1), g2 = groupOf(p2);
    if (g1 == g2) return;
    if (g1 != null) g1.playerIds[g1.playerIds.indexOf(p1)] = p2;
    if (g2 != null) g2.playerIds[g2.playerIds.indexOf(p2)] = p1;
    _changed();
  }

  /// Verplaatst een speler naar een groep (groepsgrootte verandert).
  void movePlayer(String playerId, RelayGroup to) {
    final from = groupOf(playerId);
    if (from == to) return;
    from?.playerIds.remove(playerId);
    to.playerIds.add(playerId);
    groups.removeWhere((g) => g.playerIds.isEmpty);
    _changed();
  }

  void addEmptyGroup() {
    final i = groups.isEmpty ? 0 : groups.map((g) => g.index).reduce(max) + 1;
    groups.add(RelayGroup(id: _uuid.v4(), index: i, playerIds: []));
    _changed();
  }

  void removeGroupIfEmpty(RelayGroup g) {
    if (g.playerIds.isEmpty) {
      groups.remove(g);
      _changed();
    }
  }

  void clearGroups() {
    groups.clear();
    _changed();
  }

  int timesRun(String groupId) => runs
      .where((r) => r.entries.any((e) => e.groupId == groupId))
      .length;

  // ----------------------------------------------------------------- ronde

  int get _nextRunNumber =>
      runs.isEmpty ? 1 : runs.map((r) => r.number).reduce(max) + 1;

  /// Maakt een ronde met de gekozen groepen (nog niet gestart).
  void prepareRun(List<RelayGroup> chosen) {
    current = RelayRun(
      id: _uuid.v4(),
      number: _nextRunNumber,
      entries: [
        for (final g in chosen)
          RelayEntry(
            groupId: g.id,
            label: g.label,
            playerNames: groupPlayers(g).map((p) => p.name).toList(),
          ),
      ],
    );
    _changed();
  }

  void startRun() {
    current!.startedAt = DateTime.now();
    _changed();
  }

  void stopEntry(int i) {
    final r = current!;
    r.entries[i].timeMs = r.elapsedAt(DateTime.now());
    _changed();
  }

  /// Per ongeluk gestopt: tijd loopt gewoon verder vanaf de gezamenlijke start.
  void resumeEntry(int i) {
    current!.entries[i].timeMs = null;
    _changed();
  }

  /// Timer terug naar 0, alle tijden gewist, groepen blijven gekozen.
  void resetRun() {
    final r = current!;
    r.startedAt = null;
    for (final e in r.entries) {
      e.timeMs = null;
    }
    _changed();
  }

  void cancelRun() {
    current = null;
    _changed();
  }

  void saveRun() {
    runs.add(current!);
    current = null;
    _changed();
  }

  void setEntryTime(RelayEntry e, int? ms) {
    e.timeMs = ms;
    _changed();
  }

  void removeEntry(RelayRun r, RelayEntry e) {
    r.entries.remove(e);
    if (r.entries.isEmpty) runs.remove(r);
    _changed();
  }

  void removeRun(RelayRun r) {
    runs.remove(r);
    _changed();
  }

  List<RelayRow> get ranking => relayRanking(runs);

  // ----------------------------------------------------------------- finale

  void startFinale() {
    final top = ranking.take(2).toList();
    if (top.length < 2) return;
    RelayEntry entry(RelayRow r) => RelayEntry(
          groupId: r.groupId,
          label: r.label,
          playerNames: r.players.split(', '),
          timeMs: r.timeMs,
        );
    finale = RelayFinal(a: entry(top[0]), b: entry(top[1]));
    _changed();
  }

  void setFinaleWinner(String? groupId) {
    finale!.winnerGroupId = groupId;
    _changed();
  }

  void cancelFinale() {
    finale = null;
    _changed();
  }

  // ------------------------------------------------------------ instellingen

  void setGroupsPerRun(int n) {
    groupsPerRun = n;
    _changed();
  }

  /// Wist alle estafettegegevens (spelers, groepen, rondes, finale).
  void resetAll() {
    players.clear();
    groups.clear();
    runs.clear();
    current = null;
    finale = null;
    groupsPerRun = 2;
    _changed();
  }
}

final relay = RelayStore();
