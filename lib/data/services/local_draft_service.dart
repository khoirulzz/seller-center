import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan draft lokal terisolasi per `(userId, storeId, resourceType, resourceId)`
/// sesuai `PRD` Bab 9.3. Tidak pernah dianggap sebagai commit server.
class LocalDraftEntry {
  const LocalDraftEntry({
    required this.key,
    required this.schemaVersion,
    required this.updatedAt,
    required this.data,
  });

  final String key;
  final int schemaVersion;
  final DateTime updatedAt;
  final Map<String, dynamic> data;
}

class LocalDraftService {
  static const String _activeStorePrefix = 'ns_active_store_';
  static const String _draftPrefix = 'ns_draft_v1_';
  static const String _sessionKey = 'ns_firebase_session_v1';
  static const String _biometricLockKey = 'ns_biometric_lock_enabled';

  String buildDraftKey({
    required String userId,
    required String storeId,
    required String resourceType,
    required String resourceId,
  }) {
    return '$_draftPrefix${userId}_${storeId}_${resourceType}_$resourceId';
  }

  Future<void> saveActiveStoreId(String userId, String storeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_activeStorePrefix$userId', storeId);
  }

  Future<String?> loadActiveStoreId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_activeStorePrefix$userId');
  }

  Future<void> saveSessionJson(Map<String, dynamic> sessionJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(sessionJson));
  }

  Future<Map<String, dynamic>?> loadSessionJson() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<void> saveDraft({
    required String userId,
    required String storeId,
    required String resourceType,
    required String resourceId,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = buildDraftKey(
      userId: userId,
      storeId: storeId,
      resourceType: resourceType,
      resourceId: resourceId,
    );
    final wrapper = {
      'schemaVersion': 1,
      'updatedAt': DateTime.now().toIso8601String(),
      'data': payload,
    };
    await prefs.setString(key, jsonEncode(wrapper));
  }

  Future<LocalDraftEntry?> loadDraft({
    required String userId,
    required String storeId,
    required String resourceType,
    required String resourceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = buildDraftKey(
      userId: userId,
      storeId: storeId,
      resourceType: resourceType,
      resourceId: resourceId,
    );
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return LocalDraftEntry(
        key: key,
        schemaVersion: (decoded['schemaVersion'] as num?)?.toInt() ?? 1,
        updatedAt: DateTime.tryParse((decoded['updatedAt'] ?? '').toString()) ??
            DateTime.now(),
        data: (decoded['data'] as Map<String, dynamic>?) ?? const {},
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteDraft({
    required String userId,
    required String storeId,
    required String resourceType,
    required String resourceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = buildDraftKey(
      userId: userId,
      storeId: storeId,
      resourceType: resourceType,
      resourceId: resourceId,
    );
    await prefs.remove(key);
  }

  Future<bool> getBiometricLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricLockKey) ?? false;
  }

  Future<void> setBiometricLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricLockKey, enabled);
  }
}
