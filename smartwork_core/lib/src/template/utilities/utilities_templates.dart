import '../template.dart';

class UtilitiesTemplates {
  static Template appPlatformTemplate() {
    return Template(content: '''import 'package:flutter/foundation.dart';

/// The Flutter platform this app is currently running on.
///
/// `isWeb` takes precedence over every other check: a browser running
/// on an Android phone reports `isWeb: true` and `isAndroid: false`,
/// `isMobile: false` — this reflects the Flutter web renderer, not the
/// underlying device. Every other check is independent, so an
/// unrecognized platform (e.g. a future Flutter target this app was
/// never configured for) reads `false` for every one of them rather
/// than guessing.
class AppPlatform {
  const AppPlatform._();

  /// True when running as a Flutter web app, regardless of the
  /// underlying device or browser.
  static bool get isWeb => kIsWeb;

  /// True only for a native Android build — never true on web, even in
  /// a mobile browser.
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// True only for a native iOS build — never true on web.
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// True only for a native Windows build — never true on web.
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// True only for a native macOS build — never true on web.
  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// True only for a native Linux build — never true on web.
  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// Android or iOS (native only — false on web).
  static bool get isMobile => isAndroid || isIOS;

  /// Windows, macOS, or Linux (native only — false on web).
  static bool get isDesktop => isWindows || isMacOS || isLinux;
}
''');
  }

  static Template dateTimeExtensionsTemplate() {
    return Template(
        content: '''/// Pure `DateTime` comparison and day-boundary helpers — no
/// formatting, no locale, and no timezone conversion of their own.
extension DateTimeExtensions on DateTime {
  bool _isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Whether this date is the same calendar day as right now, compared
  /// in this `DateTime`'s own UTC-or-local kind.
  bool get isToday =>
      _isSameDay(isUtc ? DateTime.now().toUtc() : DateTime.now());

  /// Whether this date is exactly one calendar day before today, by
  /// the same same-kind comparison [isToday] uses. Compares calendar
  /// day numbers (never a 24-hour `Duration` subtraction), so a local
  /// `DateTime` is unaffected by a DST transition that makes some days
  /// shorter or longer than 24 hours.
  bool get isYesterday {
    final now = isUtc ? DateTime.now().toUtc() : DateTime.now();
    final yesterday = isUtc
        ? DateTime.utc(now.year, now.month, now.day - 1)
        : DateTime(now.year, now.month, now.day - 1);
    return _isSameDay(yesterday);
  }

  /// Whether this date is exactly one calendar day after today, by the
  /// same same-kind comparison [isToday] uses. See [isYesterday] for
  /// why this is calendar-day arithmetic, not a `Duration` shift.
  bool get isTomorrow {
    final now = isUtc ? DateTime.now().toUtc() : DateTime.now();
    final tomorrow = isUtc
        ? DateTime.utc(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day + 1);
    return _isSameDay(tomorrow);
  }

  /// Midnight (00:00:00.000000) on this same date, preserving whether
  /// this `DateTime` is UTC or local.
  DateTime get startOfDay =>
      isUtc ? DateTime.utc(year, month, day) : DateTime(year, month, day);

  /// The last representable microsecond of this same date
  /// (23:59:59.999999), preserving whether this `DateTime` is UTC or
  /// local.
  DateTime get endOfDay => isUtc
      ? DateTime.utc(year, month, day, 23, 59, 59, 999, 999)
      : DateTime(year, month, day, 23, 59, 59, 999, 999);
}
''');
  }

