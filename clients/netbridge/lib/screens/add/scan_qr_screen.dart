import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../profile/profile.dart';
import '../../theme.dart';
import '../../widgets/common_widgets.dart';

/// C-05: camera QR scan (mobile). QR content = full `nbvpn:1?<base64url>`.
///
/// Terminal / peers PNG QRs are dense — high camera resolution, large window,
/// auto-zoom, torch, gallery decode, and paste are first-class.
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  final _paste = TextEditingController();
  String? _error;
  bool _handled = false;
  bool _torchOn = false;
  bool _analyzingGallery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Android defaults to 640x480 when null — too coarse for dense nbvpn URIs.
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 800,
      cameraResolution: const Size(1920, 1080),
      autoZoom: true,
      // Mild zoom helps dense terminal modules fill the frame sooner.
      initialZoom: 0.15,
      autoStart: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paste.dispose();
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Custom controller → plugin does not auto pause/resume; we must.
    if (!_controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_handled) {
          unawaited(_safeStart());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_controller.stop());
    }
  }

  Future<void> _safeStart() async {
    try {
      if (!_controller.value.isRunning && !_controller.value.isStarting) {
        await _controller.start();
      }
    } catch (_) {
      // Start races / already starting — ignore; retry / next detect recovers.
    }
  }

  Future<void> _safePause() async {
    try {
      await _controller.pause();
    } catch (_) {}
  }

  /// Prefer full `nbvpn:` payloads; otherwise the longest non-empty string.
  String _bestRaw(BarcodeCapture capture) {
    String best = '';
    String bestNb = '';
    for (final b in capture.barcodes) {
      for (final candidate in [b.rawValue, b.displayValue]) {
        if (candidate == null || candidate.isEmpty) continue;
        final cleaned = ProfileCodec.sanitizeUriInput(candidate);
        if (cleaned.toLowerCase().startsWith('nbvpn:') &&
            cleaned.length > bestNb.length) {
          bestNb = cleaned;
        }
        if (candidate.length > best.length) best = candidate;
      }
    }
    return bestNb.isNotEmpty ? bestNb : best;
  }

  Future<void> _consumeRaw(String raw) async {
    if (_handled) return;
    final cleaned = ProfileCodec.sanitizeUriInput(raw);
    if (cleaned.isEmpty) return;

    _handled = true;
    await _safePause();

    try {
      final profile = ProfileCodec.parseFlexibleImport(cleaned);
      if (!mounted) return;
      Navigator.of(context).pop(profile);
    } on ProfileException catch (e) {
      _resetDetection();
      if (!mounted) return;
      final lang = Localizations.localeOf(context).languageCode;
      setState(() => _error = e.messageForLanguage(lang));
      await _safeStart();
    } catch (_) {
      _resetDetection();
      if (!mounted) return;
      final en = Localizations.localeOf(context).languageCode.startsWith('en');
      setState(() {
        _error = en
            ? 'Could not recognize the QR. Dense terminal URIs: move closer, tap to focus, use torch, or prefer gallery (peers/*.png) / paste URI.'
            : '无法识别二维码内容。终端长 URI 较密：拉近、点按对焦、开灯，'
                '或优先用「从相册选图」（peers/*.png）/ 粘贴 URI。';
      });
      await _safeStart();
    }
  }

  void _resetDetection() {
    _handled = false;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = _bestRaw(capture);
    if (raw.isEmpty) return;
    unawaited(_consumeRaw(raw));
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法切换闪光灯')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_handled || _analyzingGallery) return;
    setState(() {
      _analyzingGallery = true;
      _error = null;
    });
    await _safePause();
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: false,
      );
      if (!mounted) return;
      final files = result?.files;
      final path =
          (files != null && files.isNotEmpty) ? files.first.path : null;
      if (path == null || path.isEmpty) {
        _resetDetection();
        await _safeStart();
        return;
      }
      final capture = await _controller.analyzeImage(
        path,
        formats: const [BarcodeFormat.qrCode],
      );
      if (!mounted) return;
      final raw = capture == null ? '' : _bestRaw(capture);
      if (raw.isEmpty) {
        _resetDetection();
        setState(() {
          _error = '图片中未识别到二维码。请选 peers/<id>.png 或改用粘贴 URI。';
        });
        await _safeStart();
        return;
      }
      await _consumeRaw(raw);
    } catch (_) {
      _resetDetection();
      if (mounted) {
        setState(() => _error = '无法从图片识别二维码，请改用粘贴 URI。');
        await _safeStart();
      }
    } finally {
      if (mounted) setState(() => _analyzingGallery = false);
    }
  }

  Future<void> _submitPaste() async {
    final text = _paste.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请粘贴 nbvpn:1?… 链接');
      return;
    }
    await _consumeRaw(text);
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _paste.text = data!.text!;
        _error = null;
      });
    }
  }

  void _resumeScanning() {
    setState(() {
      _error = null;
      _handled = false;
    });
    unawaited(_safeStart());
  }

  /// Large centered window so dense modules occupy more of the analyzer crop.
  Rect _scanWindowFor(BoxConstraints constraints) {
    final size = constraints.biggest;
    final side = (size.shortestSide * 0.90).clamp(240.0, size.shortestSide);
    return Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
        actions: [
          IconButton(
            tooltip: _torchOn ? '关闭闪光灯' : '打开闪光灯',
            onPressed: _toggleTorch,
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final window = _scanWindowFor(constraints);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      fit: BoxFit.cover,
                      scanWindow: window,
                      tapToFocus: true,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) {
                        return ColoredBox(
                          color: Colors.black,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '无法打开相机：${error.errorCode.name}\n'
                                '请允许相机权限，或改用下方「从相册选图」/粘贴。',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      overlayBuilder: (context, constraints) {
                        return IgnorePointer(
                          child: ScanWindowOverlay(
                            controller: _controller,
                            scanWindow: _scanWindowFor(constraints),
                            borderColor: NbColors.accent,
                            borderWidth: 3,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: IgnorePointer(
                        child: Text(
                          '终端 / PNG 二维码较密：填满取景框，点按对焦，必要时开灯',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12.5,
                            height: 1.35,
                            shadows: const [
                              Shadow(blurRadius: 6, color: Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _analyzingGallery ? null : _pickFromGallery,
                  icon: _analyzingGallery
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('从相册选图（推荐：peers/*.png）'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pasteClipboard,
                        icon: const Icon(Icons.content_paste, size: 18),
                        label: const Text('粘贴剪贴板'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handled ? null : _submitPaste,
                        child: const Text('校验粘贴'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _paste,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '或粘贴 nbvpn:1?…（终端密码扫不清时用）',
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorCopyable(
                    message: _error!,
                    onRetry: _resumeScanning,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
