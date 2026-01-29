import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class UsgsWebViewPage extends StatefulWidget {
  final String url;
  const UsgsWebViewPage({super.key, required this.url});

  @override
  State<UsgsWebViewPage> createState() => _UsgsWebViewPageState();
}

class _UsgsWebViewPageState extends State<UsgsWebViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) {
            if (!req.url.startsWith("https://")) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("USGS Event")),
      body: WebViewWidget(controller: _controller),
    );
  }
}
