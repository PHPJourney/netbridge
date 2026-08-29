import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Shares raw text via the platform share sheet (log export etc.).
Future<void> shareText(BuildContext context, String text) async {
  try {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'NetBridge log'),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share unavailable')),
      );
    }
  }
}
