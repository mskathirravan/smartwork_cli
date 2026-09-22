import '../template/naming_conventions.dart';

class UnsupportedJsonRootException implements Exception {
  final String description;

  UnsupportedJsonRootException(this.description);

  @override
  String toString() =>
      'Unsupported JSON root: $description. The root JSON value must be '
      'an object (e.g. "{ ... }"), not an array or a bare scalar.';
}

class DuplicateModelClassNameException implements Exception {
  final String className;

  DuplicateModelClassNameException(this.className);

  @override
  String toString() =>
      'Duplicate generated model class name: "$className". Two different '
      'JSON keys would generate the same class/file — rename one of the '
      'conflicting keys in the source JSON and try again.';
}

const _dartReservedWords = {
  'assert',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
  'await',
  'yield',
};

enum ModelFieldKind {
  primitive,

  nullValue,

  nestedObject,

  primitiveList,

  emptyList,

  objectList,
}

class GeneratedModelField {
  final String jsonKey;

  final String dartName;

  final String dartType;

  final ModelFieldKind kind;

  final GeneratedModelClass? referencedClass;

  GeneratedModelField({
    required this.jsonKey,
    required this.dartName,
    required this.dartType,
    required this.kind,
    this.referencedClass,
  });
}

class GeneratedModelClass {
  final String pascalBaseName;

  final List<GeneratedModelField> fields;

  GeneratedModelClass({required this.pascalBaseName, required this.fields});

  String get className => '${pascalBaseName}Model';

  String get fileBaseName => NamingConventions.toSnakeCase(pascalBaseName);

  List<GeneratedModelClass> get referencedClasses => fields
      .where((f) => f.referencedClass != null)
      .map((f) => f.referencedClass!)
      .toList();
}

class ModelGenerator {
  List<GeneratedModelClass> inferClasses({
    required String rootBaseName,
    required Object? decodedJson,
  }) {
    if (decodedJson is! Map) {
      throw UnsupportedJsonRootException(_describeRoot(decodedJson));
    }

    final classes = <GeneratedModelClass>[];
    final seenClassNames = <String>{};
    final root = _inferClass(
      pascalBaseName: rootBaseName,
      jsonObject: Map<String, dynamic>.from(decodedJson),
      classes: classes,
      seenClassNames: seenClassNames,
    );

    classes.remove(root);
    classes.insert(0, root);
    return classes;
  }

  GeneratedModelClass _inferClass({
    required String pascalBaseName,
    required Map<String, dynamic> jsonObject,
    required List<GeneratedModelClass> classes,
    required Set<String> seenClassNames,
  }) {
    final className = '${pascalBaseName}Model';
    if (!seenClassNames.add(className)) {
      throw DuplicateModelClassNameException(className);
    }

    final fields = <GeneratedModelField>[];
    for (final entry in jsonObject.entries) {
      fields.add(_inferField(
        jsonKey: entry.key,
        value: entry.value,
        classes: classes,
        seenClassNames: seenClassNames,
      ));
    }

    final generated =
        GeneratedModelClass(pascalBaseName: pascalBaseName, fields: fields);
    classes.add(generated);
    return generated;
  }

