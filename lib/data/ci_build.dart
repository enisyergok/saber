/// The number of the build that made this app, set by the build workflow
/// (`--dart-define=CI_BUILD=<n>`). Empty for builds made elsewhere.
const ciBuild = String.fromEnvironment('CI_BUILD');
