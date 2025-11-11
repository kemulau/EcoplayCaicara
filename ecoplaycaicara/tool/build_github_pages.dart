import 'dart:convert';
import 'dart:io';

/// Builds the Flutter web bundle and publishes it into the repo-level `docs/`
/// folder expected by GitHub Pages. Always targets the HTML renderer so the
/// game works in Safari and Edge.
Future<void> main(List<String> args) async {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run this script from the Flutter project root.');
    exitCode = 64;
    return;
  }

  final docsDir = Directory('../docs');
  final buildOutputDir = Directory('build/web');

  stdout.writeln('Running flutter pub get...');
  final pubGet = await _run('flutter', ['pub', 'get']);
  if (pubGet.exitCode != 0) {
    exitCode = pubGet.exitCode;
    return;
  }

  if (buildOutputDir.existsSync()) {
    stdout.writeln('Cleaning previous build/web directory...');
    buildOutputDir.deleteSync(recursive: true);
  }

  stdout.writeln(
    'Building flutter web (renderer: html, base href: /ecoplaycaicara/)...',
  );
  final baseArgs = <String>[
    'build',
    'web',
    '--release',
    '--base-href',
    '/ecoplaycaicara/',
  ];

  var buildResult = await _run(
    'flutter',
    [...baseArgs, '--web-renderer', 'html'],
    captureOutput: true,
  );

  if (buildResult.exitCode != 0) {
    final combined = '${buildResult.stdout ?? ''}\n${buildResult.stderr ?? ''}';
    if (combined.contains('--web-renderer')) {
      stdout.writeln(
        'Falling back to legacy flags (FLUTTER_WEB_USE_SKIA=false).',
      );
      buildResult = await _run(
        'flutter',
        baseArgs,
        environment: {
          'FLUTTER_WEB_RENDERER': 'html',
          'FLUTTER_WEB_USE_SKIA': 'false',
        },
        captureOutput: true,
      );
    }

    if (buildResult.exitCode != 0) {
      exitCode = buildResult.exitCode;
      return;
    }
  }

  if (!buildOutputDir.existsSync()) {
    stderr.writeln('Expected build/web but it was not created.');
    exitCode = 1;
    return;
  }

  stdout.writeln('Copying build/web to ../docs ...');
  if (docsDir.existsSync()) {
    docsDir.deleteSync(recursive: true);
  }
  _copyDirectory(buildOutputDir, docsDir);

  final bootstrapPath =
      File('${docsDir.path}${Platform.pathSeparator}flutter_bootstrap.js');
  if (bootstrapPath.existsSync()) {
    final bootstrap = bootstrapPath.readAsStringSync();
    const canvaskitConfig =
        '{"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"}';
    if (bootstrap.contains(canvaskitConfig)) {
      stdout.writeln('Tweaking flutter_bootstrap.js to pin renderer=html.');
      final patched = bootstrap.replaceFirst(
        canvaskitConfig,
        '{"compileTarget":"dart2js","renderer":"html","mainJsPath":"main.dart.js"}',
      );
      bootstrapPath.writeAsStringSync(patched);
    }
  }

  final noJekyll = File('${docsDir.path}${Platform.pathSeparator}.nojekyll');
  if (!noJekyll.existsSync()) {
    noJekyll.createSync(recursive: true);
  }

  stdout.writeln('Web bundle ready in ${docsDir.absolute.path}');
  stdout.writeln('Commit the docs/ folder and push to GitHub to update Pages.');
}

void _copyDirectory(Directory source, Directory target) {
  for (final entity in source.listSync(recursive: true)) {
    final relativeUri = entity.uri.path.substring(source.uri.path.length);
    if (relativeUri.isEmpty) {
      continue;
    }
    final newUri = target.uri.resolve(relativeUri);
    if (entity is Directory) {
      Directory.fromUri(newUri).createSync(recursive: true);
    } else if (entity is File) {
      final file = File.fromUri(newUri);
      file.parent.createSync(recursive: true);
      entity.copySync(file.path);
    }
  }
}

class _RunResult {
  const _RunResult(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String? stdout;
  final String? stderr;
}

Future<_RunResult> _run(
  String executable,
  List<String> args, {
  Map<String, String>? environment,
  bool captureOutput = false,
}) async {
  final process = await Process.start(
    executable,
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

  return _RunResult(
    code,
    stdoutBuffer?.toString(),
    stderrBuffer?.toString(),
  );
}
