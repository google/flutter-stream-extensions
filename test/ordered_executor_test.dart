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

import 'package:mockito/mockito.dart';
import 'package:flutter_stream_extensions/ordered_executor.dart';
import 'package:test/test.dart';

void main() {
  group(OrderedExecutor, () {
    late OrderedExecutor<int, String> executor;
    late MockCallback callback;

    setUp(() {
      callback = MockCallback();
    });

    tearDown(() {
      executor.dispose();
    });

    group('after disposal', () {
      setUp(() {
        executor = OrderedExecutor<int, String>(callback)..dispose();
      });

      test('throws from run()', () {
        expect(() => executor.run(123), throwsStateError);
        verifyNever(callback.call(any));
      });
    });

    group('with no prior param', () {
      setUp(() {
        executor = OrderedExecutor<int, String>(callback);
      });

      test('returns done with param and valid result', () {
        when(callback.call(123)).thenAnswer((_) async => 'value123');
        expect(executor.run(123), completion(ExecutionStatus.done));
        expect(executor.result.stream, emits('value123'));
        verify(callback.call(123));
        verifyNoMoreInteractions(callback);
      });

      test('returns done with param and error', () {
        when(callback.call(-456)).thenAnswer((_) async {
          throw 'error-456';
        });
        expect(executor.run(-456), completion(ExecutionStatus.done));
        expect(executor.result.stream, emitsError('error-456'));
        verify(callback.call(-456));
        verifyNoMoreInteractions(callback);
      });

      test('returns aborted when the execution completes after disposal', () {
        expect(executor.run(123), completion(ExecutionStatus.aborted));
        executor.dispose();
        verify(callback.call(123));
        verifyNoMoreInteractions(callback);
      });
    });

    group('with pending prior param', () {
      setUp(() {
        when(callback.call(123)).thenAnswer((_) async => 'value123');
        executor = OrderedExecutor<int, String>(callback);
      });

      test('does not start a new execution from run() with the same param', () {
        final prior = executor.run(123);
        final current = executor.run(123);
        expect(prior, completion(ExecutionStatus.done));
        expect(current, completion(ExecutionStatus.done));
        expect(executor.result.stream, emits('value123'));
        verify(callback.call(123));
        verifyNoMoreInteractions(callback);
      });

      test('starts a new execution from run() with a different param', () {
        when(callback.call(456)).thenAnswer((_) async => 'value456');
        final prior = executor.run(123);
        final current = executor.run(456);
        expect(prior, completion(ExecutionStatus.preempted));
        expect(current, completion(ExecutionStatus.done));
        expect(executor.result.stream, emits('value456'));
        verify(callback.call(123));
        verify(callback.call(456));
        verifyNoMoreInteractions(callback);
      });
    });

    group('with completed prior param', () {
      setUp(() {
        when(callback.call(123)).thenAnswer((_) async => 'value123');
        executor = OrderedExecutor<int, String>(callback);
      });

      test('starts a new execution with the same param', () async {
        final prior = executor.run(123);
        await pumpEventQueue();
        final current = executor.run(123);
        expect(prior, completion(ExecutionStatus.done));
        expect(current, completion(ExecutionStatus.done));
        expect(
          executor.result.stream,
          emitsInOrder([
            'value123',
            'value123',
          ]),
        );
        verify(callback.call(123)).called(2);
        verifyNoMoreInteractions(callback);
      });

      test('starts a new execution with a different param', () async {
        when(callback.call(456)).thenAnswer((_) async => 'value456');
        final prior = executor.run(123);
        await pumpEventQueue();
        final current = executor.run(456);
        expect(prior, completion(ExecutionStatus.done));
        expect(current, completion(ExecutionStatus.done));
        expect(
          executor.result.stream,
          emitsInOrder([
            'value123',
            'value456',
          ]),
        );
        verify(callback.call(123));
        verify(callback.call(456));
        verifyNoMoreInteractions(callback);
      });
    });
  });
}

abstract class Callback {
  Future<String> call(int value);
}

class MockCallback extends Mock implements Callback {
  @override
  Future<String> call(int? value) =>
      super.noSuchMethod(Invocation.method(#start, [value]));
}
