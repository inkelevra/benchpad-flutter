import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../screens/advertise_screen.dart';

/// Listens for Android's "Share to BenchPad" intent (registered in
/// AndroidManifest.xml for image/* and text/plain) and opens Post to
/// BenchPad with the shared photo already loaded.
///
/// Two cases, matching what different apps actually put in a share:
/// 1. A real image file (Gallery, most browsers' "share image", many
///    apps) — read directly, always works.
/// 2. Shared text containing a URL — only usable if it's a DIRECT link
///    to an image file (ends in .jpg/.png/.webp/.gif). Some apps
///    (Pinterest, in some flows) instead share a link to a whole page
///    (the pin's page, not the image itself) — that can't be turned
///    into a photo without scraping the page, which is fragile and not
///    done here; shows a clear message instead of failing silently.
class ShareIntentService {
  ShareIntentService._();
  static final ShareIntentService instance = ShareIntentService._();

  StreamSubscription<List<SharedMediaFile>>? _sub;
  GlobalKey<NavigatorState>? _navigatorKey;

  void start(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;

    // Already-running app receiving a new share.
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty) _handleShare(files);
    });

    // App was launched fresh by tapping "BenchPad" in the share sheet.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) _handleShare(files);
    });
  }

  void dispose() {
    _sub?.cancel();
  }

  Future<void> _handleShare(List<SharedMediaFile> files) async {
    final file = files.first;
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    try {
      Uint8List? bytes;

      if (file.type == SharedMediaType.image || file.type == SharedMediaType.file) {
        bytes = await _readLocalFile(file.path);
      } else {
        // text or url — only usable if it's a direct image link.
        final text = file.path.trim();
        if (_looksLikeDirectImageUrl(text)) {
          bytes = await _downloadImage(text);
        } else {
          _showUnsupportedLinkMessage(navigator);
          return;
        }
      }

      if (bytes == null) {
        _showUnsupportedLinkMessage(navigator);
        return;
      }

      navigator.push(MaterialPageRoute(builder: (_) => AdvertiseScreen(initialImageBytes: bytes)));
    } catch (_) {
      _showUnsupportedLinkMessage(navigator);
    }
  }

  bool _looksLikeDirectImageUrl(String text) {
    if (!text.startsWith('http://') && !text.startsWith('https://')) return false;
    final lower = text.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp') || lower.endsWith('.gif');
  }

  Future<Uint8List?> _readLocalFile(String path) async {
    try {
      final uri = Uri.tryParse(path);
      final actualPath = (uri != null && uri.scheme == 'file') ? uri.toFilePath() : path;
      final f = File(actualPath);
      if (await f.exists()) return await f.readAsBytes();
    } catch (_) {}
    return null;
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  void _showUnsupportedLinkMessage(NavigatorState navigator) {
    final context = navigator.context;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Couldn't get the image from that share — some apps share a page link instead of the photo itself. Try sharing the image directly, or save it and pick it from your gallery."),
        duration: Duration(seconds: 5),
      ),
    );
  }
}
