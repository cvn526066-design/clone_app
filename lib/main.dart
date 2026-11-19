import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Quotex/1.0")
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange urlChange) {
            // 442. نراقب الرابط.. إذا صار فيه trade أو cabinet يعني سجل دخول
            if (!_hasNavigated && (urlChange.url?.contains('/trade') == true || urlChange.url?.contains('/cabinet') == true || urlChange.url?.contains('/demo-trade') == true)) {
              _hasNavigated = true;
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

// 443. شاشة البوت (التصميم اللي بعتّه)
class MainTradingScreen extends StatefulWidget {
  const MainTradingScreen({super.key});
  @override
  State<MainTradingScreen> createState() => _MainTradingScreenState();
}

class _MainTradingScreenState extends State<MainTradingScreen> {
  bool isBotRunning = false;
  bool isDemoAccount = true;
  late IO.Socket _socket;
  List<String> _pairs = [];
  String _balance = "0.00";

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    _socket = IO.io('https://ws2.quotex.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'path': '/socket.io/',
      'query': {'EIO': '4', 'transport': 'websocket'},
    });

    _socket.onConnect((_) {
      // 444. نطلب الأزواج والرصيد
      _socket.emit('42["instruments/list"]');
      _socket.emit('42["balance/list"]');
    });

    _socket.on('instruments/update', (data) {
      if (data['instruments'] != null) {
        setState(() {
          _pairs = List<String>.from(data['instruments'].map((i) => i['name']));
        });
      }
    });

    _socket.on('balance/list', (data) {
      if (data['balance'] != null) {
        setState(() {
          _balance = data['balance'].toString();
        });
      }
    });
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
                  // بطاقة الرصيد
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF0E0E14), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF00E5FF))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الرصيد:', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                        Text('\$$_balance', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // الأزواج المتاحة
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF0E0E14), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الأزواج المتاحة:', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _pairs.map((pair) => Chip(
                            label: Text(pair, style: const TextStyle(color: Colors.white)),
                            backgroundColor: const Color(0xFF1E1E24),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // أزرار الحساب
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
                  // زر التداول
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
