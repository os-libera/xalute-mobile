import 'dart:io';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/services.dart';

class EcgPage extends StatefulWidget {
  const EcgPage({super.key});

  @override
  State<EcgPage> createState() => _EcgPageState();
}

class _EcgPageState extends State<EcgPage> {
  bool isCalendarExpanded = true;
  bool isLoading = false;
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  static const platform = MethodChannel('com.example.xalute/watch');

  // 임시 데이터
  Map<DateTime, List<String>> statusMap = {
    DateTime.utc(2025, 4, 17): ['정상', '비정상'],
    DateTime.utc(2025, 4, 20): ['정상', '정상'],
    DateTime.utc(2025, 4, 21): ['정상'],
    DateTime.utc(2025, 4, 23): ['정상'],
    DateTime.utc(2025, 4, 24): ['비정상', '비정상'],
    DateTime.utc(2025, 5, 24): ['비정상', '비정상'],
  };

  List<Map<String, dynamic>> results = [
    {
      'date': '4월 17일 11시 08분',
      'status': '정상',
      'color': Colors.green
    },
    {
      'date': '4월 17일 19시 52분',
      'status': '비정상',
      'color': Colors.red
    },
  ];

  // android, ioS 분기
  void _handleMeasureButton() {
    if (Platform.isAndroid) {
      _showAndroidMeasureDialog();
    } else if (Platform.isIOS) { // iOS 파트 수정 필요
      setState(() => isLoading = true);
      Future.delayed(const Duration(seconds: 2), () {
        setState(() => isLoading = false);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: const Text("건강 앱에서 데이터를 조회 중입니다."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("확인"),
              )
            ],
          ),
        );
      });
    }
  }

  // android 분기
  void _showAndroidMeasureDialog() async {
    try {
      final bool isConnected = await platform.invokeMethod('isWatchConnected');
      if (!isConnected) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: const Text("워치와의 연결을 확인해주세요."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("확인"),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text("워치에서 ECG 측정을 진행하시겠습니까?"),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await platform.invokeMethod('launchWatchApp');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("워치 앱 실행됨")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("워치 앱 실행 실패")),
                  );
                }
              },
              child: const Text("확인"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
          ],
        ),
      );
    } on PlatformException catch (e) {
      debugPrint("플랫폼 오류: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalCount = 0;
    int todayCount = 0;
    final now = DateTime.now();
    final selected = selectedDay ?? now;
    final normalizedSelected = DateTime.utc(selected.year, selected.month, selected.day);
    final selectedStatuses = statusMap[normalizedSelected] ?? [];

    for (var entry in statusMap.entries) {
      if (entry.key.month == selected.month) {
        totalCount += entry.value.length;
      }
    }
    todayCount = selectedStatuses.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("ECG 기록"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${focusedDay.year}.${focusedDay.month}", style: const TextStyle(fontSize: 20)),
                IconButton(
                  icon: Icon(isCalendarExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => isCalendarExpanded = !isCalendarExpanded),
                ),
              ],
            ),
          ),
          if (isCalendarExpanded)
            TableCalendar(
              focusedDay: focusedDay,
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              onDaySelected: (selected, focused) => setState(() {
                selectedDay = selected;
                focusedDay = focused;
              }),
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month'
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                disabledTextStyle: const TextStyle(color: Colors.grey),
              ),
              enabledDayPredicate: (day) => statusMap.containsKey(DateTime.utc(day.year, day.month, day.day)),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, _) {
                  final statuses = statusMap[DateTime.utc(day.year, day.month, day.day)];
                  if (statuses == null) {
                    return Center(
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  int normalCount = statuses.where((e) => e == '정상').length;
                  int abnormalCount = statuses.where((e) => e == '비정상').length;

                  return Column(
                    children: [
                      Text('${day.day}', style: const TextStyle(color: Colors.black)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (normalCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: CircleAvatar(
                                radius: 8,
                                backgroundColor: Colors.green,
                                child: Text('$normalCount', style: const TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                            ),
                          if (abnormalCount > 0)
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: Colors.red,
                              child: Text('$abnormalCount', style: const TextStyle(fontSize: 10, color: Colors.white)),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _handleMeasureButton,
                  child: Text(Platform.isAndroid ? "측정하기" : "조회하기"),
                ),
                const SizedBox(height: 12),
                Text("총 측정 횟수: $totalCount회", style: const TextStyle(fontSize: 16)),
                Text("오늘 측정 횟수: $todayCount회", style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          if (isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  return Card(
                    color: result['color'].withOpacity(0.1),
                    child: ListTile(
                      title: Text(result['date']),
                      subtitle: Text(result['status'], style: TextStyle(color: result['color'])),
                      trailing: TextButton(
                        onPressed: () {},
                        child: const Text("자세히"),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
