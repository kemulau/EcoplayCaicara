import 'dart:convert';
import 'dart:io';

/// Runs `flutter run` for web devices forcing the HTML renderer. Works even on
/// Flutter versions that do not have the `--web-renderer` flag by falling back
/// to legacy environment variables.
Future<void> main(List<String> args) async {
  final deviceId = args.isNotEmpty ? args.first : 'chrome';
  final forwarded = args.length > 1 ? args.sublist(1) : const <String>[];

  final baseArgs = <String>['run', '-d', deviceId, ...forwarded];

  final env = Map<String, String>.from(Platform.environment)
    ..putIfAbsent('FLUTTER_WEB_RENDERER', () => 'html')
    ..putIfAbsent('FLUTTER_WEB_AUTO_DETECT', () => 'false')
    ..putIfAbsent('FLUTTER_WEB_USE_SKIA', () => 'false');

  final withFlag = await _runFlutter(
    [...baseArgs, '--web-renderer=html'],
    environment: env,
    captureOutput: true,
  );

  if (withFlag.exitCode == 0) {
    exit(withFlag.exitCode);
  }

  final combined = (withFlag.stdout ?? '') + (withFlag.stderr ?? '');
  if (combined.contains("Could not find an option named \"--web-renderer\"")) {
    stdout.writeln('`--web-renderer` not supported, retrying with legacy env.');
    final fallback = await _runFlutter(baseArgs, environment: env);
    exit(fallback.exitCode);
  }

  stderr.write(combined);
  exit(withFlag.exitCode);
}

class _RunResult {
  const _RunResult(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String? stdout;
  final String? stderr;
}

Future<_RunResult> _runFlutter(
  List<String> args, {
  Map<String, String>? environment,
  bool captureOutput = false,
}) async {
  final process = await Process.start(
    'flutter',
    args,
    runInShell: true,
    environment: environment,
  );

  final stdoutBuffer = captureOutput ? StringBuffer() : null;
  final stderrBuffer = captureOutput ? StringBuffer() : null;

  final stdoutFuture = process.stdout.transform(utf8.decoder).listen((data) {
    stdout.write(data);
    stdoutBuffer?.write(data);
  }).asFuture<void>();

  final stderrFuture = process.stderr.transform(utf8.decoder).listen((data) {
    stderr.write(data);
    stderrBuffer?.write(data);
  }).asFuture<void>();

  await Future.wait([stdoutFuture, stderrFuture]);
  final code = await process.exitCode;

  return _RunResult(code, stdoutBuffer?.toString(), stderrBuffer?.toString());
}
