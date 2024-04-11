// Copyright (c) 2023, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:macros/macros.dart';

/// Resolves top-level identifier references of form `{{uri@name}}`.
Future<List<Object>> resolveIdentifiers(
  TypePhaseIntrospector introspector,
  String withIdentifiers,
) async {
  final result = <Object>[];
  var lastMatchEnd = 0;

  void addStringPart(int end) {
    final str = withIdentifiers.substring(lastMatchEnd, end);
    result.add(str);
  }

  final pattern = RegExp(r'\{\{(.+?)@(\w+?)\}\}');
  for (final match in pattern.allMatches(withIdentifiers)) {
    addStringPart(match.start);
    // ignore: deprecated_member_use
    final identifier = await introspector.resolveIdentifier(
      Uri.parse(match.group(1)!),
      match.group(2)!,
    );
    result.add(identifier);
    lastMatchEnd = match.end;
  }

  addStringPart(withIdentifiers.length);
  return result;
}

/*macro*/ class AppendInterface implements ClassTypesMacro, MixinTypesMacro {
  final String code;

  const AppendInterface(this.code);

  @override
  buildTypesForClass(clazz, builder) async {
    await _append(builder);
  }

  @override
  buildTypesForMixin(clazz, builder) async {
    await _append(builder);
  }

  Future<void> _append(InterfaceTypesBuilder builder) async {
    final parts = await resolveIdentifiers(builder, code);
    builder.appendInterfaces([
      RawTypeAnnotationCode.fromParts(parts),
    ]);
  }
}

/*macro*/ class AppendMixin implements ClassTypesMacro {
  final String code;

  const AppendMixin(this.code);

  @override
  buildTypesForClass(clazz, builder) async {
    await _append(builder);
  }

  Future<void> _append(MixinTypesBuilder builder) async {
    final parts = await resolveIdentifiers(builder, code);
    builder.appendMixins([
      RawTypeAnnotationCode.fromParts(parts),
    ]);
  }
}

/*macro*/ class DeclareClassAppendInterfaceRawCode implements ClassTypesMacro {
  final String interfaceName;

  const DeclareClassAppendInterfaceRawCode(
    this.interfaceName,
  );

  @override
  buildTypesForClass(clazz, builder) {
    builder.declareType(
      interfaceName,
      DeclarationCode.fromString(
        'abstract interface class $interfaceName {}',
      ),
    );

    builder.appendInterfaces([
      RawTypeAnnotationCode.fromString(interfaceName),
    ]);
  }
}

/*macro*/ class DeclareInLibrary
    implements ClassDeclarationsMacro, FunctionDeclarationsMacro {
  final String code;

  const DeclareInLibrary(this.code);

  @override
  buildDeclarationsForClass(clazz, builder) async {
    await _declare(builder);
  }

  @override
  buildDeclarationsForFunction(clazz, builder) async {
    await _declare(builder);
  }

  Future<void> _declare(DeclarationBuilder builder) async {
    final parts = await resolveIdentifiers(builder, code);
    builder.declareInLibrary(
      DeclarationCode.fromParts(parts),
    );
  }
}

/*macro*/ class DeclareInType
    implements
        ClassDeclarationsMacro,
        ConstructorDeclarationsMacro,
        FieldDeclarationsMacro,
        MethodDeclarationsMacro {
  final String code;

  const DeclareInType(this.code);

  @override
  buildDeclarationsForClass(clazz, builder) async {
    await _declare(builder);
  }

  @override
  buildDeclarationsForConstructor(constructor, builder) async {
    await _declare(builder);
  }

  @override
  buildDeclarationsForField(field, builder) async {
    await _declare(builder);
  }

  @override
  buildDeclarationsForMethod(method, builder) async {
    await _declare(builder);
  }

  Future<void> _declare(MemberDeclarationBuilder builder) async {
    final parts = await resolveIdentifiers(builder, code);
    builder.declareInType(
      DeclarationCode.fromParts(parts),
    );
  }
}

/*macro*/ class DeclareType implements ClassTypesMacro {
  final String name;
  final String code;

  const DeclareType(this.name, this.code);

  const DeclareType.named(this.name, this.code);

  @override
  buildTypesForClass(clazz, builder) {
    builder.declareType(
      name,
      DeclarationCode.fromString(code),
    );
  }
}
