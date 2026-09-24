/// Cross-platform setup tool for PlayTorrio Nuvio Addon.
///
/// Run once before first start:
///   dart run tool/setup.dart
///
/// What it does:
///   1. Creates lib/upstream → upstream/PlayTorrioV3/lib
///      (junction on Windows, symlink on Linux/macOS/Android)
///   2. Runs `dart pub get` if packages aren't resolved yet
import 'dart:io';

Future<void> main() async {
  // Lock CWD to project root (script lives in tool/)
  final script = File(Platform.script.toFilePath());
  Directory.current = script.parent.parent;

  print('');
  print('============================================================');
  print(' ⚙️  PlayTorrio Nuvio Addon — Setup');
  print('============================================================');
  print(' Platform: ${Platform.operatingSystem} / ${_arch()}');
  print('');

  final ok1 = await _createUpstreamLink();
  final ok2 = await _runPubGet();

  print('');
  if (ok1 && ok2) {
    print(' ✅ Setup complete!');
  } else {
    print(' ⚠️  Setup finished with warnings — see above.');
  }
  print('============================================================');
  print('');
}

// ── Upstream link ────────────────────────────────────────────────────────────

Future<bool> _createUpstreamLink() async {
  final linkPath = 'lib${Platform.pathSeparator}upstream';
  final link = Link(linkPath);
  final dir = Directory(linkPath);

  if (await link.exists()) {
    print(' [1/2] lib/upstream link already exists ✓');
    return true;
  }
  if (await dir.exists()) {
    print(' [1/2] lib/upstream directory already exists ✓');
    return true;
  }

  final target = Directory('upstream/PlayTorrioV3/lib');
  if (!await target.exists()) {
    print(' [1/2] ERROR: upstream/PlayTorrioV3/lib not found.');
    print('       Run git clone first or check the upstream/ directory.');
    return false;
  }

  print(' [1/2] Creating lib/upstream link → upstream/PlayTorrioV3/lib ...');

  if (Platform.isWindows) {
    return await _createWindowsJunction(linkPath);
  } else {
    return await _createUnixSymlink(linkPath);
  }
}

Future<bool> _createWindowsJunction(String linkPath) async {
  // mklink /J creates a directory junction — no admin rights required on Windows.
  final target = '..\\upstream\\PlayTorrioV3\\lib';
  final winLink = linkPath.replaceAll('/', '\\');
  final res = await Process.run('cmd', ['/c', 'mklink', '/J', winLink, target]);
  if (res.exitCode == 0) {
    print('       Junction created ✓');
    return true;
  }
  print('       ERROR creating junction: ${res.stderr}');
  print('       Run this manually in the project root:');
  print('         mklink /J lib\\upstream ..\\upstream\\PlayTorrioV3\\lib');
  return false;
}

Future<bool> _createUnixSymlink(String linkPath) async {
  // Symlink target is relative to the lib/ directory (where the link lives).
  const relTarget = '../upstream/PlayTorrioV3/lib';
  try {
    final link = Link(linkPath);
    await link.create(relTarget);
    print('       Symlink created ✓');
    return true;
  } catch (e) {
    // Fallback: ln -s
    final res = await Process.run('ln', ['-s', relTarget, linkPath]);
    if (res.exitCode == 0) {
      print('       Symlink created via ln -s ✓');
      return true;
    }
    print('       ERROR: $e');
    print('       Run this manually in the project root:');
    print('         ln -s ../upstream/PlayTorrioV3/lib lib/upstream');
    return false;
  }
}

// ── dart pub get ─────────────────────────────────────────────────────────────

Future<bool> _runPubGet() async {
  final configFile = File('.dart_tool/package_config.json');
  if (await configFile.exists()) {
    print(' [2/2] Dependencies already resolved ✓');
    return true;
  }

  print(' [2/2] Running dart pub get ...');
  final dartBin = Platform.isWindows ? 'dart.exe' : 'dart';
  final res = await Process.run(dartBin, ['pub', 'get']);
  if (res.exitCode == 0) {
    print('       Dependencies resolved ✓');
    return true;
  }
  print('       ERROR: ${res.stderr}');
  return false;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _arch() {
  // Platform.version contains CPU arch info in Dart 3
  try {
    final v = Platform.version;
    if (v.contains('arm64') || v.contains('aarch64')) return 'arm64';
    if (v.contains('arm')) return 'arm';
    if (v.contains('x64') || v.contains('x86_64')) return 'x64';
  } catch (_) {}
  return 'unknown';
}