  GeneratedModelField _inferField({
    required String jsonKey,
    required Object? value,
    required List<GeneratedModelClass> classes,
    required Set<String> seenClassNames,
  }) {
    final dartName = _dartFieldName(jsonKey);

    if (value == null) {
      return GeneratedModelField(
        jsonKey: jsonKey,
        dartName: dartName,
        dartType: 'Object?',
        kind: ModelFieldKind.nullValue,
      );
    }

    final primitive = _primitiveTypeOf(value);
    if (primitive != null) {
      return GeneratedModelField(
        jsonKey: jsonKey,
        dartName: dartName,
        dartType: primitive,
        kind: ModelFieldKind.primitive,
      );
    }

    if (value is Map) {
      final nestedClass = _inferClass(
        pascalBaseName: NamingConventions.toPascalCase(jsonKey),
        jsonObject: Map<String, dynamic>.from(value),
        classes: classes,
        seenClassNames: seenClassNames,
      );
      return GeneratedModelField(
        jsonKey: jsonKey,
        dartName: dartName,
        dartType: nestedClass.className,
        kind: ModelFieldKind.nestedObject,
        referencedClass: nestedClass,
      );
    }

    if (value is List) {
      if (value.isEmpty) {
        return GeneratedModelField(
          jsonKey: jsonKey,
          dartName: dartName,
          dartType: 'List<dynamic>',
          kind: ModelFieldKind.emptyList,
        );
      }

      final firstElement = value.first;
      if (firstElement is Map) {
        final itemClass = _inferClass(
          pascalBaseName: '${NamingConventions.toPascalCase(jsonKey)}Item',
          jsonObject: Map<String, dynamic>.from(firstElement),
          classes: classes,
          seenClassNames: seenClassNames,
        );
        return GeneratedModelField(
          jsonKey: jsonKey,
          dartName: dartName,
          dartType: 'List<${itemClass.className}>',
          kind: ModelFieldKind.objectList,
          referencedClass: itemClass,
        );
      }

      final elementType = _primitiveTypeOf(firstElement) ?? 'dynamic';
      return GeneratedModelField(
        jsonKey: jsonKey,
        dartName: dartName,
        dartType: 'List<$elementType>',
        kind: ModelFieldKind.primitiveList,
      );
    }

    return GeneratedModelField(
      jsonKey: jsonKey,
      dartName: dartName,
      dartType: 'Object?',
      kind: ModelFieldKind.nullValue,
    );
  }

  String? _primitiveTypeOf(Object? value) {
    if (value is String) return 'String';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    return null;
  }

  String _dartFieldName(String jsonKey) {
    final camel = NamingConventions.toCamelCase(jsonKey);
    return _dartReservedWords.contains(camel) ? '${camel}_' : camel;
  }

  String _describeRoot(Object? decodedJson) {
    if (decodedJson is List) return 'a JSON array';
    if (decodedJson == null) return 'a bare "null"';
    if (decodedJson is String) return 'a bare string';
    if (decodedJson is num) return 'a bare number';
    if (decodedJson is bool) return 'a bare boolean';
    return decodedJson.runtimeType.toString();
  }

