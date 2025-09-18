/** Main **/
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'ecg_data_service.dart';
import '../main.dart';
import 'package:lottie/lottie.dart';

class EcgPage extends StatefulWidget {
  const EcgPage({super.key});

  @override
  State<EcgPage> createState() => _EcgPageState();
}

class _EcgPageState extends State<EcgPage> {
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  bool isLoading = false;
  bool isCalendarExpanded = true;

  @override
  void initState() {
    super.initState();
    selectedDay = DateTime.now();
    final ecgService = Provider.of<EcgDataService>(context, listen: false);
    preloadSavedEcgFiles(ecgService);
    ecgService.addListener(() {
      if (mounted) setState(() {});
    });
    Future.delayed(Duration.zero, () {
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

  void _openSettings() async {
    final result = await Navigator.pushNamed(context, '/settings');
    if (result == true && mounted) {
      setState(() {});
    }
  }

  void _handleMeasureButton() async {
    if (Platform.isAndroid) {
      const platform = MethodChannel('com.example.xalute/watch');
      try {
        final bool isConnected = await platform.invokeMethod(
            'isWatchConnected');
        if (!isConnected) {
          showDialog(
            context: context,
            builder: (context) =>
                AlertDialog(
                  content: const Text(
                      "워치와의 연결을 확인해주세요."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context),
                        child: const Text("확인"))
                  ],
                ),
          );
          return;
        }

        final ecgService = Provider.of<EcgDataService>(context, listen: false);
        final name = ecgService.userName ?? "User";
        final birthDate = ecgService.birthDate ?? "";

        showDialog(
          context: context,
          builder: (context) =>
              AlertDialog(
                content: const Text(
                    "워치를 통해 ECG 측정을 시작하시겠습니까?"),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await platform.invokeMethod('launchWatchApp', {
                          'name': name,
                          'birthDate': birthDate,
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("워치 앱 실행.")));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("워치 앱 실행 실패.")));
                      }
                    },
                    child: const Text("확인"),
                  ),
                  TextButton(onPressed: () => Navigator.pop(context),
                      child: const Text("취소")),
                ],
              ),
        );
      } on PlatformException catch (e) {
        debugPrint("플랫폼 오류: ${e.message}");
      }
    } else {
      setState(() => isLoading = true);
      try {
        final ecgService = Provider.of<EcgDataService>(context, listen: false);
        final initialEntriesCount = ecgService.entries.length;

        await ecgService.fetchEcgData();
        final newEntriesCount = ecgService.entries.length;
        if (newEntriesCount <= initialEntriesCount) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("알림"),
                content: const Text("ECG 데이터를 측정해주세요."),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("확인"),
                  ),
                ],
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${newEntriesCount - initialEntriesCount}개의 새로운 ECG 데이터를 가져왔습니다.')),
            );
          }
        }
      } catch (e, stack) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
            SnackBar(content: Text('ECG 데이터 조회 실패: $e')));
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ecgService = Provider.of<EcgDataService>(context);
    final selected = selectedDay ?? DateTime.now();
    final normalizedSelected = DateTime.utc(
        selected.year, selected.month, selected.day);
    final selectedResults = ecgService.entriesForDay(normalizedSelected);
    final monthResults = ecgService.entries
        .where((entry) =>
    entry.dateTime.year == focusedDay.year &&
        entry.dateTime.month == focusedDay.month)
        .toList();
    final abnormalMonthTotal = monthResults
        .where((e) => e.result == '이상 소견 의심')
        .length;

    if (ecgService.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            top: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${ecgService.userName}님",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 24,
                                height: 32 / 24,
                                letterSpacing: 0.0,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: const [
                                Text(
                                  "건강 점수는 72점",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 24,
                                    height: 32 / 24,
                                    letterSpacing: 0.0,
                                    color: Color(0xFFFB755B),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.chevron_right),
                              ],
                            ),
                            const Text(
                              "어제보다 3점 상승",
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 13,
                                height: 1.0,
                                letterSpacing: 0.0,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Align(
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: _openSettings,
                          child: Consumer<EcgDataService>(
                            builder: (context, ecgService, child) {
                              return CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: ecgService.profileImagePath !=
                                    null
                                    ? FileImage(
                                    File(ecgService.profileImagePath!))
                                    : const AssetImage(
                                    'assets/icon/profile.png') as ImageProvider,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            "${focusedDay.year}.${focusedDay.month}",
                            style: const TextStyle(fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                setState(() => focusedDay = DateTime(
                                    focusedDay.year, focusedDay.month - 1)),
                            child: Icon(Icons.chevron_left,
                                color: Colors.grey[700], size: 24),
                          ),
                          const SizedBox(width: 2),
                          GestureDetector(
                            onTap: () =>
                                setState(() => focusedDay = DateTime(
                                    focusedDay.year, focusedDay.month + 1)),
                            child: Icon(Icons.chevron_right,
                                color: Colors.grey[700], size: 24),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          isCalendarExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.grey[700],
                        ),
                        onPressed: () {
                          setState(() {
                            isCalendarExpanded = !isCalendarExpanded;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [
                          const Text("총 측정 횟수", style: TextStyle(fontSize: 14)),
                          Text("${monthResults.length} 번",
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold))
                        ]),
                        Column(children: [
                          const Text("이상 소견 의심",
                              style: TextStyle(fontSize: 14)),
                          Text("$abnormalMonthTotal 번", style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold))
                        ])
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: isCalendarExpanded
                      ? TableCalendar(
                    focusedDay: focusedDay,
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                    onDaySelected: (selected, focused) =>
                        setState(() {
                          selectedDay = selected;
                          focusedDay = focused;
                        }),
                    onPageChanged: (newFocusedDay) =>
                        setState(() => focusedDay = newFocusedDay),
                    calendarFormat: CalendarFormat.month,
                    startingDayOfWeek: StartingDayOfWeek.sunday,
                    headerVisible: false,
                    calendarStyle: const CalendarStyle(
                      outsideDaysVisible: false,
                      todayDecoration: BoxDecoration(),
                      todayTextStyle: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black),
                      selectedDecoration: BoxDecoration(
                          color: Color(0xFFFFEEEA), shape: BoxShape.circle),
                    ),
                    enabledDayPredicate: (day) {
                      final normalized = DateTime.utc(
                          day.year, day.month, day.day);
                      final today = DateTime.now();
                      final isToday = isSameDay(today, day);
                      return ecgService.statusMap.containsKey(normalized) ||
                          isToday;
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, _) {
                        final normalized = DateTime.utc(day.year, day.month, day
                            .day);
                        final statuses = ecgService.statusMap[normalized];
                        if (statuses == null) return null;
                        final abnormalCount = statuses
                            .where((e) => e == '이상 소견 의심')
                            .length;
                        final totalCount = statuses.length;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${day.day}',
                                style: const TextStyle(color: Colors.black)),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(text: '$abnormalCount',
                                      style: const TextStyle(fontSize: 10,
                                          color: Color(0xFFFB755B))),
                                  const TextSpan(text: ' / ',
                                      style: TextStyle(
                                          fontSize: 10, color: Colors.black54)),
                                  TextSpan(text: '$totalCount',
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
                if (!isCalendarExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Center(
                      child: Text(
                        "${DateFormat('yyyy.MM').format(
                            focusedDay)} 캘린더가 접혀있습니다.",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ),
                  ),
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
                      Text("총 측정 횟수", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 10), // Adding a small space here
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: selectedResults.length,
                    separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: Colors.grey),
                    itemBuilder: (context, index) {
                      final entry = selectedResults[index];
                      final formatted = DateFormat('MM월 d일 HH:mm').format(
                          entry.dateTime);
                      final isAbnormal = entry.result == '이상 소견 의심';
                      final resultText = isAbnormal ? '이상 소견 의심' : '정상';
                      return InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/ecgDetail',
                            arguments: entry,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatted,
                                style: const TextStyle(fontSize: 16),
                              ),
                              Row(
                                children: [
                                  Text(
                                    resultText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isAbnormal ? const Color(
                                          0xFFFB755B) : Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                      Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFB755B),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handleMeasureButton,
                      child: Text(
                        Platform.isIOS ? "ECG 조회" : "측정 시작",
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.asset('assets/lottie/Animation.json', width: 100,
                        height: 100),
                    const SizedBox(height: 16),
                    const Text(
                      'Fetching ECG data\nPlease wait without closing the app',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}