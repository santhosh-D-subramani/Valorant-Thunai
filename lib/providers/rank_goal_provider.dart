import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/models/rank_goal.dart';

class RankGoalPrefsKeys {
  RankGoalPrefsKeys._();

  static const targetTierId = 'rank_goal_target_tier_id';
  static const startTierId = 'rank_goal_start_tier_id';
  static const startRR = 'rank_goal_start_rr';
  static const setDate = 'rank_goal_set_date';
  static const seasonName = 'rank_goal_season_name';
  static const archive = 'rank_goals_archive';
}

final rankGoalProvider = FutureProvider<RankGoal?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final targetTierId = prefs.getInt(RankGoalPrefsKeys.targetTierId);
  if (targetTierId == null) return null;

  final startTierId = prefs.getInt(RankGoalPrefsKeys.startTierId) ?? 0;
  final startRR = prefs.getInt(RankGoalPrefsKeys.startRR) ?? 0;
  final dateStr = prefs.getString(RankGoalPrefsKeys.setDate);
  final setDate = dateStr != null
      ? (DateTime.tryParse(dateStr) ?? DateTime.now())
      : DateTime.now();
  final seasonName = prefs.getString(RankGoalPrefsKeys.seasonName) ?? '';

  return RankGoal(
    targetTierId: targetTierId,
    startTierId: startTierId,
    startRR: startRR,
    setDate: setDate,
    seasonName: seasonName,
  );
});
