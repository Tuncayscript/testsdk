// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

void main() {
  /*1:main*/ test();
}

void /*2:test*/ test() async {
  /*3*/ throw '>ExceptionMarker<';
}
