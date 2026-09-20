import 'dart:io';

/// Finds Dart files under `lib/` that nothing reaches.
///
/// ## Why not grep
///
/// The obvious version of this check — grep for `/<basename>'` — gets several
/// things wrong, and each one flags a live file as dead:
///
/// * **Same-directory relative imports.** `import 'home_repository_interface.dart';`
///   has no leading slash, so the grep never matches it.
/// * **`part` / `export` directives.** `cache_response.g.dart` is reached by a
///   `part` directive, not an import.
/// * **Same-named files in different folders.** Two `banner.dart` files make
///   each other look reachable.
/// * **Dead cycles.** Two orphaned files that import each other both look
///   referenced, so neither is reported.
///
/// This resolves every directive to an absolute path and walks the graph from
/// the real entrypoints instead, so reachability is transitive: a file that is
/// only imported by dead code is itself reported as dead.
///
/// Usage:
///   dart run tool/find_unused_files.dart          # report, exit 1 if any
///   dart run tool/find_unused_files.dart --list   # bare paths, for scripting
void main(List<String> args) {
  final bool listOnly = args.contains('--list');

  final Directory libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('run this from the project root (no lib/ here)');
    exit(2);
  }

  final Set<String> allFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => _normalize(f.path))
      .toSet();

  // Entrypoints: main.dart, plus anything reachable from the test tree, since
  // a file used only by tests is not dead code.
  final Set<String> roots = <String>{};
  final String mainPath = _normalize('lib/main.dart');
  if (allFiles.contains(mainPath)) roots.add(mainPath);

  final Directory testDir = Directory('test');
  final List<File> testFiles = testDir.existsSync()
      ? testDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
      : <File>[];

  // Walk from main.dart and from every test file.
  final Set<String> reached = <String>{};
  final List<String> queue = <String>[...roots];

  for (final File t in testFiles) {
    for (final String dep in _directiveTargets(t)) {
      if (allFiles.contains(dep) && reached.add(dep)) queue.add(dep);
    }
  }
  reached.addAll(roots);

  while (queue.isNotEmpty) {
    final String current = queue.removeLast();
    final File f = File(current);
    if (!f.existsSync()) continue;
    for (final String dep in _directiveTargets(f)) {
      if (allFiles.contains(dep) && reached.add(dep)) {
        queue.add(dep);
      }
    }
  }

  final List<String> unused = allFiles.difference(reached).toList()..sort();

  if (listOnly) {
    for (final String u in unused) {
      stdout.writeln(_relative(u));
    }
    exit(0);
  }

  if (unused.isEmpty) {
    stdout.writeln('No unreachable files under lib/.');
    exit(0);
  }

  stdout.writeln('${unused.length} unreachable file(s) under lib/:');
  stdout.writeln('');
  int loc = 0;
  for (final String u in unused) {
    final int n = File(u).readAsLinesSync().length;
    loc += n;
    stdout.writeln('  ${_relative(u)}  ($n lines)');
  }
  stdout.writeln('');
  stdout.writeln('$loc lines total.');
  stdout.writeln(
    'Delete them, or wire them up. A file nothing reaches is a file that '
    'makes the next reader guess which widget is live.',
  );
  exit(1);
}

/// Every import/export/part target in [file], resolved to an absolute path.
Iterable<String> _directiveTargets(File file) sync* {
  final String dir = file.parent.path;
  late final List<String> lines;
  try {
    lines = file.readAsLinesSync();
  } catch (_) {
    return;
  }

  for (final String raw in lines) {
    final String line = raw.trimLeft();
    if (!line.startsWith('import ') &&
        !line.startsWith('export ') &&
        !line.startsWith('part ')) {
      continue;
    }
    // `part of` points at a parent, not a dependency.
    if (line.startsWith('part of')) continue;

    final Match? m = RegExp("""['"]([^'"]+)['"]""").firstMatch(line);
    if (m == null) continue;
    final String target = m.group(1)!;

    if (target.startsWith('dart:')) continue;

    if (target.startsWith('package:waddy_app/')) {
      yield _normalize('lib/${target.substring('package:waddy_app/'.length)}');
    } else if (!target.startsWith('package:')) {
      // Relative — resolve against the importing file's directory. This is the
      // case the grep version missed entirely.
      yield _normalize('$dir/$target');
    }
  }
}

String _normalize(String path) =>
    File(path).absolute.uri.normalizePath().toFilePath();

String _relative(String abs) {
  final String root = Directory.current.absolute.path;
  return abs.startsWith(root)
      ? abs.substring(root.length).replaceFirst(RegExp(r'^[/\\]'), '')
      : abs;
}
