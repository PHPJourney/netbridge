import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/server_entry.dart';
import '../theme.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.status,
    this.serverName,
    this.statusDetail,
    this.errorText,
    this.onCopyError,
    this.onRetry,
  });

  final VpnUiStatus status;
  final String? serverName;
  /// Optional override (e.g. “Switching server…”).
  final String? statusDetail;
  final String? errorText;
  final VoidCallback? onCopyError;
  final VoidCallback? onRetry;

  Color get _color => switch (status) {
        VpnUiStatus.disconnected => NbColors.mutedText,
        VpnUiStatus.connecting => NbColors.warn,
        VpnUiStatus.connected => NbColors.ok,
        VpnUiStatus.reconnecting => NbColors.warn,
        VpnUiStatus.error => NbColors.danger,
      };

  String _label(AppLocalizations l10n) => switch (status) {
        VpnUiStatus.disconnected => l10n.statusDisconnected,
        VpnUiStatus.connecting => l10n.statusConnecting,
        VpnUiStatus.connected => l10n.statusConnected,
        VpnUiStatus.reconnecting => l10n.statusReconnecting,
        VpnUiStatus.error => l10n.statusError,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = _label(l10n);
    final detail = switch (status) {
      VpnUiStatus.connected when serverName != null =>
        l10n.statusConnectedDetail(serverName!),
      VpnUiStatus.connecting when statusDetail != null && statusDetail!.isNotEmpty =>
        statusDetail!,
      VpnUiStatus.connecting when serverName != null =>
        l10n.statusConnectingDetail(serverName!),
      VpnUiStatus.reconnecting => l10n.statusReconnectingDetail,
      VpnUiStatus.error => errorText ?? l10n.statusErrorFallback,
      _ => statusDetail?.isNotEmpty == true ? statusDetail! : label,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NbColors.surface,
        border: Border(
          bottom: BorderSide(color: _color.withValues(alpha: 0.45), width: 2),
        ),
      ),
      child: Row(
        children: [
          _BreathingDot(
            color: _color,
            active: status == VpnUiStatus.connecting ||
                status == VpnUiStatus.reconnecting ||
                status == VpnUiStatus.connected,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              detail,
              style: const TextStyle(
                color: NbColors.warmText,
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (status == VpnUiStatus.error && errorText != null) ...[
            IconButton(
              tooltip: l10n.copyError,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: errorText!));
                onCopyError?.call();
              },
              icon: const Icon(Icons.copy, size: 18, color: NbColors.mutedText),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
          ],
        ],
      ),
    );
  }
}

class _BreathingDot extends StatefulWidget {
  const _BreathingDot({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<_BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<_BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _BreathingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.active
          ? Tween(begin: 0.35, end: 1.0).animate(_c)
          : const AlwaysStoppedAnimation(1),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
