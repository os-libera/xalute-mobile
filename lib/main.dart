import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'screens/ecg_data_service.dart';
import 'screens/splash_screen.dart';
import 'screens/setting_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final app = ChangeNotifierProvider(
    create: (_) => EcgDataService(),
    child: const HealthApp(),
  );

  runApp(app);

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

      final Map<String, dynamic> resultObj = jsonDecode(data['result']);
      final String result = resultObj['result'];
      final int timestamp = data['timestamp'];

      debugPrint("📥 saveReceivedEcg 실행 직전: result=$result");
      await saveReceivedEcg(fileContent, result, timestamp);
    }
  });
}

Future<void> saveReceivedEcg(String content, String result, int timestamp) async {
  debugPrint("📥 saveReceivedEcg called with result=$result");

  final dir = await getApplicationDocumentsDirectory();
  final fileName = 'ecg_${timestamp}_$result.txt';
  final file = File('${dir.path}/$fileName');

  await file.writeAsString(content);
  debugPrint("📥 ECG 저장 완료: ${file.path}");

  final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
  final mappedResult = result.toLowerCase() == 'normal' ? '정상' : '이상 소견 의심'; // ✅ 변경

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

  for (var file in files) {
    if (file is File && file.path.contains('ecg_') && file.path.endsWith('.txt')) {
      final fileName = file.uri.pathSegments.last;
      final parts = fileName.split('_');

      if (parts.length >= 3) {
        final timestampStr = parts[1];
        final resultWithExtension = parts[2];

        try {
          int timestamp;
          if (timestampStr.length == 13) {
            timestamp = int.parse(timestampStr);
          } else if (timestampStr.length == 14) {
            final year = int.parse(timestampStr.substring(0, 4));
            final month = int.parse(timestampStr.substring(4, 6));
            final day = int.parse(timestampStr.substring(6, 8));
            final hour = int.parse(timestampStr.substring(8, 10));
            final minute = int.parse(timestampStr.substring(10, 12));
            final second = int.parse(timestampStr.substring(12, 14));
            final dt = DateTime(year, month, day, hour, minute, second);
            timestamp = dt.millisecondsSinceEpoch;
          } else {
            debugPrint("❌ 인식 불가 timestamp: $timestampStr → 삭제");
            await file.delete();
            continue;
          }

          final dt = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
          final resultRaw = resultWithExtension.split('.').first;
          final result = resultRaw.toLowerCase() == 'normal' ? '정상' : '이상 소견 의심'; // ✅ 변경
          final color = result == '정상' ? Colors.green : const Color(0xFFFB755B);
          final content = await file.readAsString();

          service.addEntry(EcgEntry(
            dateTime: dt,
            result: result,
            color: color,
            content: content,
          ));

          debugPrint("✅ 파일 로딩: $fileName → ${dt.toIso8601String()} / $result");
        } catch (e) {
          debugPrint("⚠️ 파일 파싱 실패: $fileName / $e");
        }
      }
    }
  }

  debugPrint("📦 총 파일 로드 수: ${service.entries.length}");
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
      home: const SplashScreen(),
      routes: {
        '/settings': (context) => const SettingPage(),
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
