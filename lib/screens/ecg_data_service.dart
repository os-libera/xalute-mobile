import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

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
  static const _channel = MethodChannel('com.example.health/ecg');

  EcgDataService() {
    loadInitialData();
  }

  final List<EcgEntry> _entries = [];

  String _userName = 'User';
  String? _profileImagePath;
  bool _isLoading = true;

  String? _birthDate;
  String? get birthDate => _birthDate;

  List<EcgEntry> get entries => _entries;
  String get userName => _userName;
  String? get profileImagePath => _profileImagePath;
  bool get isLoading => _isLoading;

  void setUserName(String name) {
    _userName = name.isEmpty ? "User" : name;
    _saveToPrefs('username', _userName);
    notifyListeners();
  }

  void setBirthDate(String? date) {
    _birthDate = date;
    if (date != null) {
      _saveToPrefs('birthDate', date);
    } else {
      _removeFromPrefs('birthDate');
    }
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
    _birthDate = prefs.getString('birthDate');
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

  Future<void> fetchEcgData() async {
    try {
      final List<dynamic> raw = await _channel.invokeMethod('getECGData');

      for (var item in raw) {
        final dateTime = DateTime.parse(item['date'] as String);
        final resultStr = item['prediction'] as String;
        final color = resultStr.contains('이상')
            ? const Color(0xFFFB755B)
            : Colors.grey[700]!;
        _entries.add(EcgEntry(
          dateTime: dateTime,
          result: resultStr,
          content: '',
          color: color,
        ));
      }

      notifyListeners();
    } on PlatformException catch (e) {
      throw 'HealthKit 요청 실패: ${e.message}';
    }
  }
}
