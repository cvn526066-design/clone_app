import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// 1. شاشة تسجيل الدخول
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late WebViewController _controller;
  bool _hasNavigated = false;

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
          onUrlChange: (UrlChange urlChange) async {
            if (!_hasNavigated && (urlChange.url?.contains('/trade') == true || urlChange.url?.contains('/cabinet') == true)) {
              _hasNavigated = true;
              final cookies = await _controller.runJavaScriptReturningResult("document.cookie");
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainTradingScreen(cookies: cookies.toString())));
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/sign-in'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: WebViewWidget(controller: _controller)));
}

// 2. الثيم والألوان
class AppColors {
  static const Color bgMain = Color(0xFF030305);
  static const Color bgCard = Color(0xFF0E0E14);
  static const Color primary = Color(0xFF00E5FF);
  static const Color gold = Color(0xFFFFD700);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color success = Color(0xFF00E676);
  static const Color danger = Color(0xFFFF1744);
  static const Color textMuted = Color(0xFFA0A0B0);
  static const Color border = Color(0x14FFFFFF);
}

// 3. الشاشة الرئيسية مع WebSocket
class MainTradingScreen extends StatefulWidget {
  final String cookies;
  const MainTradingScreen({Key? key, required this.cookies}) : super(key: key);
  @override
  State<MainTradingScreen> createState() => _MainTradingScreenState();
}

class _MainTradingScreenState extends State<MainTradingScreen> {
  String currentPrice = "0.00";
  double demoBalance = 0.0;
  double realBalance = 0.0;
  bool isDemoAccount = true;
  bool isRiskManagerActive = false;
  late IO.Socket _socket;
  
  List<String> _exchangePairs = [];
  List<String> _otcPairs = [];
  
  final List<String> _athkarList = [
    "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ",
    "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ",
    "اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ",
  ];
  int _currentAthkarIndex = 0;
  Timer? _athkarTimer;

  @override
  void initState() {
    super.initState();
    _initSocket();
    _athkarTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      setState(() => _currentAthkarIndex = (_currentAthkarIndex + 1) % _athkarList.length);
    });
  }

  void _initSocket() {
    _socket = IO.io('https://ws2.quotex.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'path': '/socket.io/',
      'query': {'EIO': '4', 'transport': 'websocket'},
      'extraHeaders': {'Cookie': widget.cookies, 'User-Agent': 'Quotex/1.0'}
    });

    _socket.onConnect((_) {
      _socket.emit('42["instruments/list"]');
      _socket.emit('42["balance/list"]');
      _socket.emit('42["quotes/stream"]');
    });

    _socket.on('instruments/update', (data) {
      if (data['instruments'] != null) {
        List<String> allPairs = List<String>.from(data['instruments'].map((i) => i['name'] ?? 'Unknown'));
        setState(() {
          _exchangePairs = allPairs.where((p) => !p.contains('_otc')).toList();
          _otcPairs = allPairs.where((p) => p.contains('_otc')).toList();
        });
      }
    });

    _socket.on('balance/list', (data) {
      if (data['balance'] != null) {
        setState(() => demoBalance = double.parse(data['balance'].toString()));
      }
    });

    _socket.on('quotes/stream', (data) {
      if (data['price'] != null) {
        setState(() => currentPrice = data['price'].toStringAsFixed(5));
      }
    });
  }

  @override
  void dispose() {
    _athkarTimer?.cancel();
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Stack(
        children: [
          const StarfieldBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TopHeaderWidget(),
                  const SizedBox(height: 20),
                  AthkarCardWidget(athkarText: _athkarList[_currentAthkarIndex]),
                  const SizedBox(height: 20),
                  AccountToggleWidget(
                    isDemo: isDemoAccount,
                    onToggle: (val) => setState(() => isDemoAccount = val),
                  ),
                  const SizedBox(height: 20),
                  PriceWidget(currentPrice: currentPrice),
                  const SizedBox(height: 20),
                  // 4. عرض الرصيد
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الرصيد:', style: GoogleFonts.cairo(color: AppColors.textMuted)),
                        Text(isDemoAccount ? '\$$demoBalance' : '\$$realBalance', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 5. عرض الأزواج (بورصة و OTC)
                  PairsDropZoneWidget(
                    exchangePairs: _exchangePairs,
                    otcPairs: _otcPairs,
                  ),
                  const SizedBox(height: 20),
                  SettingsWidget(
                    isRiskActive: isRiskManagerActive,
                    onRiskToggle: (val) => setState(() => isRiskManagerActive = val),
                  ),
                  const SizedBox(height: 20),
                  ActionButtonsWidget(
                    onStart: () {
                      _socket.emit('42["orders/open", {"asset":"EURUSD","amount":10,"direction":"up","duration":60}]');
                      _showCountdownDialog(context);
                    },
                    onStop: () {
                      _socket.emit('42["orders/close"]');
                    },
                    onOpenChart: () {
                      _socket.emit('42["quotes/stream"]');
                    },
                  ),
                  const SizedBox(height: 20),
                  const TradeHistoryWidget(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        onPressed: () {},
        child: const Icon(Icons.pan_tool, color: Colors.black),
      ),
    );
  }

  void _showCountdownDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CountdownDialog(),
    );
  }
}

