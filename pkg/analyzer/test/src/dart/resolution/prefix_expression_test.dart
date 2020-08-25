// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/dart/error/syntactic_errors.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'context_collection_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PrefixExpressionResolutionTest);
    defineReflectiveTests(PrefixExpressionResolutionWithNullSafetyTest);
  });
}

@reflectiveTest
class PrefixExpressionResolutionTest extends PubPackageResolutionTest {
  test_bang_bool_context() async {
    await assertNoErrorsInCode(r'''
T f<T>() {
  throw 42;
}

main() {
  !f();
}
''');

    assertMethodInvocation2(
      findNode.methodInvocation('f();'),
      element: findElement.topFunction('f'),
      typeArgumentTypes: ['bool'],
      invokeType: 'bool Function()',
      type: 'bool',
    );

    assertPrefixExpression(
      findNode.prefix('!f()'),
      element: boolElement.getMethod('!'),
      type: 'bool',
    );
  }

  test_bang_bool_localVariable() async {
    await assertNoErrorsInCode(r'''
f(bool x) {
  !x;
}
''');

    assertPrefixExpression(
      findNode.prefix('!x'),
      element: boolElement.getMethod('!'),
      type: 'bool',
    );
  }

  test_bang_int_localVariable() async {
    await assertErrorsInCode(r'''
f(int x) {
  !x;
}
''', [
      error(CompileTimeErrorCode.NON_BOOL_NEGATION_EXPRESSION, 14, 1),
    ]);

    assertPrefixExpression(
      findNode.prefix('!x'),
      element: null,
      type: 'bool',
    );
  }

  test_minus_int_localVariable() async {
    await assertNoErrorsInCode(r'''
f(int x) {
  -x;
}
''');

    assertPrefixExpression(
      findNode.prefix('-x'),
      element: elementMatcher(
        intElement.getMethod('unary-'),
        isLegacy: isNullSafetySdkAndLegacyLibrary,
      ),
      type: 'int',
    );
  }

  test_plusPlus_double() async {
    await assertNoErrorsInCode(r'''
f(double x) {
  ++x;
}
''');

    assertPrefixExpression(
      findNode.prefix('++x'),
      element: elementMatcher(
        doubleElement.getMethod('+'),
        isLegacy: isNullSafetySdkAndLegacyLibrary,
      ),
      type: 'double',
    );
  }

  test_plusPlus_extensionOverride() async {
    await assertErrorsInCode(r'''
class C {}

extension Ext on C {
  int operator +(int _) {
    return 0;
  }
}

f(C c) {
  ++Ext(c);
}
''', [
      error(ParserErrorCode.MISSING_ASSIGNABLE_SELECTOR, 98, 1),
    ]);

    assertPrefixExpression(
      findNode.prefix('++Ext'),
      element: findElement.method('+'),
      type: 'int',
    );
  }

  test_plusPlus_int_localVariable() async {
    await assertNoErrorsInCode(r'''
f(int x) {
  ++x;
}
''');

    assertPrefixExpression(
      findNode.prefix('++x'),
      element: elementMatcher(
        numElement.getMethod('+'),
        isLegacy: isNullSafetySdkAndLegacyLibrary,
      ),
      type: 'int',
    );
  }

  /// Verify that we get all necessary types when building the dependencies
  /// graph during top-level inference.
  test_plusPlus_int_topLevelInference() async {
    await assertNoErrorsInCode(r'''
var x = 0;

class M1 {
  final y = ++x;
}
''');

    assertPrefixExpression(
      findNode.prefix('++x'),
      element: elementMatcher(
        numElement.getMethod('+'),
        isLegacy: isNullSafetySdkAndLegacyLibrary,
      ),
      type: 'int',
    );
  }

  test_plusPlus_num() async {
    await assertNoErrorsInCode(r'''
f(num x) {
  ++x;
}
''');

    assertPrefixExpression(
      findNode.prefix('++x'),
      element: elementMatcher(
        numElement.getMethod('+'),
        isLegacy: isNullSafetySdkAndLegacyLibrary,
      ),
      type: 'num',
    );
  }

  test_tilde_int_localVariable() async {
    await assertNoErrorsInCode(r'''
f(int x) {
  ~x;
}
''');

    assertPrefixExpression(
      findNode.prefix('~x'),
      element: elementMatcher(
        intElement.getMethod('~'),
        isLegacy: isNullSafetySdkAndLegacyLibrary,
      ),
      type: 'int',
    );
  }
}

@reflectiveTest
class PrefixExpressionResolutionWithNullSafetyTest
    extends PrefixExpressionResolutionTest with WithNullSafetyMixin {
  test_bang_no_nullShorting() async {
    await assertErrorsInCode(r'''
class A {
  bool get foo => true;
}

void f(A? a) {
  !a?.foo;
}
''', [
      error(CompileTimeErrorCode.UNCHECKED_USE_OF_NULLABLE_VALUE, 55, 6),
    ]);

    assertPrefixExpression(
      findNode.prefix('!a'),
      element: boolElement.getMethod('!'),
      type: 'bool',
    );
  }

  test_minus_no_nullShorting() async {
    await assertErrorsInCode(r'''
class A {
  int get foo => 0;
}

void f(A? a) {
  -a?.foo;
}
''', [
      error(CompileTimeErrorCode.UNCHECKED_USE_OF_NULLABLE_VALUE, 51, 6),
    ]);

    assertPrefixExpression(
      findNode.prefix('-a'),
      element: intElement.getMethod('unary-'),
      type: 'int',
    );
  }

  test_plusPlus_depromote() async {
    await assertNoErrorsInCode(r'''
class A {
  Object operator +(int _) => this;
}

f(Object x) {
  if (x is A) {
    ++x;
  }
}
''');

    assertPrefixExpression(
      findNode.prefix('++x'),
      element: findElement.method('+'),
      type: 'Object',
    );

    assertType(findNode.simple('x;'), 'A');
  }

  test_plusPlus_nullShorting() async {
    await assertNoErrorsInCode(r'''
class A {
  int foo = 0;
}

f(A? a) {
  ++a?.foo;
}
''');

    assertPrefixExpression(
      findNode.prefix('++a'),
      element: numElement.getMethod('+'),
      type: 'int?',
    );
  }

  test_tilde_no_nullShorting() async {
    await assertErrorsInCode(r'''
class A {
  int get foo => 0;
}

void f(A? a) {
  ~a?.foo;
}
''', [
      error(CompileTimeErrorCode.UNCHECKED_USE_OF_NULLABLE_VALUE, 51, 6),
    ]);

    assertPrefixExpression(
      findNode.prefix('~a'),
      element: intElement.getMethod('~'),
      type: 'int',
    );
  }
}
