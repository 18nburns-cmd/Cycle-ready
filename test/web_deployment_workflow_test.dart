import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web deployment generates Drift sources before compiling', () {
    final workflow =
        File('.github/workflows/deploy_web.yml').readAsStringSync();
    const generation =
        'dart run build_runner build --delete-conflicting-outputs';
    const compilation = 'flutter build web --release';

    expect(workflow, contains(generation));
    expect(workflow, contains(compilation));
    expect(
      workflow.indexOf(generation),
      lessThan(workflow.indexOf(compilation)),
    );
  });
}
