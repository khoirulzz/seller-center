import 'package:shared_preferences/shared_preferences.dart';

/// Local, per-account acknowledgement; store switching does not reset the tour.
class FeatureGuideService {
  static String keyFor(String userId) => 'ns_feature_guide_v2_$userId';

  Future<bool> hasSeen(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(keyFor(userId)) ?? false;
  }

  Future<void> markSeen(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(keyFor(userId), true);
  }
}
