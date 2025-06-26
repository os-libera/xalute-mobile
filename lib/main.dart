import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'screens/ecg_data_service.dart';
import 'screens/ecg_page.dart';
import 'screens/setting_page.dart';
import 'screens/ecg_detail_page.dart';
import 'screens/ecg_detail_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ecgService = EcgDataService();
  await ecgService.loadInitialData();

  runApp(
    ChangeNotifierProvider.value(
      value: ecgService,
      child: const HealthApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (Platform.isAndroid) {
      debugPrint("🟢 Android 환경 - setupWatchListener 실행");
      setupWatchListener();

      final context = navigatorKey.currentContext!;
      final ecgService = Provider.of<EcgDataService>(context, listen: false);
      await preloadSavedEcgFiles(ecgService);
    } else {
      debugPrint("🟡 ECG 초기화 생략 (iOS)");
    }
  });
}

void setupWatchListener() {
  const MethodChannel platform = MethodChannel('com.example.xalute/watch');

  platform.setMethodCallHandler((call) async {
    debugPrint("👂 MethodChannel received call: ${call.method}");
    if (call.method == 'onEcgFileReceived') {
      final Map<String, dynamic> data = jsonDecode(call.arguments);

      final String fileContent = data['fileContent'];
      final String result = data['result'];
      final int timestamp = data['timestamp'];
      final Map<String, dynamic> resultJson = jsonDecode(data['result_json']);

      await saveReceivedEcg(fileContent, result, timestamp, resultJson);

      debugPrint("📈 R-peaks: ${resultJson['result']['r_peaks']}");
      debugPrint("📉 distance_from_median: ${resultJson['result']['distance_from_median']}");
    }
  });
}

Future<void> saveReceivedEcg(
    String content,
    String result,
    int timestamp,
    Map<String, dynamic> resultJson,
    ) async {
  final dir = await getApplicationDocumentsDirectory();

  final fileName = 'ecg_${timestamp}_$result.txt';
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content);
  debugPrint("✅ ECG 텍스트 저장 완료: ${file.path}");

  final jsonFileName = 'ecg_${timestamp}_$result.json';
  final jsonFile = File('${dir.path}/$jsonFileName');
  await jsonFile.writeAsString(jsonEncode(resultJson));
  debugPrint("✅ 분석 결과 JSON 저장 완료: ${jsonFile.path}");

  final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
  final mappedResult = result.toLowerCase() == 'normal' ? '정상' : '이상 소견 의심';

  final context = navigatorKey.currentContext!;
  final ecgService = Provider.of<EcgDataService>(context, listen: false);

  ecgService.addEntry(EcgEntry(
    dateTime: dateTime,
    result: mappedResult,
    color: mappedResult == '정상' ? Colors.green : const Color(0xFFFB755B),
    content: content,
  ));
}

Future<void> preloadSavedEcgFiles(EcgDataService service) async {
  final dir = await getApplicationDocumentsDirectory();
  final files = dir.listSync();

  int loadedCount = 0;

  for (var file in files) {
    if (file is! File) continue;

    final fileName = file.uri.pathSegments.last;

    if (!RegExp(r'^ecg_\d{14}_(normal|abnormal)\.txt$').hasMatch(fileName)) {
      debugPrint("⚠️ 무시된 파일: $fileName");
      continue;
    }

    try {
      final fileNameWithoutExt = fileName.substring(0, fileName.length - 4);
      final parts = fileNameWithoutExt.split('_');

      final timestampStr = parts[1];
      if (timestampStr.length != 14) {
        debugPrint("⚠️ 잘못된 timestamp 길이: $fileName");
        continue;
      }

      final year = int.parse(timestampStr.substring(0, 4));
      final month = int.parse(timestampStr.substring(4, 6));
      final day = int.parse(timestampStr.substring(6, 8));
      final hour = int.parse(timestampStr.substring(8, 10));
      final minute = int.parse(timestampStr.substring(10, 12));
      final second = int.parse(timestampStr.substring(12, 14));
      final dateTime = DateTime(year, month, day, hour, minute, second);

      final result = parts[2].toLowerCase() == 'normal' ? '정상' : '이상 소견 의심';
      final color = result == '정상' ? Colors.green : const Color(0xFFFB755B);
      final content = await file.readAsString();

      final isDuplicate = service.entries.any((entry) =>
      entry.dateTime == dateTime && entry.content == content);
      if (isDuplicate) {
        debugPrint("🔁 중복 생략: $fileName");
        continue;
      }

      service.addEntry(EcgEntry(
        dateTime: dateTime,
        result: result,
        color: color,
        content: content,
      ));

      loadedCount++;
    } catch (e) {
      debugPrint("❌ 파일 처리 실패: $fileName / $e");
    }
  }

  debugPrint("✅ 로딩 완료: $loadedCount개 ECG 파일 불러옴");
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Xalute',
      theme: ThemeData(
        fontFamily: "Pretendard",
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const EcgPage(),
      routes: {
        '/settings': (context) => const SettingPage(),
        '/ecgDetail': (context) => const EcgDetailPage(
          txtPath: '',
          jsonPath: '',
          timestamp: DateTime.now(),
          result: '',
          deviceType: '',
        ), // placeholder
      },
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ko', 'KR'),
      ],
    );
  }
}
