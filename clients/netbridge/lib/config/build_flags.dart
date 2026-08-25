/// Compile-time flags for branded / commercial builds.
///
/// Pass `--dart-define=COMMERCIAL_BUILD=true` when building the commercial
/// delivery (`netbridge-commercial`).
class BuildFlags {
  BuildFlags._();

  static const commercialBuild = bool.fromEnvironment(
    'COMMERCIAL_BUILD',
    defaultValue: false,
  );

  /// Default for Settings → automatic split tunnel (exclude private networks).
  ///
  /// Off by default (full tunnel). Pass `--dart-define=DEFAULT_EXCLUDE_PRIVATE_NETWORKS=true`
  /// or set for commercial builds that want car/LAN-friendly defaults.
  static const defaultExcludePrivateNetworks = bool.fromEnvironment(
    'DEFAULT_EXCLUDE_PRIVATE_NETWORKS',
    defaultValue: false,
  );

  /// Default for Settings → IP leak protection (force full tunnel + KS intent).
  ///
  /// Defaults to [commercialBuild] when `DEFAULT_LEAK_PROTECTION` is unset, so
  /// commercial APKs ship with leak protection ON.
  static const defaultLeakProtection = bool.fromEnvironment(
    'DEFAULT_LEAK_PROTECTION',
    defaultValue: commercialBuild,
  );
}
