enum PartyPhase { idle, matchmaking, agentSelect, inMatch }

class PregamePlayer {
  final String puuid;
  final String gameName;
  final String tagLine;
  final String characterId;
  final String characterSelectionState;
  final int competitiveTier;
  final String playerCardId;
  final int accountLevel;
  final String teamId;
  final bool isAlly;

  const PregamePlayer({
    required this.puuid,
    required this.gameName,
    required this.tagLine,
    required this.characterId,
    required this.characterSelectionState,
    required this.competitiveTier,
    required this.playerCardId,
    required this.accountLevel,
    required this.teamId,
    required this.isAlly,
  });

  bool get isLocked => characterSelectionState.toLowerCase() == 'locked';
}

class PregameMatch {
  final String matchId;
  final String mapId;
  final String queueId;
  final String phase;
  final List<PregamePlayer> allyTeam;
  final List<PregamePlayer> enemyTeam;

  const PregameMatch({
    required this.matchId,
    required this.mapId,
    required this.queueId,
    required this.phase,
    required this.allyTeam,
    required this.enemyTeam,
  });

  List<PregamePlayer> get allPlayers => [...allyTeam, ...enemyTeam];
}

class CurrentGamePlayer {
  final String puuid;
  final String gameName;
  final String tagLine;
  final String teamId;
  final String characterId;
  final int competitiveTier;
  final String playerCardId;
  final int accountLevel;
  final bool isCoach;
  final bool isAlly;

  const CurrentGamePlayer({
    required this.puuid,
    required this.gameName,
    required this.tagLine,
    required this.teamId,
    required this.characterId,
    required this.competitiveTier,
    required this.playerCardId,
    required this.accountLevel,
    this.isCoach = false,
    required this.isAlly,
  });
}

class CurrentGameMatch {
  final String matchId;
  final String mapId;
  final String modeId;
  final String queueId;
  final String? gamePodId;
  final String? provisioningFlow;
  final List<CurrentGamePlayer> allyTeam;
  final List<CurrentGamePlayer> enemyTeam;

  const CurrentGameMatch({
    required this.matchId,
    required this.mapId,
    required this.modeId,
    required this.queueId,
    this.gamePodId,
    this.provisioningFlow,
    required this.allyTeam,
    required this.enemyTeam,
  });

  List<CurrentGamePlayer> get allPlayers => [...allyTeam, ...enemyTeam];
}
