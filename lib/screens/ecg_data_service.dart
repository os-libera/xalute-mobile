import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EcgEntry {
  final DateTime dateTime;
  final String result;
  final Color color;
  final String content;

  EcgEntry({
    required this.dateTime,
    required this.result,
    required this.color,
    required this.content,
  });
}

class EcgDataService extends ChangeNotifier {
  EcgDataService() {
    loadInitialData();
  }

  final List<EcgEntry> _entries = [];

  String _userName = 'User';
  String? _profileImagePath;
  bool _isLoading = true;

  List<EcgEntry> get entries => _entries;
  String get userName => _userName;
  String? get profileImagePath => _profileImagePath;
  bool get isLoading => _isLoading;

  void setUserName(String name) {
    _userName = name.isEmpty ? "User" : name;
    _saveToPrefs('username', _userName);
    notifyListeners();
  }

  void setProfileImagePath(String? path) {
    _profileImagePath = path;
    if (path != null) {
      _saveToPrefs('profileImagePath', path);
    } else {
      _removeFromPrefs('profileImagePath');
    }
    notifyListeners();
  }

  Future<void> loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('username') ?? 'User';
    _profileImagePath = prefs.getString('profileImagePath');
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveToPrefs(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _removeFromPrefs(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Map<DateTime, List<String>> get statusMap {
    final map = <DateTime, List<String>>{};
    for (var e in _entries) {
      final dayKey = DateTime.utc(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      map.putIfAbsent(dayKey, () => []);
      map[dayKey]!.add(e.result);
    }
    return map;
  }

  void addEntry(EcgEntry entry) {
    _entries.add(entry);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  List<EcgEntry> entriesForDay(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    return _entries.where((e) {
      final ed = DateTime.utc(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      return ed == d;
    }).toList();
  }
}