// ==========================================
// 4. الـ Widgets (تصميم صاحبك)
// ==========================================

// الشريط العلوي (TopHeaderWidget) - نفس تصميم صاحبك
class TopHeaderWidget extends StatelessWidget {
  const TopHeaderWidget({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.menu, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Text("التحكم الآلي", style: GoogleFonts.cairo(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4)),
              child: Text("PRO", style: GoogleFonts.cairo(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Row(
          children: [
            const Text("12:00:00", style: TextStyle(fontFamily: 'monospace', color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text("Ping", style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// بطاقة الأذكار (AthkarCardWidget) - نفس تصميم صاحبك
class AthkarCardWidget extends StatelessWidget {
  final String athkarText;
  const AthkarCardWidget({Key? key, required this.athkarText}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_bottom, color: AppColors.danger, size: 30),
              const SizedBox(width: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: BoxDecoration(border: Border.all(color: AppColors.gold), borderRadius: BorderRadius.circular(8)),
                child: Text("لا إله إلا الله", style: GoogleFonts.cairo(color: AppColors.gold, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation), child: child));
            },
            child: Text(athkarText, key: ValueKey<String>(athkarText), textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// أزرار الحساب (AccountToggleWidget) - نفس تصميم صاحبك
class AccountToggleWidget extends StatelessWidget {
  final bool isDemo;
  final ValueChanged<bool> onToggle;
  const AccountToggleWidget({Key? key, required this.isDemo, required this.onToggle}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: isDemo ? AppColors.gold : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text("حساب Demo", style: GoogleFonts.cairo(color: isDemo ? Colors.black : AppColors.textMuted, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: !isDemo ? AppColors.gold : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text("حساب Real", style: GoogleFonts.cairo(color: !isDemo ? Colors.black : AppColors.textMuted, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// السعر ومؤشر السوق (PriceWidget) - نفس تصميم صاحبك
class PriceWidget extends StatelessWidget {
  final String currentPrice;
  const PriceWidget({Key? key, required this.currentPrice}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("السعر الحالي (EUR/USD)", style: GoogleFonts.cairo(color: AppColors.textMuted)),
              Text(currentPrice, style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 15),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("شراء 75%", style: GoogleFonts.cairo(color: AppColors.success, fontSize: 12)),
                  Text("بيع 25%", style: GoogleFonts.cairo(color: AppColors.danger, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: 0.75, minHeight: 8, backgroundColor: AppColors.danger, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// منطقة الأزواج (PairsDropZoneWidget) - نفس تصميم صاحبك مع تصنيف بورصة و OTC
class PairsDropZoneWidget extends StatelessWidget {
  final List<String> exchangePairs;
  final List<String> otcPairs;
  const PairsDropZoneWidget({Key? key, required this.exchangePairs, required this.otcPairs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("الأزواج المتاحة", style: GoogleFonts.cairo(color: AppColors.primary, fontWeight: FontWeight.bold)),
              const Icon(Icons.layers, color: AppColors.primary, size: 20),
            ],
          ),
          const SizedBox(height: 15),
          // بورصة
          if (exchangePairs.isNotEmpty)
            Wrap(
              spacing: 8, runSpacing: 8,
              children: exchangePairs.map((pair) => Chip(label: Text(pair, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E1E24))).toList(),
            ),
          const SizedBox(height: 10),
          // OTC
          if (otcPairs.isNotEmpty)
            Wrap(
              spacing: 8, runSpacing: 8,
              children: otcPairs.map((pair) => Chip(label: Text(pair, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E1E24))).toList(),
            ),
        ],
      ),
    );
  }
}

// إعدادات التداول (SettingsWidget) - نفس تصميم صاحبك
class SettingsWidget extends StatelessWidget {
  final bool isRiskActive;
  final ValueChanged<bool> onRiskToggle;
  const SettingsWidget({Key? key, required this.isRiskActive, required this.onRiskToggle}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text("إدارة المخاطر الذكية", style: GoogleFonts.cairo(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    Switch(value: isRiskActive, onChanged: onRiskToggle, activeColor: AppColors.success),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Row(
                    children: [
                      Expanded(child: _buildTextField("رأس المال (\$)", "1000")),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField("نسبة المخاطرة (%)", "1")),
                    ],
                  ),
                  crossFadeState: isRiskActive ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _buildSettingRow("مبلغ الصفقة الأساسي (\$)", "10", enabled: !isRiskActive),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("نسبة المضاعفة (%)", style: GoogleFonts.cairo(color: AppColors.textMuted)),
              Row(
                children: [
                  SizedBox(width: 60, child: _buildTextField("", "100")),
                  const SizedBox(width: 10),
                  Switch(value: true, onChanged: (v) {}),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String value, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) Text(label, style: GoogleFonts.cairo(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 5),
        TextField(
          enabled: enabled,
          controller: TextEditingController(text: value),
          style: GoogleFonts.cairo(color: enabled ? Colors.white : AppColors.textMuted),
          decoration: InputDecoration(
            filled: true, fillColor: Colors.black,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: enabled ? AppColors.border : Colors.transparent)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: enabled ? AppColors.border : Colors.transparent)),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(String label, String value, {bool enabled = true}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.cairo(color: AppColors.textMuted)),
        SizedBox(width: 100, child: _buildTextField("", value, enabled: enabled)),
      ],
    );
  }
}

// أزرار البدء والتوقف (ActionButtonsWidget) - نفس تصميم صاحبك
class ActionButtonsWidget extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onOpenChart;
  const ActionButtonsWidget({Key? key, required this.onStart, required this.onStop, required this.onOpenChart}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 5),
            onPressed: onStart,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.rocket_launch, color: Colors.black),
                const SizedBox(width: 10),
                Text("بدء التداول السريع", style: GoogleFonts.cairo(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 55,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: onStop,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stop_circle, color: AppColors.danger),
                const SizedBox(width: 10),
                Text("إيقاف التداول", style: GoogleFonts.cairo(color: AppColors.danger, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 55,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: onOpenChart,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.show_chart, color: AppColors.primary),
                const SizedBox(width: 10),
                Text("فتح الشارت المباشر", style: GoogleFonts.cairo(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// سجل الصفقات (TradeHistoryWidget) - نفس تصميم صاحبك
class TradeHistoryWidget extends StatelessWidget {
  const TradeHistoryWidget({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("سجل الصفقات الأخيرة", style: GoogleFonts.cairo(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildHistoryRow("EUR/USD", "+\$15.00", AppColors.success),
          _buildHistoryRow("GBP/JPY", "-\$10.00", AppColors.danger),
          _buildHistoryRow("GOLD", "+\$25.50", AppColors.success),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(String pair, String amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(pair, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          Text(amount, style: GoogleFonts.cairo(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// العداد التنازلي (CountdownDialog) - نفس تصميم صاحبك
class CountdownDialog extends StatefulWidget {
  const CountdownDialog({Key? key}) : super(key: key);
  @override
  State<CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<CountdownDialog> {
  int seconds = 5;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (seconds > 0) {
        setState(() => seconds--);
      } else {
        _timer?.cancel();
        Navigator.pop(context);
      }
    });
  }
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.gold)),
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("جاري تحضير الصفقة", style: GoogleFonts.cairo(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(width: 120, height: 120, child: CircularProgressIndicator(value: seconds / 5, strokeWidth: 8, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.danger))),
                Text("$seconds", style: GoogleFonts.cairo(fontSize: 50, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 30),
            Text("سيتم الدخول تلقائياً في الوقت المحدد", style: GoogleFonts.cairo(color: AppColors.textMuted)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                _timer?.cancel();
                Navigator.pop(context);
              },
              child: Text("إلغاء الأمر", style: GoogleFonts.cairo(color: AppColors.danger, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// خلفية النجوم (StarfieldBackground) - نفس تصميم صاحبك
class StarfieldBackground extends StatefulWidget {
  const StarfieldBackground({Key? key}) : super(key: key);
  @override
  State<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<StarfieldBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Star> _stars = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 50; i++) {
      _stars.add(Star(x: _random.nextDouble(), y: _random.nextDouble(), size: _random.nextDouble() * 2 + 1, speed: _random.nextDouble() * 0.5 + 0.1));
    }
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _controller.addListener(() {
      setState(() {
        for (var star in _stars) {
          star.y -= star.speed * 0.005;
          if (star.y < 0) {
            star.y = 1.0;
            star.x = _random.nextDouble();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(color: AppColors.bgMain, child: CustomPaint(painter: StarPainter(stars: _stars), size: Size.infinite));
  }
}

class Star {
  double x;
  double y;
  final double size;
  final double speed;
  Star({required this.x, required this.y, required this.size, required this.speed});
}

class StarPainter extends CustomPainter {
  final List<Star> stars;
  StarPainter({required this.stars});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.5);
    for (var star in stars) {
      canvas.drawCircle(Offset(star.x * size.width, star.y * size.height), star.size, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
