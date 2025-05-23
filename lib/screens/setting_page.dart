import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    print("✅ 저장 시도: ${_nameController.text}, ${_birthdayController.text}, ${_passwordController.text}");

    await prefs.setString('username', _nameController.text);
    await prefs.setString('birthday', _birthdayController.text);
    await prefs.setString('password', _passwordController.text);

    print("✅ SharedPreferences 저장 완료");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("저장되었습니다.")),
    );
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

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('username') ?? '';
      _birthdayController.text = prefs.getString('birthday') ?? '';
      _passwordController.text = prefs.getString('password') ?? '';
    });

    print("📦 불러온 값: username=${_nameController.text}, birthday=${_birthdayController.text}, password=${_passwordController.text}");
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
            const Text("Your profile is..", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: const AssetImage('assets/icon/xalute.png'),
              ),
            ),
            const SizedBox(height: 32),
            const Text("Your name is..", style: TextStyle(fontSize: 16)),
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
            const Text("Your birthday is..", style: TextStyle(fontSize: 16)),
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
            const Text("Your password is..", style: TextStyle(fontSize: 16)),
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
