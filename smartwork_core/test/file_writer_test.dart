import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('FileWriter', () {
    late Directory tempDir;
    late FileWriter fileWriter;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('smartwork_filewriter_test_');
      fileWriter = FileWriter();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('writes a file to an existing directory', () async {
      final filePath = path.join(tempDir.path, 'test.txt');
      const content = 'Hello, World!';

      await fileWriter.write(filePath, content);

      final file = File(filePath);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), equals(content));
    });

    test('creates parent directories if they do not exist', () async {
      final filePath = path.join(tempDir.path, 'subdir', 'test.txt');
      const content = 'Test content';

      await fileWriter.write(filePath, content);

      final file = File(filePath);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), equals(content));

      final parentDir = Directory(path.join(tempDir.path, 'subdir'));
      expect(await parentDir.exists(), isTrue);
    });

    test('creates deeply nested parent directories', () async {
      final filePath =
          path.join(tempDir.path, 'a', 'b', 'c', 'd', 'e', 'test.txt');
      const content = 'Nested content';

      await fileWriter.write(filePath, content);

      final file = File(filePath);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), equals(content));
    });

    test('overwrites existing files', () async {
      final filePath = path.join(tempDir.path, 'test.txt');
      const content1 = 'First content';
      const content2 = 'Second content';

      await fileWriter.write(filePath, content1);
      expect(await File(filePath).readAsString(), equals(content1));

      await fileWriter.write(filePath, content2);
      expect(await File(filePath).readAsString(), equals(content2));
    });

    test('handles empty content', () async {
      final filePath = path.join(tempDir.path, 'empty.txt');

      await fileWriter.write(filePath, '');

      final file = File(filePath);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), isEmpty);
    });

    test('handles large content', () async {
      final filePath = path.join(tempDir.path, 'large.txt');
      final content = 'x' * 10000;

      await fileWriter.write(filePath, content);

      final file = File(filePath);
      expect(await file.readAsString(), equals(content));
    });

    test('handles multiline content', () async {
      final filePath = path.join(tempDir.path, 'multiline.dart');
      const content = '''class MyClass {
  final String name;

  MyClass(this.name);
}
''';

      await fileWriter.write(filePath, content);

      final file = File(filePath);
      expect(await file.readAsString(), equals(content));
    });

    test('handles special characters in content', () async {
      final filePath = path.join(tempDir.path, 'special.txt');
      const content = 'Test with "quotes" and \'apostrophes\' and \n newlines';

      await fileWriter.write(filePath, content);

      final file = File(filePath);
      expect(await file.readAsString(), equals(content));
    });

    test('handles unicode content', () async {
      final filePath = path.join(tempDir.path, 'unicode.txt');
      const content = 'Hello 世界 🌍 مرحبا мир';

      await fileWriter.write(filePath, content);

      final file = File(filePath);
      expect(await file.readAsString(), equals(content));
    });

    test('preserves existing sibling files', () async {
      final file1Path = path.join(tempDir.path, 'file1.txt');
      final file2Path = path.join(tempDir.path, 'file2.txt');

      await fileWriter.write(file1Path, 'Content 1');
      await fileWriter.write(file2Path, 'Content 2');

      expect(await File(file1Path).readAsString(), equals('Content 1'));
      expect(await File(file2Path).readAsString(), equals('Content 2'));
    });

    test('works with nested paths in subdirectories', () async {
      final file1 = path.join(tempDir.path, 'lib', 'main.dart');
      final file2 = path.join(tempDir.path, 'test', 'main_test.dart');

      await fileWriter.write(file1, 'void main() {}');
      await fileWriter.write(file2, 'void testMain() {}');

      expect(await File(file1).exists(), isTrue);
      expect(await File(file2).exists(), isTrue);
      expect(await File(file1).readAsString(), equals('void main() {}'));
      expect(await File(file2).readAsString(), equals('void testMain() {}'));
    });
  });
}
