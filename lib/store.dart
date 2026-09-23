import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'logic.dart';
import 'models.dart';

const _uuid = Uuid();

/// Centrale app-status. Wordt na elke wijziging lokaal opgeslagen.
class AppStore extends ChangeNotifier {
  AppStore({Random? rng, this.persist = true}) : rng = rng ?? Random();

  final Random rng;
  final bool persist;
  Directory? _dir;

  final List<Player> players = [];
  final List<Team> teams = [];
  final List<Photo> photos = [];
  final List<GameMatch> history = [];
  GameMatch? current;
  int timerMinutes = 5;

  int get timerMs => timerMinutes * 60 * 1000;

  // ---------------------------------------------------------------- opslag

  Future<void> load() async {
    _dir = await getApplicationDocumentsDirectory();
    final f = File('${_dir!.path}/state.json');
    if (!await f.exists()) return;
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      players.addAll((j['players'] as List).map((e) => Player.fromJson(e)));
      teams.addAll((j['teams'] as List).map((e) => Team.fromJson(e)));
      photos.addAll((j['photos'] as List).map((e) => Photo.fromJson(e)));
      history.addAll((j['history'] as List).map((e) => GameMatch.fromJson(e)));
      current =
          j['current'] == null ? null : GameMatch.fromJson(j['current']);
      timerMinutes = j['timerMinutes'] ?? 5;
    } catch (e) {
      debugPrint('Kon opgeslagen gegevens niet lezen: $e');
    }
  }

  Future<String> get photoDir async {
    _dir ??= await getApplicationDocumentsDirectory();
    final d = Directory('${_dir!.path}/photos');
    if (!await d.exists()) await d.create(recursive: true);
    return d.path;
  }

  void _changed() {
    notifyListeners();
    if (persist) _save();
  }

  Future<void> _saving = Future.value();

  void _save() {
    final data = jsonEncode({
      'players': players.map((e) => e.toJson()).toList(),
      'teams': teams.map((e) => e.toJson()).toList(),
      'photos': photos.map((e) => e.toJson()).toList(),
      'history': history.map((e) => e.toJson()).toList(),
      'current': current?.toJson(),
      'timerMinutes': timerMinutes,
    });
    _saving = _saving.then((_) async {
      _dir ??= await getApplicationDocumentsDirectory();
      final tmp = File('${_dir!.path}/state.json.tmp');
      await tmp.writeAsString(data, flush: true);
      await tmp.rename('${_dir!.path}/state.json');
    }).catchError((e) => debugPrint('Opslaan mislukt: $e'));
  }

  // --------------------------------------------------------------- spelers

  Player? player(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  void addPlayer(String name, String? email) {
    players.add(Player(
        id: _uuid.v4(), name: name.trim(), email: _clean(email)));
    _changed();
  }

  void updatePlayer(Player p, String name, String? email) {
    p.name = name.trim();
    p.email = _clean(email);
    _changed();
  }

  /// Verwijdert een speler. Zat hij in een team, dan wordt dat team opgeheven
  /// en komt de teamgenoot bij "niet ingedeeld".
  void removePlayer(Player p) {
    teams.removeWhere((t) => t.playerIds.contains(p.id));
    players.remove(p);
    _changed();
  }

  void clearPlayers() {
    players.clear();
    teams.clear();
    _changed();
  }

  String? _clean(String? email) {
    final e = email?.trim();
    return (e == null || e.isEmpty) ? null : e;
  }

  // ----------------------------------------------------------------- teams

  Team? team(String id) {
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  Team? teamOf(String playerId) {
    for (final t in teams) {
      if (t.playerIds.contains(playerId)) return t;
    }
    return null;
  }

  List<Player> get unassigned =>
      players.where((p) => teamOf(p.id) == null).toList();

  List<Player> teamPlayers(Team t) =>
      t.playerIds.map(player).whereType<Player>().toList();

  bool teamHasEmail(Team t) => teamPlayers(t).any((p) => p.hasEmail);

  int _nextTeamNumber() =>
      teams.isEmpty ? 1 : teams.map((t) => t.number).reduce(max) + 1;

  /// Deelt alle spelers opnieuw willekeurig in.
  void randomizeTeams() {
    teams.clear();
    _pairInto(players);
    _changed();
  }

  /// Deelt alleen de nog niet ingedeelde spelers in nieuwe teams in.
  void assignRemaining() {
    _pairInto(unassigned);
    _changed();
  }

  void _pairInto(List<Player> list) {
    for (final pair in randomPairs(list, rng)) {
      teams.add(Team(id: _uuid.v4(), number: _nextTeamNumber(), playerIds: pair));
    }
  }

  /// Wisselt twee spelers van plek (tussen teams of met "niet ingedeeld").
  void swapPlayers(String p1, String p2) {
    if (p1 == p2) return;
    final t1 = teamOf(p1), t2 = teamOf(p2);
    if (t1 == t2) return;
    if (t1 != null) t1.playerIds[t1.playerIds.indexOf(p1)] = p2;
    if (t2 != null) t2.playerIds[t2.playerIds.indexOf(p2)] = p1;
    _changed();
  }

  void clearTeams() {
    teams.clear();
    _changed();
  }

  /// Hoe vaak een team al een afgerond potje heeft gespeeld.
  int timesPlayed(String teamId) => history
      .where((m) => m.a!.teamId == teamId || m.b!.teamId == teamId)
      .length;

  // ---------------------------------------------------------------- foto's

  Photo? photo(String? id) {
    for (final p in photos) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> addPhoto(String sourcePath, String name) async {
    final id = _uuid.v4();
    final ext = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.jpg';
    final dest = '${await photoDir}/$id$ext';
    await File(sourcePath).copy(dest);
    photos.add(Photo(id: id, name: name.trim(), path: dest));
    _changed();
  }

  void renamePhoto(Photo p, String name) {
    p.name = name.trim();
    _changed();
  }

  Future<void> removePhoto(Photo p) async {
    photos.remove(p);
    _changed();
    try {
      await File(p.path).delete();
    } catch (_) {}
  }

  /// Hoe vaak elke foto al is toegewezen (afgeronde potjes + huidig potje).
  Map<String, int> get photoUsage {
    final usage = <String, int>{};
    for (final m in [...history, ?current]) {
      for (final s in [m.a, m.b]) {
        final id = s?.photoId;
        if (id != null) usage[id] = (usage[id] ?? 0) + 1;
      }
    }
    return usage;
  }

  // ----------------------------------------------------------------- potje

  void newMatch() {
    final n = history.isEmpty ? 1 : history.map((m) => m.number).reduce(max) + 1;
    current = GameMatch(id: _uuid.v4(), number: n);
    _changed();
  }

  void cancelMatch() {
    current = null;
    _changed();
  }

  Side _sideFor(Team t) => Side(
        teamId: t.id,
        teamLabel: t.label,
        playerNames: teamPlayers(t).map((p) => p.name).toList(),
      );

  /// Stap 1 → 2: teams vastleggen en meteen foto's trekken.
  void chooseTeams(Team ta, Team tb) {
    final m = current!;
    m.a = _sideFor(ta);
    m.b = _sideFor(tb);
    m.stage = MatchStage.photos;
    _draw(0);
    _draw(1);
    _changed();
  }

  void redrawPhoto(int side) {
    _draw(side);
    _changed();
  }

  void _draw(int side) {
    final m = current!;
    final s = m.side(side);
    final other = m.side(1 - side);
    s.photoId = null; // eigen huidige foto niet meetellen als gebruik
    final usage = photoUsage;
    final exclude = {if (other.photoId != null) other.photoId!};
    final p = pickPhoto(photos, usage, rng, exclude: exclude);
    s.photoId = p?.id;
    s.photoName = p?.name;
  }

  void setStage(MatchStage stage) {
    current!.stage = stage;
    _changed();
  }

  /// Stap 2 → 3: bevestigen. Foto-namen worden vastgelegd.
  void confirmPhotos() {
    final m = current!;
    for (final s in m.sides) {
      s.photoName = photo(s.photoId)?.name ?? s.photoName;
      s.sent = false;
    }
    m.stage = MatchStage.send;
    _changed();
  }

  void markSent(int side, bool sent) {
    current!.side(side).sent = sent;
    _changed();
  }

  /// E-mailadressen van de spelers van een kant van het huidige potje.
  List<String> emailsFor(Side s) {
    final t = team(s.teamId);
    if (t == null) return [];
    return teamPlayers(t)
        .where((p) => p.hasEmail)
        .map((p) => p.email!.trim())
        .toList();
  }

  // Timer ----------------------------------------------------------------

  void startTimer() {
    final m = current!;
    m.startedAt = DateTime.now();
    m.running = true;
    _changed();
  }

  void pauseTimer() {
    final m = current!;
    m.elapsedMs = m.elapsedAt(DateTime.now());
    m.startedAt = null;
    m.running = false;
    _changed();
  }

  void resetTimer() {
    final m = current!;
    m
      ..startedAt = null
      ..elapsedMs = 0
      ..running = false
      ..timeUp = false
      ..finishedSide = null
      ..finishTimeMs = null
      ..winnerSide = null;
    for (final s in m.sides) {
      s.points = null;
    }
    _changed();
  }

  /// Een team is klaar vóór het einde van de timer.
  void finishBy(int side) {
    final m = current!;
    final t = m.elapsedAt(DateTime.now()).clamp(0, timerMs);
    m
      ..elapsedMs = t
      ..startedAt = null
      ..running = false
      ..finishedSide = side
      ..finishTimeMs = t
      ..winnerSide = side
      ..stage = MatchStage.result;
    _changed();
  }

  /// Handmatig stoppen zonder dat een team klaar is: punten invullen.
  void endWithoutFinish() {
    final m = current!;
    m
      ..elapsedMs = m.elapsedAt(DateTime.now()).clamp(0, timerMs)
      ..startedAt = null
      ..running = false
      ..stage = MatchStage.result;
    _changed();
  }

  /// De timer is afgelopen. Geeft true als dit het moment van aflopen was.
  bool checkTimeUp() {
    final m = current;
    if (m == null || !m.running) return false;
    if (m.elapsedAt(DateTime.now()) < timerMs) return false;
    m
      ..elapsedMs = timerMs
      ..startedAt = null
      ..running = false
      ..timeUp = true
      ..stage = MatchStage.result;
    _changed();
    return true;
  }

  // Uitslag ---------------------------------------------------------------

  void setPoints(GameMatch m, int side, int? points) {
    m.side(side).points = points;
    m.winnerSide = autoWinner(m) ?? m.winnerSide;
    _changed();
  }

  void setWinner(GameMatch m, int? side) {
    m.winnerSide = side;
    _changed();
  }

  void setCounts(GameMatch m, int side, bool counts) {
    m.side(side).counts = counts;
    _changed();
  }

  void saveMatch() {
    history.add(current!);
    current = null;
    _changed();
  }

  void removeFromHistory(GameMatch m) {
    history.remove(m);
    _changed();
  }

  void touch() => _changed();

  // ------------------------------------------------------------ instellingen

  void setTimerMinutes(int minutes) {
    timerMinutes = minutes;
    _changed();
  }

  /// Verwijdert alle gegevens, inclusief foto's.
  Future<void> wipeAll() async {
    players.clear();
    teams.clear();
    photos.clear();
    history.clear();
    current = null;
    timerMinutes = 5;
    _changed();
    try {
      final d = Directory(await photoDir);
      if (await d.exists()) await d.delete(recursive: true);
      final tmp = await getTemporaryDirectory();
      if (await tmp.exists()) {
        await for (final e in tmp.list()) {
          await e.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('Opruimen mislukt: $e');
    }
  }
}

final store = AppStore();
