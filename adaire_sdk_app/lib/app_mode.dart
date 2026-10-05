/// App mode configuration.
///
/// Change via --dart-define=APP_MODE=production for production builds,
/// or edit the default below.
class AppMode {
  static const String value = String.fromEnvironment('APP_MODE', defaultValue: 'dev');
  static bool get isProduction => value.toLowerCase() == 'production';
}

