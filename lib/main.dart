import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

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
        ),
      ),
      home: const RootNavigation(),
    );
  }
}

// ==========================================
// 1. الشريط السفلي (RootNavigation)
// ==========================================
class RootNavigation extends StatefulWidget {
  const RootNavigation({Key? key}) : super(key: key);
  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _currentIndex = 0;
  
  // صفحة تسجيل الدخول وصفحة التداول
  final List<Widget> _pages = [
    const LoginScreen(),
    const MainTradingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0E0E14),
        selectedItemColor: const Color(0xFFFFD700),
        unselectedItemColor: const Color(0xFFA0A0B0),
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.login), label: 'تسجيل الدخول'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_graph), label: 'التداول الآلي'),
        ],
      ),
    );
  }
}

// ==========================================
// 2. شاشة تسجيل الدخول (WebView)
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Quotex/1.0")
      ..loadRequest(Uri.parse('https://quotex.com/ar/sign-in'));
  }

  void _requestPermissions() async {
    await Permission.location.request();
    await Permission.notification.request();
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: WebViewWidget(controller: _controller));
}

// ==========================================
// 3. شاشة التداول (MainTradingScreen)
// ==========================================
class MainTradingScreen extends StatefulWidget {
  const MainTradingScreen({super.key});
  @override
  State<MainTradingScreen> createState() => _MainTradingScreenState();
}

class _MainTradingScreenState extends State<MainTradingScreen> {
  String currentTime = "12:00:00";
  bool isConnected = false; // 470. متغير حالة الاتصال
  String currentPrice = "0.00";
  double demoBalance = 0.0;
  double realBalance = 0.0;
  bool isDemoAccount = true;
  late IO.Socket _socket;
  List<String> _pairs = [];

  @override
  void initState() {
    super.initState();
    _initSocket();
    _startClock();
  }

  // 471. الساعة
  void _startClock() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      setState(() {
        currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      });
    });
  }

  // 472. الاتصال بالـ WebSocket
  void _initSocket() {
    _socket = IO.io('https://ws2.quotex.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'path': '/socket.io/',
      'query': {'EIO': '4', 'transport': 'websocket'},
      'extraHeaders': {'Cookie': 'مرر_الكوكيز_هنا', 'User-Agent': 'Quotex/1.0'}
    });

    _socket.onConnect((_) {
      setState(() => isConnected = true); // الاتصال نجح
      _socket.emit('42["instruments/list"]');
      _socket.emit('42["balance/list"]');
    });

    _socket.onDisconnect((_) {
      setState(() => isConnected = false); // الاتصال فشل
    });

    _socket.on('instruments/update', (data) {
      if (data['instruments'] != null) {
        setState(() => _pairs = List<String>.from(data['instruments'].map((i) => i['name'] ?? 'Unknown')));
      }
    });

    _socket.on('balance/list', (data) {
      if (data['balance'] != null) {
        setState(() {
          if (isDemoAccount) {
            demoBalance = double.parse(data['balance'].toString());
          } else {
            realBalance = double.parse(data['balance'].toString());
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030305),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 473. الشريط العلوي مع زر الاتصال
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu, color: Color(0xFFA0A0B0)),
                      const SizedBox(width: 10),
                      Text("التحكم الآلي", style: GoogleFonts.cairo(color: const Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(4)),
                        child: Text("PRO", style: GoogleFonts.cairo(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(currentTime, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      // 474. زر الاتصال (أخضر/أحمر)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConnected ? Color(0xFF00E676) : Color(0xFFFF1744),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(isConnected ? Icons.check_circle : Icons.error, color: Colors.white, size: 16),
                            const SizedBox(width: 5),
                            Text(isConnected ? "متصل" : "غير متصل", style: GoogleFonts.cairo(fontSize: 12, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 475. بطاقة السعر
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF0E0E14), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x14FFFFFF))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("السعر الحالي (EUR/USD)", style: GoogleFonts.cairo(color: const Color(0xFFA0A0B0))),
                    Text(currentPrice, style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 476. الرصيد
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF0E0E14), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x14FFFFFF))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الرصيد:', style: GoogleFonts.cairo(color: const Color(0xFFA0A0B0))),
                    Text(isDemoAccount ? '\$$demoBalance' : '\$$realBalance', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 477. الأزواج
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF0E0E14), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x14FFFFFF))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("الأزواج المتاحة", style: GoogleFonts.cairo(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _pairs.map((pair) => Chip(label: Text(pair, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E1E24))).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 478. أزرار الحساب
              Container(
                decoration: BoxDecoration(color: const Color(0xFF0E0E14), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x14FFFFFF))),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isDemoAccount = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: isDemoAccount ? const Color(0xFFFFD700) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text("حساب Demo", style: GoogleFonts.cairo(color: isDemoAccount ? Colors.black : const Color(0xFFA0A0B0), fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isDemoAccount = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: !isDemoAccount ? const Color(0xFFFFD700) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text("حساب Real", style: GoogleFonts.cairo(color: !isDemoAccount ? Colors.black : const Color(0xFFA0A0B0), fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 479. أزرار التداول
              ElevatedButton(
                onPressed: () {
                  _socket.emit('42["orders/open", {"asset":"EURUSD","amount":10,"direction":"up","duration":60}]');
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text("بدء التداول السريع", style: GoogleFonts.cairo(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              // 480. زر الشارت
              OutlinedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChartScreen(isDemo: isDemoAccount)));
                },
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 55), side: const BorderSide(color: Color(0xFF00E5FF), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text("فتح الشارت المباشر", style: GoogleFonts.cairo(color: const Color(0xFF00E5FF), fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. شاشة الشارت (تفتح الحساب الصح)
// ==========================================
class ChartScreen extends StatefulWidget {
  final bool isDemo;
  const ChartScreen({Key? key, required this.isDemo}) : super(key: key);
  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  late WebViewController _controller;
  @override
  void initState() {
    super.initState();
    // 481. نفتح الشارت حسب الحساب
    String url = widget.isDemo ? 'https://quotex.com/ar/demo-trade' : 'https://quotex.com/ar/trade';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Quotex/1.0")
      ..loadRequest(Uri.parse(url));
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('الشارت المباشر')), body: SafeArea(child: WebViewWidget(controller: _controller)));
}
