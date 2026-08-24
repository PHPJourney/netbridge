import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/app_localizations.dart';
import '../../profile/profile_codec.dart';
import '../../profile/profile_errors.dart';
import '../../services/server_import.dart';
import '../../theme.dart';
import '../../widgets/common_widgets.dart';

/// Camera QR scan: plain `nbvpn:` and encrypted `nbvpn-enc:` (passphrase prompt).
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
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 800,
      cameraResolution: const Size(1920, 1080),
      autoZoom: true,
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
    if (!_controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_handled) unawaited(_safeStart());
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
    } catch (_) {}
  }

  Future<void> _safePause() async {
    try {
      await _controller.pause();
    } catch (_) {}
  }

  String _bestRaw(BarcodeCapture capture) {
    final candidates = <String?>[];
    for (final b in capture.barcodes) {
      candidates.add(b.rawValue);
      candidates.add(b.displayValue);
    }
    return ProfileImportService.bestFromScan(candidates);
  }

  Future<void> _consumeRaw(String raw) async {
    if (_handled) return;
    final cleaned = ProfileCodec.sanitizeUriInput(raw);
    if (cleaned.isEmpty && raw.trim().isEmpty) return;

    _handled = true;
    await _safePause();
    final lang = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);

    try {
      final entries = await ProfileImportService.parseText(
        context,
        cleaned.isNotEmpty ? cleaned : raw.trim(),
      );
      if (!mounted) return;
      if (entries == null) {
        _resetDetection();
        await _safeStart();
        return;
      }
      if (entries.isEmpty) {
        throw ProfileException(ProfileErrorCode.uriDecode, detail: 'empty pack');
      }
      Navigator.of(context).pop(entries);
    } catch (e) {
      _resetDetection();
      if (!mounted) return;
      setState(() => _error = ProfileImportService.errorMessage(e, lang));
      await _safeStart();
    }
  }

  void _resetDetection() => _handled = false;

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
          SnackBar(content: Text(AppLocalizations.of(context).torchToggleFailed)),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_handled || _analyzingGallery) return;
    final l10n = AppLocalizations.of(context);
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
      final path = (files != null && files.isNotEmpty) ? files.first.path : null;
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
        setState(() => _error = l10n.qrGalleryNoCode);
        await _safeStart();
        return;
      }
      await _consumeRaw(raw);
    } catch (_) {
      _resetDetection();
      if (mounted) {
        setState(() => _error = l10n.qrGalleryFailed);
        await _safeStart();
      }
    } finally {
      if (mounted) setState(() => _analyzingGallery = false);
    }
  }

  Future<void> _submitPaste() async {
    final l10n = AppLocalizations.of(context);
    final text = _paste.text.trim();
    if (text.isEmpty) {
      setState(() => _error = l10n.scanPasteEmpty);
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanQr),
        actions: [
          IconButton(
            tooltip: _torchOn ? l10n.torchOff : l10n.torchOn,
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
                                l10n.cameraOpenFailed(error.errorCode.name),
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
                          l10n.scanQrCameraHint,
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
                  label: Text(l10n.scanFromGallery),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pasteClipboard,
                        icon: const Icon(Icons.content_paste, size: 18),
                        label: Text(l10n.pasteFromClipboard),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handled ? null : _submitPaste,
                        child: Text(l10n.validateContinue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _paste,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n.scanPasteHint,
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
