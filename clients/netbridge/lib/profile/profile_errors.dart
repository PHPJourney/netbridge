/// Import / parse error codes per `03-contract.md` §3.3.
enum ProfileErrorCode {
  uriScheme,
  uriVersion,
  uriDecode,
  profileInvalid,
  profileUnsupported,
}

class ProfileException implements Exception {
  ProfileException(this.code, {this.detail});

  final ProfileErrorCode code;
  final String? detail;

  /// Machine code string (E_URI_* / E_PROFILE_*).
  String get codeName => switch (code) {
        ProfileErrorCode.uriScheme => 'E_URI_SCHEME',
        ProfileErrorCode.uriVersion => 'E_URI_VERSION',
        ProfileErrorCode.uriDecode => 'E_URI_DECODE',
        ProfileErrorCode.profileInvalid => 'E_PROFILE_INVALID',
        ProfileErrorCode.profileUnsupported => 'E_PROFILE_UNSUPPORTED',
      };

  /// Chinese copy for UI (design C-03 / C-12). Default for tests / zh.
  String get messageZh => _message(english: false);

  String get messageEn => _message(english: true);

  /// [languageCode] `en` → English; otherwise Chinese.
  String messageForLanguage(String languageCode) =>
      _message(english: languageCode.toLowerCase().startsWith('en'));

  String _message({required bool english}) => switch (code) {
        ProfileErrorCode.uriScheme => english
            ? 'Not a valid nbvpn link. It must start with nbvpn:.'
            : '不是有效的 nbvpn 链接，请确认以 nbvpn: 开头。',
        ProfileErrorCode.uriVersion => english
            ? 'Unsupported URI version. Use nbvpn:1? or upgrade the app.'
            : 'URI 版本不受支持，请使用 nbvpn:1? 形式或升级客户端。',
        ProfileErrorCode.uriDecode => english
            ? 'Could not decode the config (invalid Base64 or JSON).'
            : '无法解析配置内容（Base64 或 JSON 无效）。',
        ProfileErrorCode.profileInvalid => detail == null || detail!.isEmpty
            ? (english
                ? 'Invalid profile fields. Check and import again.'
                : '配置字段无效，请检查后重新导入。')
            : (english
                ? 'Invalid profile fields: $detail'
                : '配置字段无效：$detail'),
        ProfileErrorCode.profileUnsupported => english
            ? 'Profile version is too new. Upgrade the client, then import again.'
            : '配置版本过高，请升级客户端后再导入。',
      };

  @override
  String toString() =>
      detail == null || detail!.isEmpty ? codeName : '$codeName: $detail';
}
