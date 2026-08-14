import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

class EmptyServerState extends StatelessWidget {
  const EmptyServerState({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 72,
              color: NbColors.accent.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.emptyTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: NbColors.warmText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.emptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NbColors.mutedText,
                height: 1.45,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(l10n.addServer),
            ),
          ],
        ),
      ),
    );
  }
}

class SecretWarningCallout extends StatelessWidget {
  const SecretWarningCallout({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NbColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NbColors.warn.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: NbColors.warn, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.secretWarning,
              style: const TextStyle(
                color: NbColors.warmText,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorCopyable extends StatelessWidget {
  const ErrorCopyable({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NbColors.danger.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            message,
            style: const TextStyle(color: NbColors.danger, height: 1.4),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                // Clipboard via Selection / parent may handle; use SnackBar path from screen.
              },
              icon: const Icon(Icons.copy, size: 16),
              label: Text(l10n.longPressCopy),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(l10n.reenter),
              ),
          ],
        ),
      ],
    );
  }
}
