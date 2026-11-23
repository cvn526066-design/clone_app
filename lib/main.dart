import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'foreground_service',
      channelName: 'Foreground Service',
      channelImportance: NotificationChannelImportance.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: true,
    ),
  );
  runApp(const MyApp());
}

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

// 1. الشريط السفلي
class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});
  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _currentIndex = 0;
  String _cookies = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0 
          ? LoginScreen(onCookiesReady: (cookies) {
              setState(() {
                _cookies = cookies;
                _currentIndex = 1; 
              });
            }) 
          : MainTradingScreen(cookies: _cookies),
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

// 2. شاشة تسجيل الدخول
class LoginScreen extends StatefulWidget {
  final Function(String) onCookiesReady;
  const LoginScreen({super.key, required this.onCookiesReady});
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
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange urlChange) async {
            if (urlChange.url?.contains('/trade') == true || urlChange.url?.contains('/cabinet') == true) {
              final cookies = await _controller.runJavaScriptReturningResult("document.cookie");
              widget.onCookiesReady(cookies.toString());
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/sign-in'));
  }

  void _requestPermissions() async {
    await Permission.location.request();
    await Permission.notification.request();
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: WebViewWidget(controller: _controller));
}

// 3. الثيم والألوان
class AppColors {
  static const Color bgMain = Color(0xFF030305);
  static const Color bgCard = Color(0xFF0E0E14);
  static const Color primary = Color(0xFF00E5FF);
  static const Color gold = Color(0xFFFFD700);
  static const Color success = Color(0xFF00E676);
  static const Color danger = Color(0xFFFF1744);
  static const Color textMuted = Color(0xFFA0A0B0);
  static const Color border = Color(0x14FFFFFF);
}

// 4. الشاشة الرئيسية
class MainTradingScreen extends StatefulWidget {
  final String cookies;
  const MainTradingScreen({Key? key, required this.cookies}) : super(key: key);
  @override
  State<MainTradingScreen> createState() => _MainTradingScreenState();
}

class _MainTradingScreenState extends State<MainTradingScreen> {
  late WebViewController _controller;
  String currentPrice = "0.00";
  double demoBalance = 0.0;
  double realBalance = 0.0;
  bool isDemoAccount = true;
  bool isRiskManagerActive = false;
  bool isConnected = false;
  
  List<String> _exchangePairs = [];
  List<String> _otcPairs = [];
  
  final List<String> _athkarList = [
    "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ",
    "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ",
    "اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ",
  ];
  int _currentAthkarIndex = 0;
  Timer? _athkarTimer;
  String currentTime = "12:00:00";

  @override
  void initState() {
    super.initState();
    _initWebView();
    _startTimers();
  }

