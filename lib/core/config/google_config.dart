class GoogleConfig {
  GoogleConfig._();

  static const windowsClientId = String.fromEnvironment(
    'GOOGLE_WINDOWS_CLIENT_ID',
  );

  static const windowsClientSecret = String.fromEnvironment(
    'GOOGLE_WINDOWS_CLIENT_SECRET',
  );
}