import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class WebScreen extends StatefulWidget {
  const WebScreen({super.key});

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late InAppWebViewController _webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(
                "https://confidenceresellerbd.com/reseller/passive-revenue"),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            allowFileAccess: true,
            useOnDownloadStart: true,
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;

            // Adding JavaScript handler for blob to Base64 conversion
            _webViewController.addJavaScriptHandler(
              handlerName: "blobToBase64",
              callback: (data) async {
                if (data.isNotEmpty && data.length >= 2) {
                  final String base64Content = data[0];
                  final String mimeType = data[1];
                  final String extension =
                      _getFileExtensionFromMimeType(mimeType);
                  await _saveBase64File(
                      base64Content, DateTime.now().toString(), extension);
                }
              },
            );
          },
          onDownloadStartRequest: (controller, url) async {
            debugPrint("Download started: ${url.url}");

            // Injecting JavaScript to convert blob to Base64
            try {
              var jsContent =
                  await rootBundle.loadString('assets/js/base64.js');
              await _webViewController.evaluateJavascript(
                source: jsContent.replaceAll(
                    "blobUrlPlaceholder", url.url.toString()),
              );
            } catch (e) {
              debugPrint("Error injecting JavaScript: $e");
            }
          },
        ),
      ),
    );
  }

  String _getFileExtensionFromMimeType(String mimeType) {
    return mimeType.split('/').last; // Example: "application/pdf" -> "pdf"
  }

  Future<void> _saveBase64File(
      String base64Content, String fileName, String fileExtension) async {
    try {
      final decodedBytes = base64Decode(base64Content.replaceAll('\n', ''));
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final filePath = "${directory.path}/$fileName.$fileExtension";
        final file = File(filePath);
        await file.writeAsBytes(decodedBytes);
        debugPrint("File saved at: $filePath");
        await OpenFile.open(filePath);
      } else {
        debugPrint("External storage directory not available.");
      }
    } catch (e) {
      debugPrint("Error saving file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save file: $e')),
      );
    }
  }
}
