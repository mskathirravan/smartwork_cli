import 'dart:convert';
import 'dart:io';

import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('NamingConventions.toCamelCase', () {
    test('converts snake_case', () {
      expect(NamingConventions.toCamelCase('user_id'), 'userId');
      expect(NamingConventions.toCamelCase('first_name'), 'firstName');
    });

    test('converts kebab-case', () {
      expect(NamingConventions.toCamelCase('user-name'), 'userName');
    });

    test('leaves camelCase unchanged (idempotent)', () {
      expect(NamingConventions.toCamelCase('firstName'), 'firstName');
    });

    test('converts a single lowercase word unchanged', () {
      expect(NamingConventions.toCamelCase('id'), 'id');
    });
  });

  group('ModelGenerator.inferClasses — primitives and nullability', () {
    test('infers String/int/double/bool exactly as jsonDecode decodes them',
        () {
      final classes = ModelGenerator().inferClasses(
        rootBaseName: 'User',
        decodedJson: jsonDecode('{"id": 1, "name": "John", "active": true, '
            '"score": 12.5}'),
      );

      expect(classes, hasLength(1));
      final fields = {for (final f in classes.single.fields) f.jsonKey: f};
      expect(fields['id']!.dartType, 'int');
      expect(fields['name']!.dartType, 'String');
      expect(fields['active']!.dartType, 'bool');
      expect(fields['score']!.dartType, 'double');
    });

    test('a null-only field infers Object?, never a guessed primitive', () {
      final classes = ModelGenerator().inferClasses(
        rootBaseName: 'User',
        decodedJson: jsonDecode('{"name": null}'),
      );

      final field = classes.single.fields.single;
      expect(field.dartType, 'Object?');
      expect(field.kind, ModelFieldKind.nullValue);
    });
  });

  group('ModelGenerator.inferClasses — nested objects', () {
    test('a nested object generates a separate class, named from its key', () {
      final classes = ModelGenerator().inferClasses(
        rootBaseName: 'User',
        decodedJson: jsonDecode('{"id": 1, "address": {"city": "Chennai"}}'),
      );

      expect(classes, hasLength(2));
      expect(classes.first.className, 'UserModel');
      expect(classes[1].className, 'AddressModel');
      final addressField =
          classes.first.fields.firstWhere((f) => f.jsonKey == 'address');
      expect(addressField.dartType, 'AddressModel');
      expect(addressField.kind, ModelFieldKind.nestedObject);
      expect(addressField.referencedClass, classes[1]);
    });

    test('multiple nesting levels resolve independently', () {
      final classes = ModelGenerator().inferClasses(
        rootBaseName: 'User',
        decodedJson: jsonDecode('{"profile": {"address": {"city": "X"}}}'),
      );

      expect(
        classes.map((c) => c.className),
        containsAll(['UserModel', 'ProfileModel', 'AddressModel']),
      );
    });

    test(
        'throws DuplicateModelClassNameException for two keys producing '
        'the same class name', () {
      expect(
        () => ModelGenerator().inferClasses(
          rootBaseName: 'Address',
          decodedJson: jsonDecode('{"address": {"city": "X"}}'),
        ),
        throwsA(isA<DuplicateModelClassNameException>()),
      );
    });
  });

  group('ModelGenerator.inferClasses — lists', () {
    test('a String list infers List<String>', () {
      final field = ModelGenerator()
          .inferClasses(
            rootBaseName: 'User',
            decodedJson: jsonDecode('{"tags": ["a", "b"]}'),
          )
          .single
          .fields
          .single;
      expect(field.dartType, 'List<String>');
    });

    test('an int list infers List<int>', () {
      final field = ModelGenerator()
          .inferClasses(
            rootBaseName: 'User',
            decodedJson: jsonDecode('{"scores": [1, 2]}'),
          )
          .single
          .fields
          .single;
      expect(field.dartType, 'List<int>');
    });

    test('a double list infers List<double>', () {
      final field = ModelGenerator()
          .inferClasses(
            rootBaseName: 'User',
            decodedJson: jsonDecode('{"ratios": [1.5, 2.5]}'),
          )
          .single
          .fields
          .single;
      expect(field.dartType, 'List<double>');
    });

    test('a bool list infers List<bool>', () {
      final field = ModelGenerator()
          .inferClasses(
            rootBaseName: 'User',
            decodedJson: jsonDecode('{"flags": [true, false]}'),
          )
          .single
          .fields
          .single;
      expect(field.dartType, 'List<bool>');
    });

    test(
        'an object list generates a <Key>ItemModel class, never attempting '
        'English singularization', () {
      final classes = ModelGenerator().inferClasses(
        rootBaseName: 'Root',
        decodedJson: jsonDecode('{"users": [{"id": 1}]}'),
      );

      expect(classes.map((c) => c.className), contains('UsersItemModel'));
      final field = classes.first.fields.single;
      expect(field.dartType, 'List<UsersItemModel>');
      expect(field.kind, ModelFieldKind.objectList);
    });

    test(
        'an empty list infers List<dynamic> — no element-type evidence '
        'exists', () {
      final field = ModelGenerator()
          .inferClasses(
            rootBaseName: 'User',
            decodedJson: jsonDecode('{"items": []}'),
          )
          .single
          .fields
          .single;
      expect(field.dartType, 'List<dynamic>');
      expect(field.kind, ModelFieldKind.emptyList);
    });
  });

  group('ModelGenerator.inferClasses — naming', () {
    test(
        'snake_case, kebab-case, and camelCase keys all resolve to the '
        'expected Dart field name', () {
      final fields = ModelGenerator()
          .inferClasses(
            rootBaseName: 'User',
            decodedJson: jsonDecode(
                '{"user_id": 1, "user-name": "a", "firstName": "b"}'),
          )
          .single
          .fields;
      final byKey = {for (final f in fields) f.jsonKey: f.dartName};
      expect(byKey['user_id'], 'userId');
      expect(byKey['user-name'], 'userName');
      expect(byKey['firstName'], 'firstName');
    });

    test(
        'a Dart reserved word key gets a trailing underscore, but the '
        'original JSON key is preserved for serialization', () {
      final field = ModelGenerator()
          .inferClasses(
            rootBaseName: 'User',
            decodedJson: jsonDecode('{"class": "A", "for": 1, "in": 2}'),
          )
          .single
          .fields;
      final byKey = {for (final f in field) f.jsonKey: f.dartName};
      expect(byKey['class'], 'class_');
      expect(byKey['for'], 'for_');
      expect(byKey['in'], 'in_');
    });
  });

  group('ModelGenerator.inferClasses — unsupported root', () {
    test('rejects a root array', () {
      expect(
        () => ModelGenerator().inferClasses(
          rootBaseName: 'User',
          decodedJson: jsonDecode('[1, 2, 3]'),
        ),
        throwsA(isA<UnsupportedJsonRootException>()),
      );
    });

    test('rejects a root scalar', () {
      expect(
        () => ModelGenerator().inferClasses(
          rootBaseName: 'User',
          decodedJson: jsonDecode('42'),
        ),
        throwsA(isA<UnsupportedJsonRootException>()),
      );
      expect(
        () => ModelGenerator().inferClasses(
          rootBaseName: 'User',
          decodedJson: jsonDecode('"hello"'),
        ),
        throwsA(isA<UnsupportedJsonRootException>()),
      );
      expect(
        () => ModelGenerator().inferClasses(
          rootBaseName: 'User',
          decodedJson: jsonDecode('true'),
        ),
        throwsA(isA<UnsupportedJsonRootException>()),
      );
      expect(
        () => ModelGenerator().inferClasses(
          rootBaseName: 'User',
          decodedJson: jsonDecode('null'),
        ),
        throwsA(isA<UnsupportedJsonRootException>()),
      );
    });
  });

  group('ModelGenerator.renderSource', () {
    test('renders a const constructor, fields, fromJson, and toJson', () {
      final classes = ModelGenerator().inferClasses(
        rootBaseName: 'User',
        decodedJson: jsonDecode('{"id": 1, "name": "John"}'),
      );
      final source = ModelGenerator().renderSource(classes.single);

      expect(source, contains('class UserModel {'));
      expect(source, contains('const UserModel({'));
      expect(source, contains('final int id;'));
      expect(source, contains('final String name;'));
      expect(source, contains('factory UserModel.fromJson('));
      expect(source, contains('Map<String, dynamic> toJson()'));
      expect(source, isNot(contains('copyWith')));
      expect(source, isNot(contains('hashCode')));
      expect(source, isNot(contains('toString()')));
      expect(source, isNot(contains('==')));
    });

    test('nested fromJson/toJson call the nested class\'s own methods', () {
      final classes = ModelGenerator().inferClasses(
        rootBaseName: 'User',
        decodedJson: jsonDecode('{"address": {"city": "X"}}'),
      );
      final source = ModelGenerator().renderSource(classes.first);

      expect(
        source,
        contains(
            "address: AddressModel.fromJson(json['address'] as Map<String, dynamic>),"),
      );
      expect(source, contains("'address': address.toJson()"));
      expect(source, contains("import 'address_model.dart';"));
    });

    test(
        'object-list fromJson/toJson map element-wise through the item '
        'class', () {
      final classes = ModelGenerator().inferClasses(
        rootBaseName: 'Root',
        decodedJson: jsonDecode('{"users": [{"id": 1}]}'),
      );
      final source = ModelGenerator().renderSource(classes.first);

      expect(
        source,
        contains("UsersItemModel.fromJson(e as Map<String, dynamic>)"),
      );
      expect(source, contains("users.map((e) => e.toJson()).toList()"));
    });

    test(
        'a long object-list fromJson chain that would exceed 80 columns '
        'on one line is wrapped exactly the way dart_format wraps it '
        '(one call per line, not left overflowing)', () {
      final classes = ModelGenerator().inferClasses(
        rootBaseName: 'V119CaseCSample',
        decodedJson: jsonDecode(
          '{"id": 1, "name": "x", "users": [{"id": 1, "userName": "a"}]}',
        ),
      );
      final source = ModelGenerator().renderSource(classes.first);
      final lines = source.split('\n');

      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(80),
            reason: 'line exceeds 80 columns: "$line"');
      }
      expect(source, contains("users: (json['users'] as List)"));
      expect(
        source,
        contains(
            '          .map((e) => UsersItemModel.fromJson(e as Map<String, '
            'dynamic>))'),
      );
      expect(source, contains('          .toList(),'));
    });

    test(
        'toJson preserves the original JSON key for an escaped reserved '
        'word field', () {
      final classes = ModelGenerator().inferClasses(
        rootBaseName: 'User',
        decodedJson: jsonDecode('{"class": "A"}'),
      );
      final source = ModelGenerator().renderSource(classes.single);

      expect(source, contains('final String class_;'));
      expect(source, contains("json['class'] as String"));
      expect(source, contains("'class': class_"));
      expect(source, isNot(contains("'class_':")));
    });
  });

  group('ModelLifecycle.generateFromJson', () {
    late Directory tempDir;
    late String projectPath;
    late File jsonFile;

    Future<void> setUpProject({
      Architecture architecture = Architecture.cleanArchitecture,
      StateManagement stateManagement = StateManagement.bloc,
    }) async {
      final config = ProjectConfig(
        projectName: 'demo_app',
        architecture: architecture,
        stateManagement: stateManagement,
        network: Network.http,
        storage: Storage.sharedPreferences,
        initialFeatures: ['home'],
      );
      await ProjectGenerator(outputPath: projectPath, config: config)
          .generate();
    }

    Future<void> addFeature(String name) async {
      await FeatureLifecycle().addFeature(
        projectPath: projectPath,
        feature: FeatureConfig(name: name),
      );
    }

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartwork_model_test_');
      projectPath = tempDir.path;
      jsonFile = File('${tempDir.path}_input.json');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
      if (jsonFile.existsSync()) jsonFile.deleteSync();
    });

    test(
        'throws FileSystemException for a directory that is not a '
        'SmartWork project', () async {
      await jsonFile.writeAsString('{"id": 1}');

      expect(
        () => ModelLifecycle().generateFromJson(
          projectPath: projectPath,
          jsonFilePath: jsonFile.path,
          featureName: 'profile',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test(
        'throws FeatureNotFoundException when the target feature does '
        'not exist', () async {
      await setUpProject();
      await jsonFile.writeAsString('{"id": 1}');

      expect(
        () => ModelLifecycle().generateFromJson(
          projectPath: projectPath,
          jsonFilePath: jsonFile.path,
          featureName: 'profile',
        ),
        throwsA(isA<FeatureNotFoundException>()),
      );
    });

    test('throws JsonFileNotFoundException for a missing JSON file', () async {
      await setUpProject();
      await addFeature('profile');

      expect(
        () => ModelLifecycle().generateFromJson(
          projectPath: projectPath,
          jsonFilePath: '/no/such/file.json',
          featureName: 'profile',
        ),
        throwsA(isA<JsonFileNotFoundException>()),
      );
    });

    test('throws InvalidJsonException for malformed JSON', () async {
      await setUpProject();
      await addFeature('profile');
      await jsonFile.writeAsString('{not valid json');

      expect(
        () => ModelLifecycle().generateFromJson(
          projectPath: projectPath,
          jsonFilePath: jsonFile.path,
          featureName: 'profile',
        ),
        throwsA(isA<InvalidJsonException>()),
      );
    });

    test('throws UnsupportedJsonRootException for a root array', () async {
      await setUpProject();
      await addFeature('profile');
      await jsonFile.writeAsString('[1, 2, 3]');

      expect(
        () => ModelLifecycle().generateFromJson(
          projectPath: projectPath,
          jsonFilePath: jsonFile.path,
          featureName: 'profile',
        ),
        throwsA(isA<UnsupportedJsonRootException>()),
      );
    });

    test(
        'successfully generates a Clean-architecture model at '
        'data/models/<name>_model.dart', () async {
      await setUpProject();
      await addFeature('profile');
      await jsonFile.writeAsString(jsonEncode({'id': 1, 'name': 'John'}));

      final result = await ModelLifecycle().generateFromJson(
        projectPath: projectPath,
        jsonFilePath: jsonFile.path,
        featureName: 'profile',
      );

      final expectedPath =
          'lib/features/profile/data/models/${_baseNameOf(jsonFile.path)}_model.dart';
      expect(result.generatedFiles, contains(expectedPath));
      expect(File('$projectPath/$expectedPath').existsSync(), isTrue);
      // Clean's existing entity/model for "profile" itself is untouched.
      expect(
        File('$projectPath/lib/features/profile/domain/entities/profile.dart')
            .existsSync(),
        isTrue,
      );
    });

    test('successfully generates an MVVM model at models/<name>_model.dart',
        () async {
      await setUpProject(
        architecture: Architecture.mvvm,
        stateManagement: StateManagement.riverpod,
      );
      await addFeature('profile');
      await jsonFile.writeAsString(jsonEncode({'id': 1, 'name': 'John'}));

      final result = await ModelLifecycle().generateFromJson(
        projectPath: projectPath,
        jsonFilePath: jsonFile.path,
        featureName: 'profile',
      );

      final expectedPath =
          'lib/features/profile/models/${_baseNameOf(jsonFile.path)}_model.dart';
      expect(result.generatedFiles, contains(expectedPath));
    });

    test('successfully generates an MVP model at models/<name>_model.dart',
        () async {
      await setUpProject(
        architecture: Architecture.mvp,
        stateManagement: StateManagement.getx,
      );
      await addFeature('profile');
      await jsonFile.writeAsString(jsonEncode({'id': 1, 'name': 'John'}));

      final result = await ModelLifecycle().generateFromJson(
        projectPath: projectPath,
        jsonFilePath: jsonFile.path,
        featureName: 'profile',
      );

      final expectedPath =
          'lib/features/profile/models/${_baseNameOf(jsonFile.path)}_model.dart';
      expect(result.generatedFiles, contains(expectedPath));
    });

    test(
        'generates architecture-independent model content: the rendered '
        'class body is identical across Clean and MVVM for the same JSON',
        () async {
      final cleanDir =
          Directory.systemTemp.createTempSync('smartwork_model_clean_');
      final mvvmDir =
          Directory.systemTemp.createTempSync('smartwork_model_mvvm_');
      addTearDown(() => cleanDir.deleteSync(recursive: true));
      addTearDown(() => mvvmDir.deleteSync(recursive: true));

      await ProjectGenerator(
        outputPath: cleanDir.path,
        config: ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.cleanArchitecture,
          stateManagement: StateManagement.bloc,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        ),
      ).generate();
      await ProjectGenerator(
        outputPath: mvvmDir.path,
        config: ProjectConfig(
          projectName: 'demo_app',
          architecture: Architecture.mvvm,
          stateManagement: StateManagement.riverpod,
          network: Network.http,
          storage: Storage.sharedPreferences,
          initialFeatures: ['home'],
        ),
      ).generate();
      await FeatureLifecycle().addFeature(
          projectPath: cleanDir.path, feature: FeatureConfig(name: 'profile'));
      await FeatureLifecycle().addFeature(
          projectPath: mvvmDir.path, feature: FeatureConfig(name: 'profile'));

      await jsonFile.writeAsString(jsonEncode({'id': 1, 'name': 'John'}));

      await ModelLifecycle().generateFromJson(
        projectPath: cleanDir.path,
        jsonFilePath: jsonFile.path,
        featureName: 'profile',
      );
      await ModelLifecycle().generateFromJson(
        projectPath: mvvmDir.path,
        jsonFilePath: jsonFile.path,
        featureName: 'profile',
      );

      final cleanContent = File(
        '${cleanDir.path}/lib/features/profile/data/models/'
        '${_baseNameOf(jsonFile.path)}_model.dart',
      ).readAsStringSync();
      final mvvmContent = File(
        '${mvvmDir.path}/lib/features/profile/models/'
        '${_baseNameOf(jsonFile.path)}_model.dart',
      ).readAsStringSync();
      expect(cleanContent, mvvmContent);
    });

    test(
        'adds an export for the new model to the feature\'s existing '
        'barrel, preserving its existing exports', () async {
      await setUpProject();
      await addFeature('profile');
      await jsonFile.writeAsString(jsonEncode({'id': 1}));

      await ModelLifecycle().generateFromJson(
        projectPath: projectPath,
        jsonFilePath: jsonFile.path,
        featureName: 'profile',
      );

      final barrel = File('$projectPath/lib/features/profile/profile.dart')
          .readAsStringSync();
      expect(barrel, contains('data/models/profile_model.dart'));
      expect(barrel, contains('domain/entities/profile.dart'));
      expect(
        barrel,
        contains('data/models/${_baseNameOf(jsonFile.path)}_model.dart'),
      );
    });

    test(
        'rejects generation when the root model file already exists, '
        'writing nothing', () async {
      await setUpProject();
      await addFeature('profile');
      await jsonFile.writeAsString(jsonEncode({'id': 1}));
      await ModelLifecycle().generateFromJson(
        projectPath: projectPath,
        jsonFilePath: jsonFile.path,
        featureName: 'profile',
      );

      expect(
        () => ModelLifecycle().generateFromJson(
          projectPath: projectPath,
          jsonFilePath: jsonFile.path,
          featureName: 'profile',
        ),
        throwsA(isA<ModelFileCollisionException>()),
      );
    });

    test(
        'rejects generation when only a nested model file collides, and '
        'writes no files at all (not even the non-colliding root)', () async {
      await setUpProject();
      await addFeature('profile');

      // Pre-create just the nested "address_model.dart" file by hand,
      // simulating a developer's own pre-existing file with that name.
      final addressPath =
          '$projectPath/lib/features/profile/data/models/address_model.dart';
      await Directory(File(addressPath).parent.path).create(recursive: true);
      await File(addressPath).writeAsString('// developer-owned file\n');

      await jsonFile.writeAsString(jsonEncode({
        'id': 1,
        'address': {'city': 'X'}
      }));

      final rootModelPath = '$projectPath/lib/features/profile/data/models/'
          '${_baseNameOf(jsonFile.path)}_model.dart';

      expect(
        () => ModelLifecycle().generateFromJson(
          projectPath: projectPath,
          jsonFilePath: jsonFile.path,
          featureName: 'profile',
        ),
        throwsA(isA<ModelFileCollisionException>()),
      );
      // The root model — which did NOT collide — was still never
      // written, because validation happens before any file is written.
      expect(File(rootModelPath).existsSync(), isFalse);
      // The developer's own file is untouched.
      expect(
        File(addressPath).readAsStringSync(),
        '// developer-owned file\n',
      );
    });

    test(
        'is safe on a second run after a collision: existing generated '
        'files are never modified', () async {
      await setUpProject();
      await addFeature('profile');
      await jsonFile.writeAsString(jsonEncode({'id': 1, 'name': 'John'}));
      await ModelLifecycle().generateFromJson(
        projectPath: projectPath,
        jsonFilePath: jsonFile.path,
        featureName: 'profile',
      );
      final modelPath = '$projectPath/lib/features/profile/data/models/'
          '${_baseNameOf(jsonFile.path)}_model.dart';
      final contentAfterFirst = File(modelPath).readAsStringSync();

      try {
        await ModelLifecycle().generateFromJson(
          projectPath: projectPath,
          jsonFilePath: jsonFile.path,
          featureName: 'profile',
        );
      } on ModelFileCollisionException {
        // expected
      }

      expect(File(modelPath).readAsStringSync(), contentAfterFirst);
    });
  });

  group('Round-trip: JSON -> fromJson -> Model instance -> toJson -> JSON', () {
    late Directory tempDir;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_model_roundtrip_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    /// A single representative JSON sample covering every V1.1-9 field
    /// kind at once: primitives (`id`/`name`/`score`/`active`), a
    /// nullable field (`nickname`), a primitive list (`tags`), a nested
    /// object (`address`), an object list (`friends`), and a reserved
    /// Dart keyword as a JSON key (`class`).
    const sampleJson = '{'
        '"id": 1, '
        '"name": "Alice", '
        '"score": 4.5, '
        '"active": true, '
        '"nickname": null, '
        '"tags": ["x", "y"], '
        '"address": {"city": "Metropolis", "zip": "12345"}, '
        '"friends": [{"id": 2, "name": "Bob"}], '
        '"class": "vip"'
        '}';

    test(
        'the generated model actually round-trips the sample unchanged '
        '— verified by really executing the generated fromJson/toJson, '
        'not by matching strings', () async {
      final decoded = jsonDecode(sampleJson);
      final classes = ModelGenerator().inferClasses(
        rootBaseName: 'RoundTripSample',
        decodedJson: decoded,
      );
      final root = classes.first;
      final rootSource = ModelGenerator().renderSource(root);

      // 1 & 2: the generated source contains the expected fromJson/toJson.
      expect(
        rootSource,
        contains('factory RoundTripSampleModel.fromJson('
            'Map<String, dynamic> json)'),
      );
      expect(rootSource, contains('Map<String, dynamic> toJson()'));

      // 7: a reserved Dart keyword is escaped only in the Dart field
      // name — the original JSON key is untouched in both directions.
      expect(rootSource, contains('final String class_;'));
      expect(rootSource, contains("json['class'] as String"));
      expect(rootSource, contains("'class': class_"));
      expect(rootSource, isNot(contains("'class_'")));

      // Write every generated class (root + nested Address + the
      // FriendsItem object-list class) to its own file, matching
      // ModelLifecycle's real `<fileBaseName>_model.dart` naming exactly
      // — including their real cross-file relative imports.
      for (final generatedClass in classes) {
        File('${tempDir.path}/${generatedClass.fileBaseName}_model.dart')
            .writeAsStringSync(ModelGenerator().renderSource(generatedClass));
      }

      // A tiny, real driver script that actually calls the generated
      // fromJson/toJson — this is what makes the test a genuine
      // "JSON -> fromJson -> Model instance -> toJson -> JSON" round
      // trip rather than another string-matching assertion on the
      // rendered source.
      final driverPath = '${tempDir.path}/round_trip_main.dart';
      await File(driverPath).writeAsString('''
import 'dart:convert';
import 'dart:io';
import '${root.fileBaseName}_model.dart';

void main() {
  final decoded = jsonDecode(r'$sampleJson') as Map<String, dynamic>;
  final model = ${root.className}.fromJson(decoded);
  stdout.write(jsonEncode(model.toJson()));
}
''');

      final result = await Process.run(
        Platform.resolvedExecutable,
        [driverPath],
      );

      expect(result.exitCode, 0,
          reason: 'generated model failed to compile/run:\n'
              '${result.stdout}\n${result.stderr}');

      final roundTripped = jsonDecode(result.stdout as String);

      // 3/4/5/6, verified by real execution rather than string matching:
      // fromJson mapped every JSON key to the right field, toJson
      // preserved every original JSON key (including the escaped
      // reserved-word field, and every key nested inside the object and
      // the object list), the null field stayed null, and both the
      // nested object and the object list preserved their structure.
      expect(roundTripped, decoded);
    });
  });
}

String _baseNameOf(String filePath) {
  final normalized = filePath.replaceAll('\\', '/');
  final base = normalized.substring(normalized.lastIndexOf('/') + 1);
  final withoutExt =
      base.contains('.') ? base.substring(0, base.lastIndexOf('.')) : base;
  return NamingConventions.toSnakeCase(
    NamingConventions.toPascalCase(withoutExt),
  );
}