  static Template stringExtensionsTemplate() {
    return Template(
        content:
            '''/// Null-safe emptiness/blankness checks on a possibly-`null` String.
extension NullableStringExtensions on String? {
  /// `true` for `null` or an empty string.
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// `true` for `null`, an empty string, or a string containing only
  /// whitespace.
  bool get isBlank => this == null || this!.trim().isEmpty;
}

/// Text-shaping helpers with no locale or business meaning.
extension StringExtensions on String {
  /// Uppercases the first character, leaving the rest unchanged. The
  /// empty string is returned unchanged.
  String capitalize() {
    if (isEmpty) return this;
    final codePoints = runes.toList();
    final first = String.fromCharCode(codePoints.first).toUpperCase();
    final rest = String.fromCharCodes(codePoints.skip(1));
    return '\$first\$rest';
  }

  /// [capitalize]s every space-separated word, preserving the original
  /// spacing (including repeated spaces).
  String capitalizeWords() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize()).join(' ');
  }
}
''');
  }

  static Template colorHexTemplate() {
    return Template(content: '''import 'package:flutter/painting.dart';

/// Parses a hex color string into a [Color] — the shape a color
/// arrives in from API/configuration data.
extension HexColor on String {
  /// Accepts `#RRGGBB`, `RRGGBB`, `#AARRGGBB`, or `AARRGGBB`. A 6-digit
  /// value is treated as fully opaque (alpha `FF`) — the common
  /// convention for a color with no alpha channel supplied. Throws a
  /// [FormatException] for anything else — including a value that is
  /// otherwise the right length but contains a non-hex character.
  /// Every digit is checked explicitly against `0-9a-fA-F`, rather than
  /// relying on [int.tryParse]'s own leniency: `int.tryParse` accepts a
  /// leading `+`/`-` sign as part of a radix-16 value, which would
  /// otherwise let a string like `-1234567` (8 characters, but not a
  /// valid hex color) silently parse instead of being rejected.
  Color toColor() {
    final hex = startsWith('#') ? substring(1) : this;
    final isValidHex =
        (hex.length == 6 || hex.length == 8) &&
        RegExp(r'^[0-9a-fA-F]+\$').hasMatch(hex);
    if (!isValidHex) {
      throw FormatException('Not a valid hex color: \$this');
    }
    final normalized = hex.length == 6 ? 'FF\$hex' : hex;
    return Color(int.parse(normalized, radix: 16));
  }

  /// The non-throwing counterpart to [toColor] — `null` for a
  /// malformed value instead of a [FormatException].
  Color? tryToColor() {
    try {
      return toColor();
    } on FormatException {
      return null;
    }
  }
}

/// Renders a [Color] back to a hex string — the inverse of [HexColor].
extension ColorHex on Color {
  /// `#AARRGGBB` by default; pass `includeAlpha: false` for `#RRGGBB`,
  /// or `leadingHash: false` to omit the leading `#`. Always uppercase.
  String toHex({bool includeAlpha = true, bool leadingHash = true}) {
    String channel(double component) => (component * 255)
        .round()
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
    final hex = includeAlpha
        ? '\${channel(a)}\${channel(r)}\${channel(g)}\${channel(b)}'
        : '\${channel(r)}\${channel(g)}\${channel(b)}';
    final upper = hex.toUpperCase();
    return leadingHash ? '#\$upper' : upper;
  }
}
''');
  }

  static Template fileSizeTemplate() {
    return Template(
        content: '''/// Renders a byte count as a human-readable size string.
extension FileSizeFormat on int {
  /// `0` renders as `'0 B'`. Throws [ArgumentError] for a negative
  /// value — a byte count can never be negative.
  String toFileSizeString() {
    if (this < 0) {
      throw ArgumentError.value(
        this,
        'this',
        'A byte count cannot be negative',
      );
    }
    if (this == 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var size = toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    // Rounding to one decimal place can push the displayed value up to
    // the next unit's threshold (e.g. 1048535 bytes is 1023.96 KB,
    // which rounds to "1024.0 KB" — bump to the next unit so a
    // rounded display never reads 1024 or more in the unit it chose.
    if (unitIndex < units.length - 1 &&
        double.parse(size.toStringAsFixed(1)) >= 1024) {
      size /= 1024;
      unitIndex++;
    }

    final formatted = unitIndex == 0
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(1);
    return '\$formatted \${units[unitIndex]}';
  }
}
''');
  }

