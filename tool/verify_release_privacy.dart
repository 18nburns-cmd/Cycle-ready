import 'dart:convert';
import 'dart:io';

const _sensitiveFileExtensions = {
  '.db',
  '.sqlite',
  '.sqlite3',
  '.fit',
  '.gpx',
  '.tcx',
  '.log',
  '.jks',
  '.keystore',
};

final _forbiddenSignatures = <String>[
  ['-----begin ', 'private key-----'].join(),
  ['"private_', 'key"'].join(),
  ['supabase_', 'service_role_key='].join(),
  ['intervals_', 'client_secret='].join(),
  ['intervals_', 'webhook_secret='].join(),
  ['firebase_', 'service_account_json='].join(),
  ['"type":"service_', 'account"'].join(),
  ['"type": "service_', 'account"'].join(),
];

class ReleasePrivacyFinding {
  const ReleasePrivacyFinding(this.path, this.reason);

  final String path;
  final String reason;

  @override
  String toString() => '$path: $reason';
}

Future<List<ReleasePrivacyFinding>> scanReleasePrivacy(
  Iterable<FileSystemEntity> roots, {
  Iterable<String> deniedValues = const [],
}) async {
  final values = deniedValues
      .map((value) => value.trim())
      .where((value) => value.length >= 8)
      .toSet();
  final files = <File>[];
  for (final root in roots) {
    if (root is File && await root.exists()) {
      files.add(root);
    } else if (root is Directory && await root.exists()) {
      files.addAll(await root
          .list(recursive: true, followLinks: false)
          .where((entry) => entry is File)
          .cast<File>()
          .toList());
    }
  }

  final findings = <ReleasePrivacyFinding>[];
  for (final file in files) {
    final normalizedPath = file.path.replaceAll('\\', '/');
    final lowerPath = normalizedPath.toLowerCase();
    final sensitiveExtension =
        _sensitiveFileExtensions.where(lowerPath.endsWith).firstOrNull;
    if (sensitiveExtension != null) {
      findings.add(ReleasePrivacyFinding(
        normalizedPath,
        'private-data file type $sensitiveExtension is not release-safe',
      ));
      continue;
    }

    final bytes = await file.readAsBytes();
    final content = latin1.decode(bytes, allowInvalid: true).toLowerCase();
    for (final signature in _forbiddenSignatures) {
      if (content.contains(signature)) {
        findings.add(ReleasePrivacyFinding(
          normalizedPath,
          'contains forbidden secret signature',
        ));
        break;
      }
    }
    for (final value in values) {
      if (_containsBytes(bytes, utf8.encode(value))) {
        findings.add(ReleasePrivacyFinding(
          normalizedPath,
          'contains a configured private value',
        ));
        break;
      }
    }
  }
  return findings;
}

bool _containsBytes(List<int> source, List<int> pattern) {
  if (pattern.isEmpty || pattern.length > source.length) return false;
  for (var start = 0; start <= source.length - pattern.length; start++) {
    var matches = true;
    for (var offset = 0; offset < pattern.length; offset++) {
      if (source[start + offset] != pattern[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/verify_release_privacy.dart <artifact-path> [...]',
    );
    exitCode = 64;
    return;
  }
  final privateValues = <String>{
    ..._environmentValues(const [
      'SUPABASE_SERVICE_ROLE_KEY',
      'INTERVALS_CLIENT_SECRET',
      'INTERVALS_WEBHOOK_SECRET',
      'CYCLEREADY_ANDROID_STORE_PASSWORD',
      'CYCLEREADY_ANDROID_KEY_PASSWORD',
    ]),
    ..._splitPrivateValues(
      Platform.environment['CYCLEREADY_PRIVATE_SCAN_VALUES'],
    ),
  };
  final roots = arguments.map<FileSystemEntity>((path) {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    return type == FileSystemEntityType.directory
        ? Directory(path)
        : File(path);
  });
  final findings = await scanReleasePrivacy(
    roots,
    deniedValues: privateValues,
  );
  if (findings.isEmpty) {
    stdout.writeln('Release privacy scan passed (${arguments.join(', ')}).');
    return;
  }
  stderr.writeln('Release privacy scan failed:');
  for (final finding in findings) {
    stderr.writeln('- $finding');
  }
  exitCode = 1;
}

Iterable<String> _environmentValues(Iterable<String> names) sync* {
  for (final name in names) {
    final value = Platform.environment[name];
    if (value != null && value.trim().isNotEmpty) yield value;
  }
}

Iterable<String> _splitPrivateValues(String? value) =>
    value == null ? const [] : const LineSplitter().convert(value);
