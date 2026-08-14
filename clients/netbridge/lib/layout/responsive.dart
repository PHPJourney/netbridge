import 'package:flutter/material.dart';

/// Wide-window / desktop layout breakpoint (logical px).
const double kDesktopBreakpoint = 900;

/// Default max content width for settings / add flows on desktop.
const double kDesktopContentMaxWidth = 720;

/// Home master–detail list pane width on desktop.
const double kDesktopListPaneWidth = 380;

bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// Horizontal padding: roomier on wide windows, phone-compact otherwise.
EdgeInsets pagePadding(BuildContext context, {double mobile = 20}) {
  if (isDesktopLayout(context)) {
    return const EdgeInsets.fromLTRB(32, 24, 32, 24);
  }
  return EdgeInsets.all(mobile);
}

/// Centers content with a max width on desktop; full-bleed on narrow/mobile.
/// Prefer placing a non-scrolling column/form as [child]; wraps in a
/// [SingleChildScrollView] so Scaffold bodies stay bounded.
class DesktopConstrainedBody extends StatelessWidget {
  const DesktopConstrainedBody({
    super.key,
    required this.child,
    this.maxWidth = kDesktopContentMaxWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? pagePadding(context);
    final desktop = isDesktopLayout(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = desktop
            ? maxWidth.clamp(0, constraints.maxWidth).toDouble()
            : constraints.maxWidth;
        return SingleChildScrollView(
          padding: pad,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
