/// Official / legal URLs for Settings → About.
///
/// Defaults align with GitHub Pages store + GitHub Releases.
/// Replace only if you move the public landing / legal pages.
class BrandLinks {
  BrandLinks._();

  static const githubRepo = 'https://github.com/PHPJourney/netbridge';

  static const githubReleases = 'https://github.com/PHPJourney/netbridge/releases';

  /// GitHub Pages store (project site).
  static const officialSite = 'https://phpjourney.github.io/netbridge/';

  /// Optional OpenList browse mirror (packages may also live on Releases).
  static const openlistBrowse = 'http://154.37.213.245:5244/store';

  static const openlistBase = 'http://154.37.213.245:5244';

  static const termsUrl = 'https://phpjourney.github.io/netbridge/terms.html';

  static const privacyUrl = 'https://phpjourney.github.io/netbridge/privacy.html';

  static const partnersLine = 'TradeMind / TM Open Platform';

  /// Keep in sync with pubspec `version` (before `+build`).
  static const appVersion = '0.1.19';
}
