import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'ecg_data_service.dart';
import '../main.dart'; // navigatorKey, preloadSavedEcgFiles 사용 시 필요

class EcgPage extends StatefulWidget {
  const EcgPage({super.key});

  @override
  State<EcgPage> createState() => _EcgPageState();
}

class _EcgPageState extends State<EcgPage> {
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;

  @override
  void initState() {
    super.initState();
    selectedDay = DateTime.now();
    final ecgService = Provider.of<EcgDataService>(context, listen: false);
    preloadSavedEcgFiles(ecgService); // 초기 로딩
    ecgService.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _refreshCalendarData() async {
    final context = navigatorKey.currentContext!;
    final ecgService = Provider.of<EcgDataService>(context, listen: false);
    ecgService.clear();
    await preloadSavedEcgFiles(ecgService);
    setState(() {});
  }

  void _openSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  void _handleMeasureButton() async {
    if (Platform.isAndroid) {
      const platform = MethodChannel('com.example.xalute/watch');
      try {
        final bool isConnected = await platform.invokeMethod('isWatchConnected');
        if (!isConnected) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: const Text("워치와의 연결을 확인해주세요."),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("확인"))],
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("워치 앱 실행됨")));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("워치 앱 실행 실패")));
                  }
                },
                child: const Text("확인"),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
            ],
          ),
        );
      } on PlatformException catch (e) {
        debugPrint("플랫폼 오류: \${e.message}");
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("To do")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ecgService = Provider.of<EcgDataService>(context);
    final selected = selectedDay ?? DateTime.now();
    final normalizedSelected = DateTime.utc(selected.year, selected.month, selected.day);
    final selectedResults = ecgService.entriesForDay(normalizedSelected);
    final monthResults = ecgService.entries.where((entry) =>
    entry.dateTime.year == focusedDay.year && entry.dateTime.month == focusedDay.month).toList();
    final abnormalMonthTotal = monthResults.where((e) => e.result == '이상 소견 의심').length;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${ecgService.userName}님의 건강점수는",
                            style: const TextStyle(fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Text("72점", style: TextStyle(fontSize: 32, color: Color(0xFFFB755B), fontWeight: FontWeight.bold)),
                              SizedBox(width: 6),
                              Icon(Icons.chevron_right)
                            ],
                          ),
                          const Text("어제보다 3점 올랐어요", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _openSettings,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 8),
                        child: Image.asset('assets/icon/profile.png', width: 48, height: 48),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() => focusedDay = DateTime(focusedDay.year, focusedDay.month - 1)),
                    ),
                    Text("${focusedDay.year}년 ${focusedDay.month}월", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() => focusedDay = DateTime(focusedDay.year, focusedDay.month + 1)),
                    ),
                    IconButton(icon: const Icon(Icons.refresh, size: 20), tooltip: '새로고침', onPressed: _refreshCalendarData),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(children: [
                        const Text("총 측정횟수", style: TextStyle(fontSize: 14)),
                        Text("${monthResults.length}회", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                      ]),
                      Column(children: [
                        const Text("이상 소견 의심", style: TextStyle(fontSize: 14)),
                        Text("$abnormalMonthTotal회", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                      ])
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TableCalendar(
                focusedDay: focusedDay,
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                onDaySelected: (selected, focused) => setState(() { selectedDay = selected; focusedDay = focused; }),
                onPageChanged: (newFocusedDay) => setState(() => focusedDay = newFocusedDay),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.sunday,
                headerVisible: false,
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  todayDecoration: const BoxDecoration(),
                  todayTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  selectedDecoration: BoxDecoration(color: Color(0xFFFFEEEA), shape: BoxShape.circle),
                ),
                enabledDayPredicate: (day) {
                  final normalized = DateTime.utc(day.year, day.month, day.day);
                  return ecgService.statusMap.containsKey(normalized);
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, _) {
                    final normalized = DateTime.utc(day.year, day.month, day.day);
                    final statuses = ecgService.statusMap[normalized];
                    if (statuses == null) return null;
                    final abnormalCount = statuses.where((e) => e == '이상 소견 의심').length;
                    final totalCount = statuses.length;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${day.day}', style: const TextStyle(color: Colors.black)),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(text: '$abnormalCount', style: const TextStyle(fontSize: 10, color: Color(0xFFFB755B))),
                              const TextSpan(text: ' / ', style: TextStyle(fontSize: 10, color: Colors.black54)),
                              TextSpan(text: '$totalCount', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },

                  // ✅ 이 부분을 추가하세요
                  todayBuilder: (context, day, _) {
                    final normalized = DateTime.utc(day.year, day.month, day.day);
                    final statuses = ecgService.statusMap[normalized];
                    if (statuses == null) return null;
                    final abnormalCount = statuses.where((e) => e == '이상 소견 의심').length;
                    final totalCount = statuses.length;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(text: '$abnormalCount', style: const TextStyle(fontSize: 10, color: Color(0xFFFB755B))),
                              const TextSpan(text: ' / ', style: TextStyle(fontSize: 10, color: Colors.black54)),
                              TextSpan(text: '$totalCount', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, color: Color(0xFFFB755B), size: 8),
                    SizedBox(width: 4),
                    Text("이상 소견 의심", style: TextStyle(fontSize: 12)),
                    SizedBox(width: 16),
                    Icon(Icons.circle, color: Colors.grey, size: 8),
                    SizedBox(width: 4),
                    Text("전체 측정 횟수", style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: selectedResults.map((entry) {
                    final formatted = DateFormat('M월 d일 HH시 mm분').format(entry.dateTime);
                    final isAbnormal = entry.result == '이상 소견 의심';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(formatted),
                      trailing: Text(
                        entry.result,
                        style: TextStyle(color: isAbnormal ? const Color(0xFFFB755B) : Colors.grey[700], fontWeight: FontWeight.w500),
                      ),
                      onTap: () {},
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFB755B),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _handleMeasureButton,
                    child: Text(
                      Platform.isIOS ? "데이터 조회" : "측정 시작",
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/**import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'ecg_data_service.dart';
import '../main.dart'; // navigatorKey 및 preloadSavedEcgFiles 사용 위해

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
    final ecgService = Provider.of<EcgDataService>(context, listen: false);
    ecgService.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _refreshCalendarData() async {
    final context = navigatorKey.currentContext!;
    final ecgService = Provider.of<EcgDataService>(context, listen: false);
    ecgService.clear(); // 기존 메모리 데이터 초기화
    await preloadSavedEcgFiles(ecgService); // 저장된 파일에서 다시 로딩
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
    final normalizedSelected = DateTime.utc(selected.year, selected.month, selected.day);
    final statusMap = ecgService.statusMap;
    final selectedResults = ecgService.entriesForDay(normalizedSelected);

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
                Row(
                  children: [
                    IconButton(
                      icon: Icon(isCalendarExpanded ? Icons.expand_less : Icons.expand_more),
                      onPressed: () => setState(() => isCalendarExpanded = !isCalendarExpanded),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: "캘린더 새로고침",
                      onPressed: _refreshCalendarData,
                    ),
                  ],
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
                final normalized = DateTime.utc(day.year, day.month, day.day);
                return statusMap.containsKey(normalized);
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, _) {
                  final normalized = DateTime.utc(day.year, day.month, day.day);
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
**/