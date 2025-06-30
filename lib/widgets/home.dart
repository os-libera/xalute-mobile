/** Not USE **/
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MainCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String unit;
  final bool chart;
  final bool bars;
  final VoidCallback? onTap;

  const MainCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.unit,
    this.chart = false,
    this.bars = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.1),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 6),
                  Text('$value $unit',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (chart)
                    SizedBox(
                      height: 40,
                      child: LineChart(
                        LineChartData(
                          lineTouchData: LineTouchData(enabled: false),
                          lineBarsData: [
                            LineChartBarData(
                              isCurved: true,
                              spots: const [
                                FlSpot(0, 2),
                                FlSpot(1, 3),
                                FlSpot(2, 1.5),
                                FlSpot(3, 2.8),
                                FlSpot(4, 2.2),
                                FlSpot(5, 3),
                                FlSpot(6, 2.5),
                              ],
                              color: iconColor,
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                            ),
                          ],
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    )
                  else if (bars)
                    Row(
                      children: List.generate(7, (index) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: (index + 1) * 5.0,
                            decoration: BoxDecoration(
                              color: iconColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}