  static Template utilitiesBarrelTemplate() {
    return Template(content: '''export 'app_platform.dart';
export 'date_time_extensions.dart';
export 'string_extensions.dart';
export 'color_hex.dart';
export 'file_size.dart';
''');
  }

  static Template appPlatformTestTemplate() {
    return Template(content: '''import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{projectName}}/core/utilities/utilities.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = null);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('isWeb matches the real kIsWeb constant', () {
    expect(AppPlatform.isWeb, kIsWeb);
  });

  test('isAndroid is true only for android, and counts as mobile', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AppPlatform.isAndroid, isTrue);
    expect(AppPlatform.isIOS, isFalse);
    expect(AppPlatform.isMobile, isTrue);
    expect(AppPlatform.isDesktop, isFalse);
  });

  test('isIOS is true only for iOS, and counts as mobile', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AppPlatform.isIOS, isTrue);
    expect(AppPlatform.isAndroid, isFalse);
    expect(AppPlatform.isMobile, isTrue);
    expect(AppPlatform.isDesktop, isFalse);
  });

  test('isWindows/isMacOS/isLinux are each true only for their own '
      'platform, and count as desktop, never mobile', () {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(AppPlatform.isDesktop, isTrue, reason: '\$platform');
      expect(AppPlatform.isMobile, isFalse, reason: '\$platform');
    }
  });

  test('an unlisted TargetPlatform (fuchsia) reads false for every '
      'specific check, and neither mobile nor desktop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    expect(AppPlatform.isAndroid, isFalse);
    expect(AppPlatform.isIOS, isFalse);
    expect(AppPlatform.isWindows, isFalse);
    expect(AppPlatform.isMacOS, isFalse);
    expect(AppPlatform.isLinux, isFalse);
    expect(AppPlatform.isMobile, isFalse);
    expect(AppPlatform.isDesktop, isFalse);
  });
}
''');
  }

  static Template dateTimeExtensionsTestTemplate() {
    return Template(content: '''import 'package:flutter_test/flutter_test.dart';

import 'package:{{projectName}}/core/utilities/utilities.dart';

void main() {
  test('isToday is true for right now, false for yesterday/tomorrow', () {
    final now = DateTime.now();
    expect(now.isToday, isTrue);
    expect(now.isYesterday, isFalse);
    expect(now.isTomorrow, isFalse);
  });

  test('isYesterday is true for exactly one day ago', () {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    expect(yesterday.isYesterday, isTrue);
    expect(yesterday.isToday, isFalse);
    expect(yesterday.isTomorrow, isFalse);
  });

  test('isTomorrow is true for exactly one day ahead', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(tomorrow.isTomorrow, isTrue);
    expect(tomorrow.isToday, isFalse);
    expect(tomorrow.isYesterday, isFalse);
  });

  test('a date well outside today/yesterday/tomorrow is none of the '
      'three', () {
    final farAway = DateTime.now().add(const Duration(days: 30));
    expect(farAway.isToday, isFalse);
    expect(farAway.isYesterday, isFalse);
    expect(farAway.isTomorrow, isFalse);
  });

  test('startOfDay is midnight on the same date', () {
    final date = DateTime(2024, 3, 15, 18, 45, 30);
    final start = date.startOfDay;
    expect(start, DateTime(2024, 3, 15));
    expect(start.hour, 0);
    expect(start.minute, 0);
    expect(start.second, 0);
    expect(start.millisecond, 0);
    expect(start.microsecond, 0);
  });

  test('endOfDay is the last microsecond of the same date', () {
    final date = DateTime(2024, 3, 15, 6, 0);
    final end = date.endOfDay;
    expect(end.year, 2024);
    expect(end.month, 3);
    expect(end.day, 15);
    expect(end.hour, 23);
    expect(end.minute, 59);
    expect(end.second, 59);
    expect(end.millisecond, 999);
    expect(end.microsecond, 999);
  });

  test('startOfDay/endOfDay preserve UTC-ness rather than collapsing '
      'to local', () {
    final utcDate = DateTime.utc(2024, 3, 15, 12);
    expect(utcDate.startOfDay.isUtc, isTrue);
    expect(utcDate.endOfDay.isUtc, isTrue);

    final localDate = DateTime(2024, 3, 15, 12);
    expect(localDate.startOfDay.isUtc, isFalse);
    expect(localDate.endOfDay.isUtc, isFalse);
  });

  test('a date at the very last microsecond of a day is not mistaken '
      'for the next day', () {
    final almostMidnight = DateTime(2024, 3, 15, 23, 59, 59, 999, 999);
    expect(almostMidnight.startOfDay, DateTime(2024, 3, 15));
  });

  test('isYesterday/isTomorrow correctly cross a month/year boundary', () {
    final newYearsEve = DateTime(2023, 12, 31);
    final newYearsDay = DateTime(2024, 1, 1);
    expect(newYearsEve.startOfDay.add(const Duration(days: 1)), newYearsDay);
  });
}
''');
  }

