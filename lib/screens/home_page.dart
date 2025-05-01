import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/home.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  static const platform = MethodChannel('com.xalute.health/ecg');

  void _handleEcgTap(BuildContext context) async {
    debugPrint("Flutter: ECG 카드 클릭됨");
    try {
      final String result = await platform.invokeMethod('getEcgData');
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("ECG 데이터"),
          content: Text(result),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("확인"),
            )
          ],
        ),
      );
    } on PlatformException catch (e) {
      debugPrint("ECG 가져오기 실패: ${e.message}");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hello, Xalute', // 제목
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              MainCard(
                icon: Icons.favorite,
                iconColor: Colors.red,
                title: 'ECG',
                value: '',
                unit: '',
                chart: true,
                onTap: () => _handleEcgTap(context),
              ),
              const SizedBox(height: 20),
              const MainCard(
                icon: Icons.local_fire_department,
                iconColor: Colors.orange,
                title: 'Nutrition',
                value: '',
                unit: '',
              ),
              const SizedBox(height: 20),
              const MainCard(
                icon: Icons.bedtime,
                iconColor: Colors.indigo,
                title: 'Sleep',
                value: '',
                unit: '',
                bars: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
