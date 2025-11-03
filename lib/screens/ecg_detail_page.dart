import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:path/path.dart' as p;

class EcgDetailPage extends StatefulWidget {
  final String txtPath;
  final String jsonPath;
  final DateTime timestamp;
  final String result;
  final String deviceType;

  const EcgDetailPage({
    super.key,
    required this.txtPath,
    required this.jsonPath,
    required this.timestamp,
    required this.result,
    required this.deviceType,
  });

  @override
  State<EcgDetailPage> createState() => _EcgDetailPageState();
}

class _EcgDetailPageState extends State<EcgDetailPage> {
  int selectedLead = 0;
  List<List<FlSpot>> leadData = List.generate(12, (_) => []);
  List<int> rPeaks = [];
  List<double> distances = [];
  bool isLoading = true;
  double zoomScale = 1.0;
  final ScrollController _scrollController = ScrollController();
  final TransformationController _transformationController = TransformationController();

  List<double> qtIntervals = [];
  List<double> stSegments = [];

  String? hospitalName;
  String? measureDate;
  String? surgeryDate;
  String? diseaseName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final txtFile = File(widget.txtPath);
      if (!txtFile.existsSync()) {
        debugPrint('❌ TXT 파일이 존재하지 않음');
      } else {
        final txtContent = await txtFile.readAsString();
        final rawRecords = txtContent.trim().split(') (');

        List<FlSpot> txtSpots = [];
        for (final record in rawRecords) {
          final clean = record.replaceAll('(', '').replaceAll(')', '');
          final parts = clean.split(',');
          if (parts.length == 2) {
            final y = double.tryParse(parts[0].trim());
            final x = double.tryParse(parts[1].trim());
            if (x != null && y != null) {
              txtSpots.add(FlSpot(x, y));
            }
          }
        }

        txtSpots.sort((a, b) => a.x.compareTo(b.x));

        final baseX = txtSpots.first.x;
        final convertedSpots = txtSpots.map((spot) {
          return FlSpot(spot.x - baseX, spot.y);
        }).toList();

        leadData[0] = convertedSpots;

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('http://34.69.44.173:7001/predict12lead/512'),// 512-> sampling rate
        );
        request.files.add(await http.MultipartFile.fromPath('file', txtFile.path));
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final sanitizedBody = response.body.replaceAll('NaN', 'null');
          debugPrint("Response: ${sanitizedBody}");
          final jsonData = jsonDecode(sanitizedBody);

          final resultArray = jsonData['result'];
          final leads = resultArray[0][0].sublist(3, 14);
          for (int i = 0; i < 11; i++) {
            leadData[i + 1] = List.generate(
              leads[i].length,
                  (j) => FlSpot(j * (10.0 / 512.0), leads[i][j].toDouble()),
            );
          }