  void _startTimers() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      setState(() {
        currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      });
    });
    _athkarTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      setState(() => _currentAthkarIndex = (_currentAthkarIndex + 1) % _athkarList.length);
    });
  }

  // 585. نحقن الكوكيز بالجافاسكريبت
  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Quotex/1.0")
      ..addJavaScriptChannel(
        'QTX_DATA',
        onMessageReceived: (msg) {
          print("JAVASCRIPT MESSAGE: ${msg.message}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("رسالة من JS: ${msg.message}"), backgroundColor: Colors.blue),
          );
          
          var data = jsonDecode(msg.message);
          if (data['type'] == 'connected') {
            setState(() => isConnected = true);
          } else if (data['type'] == 'disconnected') {
            setState(() => isConnected = false);
          } else if (data['type'] == 'pairs') {
            setState(() {
              _exchangePairs = List<String>.from(data['exchange']);
              _otcPairs = List<String>.from(data['otc']);
            });
          } else if (data['type'] == 'balance') {
            setState(() => demoBalance = double.parse(data['balance'].toString()));
          } else if (data['type'] == 'price') {
            setState(() => currentPrice = data['price'].toStringAsFixed(5));
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            // نحقن الكوكيز في الصفحة
            await _controller.runJavaScript("document.cookie = '${widget.cookies}';");
            _injectWebSocketScript(widget.cookies);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/demo-trade'));
  }

  void _injectWebSocketScript(String cookies) {
    String jsScript = """
      (function() {
        if (window.__qtxSocket) return;
        var token = '';
        var match = document.cookie.match(/qtx_session_cookie=([^;]+)/);
        if (match) token = match[1];
        
        var socket = new WebSocket('wss://ws2.quotex.com/socket.io/?EIO=4&transport=websocket', [], {
          headers: {
            'Cookie': document.cookie,
            'User-Agent': 'Quotex/1.0',
            'Authorization': 'Bearer ' + token
          }
        });
        socket.onopen = function() {
          QTX_DATA.postMessage(JSON.stringify({type: 'connected'}));
          socket.send('42["instruments/list"]');
          socket.send('42["balance/list"]');
          socket.send('42["quotes/stream"]');
        };
        socket.onclose = function() {
          QTX_DATA.postMessage(JSON.stringify({type: 'disconnected'}));
        };
        socket.onerror = function() {
          QTX_DATA.postMessage(JSON.stringify({type: 'disconnected'}));
        };
        socket.onmessage = function(event) {
          var msg = event.data;
          if (msg.includes('instruments/update')) {
            var data = JSON.parse(msg.substring(2));
            var pairs = data[1].instruments.map(i => i.name);
            var exchange = pairs.filter(p => !p.includes('_otc'));
            var otc = pairs.filter(p => p.includes('_otc'));
            QTX_DATA.postMessage(JSON.stringify({type: 'pairs', exchange: exchange, otc: otc}));
          } else if (msg.includes('balance/list')) {
            var data = JSON.parse(msg.substring(2));
            QTX_DATA.postMessage(JSON.stringify({type: 'balance', balance: data[1].balance}));
          } else if (msg.includes('quotes/stream')) {
            var data = JSON.parse(msg.substring(2));
            QTX_DATA.postMessage(JSON.stringify({type: 'price', price: data[1].price}));
          }
        };
        window.__qtxSocket = socket;
      })();
    """;
    _controller.runJavaScript(jsScript);
  }

  @override
  void dispose() {
    _athkarTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Stack(
        children: [
          Opacity(opacity: 0.0, child: SizedBox(width: 1, height: 1, child: WebViewWidget(controller: _controller))),
          const StarfieldBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TopHeaderWidget(currentTime: currentTime, isConnected: isConnected),
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الرصيد:', style: GoogleFonts.cairo(color: AppColors.textMuted)),
                        Text(isDemoAccount ? '\\\$$demoBalance' : '\\\$$realBalance', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  PairsDropZoneWidget(exchangePairs: _exchangePairs, otcPairs: _otcPairs),
                  const SizedBox(height: 20),
                  SettingsWidget(
                    isRiskActive: isRiskManagerActive,
                    onRiskToggle: (val) => setState(() => isRiskManagerActive = val),
                  ),
                  const SizedBox(height: 20),
                  ActionButtonsWidget(
                    onStart: () {
                      _controller.runJavaScript('window.__qtxSocket.send(\'42["orders/open", {"asset":"EURUSD","amount":10,"direction":"up","duration":60}]\')');
                      _showCountdownDialog(context);
                    },
                    onStop: () {
                      _controller.runJavaScript('window.__qtxSocket.send(\'42["orders/close"]\')');
                    },
                    onOpenChart: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ChartScreen(isDemo: isDemoAccount)));
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

// 5. شاشة الشارت
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
    String url = widget.isDemo ? 'https://quotex.com/ar/demo-trade' : 'https://quotex.com/ar/trade';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Quotex/1.0")
      ..loadRequest(Uri.parse(url));
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('الشارت المباشر')), body: SafeArea(child: WebViewWidget(controller: _controller)));
}

// 6. الـ Widgets (التصميم كامل، متل ما هو)
// (باقي الـ Widgets متل ما هي، ما في داعي أكررها، بس إنت بتعرف إنها موجودة كاملة).
