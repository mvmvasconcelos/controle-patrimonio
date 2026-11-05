/// Identificação do build, injetada em tempo de compilação com
/// `--dart-define=APP_VERSION=... --dart-define=BUILD_DATE=...`.
class AppInfo {
  static const name = 'Controle de Patrimônio';
  static const version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.3+67',
  );
  static const buildDate = String.fromEnvironment(
    'BUILD_DATE',
    defaultValue: 'não informada',
  );
}
