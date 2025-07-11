/** Not USE **/
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String username = "user";
  // dumy data
  int healthScore = 72;
  int healthDiff = 3;
  int monthlyCount = 6;
  int streakDays = 5;
  int todayCount = 2;
  int arrhythmiaCount = 3;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? "user";
    });
  }

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
              Text("Measured for ${streakDays}days in a row.", style: comment),
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
