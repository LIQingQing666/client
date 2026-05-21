import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class StorageService {
  StorageService({required this.prefs, required this.box});

  final SharedPreferences prefs;
  final Box<dynamic> box;

  // ---- Token ----

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _roleKey = 'user_role';

  String? get token => prefs.getString(_tokenKey);
  String? get userId => prefs.getString(_userIdKey);
  String? get role => prefs.getString(_roleKey);

  Future<void> setToken(String token) => prefs.setString(_tokenKey, token);

  Future<void> setUserId(String id) => prefs.setString(_userIdKey, id);

  Future<void> setRole(String role) => prefs.setString(_roleKey, role);

  Future<void> clearAuth() async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_roleKey);
  }

  // ---- User Profile ----

  static const _userProfileKey = 'profile';

  Map<String, dynamic>? getUserProfile() {
    final raw = box.get(_userProfileKey);
    if (raw is String) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> setUserProfile(Map<String, dynamic> profile) async {
    await box.put(_userProfileKey, jsonEncode(profile));
  }

  // ---- Browsing History ----

  static const _historyKey = 'browsing_history';
  static const int _maxHistoryItems = 100;

  List<Map<String, dynamic>> getBrowsingHistory() {
    final raw = box.get(_historyKey);
    if (raw is String) {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> addBrowsingHistory(Map<String, dynamic> item) async {
    final history = getBrowsingHistory();
    final id = item['id']?.toString();

    history.removeWhere((h) => h['id']?.toString() == id);

    item['browsedAt'] = DateTime.now().toIso8601String();
    history.insert(0, item);

    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }

    await box.put(_historyKey, jsonEncode(history));
  }

  Future<void> clearBrowsingHistory() async {
    await box.delete(_historyKey);
  }

  // ---- Generic ----

  Future<void> setString(String key, String value) => box.put(key, value);

  String? getString(String key) => box.get(key) as String?;

  Future<void> remove(String key) => box.delete(key);
}
