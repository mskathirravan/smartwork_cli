import '../../../models/service_definition.dart';

String eventBusServiceSource() {
  return '''import 'dart:async';

/// Application-level, in-memory, typed publish/subscribe primitive for
/// application events.
///
/// Not a state-management system, message broker, persistence
/// mechanism, queue, or background worker — a lightweight way for
/// unrelated parts of the app to notify each other about something
/// that happened, without a direct reference to one another. Event
/// classes are ordinary Dart classes; no SmartWork base class is
/// required:
///
/// ```dart
/// class UserLoggedInEvent {
///   UserLoggedInEvent(this.userId);
///   final String userId;
/// }
///
/// EventBusService.instance.subscribe<UserLoggedInEvent>((event) {
///   // react to login
/// });
///
/// EventBusService.instance.publish(UserLoggedInEvent('42'));
/// ```
class EventBusService {
  EventBusService._();

  static final EventBusService instance = EventBusService._();

  final Map<Type, List<Function>> _handlers = {};

  /// Registers [handler] to be invoked with every event of type [T]
  /// published after this call. Subscribing the same [handler]
  /// reference more than once registers it that many times: [publish]
  /// invokes it once per registration, and each [unsubscribe] call
  /// removes exactly one registration.
  void subscribe<T>(void Function(T event) handler) {
    (_handlers[T] ??= <Function>[]).add(handler);
  }

  /// Removes one registration of [handler] for event type [T] — the
  /// exact same function reference passed to [subscribe]. A [handler]
  /// that is not currently subscribed is a safe no-op.
  void unsubscribe<T>(void Function(T event) handler) {
    _handlers[T]?.remove(handler);
  }

  /// Synchronously invokes every handler currently subscribed to [T]
  /// — the type parameter, not `event.runtimeType` — in registration
  /// order. Safe to call with no subscribers.
  ///
  /// If a handler throws, the exception is isolated: every other
  /// handler still runs, and the original error (with its stack trace)
  /// is rethrown asynchronously so it is never silently swallowed —
  /// SmartWork adds no error-reporting integration of its own here;
  /// wiring a handler exception into crash reporting (or anywhere
  /// else) is the application's own decision.
  void publish<T>(T event) {
    final handlers = _handlers[T];
    if (handlers == null || handlers.isEmpty) return;

    for (final handler in List<Function>.from(handlers)) {
      try {
        (handler as void Function(T))(event);
      } catch (error, stackTrace) {
        scheduleMicrotask(() => Error.throwWithStackTrace(error, stackTrace));
      }
    }
  }
}
''';
}

String eventBusServiceTestSource(String projectName) {
  final importPath =
      'package:$projectName/services/${Service.eventBus.folderName}/'
      'event_bus_service.dart';
  return '''import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '$importPath';

class _TestEventA {
  const _TestEventA();
}

class _TestEventB {
  const _TestEventB();
}

void main() {
  test('instance is a singleton', () {
    final a = EventBusService.instance;
    final b = EventBusService.instance;
    expect(a, same(b));
  });

  test('publish() with no subscribers does not throw', () {
    expect(
      () => EventBusService.instance.publish(const _TestEventA()),
      returnsNormally,
    );
  });

  test('subscribe() then publish() invokes the handler with the event', () {
    _TestEventA? received;
    void handler(_TestEventA event) => received = event;
    const event = _TestEventA();

    EventBusService.instance.subscribe<_TestEventA>(handler);
    EventBusService.instance.publish<_TestEventA>(event);

    expect(received, same(event));

    EventBusService.instance.unsubscribe<_TestEventA>(handler);
  });

  test('every subscriber for the same type is invoked, in registration '
      'order', () {
    final received = <String>[];
    void handlerA(_TestEventA event) => received.add('A');
    void handlerB(_TestEventA event) => received.add('B');
    void handlerC(_TestEventA event) => received.add('C');

    EventBusService.instance.subscribe<_TestEventA>(handlerA);
    EventBusService.instance.subscribe<_TestEventA>(handlerB);
    EventBusService.instance.subscribe<_TestEventA>(handlerC);

    EventBusService.instance.publish<_TestEventA>(const _TestEventA());

    expect(received, ['A', 'B', 'C']);

    EventBusService.instance.unsubscribe<_TestEventA>(handlerA);
    EventBusService.instance.unsubscribe<_TestEventA>(handlerB);
    EventBusService.instance.unsubscribe<_TestEventA>(handlerC);
  });

  test('a subscriber to one type never receives a different type', () {
    var invoked = false;
    void handler(_TestEventA event) => invoked = true;

    EventBusService.instance.subscribe<_TestEventA>(handler);
    EventBusService.instance.publish<_TestEventB>(const _TestEventB());

    expect(invoked, isFalse);

    EventBusService.instance.unsubscribe<_TestEventA>(handler);
  });

  test('unsubscribe() stops the handler from receiving further events', () {
    var callCount = 0;
    void handler(_TestEventA event) => callCount++;

    EventBusService.instance.subscribe<_TestEventA>(handler);
    EventBusService.instance.publish<_TestEventA>(const _TestEventA());
    EventBusService.instance.unsubscribe<_TestEventA>(handler);
    EventBusService.instance.publish<_TestEventA>(const _TestEventA());

    expect(callCount, 1);
  });

  test('subscribing the same handler twice invokes it twice per publish, '
      'and each unsubscribe() removes exactly one registration', () {
    var callCount = 0;
    void handler(_TestEventA event) => callCount++;

    EventBusService.instance.subscribe<_TestEventA>(handler);
    EventBusService.instance.subscribe<_TestEventA>(handler);
    EventBusService.instance.publish<_TestEventA>(const _TestEventA());

    expect(callCount, 2);

    EventBusService.instance.unsubscribe<_TestEventA>(handler);
    EventBusService.instance.publish<_TestEventA>(const _TestEventA());

    expect(callCount, 3);

    EventBusService.instance.unsubscribe<_TestEventA>(handler);
  });

  test('a throwing handler does not prevent other subscribers from being '
      'notified, and its exception is rethrown asynchronously rather '
      'than swallowed', () async {
    final received = <String>[];
    void throwingHandler(_TestEventA event) => throw Exception('boom');
    void otherHandler(_TestEventA event) => received.add('other');

    Object? uncaught;
    await runZonedGuarded(
      () async {
        EventBusService.instance.subscribe<_TestEventA>(throwingHandler);
        EventBusService.instance.subscribe<_TestEventA>(otherHandler);

        EventBusService.instance.publish<_TestEventA>(const _TestEventA());

        await Future<void>.delayed(Duration.zero);
      },
      (error, stackTrace) {
        uncaught = error;
      },
    );

    expect(received, ['other']);
    expect(uncaught, isNotNull);

    EventBusService.instance.unsubscribe<_TestEventA>(throwingHandler);
    EventBusService.instance.unsubscribe<_TestEventA>(otherHandler);
  });
}
''';
}
