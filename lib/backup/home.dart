import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final String username;
  final int healthScore;
  final int healthDiff;
  final int monthlyCount;
  final int streakDays;
  final int todayCount;
  final int arrhythmiaCount;

  const HomePage({
    super.key,
    this.username = "user",
    this.healthScore = 72,
    this.healthDiff = 3,
    this.monthlyCount = 6,
    this.streakDays = 5,
    this.todayCount = 2,
    this.arrhythmiaCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle header = const TextStyle(fontSize: 20, fontWeight: FontWeight.w500);
    TextStyle number = const TextStyle(fontSize: 36, fontWeight: FontWeight.bold);
    TextStyle comment = const TextStyle(fontSize: 16);
    TextStyle highlight = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome. $username!", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text("This is Xalute!", style: TextStyle(fontSize: 18)),
              const SizedBox(height: 32),
              Text("Today's health score is", style: header),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("$healthScore", style: number),
                  const Text("points.", style: TextStyle(fontSize: 20)),
                ],
              ),
              Text("${healthDiff >= 0 ? "+" : "-"}$healthDiff compared to yesterday.", style: comment),
              const SizedBox(height: 32),
              Text("Total measurements this month", style: header),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("$monthlyCount", style: number),
                  const Text("times.", style: TextStyle(fontSize: 20)),
                ],
              ),
              Text("Measured for ${streakDays} days in a row.", style: comment),
              Text("${todayCount} measurements today.", style: comment),
              const SizedBox(height: 32),
              Text("Suspected arrhythmias this month", style: header),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("$arrhythmiaCount", style: highlight),
                  const Text("times.", style: TextStyle(fontSize: 20)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
