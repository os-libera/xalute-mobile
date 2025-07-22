import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class EcgEntry {
  final DateTime dateTime;
  final String result;
  final Color color;
  final String content;
  final String txtPath;
  final String jsonPath;
  final String deviceType;

  EcgEntry({
    required this.dateTime,
    required this.result,
    required this.color,
    required this.content,
    required this.txtPath,
    required this.jsonPath,
    required this.deviceType,
  });
}

class EcgDataService extends ChangeNotifier {
  static const _channel = MethodChannel('com.example.health/ecg');

  EcgDataService() {
    loadInitialData().then((_) async {
      await _importJulySamplesIfNeeded();
      await loadFromLocalFiles();
    });
  }

  DateTime _parseFileDate(String raw) {
    final cleaned = raw
        .replaceFirst('T', ' ')
        .replaceAll('-', ':');
    return DateTime.parse(cleaned);
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
 Future<bool> _requestAuthorization() async {
  if (!Platform.isIOS) return true;
  try {
    final granted = await _channel.invokeMethod<bool>('requestAuthorization');
    return granted == true;
  } on PlatformException {
    return false;
  }
}
  Future<void> fetchEcgData() async {
  try {
    if (Platform.isIOS) {
      final ok = await _requestAuthorization();
      if (!ok) {
        throw 'HealthKit 권한이 필요합니다.';
      }
    }
    final List<dynamic> raw = await _channel.invokeMethod('getECGData');

    for (var item in raw) {
      final dateTime = DateTime.parse(item['date'] as String);

      final rawResult = (item['prediction'] as String).toLowerCase();

      final mappedResult = rawResult == 'normal'? '정상' : '이상 소견 의심';

      final color = mappedResult.contains('이상 소견 의심') ? const Color(0xFFFB755B) : Colors.grey[700]!;

      final txtPath  = item['txtPath']  as String? ?? '';
      final jsonPath = item['jsonPath'] as String? ?? '';

      _entries.add(EcgEntry(
        dateTime: dateTime,
        result: mappedResult,
        content: '',
        color: color,
        txtPath: txtPath,
        jsonPath: jsonPath,
        deviceType: Platform.isIOS ? 'iOS' : 'Android',
      ));
    }
    notifyListeners();
  } on PlatformException catch (e) {
    throw 'HealthKit 요청 실패: ${e.message}';
  }
}

  Future<void> loadFromLocalFiles() async {
    final dir = Directory('/data/user/0/com.example.xalute/app_flutter');
    if (!dir.existsSync()) return;

    final files = dir.listSync();

    for (var file in files) {
      if (file is! File || !file.path.endsWith('.txt')) continue;

      final jsonPath = file.path.replaceAll('.txt', '.json');
      if (!File(jsonPath).existsSync()) continue;

      final base = p.basenameWithoutExtension(file.path);
      final parts = base.split('_');
      if (parts.length < 4) continue;

      final timestamp = _parseFileDate(parts[1]);
      final resultKor = parts[2] == 'abnormal' ? '이상 소견 의심' : '정상';

      final color = resultKor == '이상 소견 의심'
          ? const Color(0xFFFB755B)
          : Colors.grey[700]!;

      _entries.add(EcgEntry(
        dateTime: timestamp,
        result: resultKor,
        color: color,
        content: await file.readAsString(),
        txtPath: file.path,
        jsonPath: jsonPath,
        deviceType: Platform.isIOS ? 'iOS' : 'Android',
      ));
    }
    notifyListeners();
  }

  void _addEntryFromPaths({
    required String txtPath,
    required String jsonPath,
    required String result,
  }) {
    final parts = p.basenameWithoutExtension(txtPath).split('_');
    final dateTime = _parseFileDate(parts[1]);

    _entries.add(EcgEntry(
      dateTime: dateTime,
      result: result,
      color: result == '정상' ? Colors.grey[700]! : const Color(0xFFFB755B),
      content: '',
      txtPath: txtPath,
      jsonPath: jsonPath,
      deviceType: 'iOS',
    ));
  }

  Future<void> _importJulySamplesIfNeeded() async {
    if (!Platform.isIOS) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('julySamplesImported') ?? false) {
      debugPrint('[EcgDataService] 7월 샘플');
      return;
    }

    final sampleNames = List.generate(31, (i) {
      final d = (i + 1).toString().padLeft(2, '0');
      final result = (i.isEven) ? 'abnormal' : 'normal';
      return 'ecg_2025-07-${d}T09-00-00_${result}_raw';
    });

    final appDir = await getApplicationDocumentsDirectory();

    for (final name in sampleNames) {
      try {
        final txtData = await rootBundle.loadString('assets/ecg_samples/$name.txt');
        final txtPath = p.join(appDir.path, '$name.txt');
        await File(txtPath).writeAsString(txtData, flush: true);

        final jsonData = await rootBundle.loadString('assets/ecg_samples/$name.json');
        final jsonPath = p.join(appDir.path, '$name.json');
        await File(jsonPath).writeAsString(jsonData, flush: true);

        final parts = name.split('_');            // [ecg, 2025-07-.., normal/abnormal, raw]
        final resultKor = parts[2] == 'abnormal' ? '이상 소견 의심' : '정상';

        _addEntryFromPaths(
          txtPath: txtPath,
          jsonPath: jsonPath,
          result: resultKor,
        );

        debugPrint('[EcgDataService] 샘플 불러오기 완료: $name');
      } catch (e) {
        debugPrint('[$name] 샘플 누락: $e');
      }
    }

    await prefs.setBool('julySamplesImported', true);
    notifyListeners();
  }

}
