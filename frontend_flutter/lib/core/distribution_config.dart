/// Build-time switches for distribution-specific behavior.
///
/// The Google Play bundle is built with
/// `--dart-define=PLAY_STORE_BUILD=true`. Direct APK and web builds retain the
/// existing Pago Móvil flow.
const bool isGooglePlayBuild = bool.fromEnvironment(
  'PLAY_STORE_BUILD',
  defaultValue: false,
);
