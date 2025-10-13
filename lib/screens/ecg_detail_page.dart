import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:math';

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
      // JSON에서 r_peaks, distances 불러오기
      if (widget.jsonPath.isNotEmpty && File(widget.jsonPath).existsSync()) {
        final jsonStr = await File(widget.jsonPath).readAsString();
        final jsonData = jsonDecode(jsonStr);
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
    final spots = leadData[selectedLead];
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
        title: const Text('측정 결과', style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          //padding: const EdgeInsets.all(10),
          //padding: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.7,
                child: _buildChart(),
              ),
              const SizedBox(height: 20),
              _buildLeadButtons(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('날짜', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(DateFormat('yyyy년 MM월 dd일 (EEE) HH:mm', 'ko_KR').format(widget.timestamp)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('결과', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(widget.result == '이상 소견 의심' ? '이상 소견 의심' : '정상'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('기기 종류', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(widget.deviceType),
                ],
              ),
              _buildQtStResult(),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildQtStResult() {
    if (qtIntervals.isEmpty && stSegments.isEmpty) {
      return const Text('QT/ST 데이터가 없습니다.',
          style: TextStyle(color: Colors.grey, fontSize: 13));
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
      double stMv = st;
      if (stMv > 0.1) stElevCount++;
      else if (stMv < -0.1) stDepressCount++;
    }

    String stStatus;
    if (stElevCount > 0) {
      stStatus = 'ST 상승 의심';
    } else if (stDepressCount > 0) {
      stStatus = 'ST 하강 의심';
    } else {
      stStatus = '정상';
    }

    Color qtColor =
    (qtStatus == '정상') ? Colors.green : const Color(0xFFFB755B);
    Color stColor =
    (stStatus == '정상') ? Colors.green : const Color(0xFFFB755B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QT/ST 분석 결과',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('QT 판정: $qtStatus',
                  style: TextStyle(fontSize: 13, color: qtColor)),
              Text('ST 판정: $stStatus',
                  style: TextStyle(fontSize: 13, color: stColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'QT 단축: $qtShortCount개, QT 연장: $qtLongCount개',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            'ST 상승: $stElevCount개, ST 하강: $stDepressCount개',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
