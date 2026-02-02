import 'dart:io';
import 'package:markdown/markdown.dart' as md;
import 'package:yaml/yaml.dart';
import 'package:mustache_template/mustache.dart';

void main(List<String> args) async {
  var siteRoot = args.isNotEmpty ? args[0] : '/';
  if (!siteRoot.endsWith('/')) siteRoot = '$siteRoot/';
  if (!siteRoot.startsWith('/')) siteRoot = '/$siteRoot';

  final baseHref = siteRoot;
  final buildDir = Directory('build');

  if (buildDir.existsSync()) buildDir.deleteSync(recursive: true);
  buildDir.createSync();

  // Load templates
  final listTemplate =
      Template(File('scripts/templates/list.mustache').readAsStringSync());
  final detailTemplate =
      Template(File('scripts/templates/detail.mustache').readAsStringSync());

  // Copy style.css
  final cssFile = File('scripts/style.css');
  if (cssFile.existsSync()) cssFile.copySync('build/style.css');

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
          final htmlContent = processMarkdown(markdown);
          final slug = file.uri.pathSegments.last.replaceAll('.md', '');

          logs.add({
            'title': yaml['title'] ?? 'Untitled',
            'date': yaml['date'] ?? '',
            'summary': processMarkdown(yaml['summary'] ?? ''),
            'slug': slug,
            'html': htmlContent,
          });
        }
      }
    }
  }
  logs.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));

  final recentLogs = logs.take(10).toList();

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
          final htmlContent = processMarkdown(markdown);
          final slug = file.uri.pathSegments.last.replaceAll('.md', '');

          final item = {
            'name': yaml['name'] ?? 'Unknown',
            'category': yaml['category'] ?? '',
            'status': yaml['status'] ?? '',
            'price': yaml['price'] ?? 0,
            'slug': slug,
            'html': htmlContent,
          };

          hardwareItems.add(item);
          if (slug == 'h15-beast') {
            mainHardware = item;
          }
        }
      }
    }
  }

  // 3. Generate HTML Files

  // Index (Log List)
  var logListHtml = '<h1>Daily Logs</h1>';
  for (final log in logs) {
    logListHtml += '''
      <div class="log-item">
        <h2><a href="logs/${log['slug']}/">${log['title']}</a></h2>
        <div class="meta">${log['date']}</div>
        <p>${log['summary']}</p>
      </div>
    ''';
  }
  File('build/index.html').writeAsStringSync(listTemplate.renderString({
    'base_href': baseHref,
    'title': 'Logs',
    'content': logListHtml,
    'recent_logs': recentLogs,
  }));

  // Individual Log Pages with Pagination
  for (var i = 0; i < logs.length; i++) {
    final log = logs[i];
    final prev = i < logs.length - 1 ? logs[i + 1] : null;
    final next = i > 0 ? logs[i - 1] : null;

    final logPage = detailTemplate.renderString({
      'base_href': baseHref,
      'title': log['title'],
      'content':
          '<h1>${log['title']}</h1><div class="meta">${log['date']}</div>${log['html']}',
      'recent_logs': recentLogs,
      'prev': prev,
      'next': next,
    });

    final logOutputFile = File('build/logs/${log['slug']}/index.html');
    logOutputFile.parent.createSync(recursive: true);
    logOutputFile.writeAsStringSync(logPage);
  }

  // Hardware List
  var hardwareListHtml = '<h1>Hardware Inventory</h1>';
  if (mainHardware != null) hardwareListHtml += mainHardware['html'];
  hardwareListHtml +=
      '<h2>Components</h2><table><tr><th>Component</th><th>Category</th><th>Status</th></tr>';
  for (final item in hardwareItems) {
    hardwareListHtml +=
        '<tr><td><a href="hardware/${item['slug']}/">${item['name']}</a></td><td>${item['category']}</td><td>${item['status']}</td></tr>';

    final hwPage = detailTemplate.renderString({
      'base_href': baseHref,
      'title': item['name'],
      'content': '<h1>${item['name']}</h1>${item['html']}',
      'recent_logs': recentLogs,
      'prev': null,
      'next': null,
    });

    final hwOutputFile = File('build/hardware/${item['slug']}/index.html');
    hwOutputFile.parent.createSync(recursive: true);
    hwOutputFile.writeAsStringSync(hwPage);
  }
  hardwareListHtml += '</table>';
  File('build/hardware.html').writeAsStringSync(listTemplate.renderString({
    'base_href': baseHref,
    'title': 'Hardware',
    'content': hardwareListHtml,
    'recent_logs': recentLogs,
  }));

  // 4. Generate RSS Feed
  final rssTemplate =
      Template(File('scripts/templates/rss.mustache').readAsStringSync());

  final rssLogs = logs.map((log) {
    return {
      ...log,
      'plain_summary': log['summary'].replaceAll(RegExp(r'<[^>]*>'), ''),
    };
  }).toList();

  final rssXml = rssTemplate.renderString({
    'base_href': baseHref,
    'logs': rssLogs,
    'username': 'ANT-Industries',
  });

  File('build/rss.xml').writeAsStringSync(rssXml);

  print('Site built to build/ with baseHref: $baseHref');
}

String processMarkdown(String markdown) {
  var html =
      md.markdownToHtml(markdown, extensionSet: md.ExtensionSet.gitHubFlavored);
  html = html.replaceAllMapped(RegExp(r'\[\[([^\]|]+)\|([^\]]+)\]\]'), (match) {
    final slug = match.group(1)!.trim();
    final text = match.group(2)!.trim();
    return '<a href="${getLinkForSlug(slug)}">$text</a>';
  });
  html = html.replaceAllMapped(RegExp(r'\[\[([^\]|]+)\]\]'), (match) {
    final slug = match.group(1)!.trim();
    return '<a href="${getLinkForSlug(slug)}">$slug</a>';
  });
  return html;
}

String getLinkForSlug(String slug) {
  if (File('content/log/$slug.md').existsSync()) return 'logs/$slug/';
  if (File('content/hardware/$slug.md').existsSync()) return 'hardware/$slug/';
  return '#';
}
