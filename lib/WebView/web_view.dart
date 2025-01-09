import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reseller_webview/WebView/back_pressed.dart';
import 'package:url_launcher/url_launcher.dart';

class WebScreen extends StatefulWidget {
  const WebScreen({super.key});

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late InAppWebViewController _webViewController;
  final BackPressed _backPressed = BackPressed();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      //canPop: true,
      onWillPop: () async {
        //If website can go back page
        if (await _webViewController.canGoBack()) {
          await _webViewController.goBack();
          return false;
        } else {
          //Double pressed to exit app
          return _backPressed.exit(context);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: InAppWebView(
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final uri = navigationAction.request.url!;

              // Check if the URL should be opened externally or handled within the WebView
              if (uri.scheme == 'http' || uri.scheme == 'https') {
                // Allow the WebView to load the URL
                return NavigationActionPolicy.ALLOW;
              } else {
                // For non-http/https URLs, try launching them externally
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  debugPrint('Could not launch $uri');
                }
                return NavigationActionPolicy.CANCEL;
              }
            },
            initialUrlRequest: URLRequest(
              // mainDocumentURL: WebUri(source),
              url: WebUri("https://confidenceresellerbd.com/reseller/home"),
            ),
            initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowFileAccess: true,
                useOnDownloadStart: true,
                builtInZoomControls: false,
                pageZoom: .0,
                supportZoom: false),
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
                        base64Content,
                        "${DateTime.now().year}-${DateTime.now().hour}-${DateTime.now().minute}-${DateTime.now().second}",
                        extension);
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
      ),
    );
  }

  String _getFileExtensionFromMimeType(String mimeType) {
    return mimeType.split('/').last; // Example: "application/pdf" -> "pdf"
  }

  Future<void> _saveBase64File(
      String base64Content, String fileName, String fileExtension) async {
    if (await Permission.manageExternalStorage.isGranted ||
        (await Permission.storage.isGranted &&
            await Permission.mediaLibrary.isGranted)) {
      debugPrint("All permissions granted");
    } else {
      debugPrint("Requesting permissions");
      await Permission.manageExternalStorage.request();
      await Permission.storage.request();
      await Permission.mediaLibrary.request();
    }
    try {
      final decodedBytes = base64Decode(base64Content.replaceAll('\n', ''));
      final directory = Directory('/storage/emulated/0/Download');
      final filePath = "${directory.path}/$fileName.$fileExtension";
      final file = File(filePath);
      await file.writeAsBytes(decodedBytes);
      await ImageGallerySaverPlus.saveImage(decodedBytes);
      //await OpenFile.open(filePath);
      debugPrint("File saved at: $filePath");
    } catch (e) {
      debugPrint("Error saving file: $e");
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save file: $e')),
      );
    }
  }
}