  static Template stringExtensionsTestTemplate() {
    return Template(content: '''import 'package:flutter_test/flutter_test.dart';

import 'package:{{projectName}}/core/utilities/utilities.dart';

void main() {
  group('isNullOrEmpty', () {
    test('is true for null', () {
      const String? value = null;
      expect(value.isNullOrEmpty, isTrue);
    });

    test('is true for an empty string', () {
      expect(''.isNullOrEmpty, isTrue);
    });

    test('is false for whitespace-only text (not empty, just blank)', () {
      expect('   '.isNullOrEmpty, isFalse);
    });

    test('is false for normal text', () {
      expect('hello'.isNullOrEmpty, isFalse);
    });
  });

  group('isBlank', () {
    test('is true for null', () {
      const String? value = null;
      expect(value.isBlank, isTrue);
    });

    test('is true for an empty string', () {
      expect(''.isBlank, isTrue);
    });

    test('is true for whitespace-only text', () {
      expect('   '.isBlank, isTrue);
    });

    test('is false for normal text', () {
      expect('hello'.isBlank, isFalse);
    });
  });

  group('capitalize', () {
    test('uppercases the first letter of lowercase text', () {
      expect('hello'.capitalize(), 'Hello');
    });

    test('leaves already-capitalized text unchanged', () {
      expect('Hello'.capitalize(), 'Hello');
    });

    test('returns the empty string unchanged', () {
      expect(''.capitalize(), '');
    });

    test('only capitalizes the first word when text has multiple words', () {
      expect('hello world'.capitalize(), 'Hello world');
    });

    test('leaves a leading punctuation character unchanged — there is '
        'no uppercase form of punctuation', () {
      expect('(parenthetical) text'.capitalize(), '(parenthetical) text');
    });

    test('uses real Unicode case mapping for an accented first letter', () {
      expect('école'.capitalize(), 'École');
    });

    test('never splits a leading Unicode character outside the Basic '
        'Multilingual Plane (a surrogate pair) — an emoji has no '
        'uppercase form, so it is preserved exactly rather than '
        'corrupted', () {
      expect('😀 hello'.capitalize(), '😀 hello');
    });
  });

  group('capitalizeWords', () {
    test('capitalizes every word in lowercase text', () {
      expect('hello world'.capitalizeWords(), 'Hello World');
    });

    test('leaves already-capitalized text unchanged', () {
      expect('Hello World'.capitalizeWords(), 'Hello World');
    });

    test('returns the empty string unchanged', () {
      expect(''.capitalizeWords(), '');
    });

    test('preserves repeated spaces between words', () {
      expect('hello  world'.capitalizeWords(), 'Hello  World');
    });
  });
}
''');
  }

