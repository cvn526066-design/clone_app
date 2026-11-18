import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تطبيق التداول الآلي',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF030305),
        primaryColor: const Color(0xFF00E5FF),
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFFD700),
          surface: Color(0xFF0E0E14),
          error: Color(0xFFFF1744),
          onPrimary: Colors.black,
          onSecondary: Colors.black,
        ),
      ),
      home: const MainTradingScreen(),
    );
  }
}

class MainTradingScreen extends StatefulWidget {
  const MainTradingScreen({Key? key}) : super(key: key);

  @override
  State<MainTradingScreen> createState() => _MainTradingScreenState();
}

class _MainTradingScreenState extends State<MainTradingScreen> {
  bool isDemoAccount = true;
  bool isRiskManagerActive = false;
  bool isBotRunning = false;

  void toggleBot() {
    setState(() {
      isBotRunning = !isBotRunning;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isBotRunning ? "تم تشغيل البوت!" : "تم إيقاف البوت!"),
        backgroundColor: isBotRunning ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF0E0E14), Color(0xFF030305)],
                center: Alignment.center,
                radius: 1.5,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.menu, color: Colors.white),
                      Text('التحكم الآلي', style: TextStyle(color: const Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.bold)),
                      const Icon(Icons.settings, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isDemoAccount = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: isDemoAccount
                                    ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)])
                                    : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text('تجريبي', style: TextStyle(color: isDemoAccount ? Colors.black : Colors.white)),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isDemoAccount = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: !isDemoAccount
                                    ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)])
                                    : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text('حقيقي', style: TextStyle(color: !isDemoAccount ? Colors.black : Colors.white)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: toggleBot,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBotRunning ? Colors.red : const Color(0xFF00E5FF),
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(isBotRunning ? 'إيقاف البوت' : 'بدء التداول', style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
