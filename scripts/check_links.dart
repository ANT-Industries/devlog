import 'dart:io';
import 'package:html/parser.dart' show parse;

void main() async {
  final buildDir = Directory('build');
  if (!buildDir.existsSync()) {
    print('Error: build/ directory does not exist. Run build_site.dart first.');
    exit(1);
  }

  print('Checking links in ${buildDir.path}...');
  var brokenCount = 0;
  var checkedCount = 0;

  final files = buildDir.listSync(recursive: true).whereType<File>();

  for (final file in files) {
    if (file.path.endsWith('.html')) {
      final content = file.readAsStringSync();
      final document = parse(content);

      // Check individual links
      final links = document.querySelectorAll('a, link, script, img');
      for (final element in links) {
        final attr = element.localName == 'a' || element.localName == 'link'
            ? 'href'
            : 'src';
        var target = element.attributes[attr];

        if (target == null ||
            target.isEmpty ||
            target.startsWith('http') ||
            target.startsWith('#') ||
            target.startsWith('mailto:')) {
          continue;
        }

        checkedCount++;

        // Handle base href if present
        final baseAttr = document.querySelector('base')?.attributes['href'];

        var isBroken = false;
        File targetFile;

        if (target.startsWith('/')) {
          // Root relative - this is tricky because we don't know the server root
          // But for local build/ we assume it's relative to build/
          var cleanPath = target;
          if (cleanPath.startsWith('/devlog/')) {
            cleanPath = cleanPath.replaceFirst('/devlog/', '/');
          }
          targetFile = File('build${cleanPath}');
        } else if (baseAttr != null) {
          // Relative to base href
          var resolvedPath = baseAttr;
          if (!resolvedPath.endsWith('/')) resolvedPath += '/';
          resolvedPath += target;

          // Normalize for local checking
          if (resolvedPath.startsWith('/devlog/')) {
            resolvedPath = resolvedPath.replaceFirst('/devlog/', '/');
          }
          if (resolvedPath.startsWith('/')) {
            targetFile = File('build${resolvedPath}');
          } else {
            // If base is also relative (unlikely for us but possible)
            targetFile = File('${file.parent.path}/${resolvedPath}');
          }
        } else {
          // Relative to current file
          targetFile = File('${file.parent.path}/${target}');
        }

        // Check if file or directory/index.html exists
        if (!targetFile.existsSync()) {
          final indexFile = File('${targetFile.path}/index.html');
          if (!indexFile.existsSync()) {
            isBroken = true;
          }
        }

        if (isBroken) {
          print('Broken link in ${file.path}: $target');
          brokenCount++;
        }
      }
    }
  }

  print('\nCheck complete.');
  print('Checked $checkedCount links.');
  if (brokenCount > 0) {
    print('Found $brokenCount broken links.');
    exit(1);
  } else {
    print('All internal links are valid!');
  }
}
