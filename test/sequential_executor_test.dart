// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:streams/sequential_executor.dart';
import 'package:quiver/check.dart';
import 'package:test/test.dart';

void main() {
  group(SequentialExecutor, () {
    late SequentialExecutor executor;
    late Task<int?> intTask;
    late Task<String?> stringTask;
    late Task<double?> doubleTask;

    setUp(() {
      executor = SequentialExecutor();
      intTask = Task<int?>();
      stringTask = Task<String?>();
      doubleTask = Task<double?>();
    });

    tearDown(() {
      if (!intTask.isCompleted) {
        intTask.complete(null);
      }
      if (!stringTask.isCompleted) {
        stringTask.complete(null);
      }
      if (!doubleTask.isCompleted) {
        doubleTask.complete(null);
      }
    });

    group('with multiple zones', () {
      late Zone siblingA;
      late Zone siblingB;
      late Zone childA;

      setUp(() {
        // Create a tree of zones:
        // ```
        //        [current]
        //         /    \
        // [siblingA]   [siblingB]
        //     |
        //  [childA]
        // ```
        siblingA = Zone.current.fork();
        siblingB = Zone.current.fork();
        childA = siblingA.fork();
      });

      test('can run tasks from sibling zones', () async {
        siblingA.run(() {
          expect(executor.run(intTask), completion(123));
        });
        siblingB.run(() {
          expect(executor.run(stringTask), completion('abc'));
        });
        expect(intTask.called, isTrue);
        expect(stringTask.called, isFalse);
        siblingA.run(() {
          intTask.complete(123);
        });
        await pumpEventQueue();
        expect(stringTask.called, isTrue);
        siblingB.run(() {
          stringTask.complete('abc');
        });
      });

      test('can run tasks from the zone and its child zone', () async {
        siblingA.run(() {
          expect(executor.run(intTask), completion(123));
        });
        childA.run(() {
          expect(executor.run(stringTask), completion('abc'));
        });
        expect(intTask.called, isTrue);
        expect(stringTask.called, isFalse);
        siblingA.run(() {
          intTask.complete(123);
        });
        await pumpEventQueue();
        expect(stringTask.called, isTrue);
        childA.run(() {
          stringTask.complete('abc');
        });
      });

      test('is not affected by errors from a sibling-zoned task', () async {
        siblingA.run(() {
          expect(executor.run(intTask), throwsStateError);
        });
        siblingB.run(() {
          expect(executor.run(stringTask), completion('abc'));
        });
        expect(intTask.called, isTrue);
        expect(stringTask.called, isFalse);
        siblingA.run(() {
          intTask.completeError(StateError('fatal'));
        });
        await pumpEventQueue();
        expect(stringTask.called, isTrue);
        siblingB.run(() {
          stringTask.complete('abc');
        });
      });

      test('is not affected by errors from a parent-zoned task', () async {
        siblingA.run(() {
          expect(executor.run(intTask), throwsStateError);
        });
        childA.run(() {
          expect(executor.run(stringTask), completion('abc'));
        });
        expect(intTask.called, isTrue);
        expect(stringTask.called, isFalse);
        siblingA.run(() {
          intTask.completeError(StateError('fatal'));
        });
        await pumpEventQueue();
        expect(stringTask.called, isTrue);
        childA.run(() {
          stringTask.complete('abc');
        });
      });

      test('is not affected by errors from a child-zoned task', () async {
        childA.run(() {
          expect(executor.run(intTask), throwsStateError);
        });
        siblingA.run(() {
          expect(executor.run(stringTask), completion('abc'));
        });
        expect(intTask.called, isTrue);
        expect(stringTask.called, isFalse);
        childA.run(() {
          intTask.completeError(StateError('fatal'));
        });
        await pumpEventQueue();
        expect(stringTask.called, isTrue);
        siblingA.run(() {
          stringTask.complete('abc');
        });
      });
    });

    group('without pending tasks', () {
      test('runs immediately', () {
        executor.run(intTask);
        expect(intTask.called, isTrue);
      });

      test('returns expected value when completed', () {
        expect(executor.run(intTask), completion(123));
        intTask.complete(123);
      });

      test('returns expected error when completed', () {
        expect(executor.run(intTask), throwsA('big error'));
        intTask.completeError('big error');
      });
    });

    group('with a pending task', () {
      setUp(() {
        // Make sure to catch all errors here to prevent any throwable from
        // going to the Zone error reporter.
        executor.run(intTask).catchError((_) {});
      });

      test('does not run immediately', () {
        executor.run(stringTask);
        expect(stringTask.called, isFalse);
      });

      group('after predecessor completes with value', () {
        late Future<String?> stringResult;

        setUp(() async {
          stringResult = executor.run(stringTask);
          intTask.complete(123);
          await pumpEventQueue();
        });

        test('runs now', () {
          expect(stringTask.called, isTrue);
        });

        test('returns expected value when completed', () {
          expect(stringResult, completion('abc'));
          stringTask.complete('abc');
        });

        test('returns expected error when completed', () {
          expect(stringResult, throwsA('huge error'));
          stringTask.completeError('huge error');
        });
      });

      group('after predecessor completes with error', () {
        late Future<String?> stringResult;

        setUp(() async {
          stringResult = executor.run(stringTask);
          intTask.completeError('big error');
          await pumpEventQueue();
        });

        test('runs now', () {
          expect(stringTask.called, isTrue);
        });

        test('returns expected value when completed', () {
          expect(stringResult, completion('abc'));
          stringTask.complete('abc');
        });

        test('returns expected error when completed', () {
          expect(stringResult, throwsA('huge error'));
          stringTask.completeError('huge error');
        });
      });
    });

    // Verifies the ordering of pending tasks.
    group('with two pending tasks', () {
      late Future<double?> doubleResult;

      setUp(() {
        // Make sure to catch all errors here to prevent any throwable from
        // going to the Zone error reporter.
        executor.run(intTask).catchError((_) {});
        executor.run(stringTask).catchError((_) {});
        doubleResult = executor.run(doubleTask);
      });

      test('does not run immediately', () {
        expect(doubleTask.called, isFalse);
      });

      group('and first pending task completes with value', () {
        setUp(() async {
          intTask.complete(123);
          await pumpEventQueue();
        });

        test('still does not run', () {
          expect(doubleTask.called, isFalse);
        });

        group('and second pending task completes with value', () {
          setUp(() async {
            stringTask.complete('abc');
            await pumpEventQueue();
          });

          test('runs now', () {
            expect(doubleTask.called, isTrue);
          });

          test('returns expected value when completed', () {
            expect(doubleResult, completion(1.2));
            doubleTask.complete(1.2);
          });

          test('returns expected error when completed', () {
            expect(doubleResult, throwsA('fatal error'));
            doubleTask.completeError('fatal error');
          });
        });

        group('and second pending task completes with error', () {
          setUp(() async {
            stringTask.completeError('huge error');
            await pumpEventQueue();
          });

          test('runs now', () {
            expect(doubleTask.called, isTrue);
          });

          test('returns expected value when completed', () {
            expect(doubleResult, completion(1.2));
            doubleTask.complete(1.2);
          });

          test('returns expected error when completed', () {
            expect(doubleResult, throwsA('fatal error'));
            doubleTask.completeError('fatal error');
          });
        });
      });

      group('and first pending task completes with error', () {
        setUp(() async {
          intTask.completeError('big error');
          await pumpEventQueue();
        });

        test('still does not run', () {
          expect(doubleTask.called, isFalse);
        });

        group('and second pending task completes with value', () {
          setUp(() async {
            stringTask.complete('abc');
            await pumpEventQueue();
          });

          test('runs now', () {
            expect(doubleTask.called, isTrue);
          });

          test('returns expected value when completed', () {
            expect(doubleResult, completion(1.2));
            doubleTask.complete(1.2);
          });

          test('returns expected error when completed', () {
            expect(doubleResult, throwsA('fatal error'));
            doubleTask.completeError('fatal error');
          });
        });

        group('and second pending task completes with error', () {
          setUp(() async {
            stringTask.completeError('huge error');
            await pumpEventQueue();
          });

          test('runs now', () {
            expect(doubleTask.called, isTrue);
          });

          test('returns expected value when completed', () {
            expect(doubleResult, completion(1.2));
            doubleTask.complete(1.2);
          });

          test('returns expected error when completed', () {
            expect(doubleResult, throwsA('fatal error'));
            doubleTask.completeError('fatal error');
          });
        });
      });
    });

    group('with an already completed task', () {
      setUp(() async {
        unawaited(executor.run(intTask).catchError((_) {}));
        intTask.complete(123);
        await pumpEventQueue();
      });

      test('runs immediately', () {
        executor.run(stringTask);
        expect(stringTask.called, isTrue);
      });

      test('returns expected value when completed', () {
        expect(executor.run(stringTask), completion('abc'));
        stringTask.complete('abc');
      });

      test('returns expected error when completed', () {
        expect(executor.run(stringTask), throwsA('huge error'));
        stringTask.completeError('huge error');
      });
    });
  });
}

/// A fake async task for unit testing.
class Task<T> {
  /// Whether this task has been called.
  bool get called => _called;
  bool _called = false;

  /// Completer of this task's returned future.
  final _completer = Completer<T>();

  /// Whether this task has completed, either with a value or an error.
  bool get isCompleted => _completer.isCompleted;

  /// Completes this task with [value].
  void complete(T value) => _completer.complete(value);

  /// Completes this task with [error].
  void completeError(Object error) => _completer.completeError(error);

  /// Calls this task. You don't have to call this method directly - the object
  /// itself is a function and can be called directly:
  ///
  /// ```dart
  /// final task = Task<String?>();
  /// // Invoke this task.
  /// task();
  /// ```
  ///
  /// This method prevents reentraincy - it throws [StateError] when called a
  /// second time.
  Future<T> call() {
    checkState(!_called);
    _called = true;
    return _completer.future;
  }
}
