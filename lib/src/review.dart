import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for a Play Store rating at happy moments only, at most every 60
/// days. Google Play applies its own quota on top of this.
class ReviewPrompter {
  ReviewPrompter(this._prefs);

  final SharedPreferences _prefs;

  static const _askedKey = 'review_asked_at';
  static const _milestones = {5, 25, 75};
  static const _cooldown = Duration(days: 60);

  bool shouldAsk({required int totalPomodoros, required bool goalJustReached}) {
    if (!_milestones.contains(totalPomodoros) && !goalJustReached) return false;
    final last = _prefs.getInt(_askedKey);
    if (last == null) return totalPomodoros >= 3;
    return DateTime.now().millisecondsSinceEpoch - last >
        _cooldown.inMilliseconds;
  }

  Future<void> maybeAsk({
    required int totalPomodoros,
    required bool goalJustReached,
  }) async {
    if (!shouldAsk(
      totalPomodoros: totalPomodoros,
      goalJustReached: goalJustReached,
    )) {
      return;
    }
    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      await _prefs.setInt(_askedKey, DateTime.now().millisecondsSinceEpoch);
      await review.requestReview();
    } catch (error) {
      debugPrint('In-app review unavailable: $error');
    }
  }
}
