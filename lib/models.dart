/// Datamodellen van de app. Alles wordt als JSON lokaal opgeslagen.
library;

class Player {
  Player({required this.id, required this.name, this.email});

  final String id;
  String name;
  String? email;

  bool get hasEmail => email != null && email!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};

  factory Player.fromJson(Map<String, dynamic> j) =>
      Player(id: j['id'], name: j['name'], email: j['email']);
}

/// Een team bestaat altijd uit twee spelers.
class Team {
  Team({required this.id, required this.number, required this.playerIds});

  final String id;
  final int number;
  final List<String> playerIds;

  String get label => 'Team $number';

  Map<String, dynamic> toJson() =>
      {'id': id, 'number': number, 'playerIds': playerIds};

  factory Team.fromJson(Map<String, dynamic> j) => Team(
        id: j['id'],
        number: j['number'],
        playerIds: List<String>.from(j['playerIds']),
      );
}

class Photo {
  Photo({required this.id, required this.name, required this.path});

  final String id;
  String name;
  final String path;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'path': path};

  factory Photo.fromJson(Map<String, dynamic> j) =>
      Photo(id: j['id'], name: j['name'], path: j['path']);
}

/// De stappen die een potje doorloopt.
enum MatchStage { teams, photos, send, play, result }

/// Eén kant (team) van een potje, inclusief momentopname van namen zodat het
/// scorebord klopt, ook als teams later opnieuw worden ingedeeld.
class Side {
  Side({
    required this.teamId,
    required this.teamLabel,
    required this.playerNames,
    this.photoId,
    this.photoName,
    this.sent = false,
    this.points,
    this.counts = true,
  });

  final String teamId;
  final String teamLabel;
  final List<String> playerNames;
  String? photoId;
  String? photoName;
  bool sent;
  int? points;

  /// Telt de score van dit team mee in het klassement? Standaard aan.
  bool counts;

  String get playersText => playerNames.join(' & ');

  Map<String, dynamic> toJson() => {
        'teamId': teamId,
        'teamLabel': teamLabel,
        'playerNames': playerNames,
        'photoId': photoId,
        'photoName': photoName,
        'sent': sent,
        'points': points,
        'counts': counts,
      };

  factory Side.fromJson(Map<String, dynamic> j) => Side(
        teamId: j['teamId'],
        teamLabel: j['teamLabel'],
        playerNames: List<String>.from(j['playerNames']),
        photoId: j['photoId'],
        photoName: j['photoName'],
        sent: j['sent'] ?? false,
        points: j['points'],
        counts: j['counts'] ?? true,
      );
}

class GameMatch {
  GameMatch({
    required this.id,
    required this.number,
    this.stage = MatchStage.teams,
    this.a,
    this.b,
    this.startedAt,
    this.elapsedMs = 0,
    this.running = false,
    this.timeUp = false,
    this.finishedSide,
    this.finishTimeMs,
    this.winnerSide,
  });

  final String id;
  final int number;
  MatchStage stage;
  Side? a;
  Side? b;

  // Timer. De verstreken tijd = elapsedMs + (nu - startedAt) zolang hij loopt.
  DateTime? startedAt;
  int elapsedMs;
  bool running;
  bool timeUp;

  /// 0 = team A, 1 = team B. Het team dat vóór het einde van de timer klaar was.
  int? finishedSide;
  int? finishTimeMs;

  /// 0 = team A, 1 = team B, null = nog niet bepaald.
  int? winnerSide;

  List<Side> get sides => [a!, b!];

  Side side(int i) => i == 0 ? a! : b!;

  bool get timerStarted => startedAt != null || elapsedMs > 0;

  int elapsedAt(DateTime now) =>
      elapsedMs +
      (running && startedAt != null
          ? now.difference(startedAt!).inMilliseconds
          : 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'stage': stage.name,
        'a': a?.toJson(),
        'b': b?.toJson(),
        'startedAt': startedAt?.toIso8601String(),
        'elapsedMs': elapsedMs,
        'running': running,
        'timeUp': timeUp,
        'finishedSide': finishedSide,
        'finishTimeMs': finishTimeMs,
        'winnerSide': winnerSide,
      };

  factory GameMatch.fromJson(Map<String, dynamic> j) => GameMatch(
        id: j['id'],
        number: j['number'],
        stage: MatchStage.values.byName(j['stage']),
        a: j['a'] == null ? null : Side.fromJson(j['a']),
        b: j['b'] == null ? null : Side.fromJson(j['b']),
        startedAt:
            j['startedAt'] == null ? null : DateTime.parse(j['startedAt']),
        elapsedMs: j['elapsedMs'] ?? 0,
        running: j['running'] ?? false,
        timeUp: j['timeUp'] ?? false,
        finishedSide: j['finishedSide'],
        finishTimeMs: j['finishTimeMs'],
        winnerSide: j['winnerSide'],
      );
}
