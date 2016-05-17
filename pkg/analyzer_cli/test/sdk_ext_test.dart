// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Test that sdk extensions are properly detected in various scenarios.
library analyzer_cli.test.sdk_ext;

import 'dart:io';

import 'package:analyzer/src/generated/sdk_io.dart';
import 'package:analyzer_cli/src/driver.dart' show Driver, errorSink, outSink;
import 'package:path/path.dart' as path;
import 'package:unittest/unittest.dart';

import 'utils.dart';

main() {
  group('Sdk extensions', () {
    StringSink savedOutSink, savedErrorSink;
    int savedExitCode;

    setUp(() {
      savedOutSink = outSink;
      savedErrorSink = errorSink;
      savedExitCode = exitCode;
      outSink = new StringBuffer();
      errorSink = new StringBuffer();
    });
    tearDown(() {
      outSink = savedOutSink;
      errorSink = savedErrorSink;
      exitCode = savedExitCode;
    });

    test('.packages file present', () async {
      String testDir = path.join(testDirectory, 'data', 'packages_file');
      Driver driver = new Driver()..start([
        '--packages',
        path.join(testDir, '.packages'),
        path.join(testDir, 'sdk_ext_user.dart')
      ]);

      DirectoryBasedDartSdk sdk = driver.sdk;
      expect(sdk.useSummary, isFalse);

      expect(exitCode, 0);
    });
  });
}
