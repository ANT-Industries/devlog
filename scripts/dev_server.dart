import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:watcher/watcher.dart';

void main(List<String> args) async {
  final watch = args.contains('--watch');
  final port = 8080;

  // 1. Initial build
  await _build();

  // 2. Setup watcher if requested
  if (watch) {
    print('Watching for changes in content/ and scripts/...');
    _setupWatcher('content');
    _setupWatcher('scripts');
  }

  // 3. Start server
  final staticHandler =
      createStaticHandler('build', defaultDocument: 'index.html');

  // Handle both the root and the /devlog/ base path for easier local testing
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler((Request request) {
    if (request.url.path.startsWith('devlog/')) {
      return staticHandler(request.change(path: 'devlog'));
    }
    return staticHandler(request);
  });

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Dev server running at http://${server.address.host}:${server.port}');
}

Future<void> _build() async {
  print('Building site...');
  final result = await Process.run('dart', ['scripts/build_site.dart']);
  if (result.exitCode == 0) {
    print('Build successful');
  } else {
    print('Build failed:');
    print(result.stdout);
    print(result.stderr);
  }
}

void _setupWatcher(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) return;

  final watcher = DirectoryWatcher(path);
  Timer? debounce;

  watcher.events.listen((event) {
    // Avoid multiple builds for rapid changes
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 500), () async {
      print('Change detected in ${event.path}. Rebuilding...');
      await _build();
    });
  });
}
