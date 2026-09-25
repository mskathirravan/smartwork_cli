import 'package:smartwork_core/smartwork_core.dart';
import 'package:test/test.dart';

void main() {
  group('ThemeServiceTemplates.appThemeTestTemplate', () {
    test(
        'a Google Font project uses testWidgets for every AppTheme test, so '
        'a failed background font download under google_fonts <8.2.1 '
        '(older Flutter SDKs) never fails the suite', () {
      final content = ThemeServiceTemplates.appThemeTestTemplate(
        FontConfig.google(GoogleFontConfig(family: 'Roboto')),
      ).content;

      expect(RegExp(r'^  testWidgets\(', multiLine: true).allMatches(content),
          hasLength(4));
      expect(content, isNot(contains(RegExp(r'^  test\(', multiLine: true))));
    });

    test('a project without a Google Font keeps plain test() cases', () {
      final content = ThemeServiceTemplates.appThemeTestTemplate(
        FontConfig.none(),
      ).content;

      expect(RegExp(r'^  test\(', multiLine: true).allMatches(content),
          hasLength(3));
      expect(content, isNot(contains('testWidgets(')));
    });
  });
}