          final qtStData = jsonData['qt_st'];
          if (qtStData != null) {
            qtIntervals = (qtStData['qt_intervals'] as List<dynamic>)
                .where((value) => value != null)
                .map((e) => (e as num).toDouble())
                .toList();

            stSegments = (qtStData['st_segments'] as List<dynamic>)
                .where((value) => value != null)
                .map((e) => (e as num).toDouble())
                .toList();

            debugPrint('QT Intervals: $qtIntervals');
            debugPrint('ST Segments: $stSegments');
          }
        } else {
          debugPrint('❌ 서버 오류: ${response.reasonPhrase}');
        }
      }

      if (widget.jsonPath.isNotEmpty && File(widget.jsonPath).existsSync()) {
        final jsonStr = await File(widget.jsonPath).readAsString();
        final jsonData = jsonDecode(jsonStr);

        if (widget.jsonPath.contains('hospital')) {
          final hospitalMeta = _getHospitalMeta(widget.jsonPath);
          hospitalName = hospitalMeta['name'];
          measureDate = hospitalMeta['measureDate'];
          surgeryDate = hospitalMeta['surgeryDate'];
          diseaseName = hospitalMeta['disease'];
        }

        if (jsonData['result'] is Map<String, dynamic>) {
          final rawDistances = jsonData['result']['distance_from_median'] ?? [];
          distances = rawDistances.map<double>((e) => (e as num).toDouble()).toList();
          rPeaks = List<int>.from(jsonData['result']['r_peaks'] ?? []);
        }
      }
    } catch (e) {
      debugPrint('❌ 오류: $e');
    }

    setState(() => isLoading = false);
  }

  Widget _buildLeadButtons() {
    final leadLabels = ['I', 'II', 'III', 'aVR', 'aVL', 'aVF', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6'];

    return Column(
      children: List.generate(3, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (colIndex) {
              final index = rowIndex * 4 + colIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SizedBox(
                  width: 80,
                  height: 35,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedLead == index ? const Color(0xFFFB755B) : Colors.white,
                      foregroundColor: selectedLead == index ? Colors.white : Colors.black,
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      setState(() {
                        selectedLead = index;
                        zoomScale = 1.0;
                      });
                    },
                    child: Text(
                      leadLabels[index],
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  double baseScale = 1.0;

  Widget _buildChart() {
    List<FlSpot> spots = leadData[selectedLead];

    if (selectedLead == 0 && spots.isNotEmpty) {
      spots = spots.where((spot) => spot.x >= 5.0).toList();
      if (spots.isNotEmpty) {
        final baseX = spots.first.x;
        spots = spots.map((e) => FlSpot(e.x - baseX, e.y)).toList();
      }
    }

    final isFirstSignal = selectedLead == 0;


    if (spots.isEmpty) {
      return const Center(child: Text('해당 리드에 대한 데이터가 없습니다.', style: TextStyle(fontSize: 14)));
    }

    const double rrThreshold = 0.31;
    List<int> filteredRPeaks = [];
    List<double> filteredDistances = [];

    debugPrint('--- 비정상 R-R 간격 데이터 필터링 ---');
    for (int i = 0; i < distances.length; i++) {
      if ((i * 2 + 1) < rPeaks.length) {
        if (distances[i] > rrThreshold) {
          filteredDistances.add(distances[i]);
          filteredRPeaks.add(rPeaks[i * 2]);
          filteredRPeaks.add(rPeaks[i * 2 + 1]);

          debugPrint('임계값 초과: distance=${distances[i]}, R-peaks 인덱스: [${rPeaks[i * 2]}, ${rPeaks[i * 2 + 1]}]');
        }
      }
    }
    debugPrint('--- 필터링 완료: ${filteredDistances.length}개 ---');

    final adjustedSpots = spots;
    final xMax = adjustedSpots.last.x;
    final yMin = adjustedSpots.map((e) => e.y.toDouble()).reduce((a, b) => a < b ? a : b);
    final yMax = adjustedSpots.map((e) => e.y.toDouble()).reduce((a, b) => a > b ? a : b);
    final chartWidth = xMax * 50 * zoomScale;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) {
        baseScale = zoomScale;
      },
      onScaleUpdate: (details) {
        setState(() {
          //final newScale = baseScale * details.scale;
          //final newScale = baseScale * (1 + (details.scale - 1) * 10);
          final newScale = baseScale * details.scale;
          zoomScale = newScale.clamp(1.0, 4.0);
        });
      },
      child: Container(
        height: 500,
        color: Colors.transparent,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: chartWidth,
            height: 300,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: xMax,
                minY: yMin,
                maxY: yMax,
                clipData: FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: true,
                  verticalInterval: 1,
                  horizontalInterval: ((yMax - yMin) / 5).clamp(0.1, double.infinity),
                  getDrawingVerticalLine: (_) => FlLine(
                    color: Colors.grey.shade300,
                    strokeWidth: 0.5,
                  ),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.shade300,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final rounded = value.round();
                        return (value - rounded).abs() < 0.05
                            ? Text('${rounded}s', style: const TextStyle(fontSize: 10))
                            : const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(enabled: false),
                rangeAnnotations: isFirstSignal
                    ? RangeAnnotations(
                  verticalRangeAnnotations: () {
                    List<VerticalRangeAnnotation> annotations = [];
                    for (int i = 0; i < filteredRPeaks.length ~/ 2; i++) {
                      final rPeak1Index = filteredRPeaks[i * 2];
                      final rPeak2Index = filteredRPeaks[i * 2 + 1];

                      if (rPeak2Index < spots.length) {
                        final x1 = spots[rPeak1Index].x;
                        final x2 = spots[rPeak2Index].x;
                        annotations.add(
                          VerticalRangeAnnotation(
                            x1: x1,
                            x2: x2,
                            color: const Color(0x33FB755B),
                          ),
                        );
                      }
                    }
                    return annotations;
                  }(),
                )
                    : const RangeAnnotations(),
                lineBarsData: [
                  if (isFirstSignal)
                    LineChartBarData(
                      spots: rPeaks
                          .where((x) => x < spots.length)
                          .map((x) => FlSpot(spots[x].x, spots[x].y))
                          .toList(),
                      isCurved: false,
                      color: Colors.transparent, // 라인은 투명하게
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 2,
                          strokeWidth: 1,
                          color: const Color(0xFFF9FAFE),
                          strokeColor: const Color(0xFFFB755B),
                        ),
                      ),
                    ),

                  LineChartBarData(
                    spots: adjustedSpots,
                    isCurved: false,
                    barWidth: 1,
                    color: const Color(0xFFFB755B),
                    dotData: FlDotData(show: false),
                  ),

                  if (isFirstSignal)
                    LineChartBarData(
                      spots: filteredRPeaks
                          .where((x) => x < spots.length)
                          .map((x) => FlSpot(spots[x].x, spots[x].y))
                          .toList(),
                      isCurved: false,
                      color: Colors.transparent,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 2,
                          strokeWidth: 1,
                          color: const Color(0xFFF9FAFE),
                          strokeColor: const Color(0xFFFB755B),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          '측정 결과',
          style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(aspectRatio: 1.7, child: _buildChart()),
              const SizedBox(height: 20),
              _buildLeadButtons(),
              const SizedBox(height: 24),

              // ===== 정보 라인들 =====
              _buildInfoRow(
                '날짜',
                DateFormat('yyyy년 MM월 dd일 (EEE) HH:mm', 'ko_KR')
                    .format(widget.timestamp),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                '결과',
                widget.result == '이상 소견 의심' ? '이상 소견 의심' : '정상',
                color: widget.result == '이상 소견 의심'
                    ? const Color(0xFFFB755B)
                    : Colors.green,
              ),
              const SizedBox(height: 8),

              // QT/ST 결과 표시
              _buildQtStRows(),

              const SizedBox(height: 8),
              _buildInfoRow('기기 종류', widget.deviceType),

              if (widget.jsonPath.contains('hospital')) ...[
                const SizedBox(height: 8),
                _buildInfoRow('이름', hospitalName ?? '정보 없음'),
                const SizedBox(height: 8),
                _buildInfoRow('측정 날짜', measureDate ?? '정보 없음'),
                const SizedBox(height: 8),
                _buildInfoRow('수술 날짜', surgeryDate ?? '정보 없음'),
                const SizedBox(height: 8),
                _buildInfoRow('병명', diseaseName ?? '정보 없음'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: color ?? Colors.black)),
      ],
    );
  }

  Map<String, dynamic> _getHospitalMeta(String jsonPath) {
    final metaMap = {
      "ecg_2025-11-05T17-17-01_normal_raw": {
        "name": "wg17",
        "measurement": "2023-11-13 15:58:29",
        "surgeryDate": "2023-11-14",
        "disease": "Paroxysmal atrial fibrillation"
      },
      "ecg_2025-11-05T17-17-02_normal_raw": {
        "name": "wg17",
        "measurement": "2023-11-15 10:27:48",
        "surgeryDate": "2023-11-14",
        "disease": "Paroxysmal atrial fibrillation"
      },
      "ecg_2025-11-05T21-21-01_abnormal_raw": {
        "name": "wg21",
        "measurement": "2023-11-21 14:26:06",
        "surgeryDate": "2023-11-22",
        "disease": "Long-standing persistent atrial fibrillation"
      },
      "ecg_2025-11-05T21-21-02_normal_raw": {
        "name": "wg21",
        "measurement": "2023-11-23 11:39:03",
        "surgeryDate": "2023-11-22",
        "disease": "Long-standing persistent atrial fibrillation"
      },
      "ecg_2025-11-05T22-22-01_abnormal_raw": {
        "name": "wg22",
        "measurement": "2023-11-21 14:33:18",
        "surgeryDate": "2023-11-22",
        "disease": "Long-standing persistent atrial fibrillation"
      },
      "ecg_2025-11-05T23-23-01_abnormal_raw": {
        "name": "wg23",
        "measurement": "2023-11-21 14:41:15",
        "surgeryDate": "2023-11-22",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T23-23-02_normal_raw": {
        "name": "wg23",
        "measurement": "2023-11-23 12:43:14",
        "surgeryDate": "2023-11-22",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T26-26-01_abnormal_raw": {
        "name": "wg26",
        "measurement": "2023-11-28 15:20:14",
        "surgeryDate": "2023-11-29",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T26-26-02_abnormal_raw": {
        "name": "wg26",
        "measurement": "2023-11-30 11:28:43",
        "surgeryDate": "2023-11-29",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T27-27-01_abnormal_raw": {
        "name": "wg27",
        "measurement": "2023-11-28 15:30:27",
        "surgeryDate": "2023-11-29",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T27-27-02_abnormal_raw": {
        "name": "wg27",
        "measurement": "2023-11-30 11:25:16",
        "surgeryDate": "2023-11-29",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T28-28-01_normal_raw": {
        "name": "wg28",
        "measurement": "2023-11-29 13:38:22",
        "surgeryDate": "2023-11-30",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T28-28-02_abnormal_raw": {
        "name": "wg28",
        "measurement": "2023-12-01 11:08:25",
        "surgeryDate": "2023-11-30",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T29-29-01_normal_raw": {
        "name": "wg29",
        "measurement": "2023-12-05 15:37:03",
        "surgeryDate": "2023-12-06",
        "disease": "Paroxysmal atrial fibrillation"
      },
      "ecg_2025-11-05T30-30-01_abnormal_raw": {
        "name": "wg30",
        "measurement": "2023-12-05 15:41:25",
        "surgeryDate": "2023-12-06",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T31-31-01_normal_raw": {
        "name": "wg31",
        "measurement": "2023-12-05 15:44:00",
        "surgeryDate": "2023-12-06",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T35-35-02_normal_raw": {
        "name": "wg35",
        "measurement": "2023-12-21 10:54:37",
        "surgeryDate": "2023-12-20",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T36-36-02_abnormal_raw": {
        "name": "wg36",
        "measurement": "2023-12-21 10:20:39",
        "surgeryDate": "2023-12-20",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T44-44-01_normal_raw": {
        "name": "wg44",
        "measurement": "2024-01-09 15:30:41",
        "surgeryDate": "2024-01-10",
        "disease": "Paroxysmal atrial fibrillation"
      },
      "ecg_2025-11-05T44-44-02_normal_raw": {
        "name": "wg44",
        "measurement": "2024-01-11 16:40:06",
        "surgeryDate": "2024-01-10",
        "disease": "Paroxysmal atrial fibrillation"
      },
      "ecg_2025-11-05T45-45-01_abnormal_raw": {
        "name": "wg45",
        "measurement": "2024-01-09 15:32:13",
        "surgeryDate": "2024-01-10",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T46-46-01_abnormal_raw": {
        "name": "wg46",
        "measurement": "2024-01-09 16:22:05",
        "surgeryDate": "2024-01-10",
        "disease": "Paroxysmal atrial fibrillation"
      },
      "ecg_2025-11-05T46-46-02_normal_raw": {
        "name": "wg46",
        "measurement": "2024-01-11 16:42:37",
        "surgeryDate": "2024-01-10",
        "disease": "Paroxysmal atrial fibrillation"
      },
      "ecg_2025-11-05T53-53-02_normal_raw": {
        "name": "wg53",
        "measurement": "2024-01-25 12:43:11",
        "surgeryDate": "2024-01-24",
        "disease": "Atrial fibrillation"
      },
      "ecg_2025-11-05T54-54-02_normal_raw": {
        "name": "wg54",
        "measurement": "2024-01-25 12:45:12",
        "surgeryDate": "2024-01-24",
        "disease": "Paroxysmal atrial fibrillation"
      },
      "ecg_2025-11-05T55-55-02_normal_raw": {
        "name": "wg55",
        "measurement": "2024-01-25 12:47:24",
        "surgeryDate": "2024-01-24",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T58-58-02_normal_raw": {
        "name": "wg58",
        "measurement": "2024-02-08 13:31:46",
        "surgeryDate": "2024-02-07",
        "disease": "Paroxysmal atrial fibrillation"
      },
      "ecg_2025-11-05T59-59-02_abnormal_raw": {
        "name": "wg59",
        "measurement": "2024-02-08 13:36:07",
        "surgeryDate": "2024-02-07",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T60-60-02_abnormal_raw": {
        "name": "wg60",
        "measurement": "2024-02-08 13:43:15",
        "surgeryDate": "2024-02-07",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T61-61-02_normal_raw": {
        "name": "wg61",
        "measurement": "2024-02-08 13:52:25",
        "surgeryDate": "2024-02-07",
        "disease": "Paroxysmal atrial fibrillation"
      },
      "ecg_2025-11-05T62-62-01_abnormal_raw": {
        "name": "wg62",
        "measurement": "2024-03-06 16:11:49",
        "surgeryDate": "2024-03-07",
        "disease": "Persistent atrial fibrillation"
      },
      "ecg_2025-11-05T63-63-01_normal_raw": {
        "name": "wg63",
        "measurement": "2024-03-19 16:07:29",
        "surgeryDate": "2024-03-20",
        "disease": "paroxymal atrial fibrillation"
      },
      "ecg_2025-11-05T63-63-02_abnormal_raw": {
        "name": "wg63",
        "measurement": "2024-03-21 11:56:14",
        "surgeryDate": "2024-03-20",
        "disease": "paroxymal atrial fibrillation"
      },
      "ecg_2025-11-05T70-70-02_normal_raw": {
        "name": "wg70",
        "measurement": "2024-03-29 11:29:14",
        "surgeryDate": "2024-03-28",
        "disease": "persistent atrial fibrillation"
      },
      "ecg_2025-11-05T73-73-01_abnormal_raw": {
        "name": "wg73",
        "measurement": "2024-04-16 14:56:20",
        "surgeryDate": "2024-04-17",
        "disease": "paroxymal atrial fibrillation"
      }
    };

    final baseName = p.basenameWithoutExtension(jsonPath);
    return metaMap[baseName] ?? {
      'name': '정보 없음',
      'surgeryDate': '-',
      'disease': '-',
    };
  }

  Widget _buildQtStRows() {
    if (qtIntervals.isEmpty && stSegments.isEmpty) {
      return const Text(
        'QT/ST 데이터가 없습니다.',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      );
    }

    int qtShortCount = 0;
    int qtLongCount = 0;
    for (double qt in qtIntervals) {
      if (qt < 350) qtShortCount++;
      else if (qt > 470) qtLongCount++;
    }

    String qtStatus;
    if (qtShortCount > 0) {
      qtStatus = 'QT 단축 의심';
    } else if (qtLongCount > 0) {
      qtStatus = 'QT 연장 의심';
    } else {
      qtStatus = '정상';
    }

    int stElevCount = 0;
    int stDepressCount = 0;
    for (double st in stSegments) {
      if (st > 0.1) stElevCount++;
      else if (st < -0.1) stDepressCount++;
    }

    String stStatus;
    if (stElevCount > 0) {
      stStatus = 'ST 상승 의심';
    } else if (stDepressCount > 0) {
      stStatus = 'ST 하강 의심';
    } else {
      stStatus = '정상';
    }

    Color qtColor = (qtStatus == '정상') ? Colors.green : const Color(0xFFFB755B);
    Color stColor = (stStatus == '정상') ? Colors.green : const Color(0xFFFB755B);

    String qtDetail = '';
    if (qtShortCount > 0) {
      qtDetail = ' (QT 단축: $qtShortCount개)';
    } else if (qtLongCount > 0) {
      qtDetail = ' (QT 연장: $qtLongCount개)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('QT 간격', '$qtStatus$qtDetail', color: qtColor),
        const SizedBox(height: 8),
        _buildInfoRow('ST 분절', stStatus, color: stColor),
      ],
    );
  }
}
