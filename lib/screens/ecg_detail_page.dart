import 'package:flutter/material.dart';
import 'ecg_data_service.dart';

class EcgDetailPage extends StatelessWidget {
  const EcgDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final EcgEntry entry = ModalRoute.of(context)!.settings.arguments as EcgEntry;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ECG 상세 보기'),
        backgroundColor: const Color(0xFFFB755B),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "📅 측정 시각: d}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              "🔍 분류 결과: ${entry.result}",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: entry.result == '이상 소견 의심' ? const Color(0xFFFB755B) : Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            const Text("📈 ECG 데이터", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  entry.content,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
