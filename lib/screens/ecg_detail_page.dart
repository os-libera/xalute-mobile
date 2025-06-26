import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

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
  int selectedLead = 0; // 0 to 11
  List<List<FlSpot>> leadData = List.generate(12, (_) => []);
  List<int> rPeaks = [];
  List<double> distances = [];
  final List<String> leadLabels = [
    'I', 'II', 'III', 'aVR', 'aVL', 'aVF', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6'
  ];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final jsonFile = File(widget.jsonPath);
      final jsonStr = await jsonFile.readAsString();
      final jsonData = jsonDecode(jsonStr);
      final resultArray = jsonData['result'];
      final leads = resultArray[0][0].sublist(2, 14);

      for (int i = 0; i < 12; i++) {
        final List<FlSpot> spots = [];
        final lead = leads[i];
        for (int j = 0; j < lead.length; j++) {
          spots.add(FlSpot(j.toDouble(), lead[j].toDouble()));
        }
        leadData[i] = spots;
      }

      distances = List<double>.from(jsonData['result']['distance_from_median'] ?? []);
      rPeaks = List<int>.from(jsonData['result']['r_peaks'] ?? []);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    setState(() => isLoading = false);
  }

  Widget _buildLeadButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(12, (index) {
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: selectedLead == index
                ? const Color(0xFFFB755B)
                : Colors.white,
            foregroundColor: selectedLead == index
                ? Colors.white
                : Colors.black,
            side: BorderSide(color: Colors.grey.shade400),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: () => setState(() => selectedLead = index),
          child: Text('Signal ${index + 1}'),
        );
      }),
    );
  }

  Widget _buildChart() {
    final spots = leadData[selectedLead];
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(enabled: true),
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 1,
            color: const Color(0xFFFB755B),
            dotData: FlDotData(show: false),
          ),
        ],
        extraLinesData: ExtraLinesData(
          verticalLines: rPeaks.map((index) => VerticalLine(
            x: index.toDouble(),
            color: Colors.black,
            strokeWidth: 1,
          )).toList(),
          horizontalLines: distances.isNotEmpty
              ? [
            HorizontalLine(
              y: distances[0],
              color: const Color(0x44FB755B),
              strokeWidth: 10,
            ),
            HorizontalLine(
              y: distances[1],
              color: const Color(0x44FB755B),
              strokeWidth: 10,
            ),
          ]
              : [],
        ),
        minY: -1,
        maxY: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFB755B),
        title: const Text('측정 결과'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.7,
              child: InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                child: _buildChart(),
              ),
            ),
            const SizedBox(height: 20),
            _buildLeadButtons(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('날짜', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(DateFormat('yyyy.MM.dd (E) HH시 mm분', 'ko_KR').format(widget.timestamp)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('결과', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.result),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('측정 기기', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Android / iOS'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
