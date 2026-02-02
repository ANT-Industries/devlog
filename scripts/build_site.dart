import 'dart:io';
import 'package:markdown/markdown.dart' as md;
import 'package:yaml/yaml.dart';

void main(List<String> args) async {
  // Get siteRoot from CLI args (e.g., dart scripts/build_site.dart /devlog/)
  // Default to '/' if not provided
  var siteRoot = args.isNotEmpty ? args[0] : '/';
  if (!siteRoot.endsWith('/')) {
    siteRoot = '$siteRoot/';
  }
  if (!siteRoot.startsWith('/')) {
    siteRoot = '/$siteRoot';
  }

  // Handle local development vs production GH pages
  // Note: <base href> is usually best as an absolute path from root
  final baseHref = siteRoot;

  final buildDir = Directory('build');

  if (buildDir.existsSync()) {
    buildDir.deleteSync(recursive: true);
  }
  buildDir.createSync();

  final template = File('scripts/template.html').readAsStringSync();

  // Copy style.css to build
  final cssFile = File('scripts/style.css');
  if (cssFile.existsSync()) {
    cssFile.copySync('build/style.css');
  }

  // 1. Process Logs
  final logDir = Directory('content/log');
  final logs = <Map<String, dynamic>>[];
  if (logDir.existsSync()) {
    for (final file in logDir.listSync().whereType<File>()) {
      if (file.path.endsWith('.md')) {
        final content = file.readAsStringSync();
        final parts = content.split('---');
        if (parts.length >= 3) {
          final yaml = loadYaml(parts[1]) as YamlMap;
          final markdown = parts.sublist(2).join('---');
          final htmlContent = processMarkdown(markdown, siteRoot);

          final slug = file.uri.pathSegments.last.replaceAll('.md', '');
          logs.add({
            'title': yaml['title'] ?? 'Untitled',
            'date': yaml['date'] ?? '',
            'summary': processMarkdown(yaml['summary'] ?? '', siteRoot),
            'slug': slug,
            'html': htmlContent,
          });
        }
      }
    }
  }
  logs.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));

  // 2. Process Hardware
  final hardwareDir = Directory('content/hardware');
  final hardwareItems = <Map<String, dynamic>>[];
  Map<String, dynamic>? mainHardware;

  if (hardwareDir.existsSync()) {
    for (final file in hardwareDir.listSync().whereType<File>()) {
      if (file.path.endsWith('.md')) {
        final content = file.readAsStringSync();
        final parts = content.split('---');
        if (parts.length >= 3) {
          final yaml = loadYaml(parts[1]) as YamlMap;
          final markdown = parts.sublist(2).join('---');
          final htmlContent = processMarkdown(markdown, siteRoot);
          final slug = file.uri.pathSegments.last.replaceAll('.md', '');

          final item = {
            'name': yaml['name'] ?? 'Unknown',
            'category': yaml['category'] ?? '',
            'status': yaml['status'] ?? '',
            'price': yaml['price'] ?? 0,
            'slug': slug,
            'html': htmlContent,
          };

          if (slug == 'h15-beast') {
            mainHardware = item;
          } else {
            hardwareItems.add(item);
          }
        }
      }
    }
  }

  // 3. Generate HTML Files

  // Index - Logs List
  var logListHtml = '<h1>Daily Logs</h1>';
  for (final log in logs) {
    logListHtml += '''
      <div style="margin-bottom: 2rem; border-bottom: 1px solid #30363d; padding-bottom: 1rem;">
        <h2 style="margin-top: 0;"><a href="logs/${log['slug']}/">${log['title']}</a></h2>
        <div class="meta">${log['date']}</div>
        <p>${log['summary']}</p>
      </div>
    ''';

    // Individual Log Pages - Pretty URL (slug/index.html)
    final logPage = template
        .replaceFirst('{{base_href}}', baseHref)
        .replaceFirst('{{title}}', log['title'])
        .replaceFirst('{{content}}',
            '<h1>${log['title']}</h1><div class="meta">${log['date']}</div>${log['html']}');

    final logOutputFile = File('build/logs/${log['slug']}/index.html');
    logOutputFile.parent.createSync(recursive: true);
    logOutputFile.writeAsStringSync(logPage);
  }
  File('build/index.html').writeAsStringSync(template
      .replaceFirst('{{base_href}}', baseHref)
      .replaceFirst('{{title}}', 'Logs')
      .replaceFirst('{{content}}', logListHtml));

  // Hardware List
  var hardwareListHtml = '<h1>Hardware Inventory</h1>';
  if (mainHardware != null) {
    hardwareListHtml += mainHardware['html'];
  }
  hardwareListHtml +=
      '<h2>Components</h2><table><tr><th>Component</th><th>Category</th><th>Status</th></tr>';
  for (final item in hardwareItems) {
    hardwareListHtml +=
        '<tr><td><a href="hardware/${item['slug']}/">${item['name']}</a></td><td>${item['category']}</td><td>${item['status']}</td></tr>';

    // Individual Hardware Pages - Pretty URL (slug/index.html)
    final hwPage = template
        .replaceFirst('{{base_href}}', baseHref)
        .replaceFirst('{{title}}', item['name'])
        .replaceFirst('{{content}}', '<h1>${item['name']}</h1>${item['html']}');

    final hwOutputFile = File('build/hardware/${item['slug']}/index.html');
    hwOutputFile.parent.createSync(recursive: true);
    hwOutputFile.writeAsStringSync(hwPage);
  }
  hardwareListHtml += '</table>';
  File('build/hardware.html').writeAsStringSync(template
      .replaceFirst('{{base_href}}', baseHref)
      .replaceFirst('{{title}}', 'Hardware')
      .replaceFirst('{{content}}', hardwareListHtml));

  // 4. Generate RSS Feed
  var rssHtml = '''<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
  <title>DevLog</title>
  <link>https://rodydavis.github.io/devlog${baseHref}</link>
  <description>Daily logs and hardware inventory for the H15 Beast</description>
''';
  for (final log in logs) {
    rssHtml += '''
  <item>
    <title>${log['title']}</title>
    <link>https://rodydavis.github.io/devlog${baseHref}logs/${log['slug']}/</link>
    <description>${log['summary'].replaceAll(RegExp(r'<[^>]*>'), '')}</description>
    <pubDate>${log['date']}</pubDate>
  </item>
''';
  }
  rssHtml += '</channel></rss>';
  File('build/rss.xml').writeAsStringSync(rssHtml);

  print('Site built to build/ with baseHref: $baseHref');
}

String processMarkdown(String markdown, String siteRoot) {
  // Convert Wiki Links [[slug|text]] or [[slug]]
  var html =
      md.markdownToHtml(markdown, extensionSet: md.ExtensionSet.gitHubFlavored);

  // Regex to find [[slug|text]]
  html = html.replaceAllMapped(RegExp(r'\[\[([^\]|]+)\|([^\]]+)\]\]'), (match) {
    final slug = match.group(1)!.trim();
    final text = match.group(2)!.trim();
    return '<a href="${getLinkForSlug(slug)}">$text</a>';
  });

  // Regex to find [[slug]]
  html = html.replaceAllMapped(RegExp(r'\[\[([^\]|]+)\]\]'), (match) {
    final slug = match.group(1)!.trim();
    return '<a href="${getLinkForSlug(slug)}">$slug</a>';
  });

  return html;
}

String getLinkForSlug(String slug) {
  // Check if it's a log or hardware item
  if (File('content/log/$slug.md').existsSync()) return 'logs/$slug/';
  if (File('content/hardware/$slug.md').existsSync()) return 'hardware/$slug/';
  return '#';
}
