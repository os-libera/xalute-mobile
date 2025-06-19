import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ecg_data_service.dart';
import 'package:provider/provider.dart';


class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _nameFocus.addListener(() {
      if (_nameFocus.hasFocus && _nameController.text.isEmpty) {
        _nameController.clear();
      }
    });

    _passwordFocus.addListener(() {
      if (_passwordFocus.hasFocus && _passwordController.text.isEmpty) {
        _passwordController.clear();
      }
    });
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final name = _nameController.text;
    final birthday = _birthdayController.text;
    final password = _passwordController.text;

    await prefs.setString('username', name);
    await prefs.setString('birthday', birthday);
    await prefs.setString('password', password);

    // ✅ EcgDataService에도 반영
    final ecgService = Provider.of<EcgDataService>(context, listen: false);
    ecgService.setUserName(name);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("저장되었습니다.")),
    );
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('username') ?? '';

    setState(() {
      _nameController.text = name;
      _birthdayController.text = prefs.getString('birthday') ?? '';
      _passwordController.text = prefs.getString('password') ?? '';
    });

    // ✅ 초기 로드시도 EcgDataService에 이름 반영
    final ecgService = Provider.of<EcgDataService>(context, listen: false);
    ecgService.setUserName(name);
  }


  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2001, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale("ko", "KR"),
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("설정"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(" ", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: const AssetImage('assets/icon/xalute.png'),
              ),
            ),
            const SizedBox(height: 32),
            const Text("이름", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              decoration: const InputDecoration(
                hintText: "username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text("생년월일", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectBirthday,
              child: AbsorbPointer(
                child: TextField(
                  controller: _birthdayController,
                  decoration: const InputDecoration(
                    hintText: "01/01/2001",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("비밀번호", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "0000",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  print("🟡 저장 버튼 눌림!");
                  _saveUserData();
                },
                child: const Text("저장"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
