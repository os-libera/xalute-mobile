import 'package:flutter/material.dart';

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
  final List<EcgEntry> _entries = [];

  List<EcgEntry> get entries => _entries;

  Map<DateTime, List<String>> get statusMap {
    final map = <DateTime, List<String>>{};
    for (var e in _entries) {
      final dayKey = DateTime.utc(e.dateTime.year, e.dateTime.month, e.dateTime.day); // ✅ UTC 기준
      map.putIfAbsent(dayKey, () => []);
      map[dayKey]!.add(e.result);
    }
    return map;
  }

  void addEntry(EcgEntry entry) {
    _entries.add(entry);
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

