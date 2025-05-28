import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/services.dart';
import 'ecg_data_service.dart';

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

  @override
  void initState() {
    super.initState();
    selectedDay = DateTime.now();
    Future.delayed(Duration.zero, () {
      final ecgService = Provider.of<EcgDataService>(context, listen: false);
      ecgService.addListener(() {
        if (mounted) setState(() {});
      });
    });
  }

  void _handleMeasureButton() {
    if (Platform.isAndroid) {
      _showAndroidMeasureDialog();
    } else if (Platform.isIOS) {
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
    } else {
      debugPrint("⚠️ 지원되지 않는 플랫폼에서 버튼 눌림");
    }
  }

  void _showAndroidMeasureDialog() async {
    if (!Platform.isAndroid) return;

    const platform = MethodChannel('com.example.xalute/watch');

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
    final ecgService = Provider.of<EcgDataService>(context);
    final now = DateTime.now();
    final selected = selectedDay ?? now;
    final normalizedSelected = DateTime(selected.year, selected.month, selected.day);
    final statusMap = ecgService.statusMap;
    final selectedResults = ecgService.entriesForDay(normalizedSelected);

    debugPrint("✅ 현재 statusMap: ${statusMap.keys}");
    debugPrint("✅ entries: ${ecgService.entries.length}");
    debugPrint("📆 선택된 날짜: ${normalizedSelected.toIso8601String()}");
    debugPrint("✅ 선택된 날짜의 결과 개수: ${selectedResults.length}");

    int totalCount = statusMap.entries
        .where((e) => e.key.month == selected.month && e.key.year == selected.year)
        .fold(0, (sum, e) => sum + e.value.length);
    int todayCount = selectedResults.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("ECG"),
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
              onDaySelected: (selected, focused) {
                setState(() {
                  selectedDay = selected;
                  focusedDay = focused;
                });
              },
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
              enabledDayPredicate: (day) {
                final normalized = DateTime(day.year, day.month, day.day);
                return statusMap.containsKey(normalized);
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, _) {
                  final normalized = DateTime(day.year, day.month, day.day);
                  final statuses = statusMap[normalized];
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
                itemCount: selectedResults.length,
                itemBuilder: (context, index) {
                  final result = selectedResults[index];
                  return Card(
                    color: result.color.withOpacity(0.1),
                    child: ListTile(
                      title: Text("${result.dateTime.month}월 ${result.dateTime.day}일 ${result.dateTime.hour}시 ${result.dateTime.minute}분"),
                      subtitle: Text(result.result, style: TextStyle(color: result.color)),
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