  String renderSource(GeneratedModelClass modelClass) {
    final imports = modelClass.referencedClasses
        .map((c) => "import '${c.fileBaseName}_model.dart';")
        .toSet()
        .toList()
      ..sort();

    final buffer = StringBuffer();
    for (final import in imports) {
      buffer.writeln(import);
    }
    if (imports.isNotEmpty) buffer.writeln();

    buffer.writeln('class ${modelClass.className} {');
    _writeConstructor(buffer, modelClass);
    buffer.writeln();
    for (final field in modelClass.fields) {
      buffer.writeln('  final ${field.dartType} ${field.dartName};');
    }
    buffer.writeln();
    buffer.writeln(
        '  factory ${modelClass.className}.fromJson(Map<String, dynamic> json) {');
    _writeFromJsonBody(buffer, modelClass);
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Map<String, dynamic> toJson() {');
    _writeToJsonBody(buffer, modelClass);
    buffer.writeln('  }');
    buffer.writeln('}');
    return buffer.toString();
  }

  static const _maxLineLength = 80;

  void _writeConstructor(StringBuffer buffer, GeneratedModelClass modelClass) {
    final params =
        modelClass.fields.map((f) => 'required this.${f.dartName}').join(', ');
    final singleLine = '  const ${modelClass.className}({$params});';
    if (singleLine.length <= _maxLineLength) {
      buffer.writeln(singleLine);
      return;
    }
    buffer.writeln('  const ${modelClass.className}({');
    for (final field in modelClass.fields) {
      buffer.writeln('    required this.${field.dartName},');
    }
    buffer.writeln('  });');
  }

  void _writeFromJsonBody(
    StringBuffer buffer,
    GeneratedModelClass modelClass,
  ) {
    final args = modelClass.fields
        .map((f) => '${f.dartName}: ${_fromJsonExpr(f)}')
        .join(', ');
    final singleLine = '    return ${modelClass.className}($args);';
    if (singleLine.length <= _maxLineLength) {
      buffer.writeln(singleLine);
      return;
    }
    buffer.writeln('    return ${modelClass.className}(');
    for (final field in modelClass.fields) {
      _writeFromJsonFieldLine(buffer, field);
    }
    buffer.writeln('    );');
  }

  void _writeToJsonBody(StringBuffer buffer, GeneratedModelClass modelClass) {
    final entries = modelClass.fields
        .map((f) => "'${f.jsonKey}': ${_toJsonExpr(f)}")
        .join(', ');
    final singleLine = '    return {$entries};';
    if (singleLine.length <= _maxLineLength) {
      buffer.writeln(singleLine);
      return;
    }
    buffer.writeln('    return {');
    for (final field in modelClass.fields) {
      _writeToJsonFieldLine(buffer, field);
    }
    buffer.writeln('    };');
  }

  void _writeFromJsonFieldLine(StringBuffer buffer, GeneratedModelField field) {
    final singleLine = '      ${field.dartName}: ${_fromJsonExpr(field)},';
    if (singleLine.length <= _maxLineLength) {
      buffer.writeln(singleLine);
      return;
    }
    final mapCall = switch (field.kind) {
      ModelFieldKind.primitiveList =>
        '.map((e) => e as ${_primitiveListElementType(field)})',
      ModelFieldKind.objectList => '.map((e) => '
          '${field.referencedClass!.className}.fromJson('
          'e as Map<String, dynamic>))',
      _ => null,
    };
    if (mapCall == null) {
      buffer.writeln(singleLine);
      return;
    }
    final key = "json['${field.jsonKey}']";
    buffer.writeln('      ${field.dartName}: ($key as List)');
    buffer.writeln('          $mapCall');
    buffer.writeln('          .toList(),');
  }

  void _writeToJsonFieldLine(StringBuffer buffer, GeneratedModelField field) {
    final singleLine = "      '${field.jsonKey}': ${_toJsonExpr(field)},";
    if (singleLine.length <= _maxLineLength ||
        field.kind != ModelFieldKind.objectList) {
      buffer.writeln(singleLine);
      return;
    }
    buffer.writeln("      '${field.jsonKey}': ${field.dartName}");
    buffer.writeln('          .map((e) => e.toJson())');
    buffer.writeln('          .toList(),');
  }

  String _primitiveListElementType(GeneratedModelField field) {
    return field.dartType.substring(
      'List<'.length,
      field.dartType.length - 1,
    );
  }

  String _fromJsonExpr(GeneratedModelField field) {
    final key = "json['${field.jsonKey}']";
    switch (field.kind) {
      case ModelFieldKind.nullValue:
        return key;
      case ModelFieldKind.primitive:
        return '$key as ${field.dartType}';
      case ModelFieldKind.nestedObject:
        return '${field.referencedClass!.className}.fromJson('
            '$key as Map<String, dynamic>)';
      case ModelFieldKind.emptyList:
        return '$key as List<dynamic>';
      case ModelFieldKind.primitiveList:
        final elementType = _primitiveListElementType(field);
        return '($key as List).map((e) => e as $elementType).toList()';
      case ModelFieldKind.objectList:
        return '($key as List).map((e) => '
            '${field.referencedClass!.className}.fromJson('
            'e as Map<String, dynamic>)).toList()';
    }
  }

  String _toJsonExpr(GeneratedModelField field) {
    switch (field.kind) {
      case ModelFieldKind.nullValue:
      case ModelFieldKind.primitive:
      case ModelFieldKind.emptyList:
      case ModelFieldKind.primitiveList:
        return field.dartName;
      case ModelFieldKind.nestedObject:
        return '${field.dartName}.toJson()';
      case ModelFieldKind.objectList:
        return '${field.dartName}.map((e) => e.toJson()).toList()';
    }
  }
}
