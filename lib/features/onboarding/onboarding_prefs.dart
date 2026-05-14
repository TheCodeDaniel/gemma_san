import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPrefs {
  OnboardingPrefs._();

  static const _kHasOnboarded = 'has_onboarded';
  static const _kAgeRange = 'age_range';
  static const _kAvatarId = 'avatar_id';

  static Future<bool> get hasOnboarded async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kHasOnboarded) ?? false;
  }

  static Future<void> setOnboarded() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kHasOnboarded, true);
  }

  static Future<String?> get ageRange async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kAgeRange);
  }

  static Future<void> setAgeRange(String range) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAgeRange, range);
  }

  static Future<String?> get avatarId async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kAvatarId);
  }

  static Future<void> setAvatarId(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAvatarId, id);
  }
}