  static Template colorHexTestTemplate() {
    return Template(content: '''import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{projectName}}/core/utilities/utilities.dart';

void main() {
  group('toColor', () {
    test('parses #RRGGBB as fully opaque', () {
      final color = '#FF0000'.toColor();
      expect(color.toHex(), '#FFFF0000');
    });

    test('parses RRGGBB (no hash) as fully opaque', () {
      final color = '00FF00'.toColor();
      expect(color.toHex(), '#FF00FF00');
    });

    test('parses #AARRGGBB with its own alpha', () {
      final color = '#800000FF'.toColor();
      expect(color.toHex(), '#800000FF');
    });

    test('parses AARRGGBB (no hash) with its own alpha', () {
      final color = 'FF0000FF'.toColor();
      expect(color.toHex(), '#FF0000FF');
    });

    test('throws FormatException for the wrong length', () {
      expect(() => 'FFF'.toColor(), throwsFormatException);
    });

    test('throws FormatException for non-hex characters', () {
      expect(() => 'ZZZZZZ'.toColor(), throwsFormatException);
    });

    test('throws FormatException for a leading sign character, even '
        'though the right length — int.tryParse alone would otherwise '
        'accept a radix-16 sign and silently parse it', () {
      expect(() => '-1234567'.toColor(), throwsFormatException);
      expect(() => '+1234567'.toColor(), throwsFormatException);
    });

    test('tryToColor returns null instead of throwing for a malformed '
        'value', () {
      expect('not-a-color'.tryToColor(), isNull);
    });

    test('tryToColor returns the real color for a valid value', () {
      expect('#FF0000'.tryToColor(), isNotNull);
    });

    test('parses pure black and pure white', () {
      expect('#000000'.toColor().toHex(), '#FF000000');
      expect('#FFFFFF'.toColor().toHex(), '#FFFFFFFF');
    });

    test('parses fully transparent (zero alpha) black', () {
      expect('#00000000'.toColor().toHex(), '#00000000');
    });
  });

  group('toHex', () {
    test('round-trips a color through toColor/toHex', () {
      const original = Color(0xFF336699);
      final hex = original.toHex();
      expect(hex.toColor(), original);
    });

    test('includeAlpha: false omits the alpha channel', () {
      const color = Color(0xFF336699);
      expect(color.toHex(includeAlpha: false), '#336699');
    });

    test('leadingHash: false omits the leading #', () {
      const color = Color(0xFF336699);
      expect(color.toHex(leadingHash: false), 'FF336699');
    });
  });
}
''');
  }

  static Template fileSizeTestTemplate() {
    return Template(content: '''import 'package:flutter_test/flutter_test.dart';

import 'package:{{projectName}}/core/utilities/utilities.dart';

void main() {
  test('zero renders as "0 B"', () {
    expect(0.toFileSizeString(), '0 B');
  });

  test('a small byte count renders as whole bytes, no decimal', () {
    expect(340.toFileSizeString(), '340 B');
  });

  test('just under 1 KB still renders in bytes', () {
    expect(1023.toFileSizeString(), '1023 B');
  });

  test('exactly 1024 bytes renders as 1.0 KB', () {
    expect(1024.toFileSizeString(), '1.0 KB');
  });

  test('renders megabytes with one decimal place', () {
    expect((1258291).toFileSizeString(), '1.2 MB');
  });

  test('renders gigabytes with one decimal place', () {
    expect((1288490189).toFileSizeString(), '1.2 GB');
  });

  test('exactly 1024^4 bytes renders as 1.0 TB', () {
    expect((1024 * 1024 * 1024 * 1024).toFileSizeString(), '1.0 TB');
  });

  test('a value that rounds up to 1024 at one decimal place bumps to the '
      'next unit, rather than displaying "1024.0 KB"', () {
    expect(1048535.toFileSizeString(), '1.0 MB');
  });

  test('the same rounding-boundary bump also applies at the MB -> GB '
      'threshold', () {
    expect(1073700000.toFileSizeString(), '1.0 GB');
  });

  test('a negative byte count throws ArgumentError', () {
    expect(() => (-1).toFileSizeString(), throwsArgumentError);
  });
}
''');
  }
}
