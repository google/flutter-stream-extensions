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

import 'package:flutter_stream_extensions/replay_stream.dart';
import 'package:flutter_stream_extensions/stream_event.dart';
import 'package:test/test.dart';

void main() {
  group('ReplayStream', () {
    group('Stream contract', () {
      test('is broadcast', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.isBroadcast, isTrue);
      });

      /// This test verifies that [ReplayStream] is truly broadcast. It is easy
      /// to implement a [Stream] subclass that always returns true for its
      /// [isBroadcast] method but throws an exception when listened to twice.
      test('can be listened to concurrently', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        final listener1 = stream.listen((value) {});
        final listener2 = stream.listen((value) {});
        listener1.cancel();
        listener2.cancel();
      });

      test('has null initial event', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.event, isNull);
      });

      test('does not replay with null event', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream, emits(emitsDone));
      });

      test('replays initial data event', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent<int>.data(901),
        );
        expect(
          stream,
          emitsInOrder([
            901,
            emitsDone,
          ]),
        );
      });

      test('returns initial data event', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent<int>.data(901),
        );
        expect(stream.event, StreamEvent<int>.data(901));
      });

      test('replays initial error event', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent<int>.error('Big Mistake'),
        );
        expect(
          stream,
          emitsInOrder([
            emitsError('Big Mistake'),
            emitsDone,
          ]),
        );
      });

      test('returns initial error event', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent<int>.error('Big Mistake'),
        );
        expect(stream.event, StreamEvent<int>.error('Big Mistake'));
      });

      test('replays the latest value', () async {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        await pumpEventQueue();
        expect(
          stream,
          emitsInOrder([
            3,
            emitsDone,
          ]),
        );
      });

      test('replays the latest value before new values', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        controller.add(5);
        controller.add(6);
        final controllerDone = controller.close();
        expect(
          stream,
          emitsInOrder([
            3,
            4,
            5,
            6,
            emitsDone,
          ]),
        );
        await controllerDone;
      });

      test('replays when the latest event is an error', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.addError('Big Mistake');
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(3);
        controller.add(4);
        controller.add(5);
        final controllerDone = controller.close();
        expect(
          stream,
          emitsInOrder([
            emitsError('Big Mistake'),
            3,
            4,
            5,
            emitsDone,
          ]),
        );
        await controllerDone;
      });

      test('replays latest value when the delegate was already done', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await controller.close();
        // Block until the last event is received.
        expect(await stream.last, 3);
        expect(
          stream,
          emitsInOrder([
            3,
            emitsDone,
          ]),
        );
      });
    });

    group('ReplayStream with idleUntilFirstSubscription', () {
      test('does not listen to delegate after construction', () {
        var listened = false;
        final controller =
            StreamController<int>(onListen: () => listened = true);
        final stream = ReplayStream<int>(
          controller.stream,
          idleUntilFirstSubscription: true,
        );
        expect(listened, isFalse);
        expect(stream.event, isNull);
        controller.close();
      });

      test('returns initial data event before first subscription', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent<int>.data(901),
          idleUntilFirstSubscription: true,
        );
        expect(stream.event, StreamEvent<int>.data(901));
      });

      test('returns initial error event before first subscription', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent<int>.error('Big Mistake'),
          idleUntilFirstSubscription: true,
        );
        expect(stream.event, StreamEvent<int>.error('Big Mistake'));
      });

      test('listens to delegate after first subscription', () async {
        var listened = false;
        final controller =
            StreamController<int>(onListen: () => listened = true);
        controller.add(3);
        final stream = ReplayStream<int>(
          controller.stream,
          idleUntilFirstSubscription: true,
        );
        final subscription = stream.listen((data) {});
        expect(listened, isTrue);
        await pumpEventQueue();
        expect(stream.event, StreamEvent<int>.data(3));
        await subscription.cancel();
        await controller.close();
      });

      test('replays initial data event', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent<int>.data(901),
          idleUntilFirstSubscription: true,
        );
        expect(
          stream,
          emitsInOrder([
            901,
            emitsDone,
          ]),
        );
        expect(stream.event, StreamEvent<int>.data(901));
      });

      test('replays initial error event with error', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent<int>.error('Big Mistake'),
          idleUntilFirstSubscription: true,
        );
        expect(
          stream,
          emitsInOrder([
            emitsError('Big Mistake'),
            emitsDone,
          ]),
        );
        expect(stream.event, StreamEvent<int>.error('Big Mistake'));
      });

      test('returns initial data event after first subscription', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent<int>.data(901),
          idleUntilFirstSubscription: true,
        );
        final subscription = stream.listen((data) {});
        expect(stream.event, StreamEvent<int>.data(901));
        subscription.cancel();
      });

      test('returns initial error event after first subscription', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent<int>.error('Big Mistake'),
          idleUntilFirstSubscription: true,
        );
        final subscription = stream.listen((data) {});
        expect(stream.event, StreamEvent<int>.error('Big Mistake'));
        subscription.cancel();
      });
    });

    group('replay_stream.first', () {
      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.first, throwsStateError);
      });

      test('with non-empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        expect(stream.first, completion(equals(1)));
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(901),
        );
        expect(stream.first, completion(equals(901)));
      });

      test('with seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(901),
        );
        expect(stream.first, completion(equals(901)));
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(
          controller.stream,
          initialEvent: StreamEvent.data(-1),
        );
        await pumpEventQueue();
        controller.add(4);
        controller.add(5);
        controller.add(6);
        expect(stream.first, completion(equals(3)));
        await controller.close();
      });
    });

    group('replay_stream.isEmpty', () {
      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.isEmpty, completion(isTrue));
      });

      test('with non-empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        expect(stream.isEmpty, completion(isFalse));
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(901),
        );
        expect(stream.isEmpty, completion(isFalse));
      });

      test('with seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(901),
        );
        expect(stream.isEmpty, completion(isFalse));
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        expect(stream.isEmpty, completion(isFalse));
        await controller.close();
      });
    });

    group('replay_stream.last', () {
      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.last, throwsStateError);
      });

      test('with non-empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        expect(stream.last, completion(equals(3)));
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(901),
        );
        expect(stream.last, completion(equals(901)));
      });

      test('with seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(901),
        );
        expect(stream.last, completion(equals(3)));
      });

      test('replayed latest value', () async {
        final delegate =
            Stream<int>.fromIterable([1, 2, 3]).asBroadcastStream();
        final stream = ReplayStream<int>(delegate);
        await pumpEventQueue();
        expect(delegate.last, throwsStateError);
        expect(stream.last, completion(equals(3)));
      });
    });

    group('replay_stream.single', () {
      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.single, throwsStateError);
      });

      test('with single-element delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1]));
        expect(stream.single, completion(equals(1)));
      });

      test('with multi-element delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        expect(stream.single, throwsStateError);
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(901),
        );
        expect(stream.single, completion(equals(901)));
      });

      test('with seedValue and single-element delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1]),
          initialEvent: StreamEvent.data(901),
        );
        expect(stream.single, throwsStateError);
      });

      test('with seedValue and multi-element delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(901),
        );
        expect(stream.single, throwsStateError);
      });

      test('replayed latest value', () async {
        final delegate =
            Stream<int>.fromIterable([1, 2, 3]).asBroadcastStream();
        final stream = ReplayStream<int>(delegate);
        await pumpEventQueue();
        expect(delegate.single, throwsStateError);
        expect(stream.single, completion(equals(3)));
      });
    });

    group('replay_stream.any', () {
      // Returns true if [value] is an even integer.
      bool anyTest(int value) => value % 2 == 0;

      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.any(anyTest), completion(isFalse));
      });

      test('with delegate - postive case', () {
        final stream =
            ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3, 5]));
        expect(stream.any(anyTest), completion(isTrue));
      });

      test('with delegate - negative case', () {
        final stream =
            ReplayStream<int>(Stream<int>.fromIterable([1, 7, 3, 5]));
        expect(stream.any(anyTest), completion(isFalse));
      });

      test('with seedValue and empty delegate - positive case', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(8),
        );
        expect(stream.any(anyTest), completion(isTrue));
      });

      test('with seedValue and empty delegate - negative case', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(7),
        );
        expect(stream.any(anyTest), completion(isFalse));
      });

      test('with seedValue and non-empty delegate - negative case', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 3, 5]),
          initialEvent: StreamEvent.data(7),
        );
        expect(stream.any(anyTest), completion(isFalse));
      });

      test('with seedValue and non-empty delegate - positive seedValue only',
          () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 3, 5]),
          initialEvent: StreamEvent.data(2),
        );
        expect(stream.any(anyTest), completion(isTrue));
      });

      test('with seedValue and non-empty delegate - positive delegate only',
          () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 5]),
          initialEvent: StreamEvent.data(3),
        );
        expect(stream.any(anyTest), completion(isTrue));
      });

      test('with seedValue and non-empty delegate - positive case', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 5]),
          initialEvent: StreamEvent.data(4),
        );
        expect(stream.any(anyTest), completion(isTrue));
      });

      test('only replayed latest value is positive', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(3);
        controller.add(4);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(5);
        controller.add(7);
        controller.add(9);
        expect(stream.any(anyTest), completion(isTrue));
        await controller.close();
      });
    });

    group('replay_stream.asyncExpand', () {
      Stream<String> convert(int value) {
        final controller = StreamController<String>();
        controller.add('foo$value');
        controller.add('foo$value');
        controller.close();
        return controller.stream;
      }

      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(
          stream.asyncExpand(convert),
          emitsInOrder([
            emitsDone,
          ]),
        );
      });

      test('with non-empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        expect(
          stream.asyncExpand(convert),
          emitsInOrder([
            'foo1',
            'foo1',
            'foo2',
            'foo2',
            'foo3',
            'foo3',
            emitsDone,
          ]),
        );
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.asyncExpand(convert),
          emitsInOrder([
            'foo4',
            'foo4',
            emitsDone,
          ]),
        );
      });

      test('with seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.asyncExpand(convert),
          emitsInOrder([
            'foo4',
            'foo4',
            'foo1',
            'foo1',
            'foo2',
            'foo2',
            'foo3',
            'foo3',
            emitsDone,
          ]),
        );
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        controller.add(5);
        controller.add(6);
        final controllerDone = controller.close();
        expect(
          stream.asyncExpand(convert),
          emitsInOrder([
            'foo3',
            'foo3',
            'foo4',
            'foo4',
            'foo5',
            'foo5',
            'foo6',
            'foo6',
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.asyncMap', () {
      Future<String> convert(int value) => Future.value('foo$value');

      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(
          stream.asyncMap(convert),
          emitsInOrder([
            emitsDone,
          ]),
        );
      });

      test('with non-empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        expect(
          stream.asyncMap(convert),
          emitsInOrder([
            'foo1',
            'foo2',
            'foo3',
            emitsDone,
          ]),
        );
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.asyncMap(convert),
          emitsInOrder([
            'foo4',
            emitsDone,
          ]),
        );
      });

      test('with seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.asyncMap(convert),
          emitsInOrder([
            'foo4',
            'foo1',
            'foo2',
            'foo3',
            emitsDone,
          ]),
        );
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        controller.add(5);
        final controllerDone = controller.close();
        expect(
          stream.asyncMap(convert),
          emitsInOrder([
            'foo3',
            'foo4',
            'foo5',
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.cast', () {
      test('seedValue included', () {
        final stream = ReplayStream<Object>(
          Stream.fromIterable(<Object>[1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.cast<int>(),
          emitsInOrder([
            4,
            1,
            2,
            3,
            emitsDone,
          ]),
        );
      });

      test('replayed latest value included', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(
          controller.stream,
          initialEvent: StreamEvent.data(5),
        );
        await pumpEventQueue();
        controller.add(4);
        controller.add(5);
        final controllerDone = controller.close();
        expect(
          stream.cast<int>(),
          emitsInOrder([
            3,
            4,
            5,
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.contains', () {
      test('matches seedValue', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(stream.contains(4), completion(isTrue));
      });

      test('matches replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        controller.add(5);
        final controllerDone = controller.close();
        expect(stream.contains(3), completion(isTrue));
        await controllerDone;
      });
    });

    group('replay_stream.distinct', () {
      test('seedValue included', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 2]),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.distinct(),
          emitsInOrder([
            4,
            1,
            2,
            emitsDone,
          ]),
        );
      });

      test('seedValue not distinct', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 2]),
          initialEvent: StreamEvent.data(1),
        );
        expect(
          stream.distinct(),
          emitsInOrder([
            1,
            2,
            emitsDone,
          ]),
        );
      });

      test('distinct replayed latest value included', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        controller.add(4);
        final controllerDone = controller.close();
        expect(
          stream.distinct(),
          emitsInOrder([
            3,
            4,
            emitsDone,
          ]),
        );
        await controllerDone;
      });

      test('non-distinct replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(3);
        controller.add(4);
        final controllerDone = controller.close();
        expect(
          stream.distinct(),
          emitsInOrder([
            3,
            4,
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.drain', () {
      test('done', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(stream.drain(5), completion(equals(5)));
      });

      test('error', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromFuture(Future<int>.error('error')),
          initialEvent: StreamEvent.data(4),
        );
        expect(stream.drain(5), throwsA(equals('error')));
      });
    });

    group('replay_stream.elementAt', () {
      test('seedValue at index zero', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(1),
        );
        expect(stream.elementAt(0), completion(equals(1)));
      });

      test('replayed seedValue without seedValue', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        expect(stream.elementAt(0), completion(equals(3)));
      });

      test('replayed latest value at index zero', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(
          controller.stream,
          initialEvent: StreamEvent.data(8),
        );
        await pumpEventQueue();
        expect(stream.elementAt(0), completion(equals(3)));
      });
    });

    group('replay_stream.every', () {
      // Returns true if [value] is an even integer.
      bool everyTest(int value) => value % 2 == 0;

      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.every(everyTest), completion(isTrue));
      });

      test('with delegate - postive case', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([2, 4, 6]));
        expect(stream.every(everyTest), completion(isTrue));
      });

      test('with delegate - negative case', () {
        final stream =
            ReplayStream<int>(Stream<int>.fromIterable([1, 2, 4, 6]));
        expect(stream.every(everyTest), completion(isFalse));
      });

      test('with seedValue and empty delegate - positive case', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(8),
        );
        expect(stream.every(everyTest), completion(isTrue));
      });

      test('with seedValue and empty delegate - negative case', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(7),
        );
        expect(stream.every(everyTest), completion(isFalse));
      });

      test('with seedValue and non-empty delegate - negative seedValue only',
          () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([2, 4, 6]),
          initialEvent: StreamEvent.data(7),
        );
        expect(stream.every(everyTest), completion(isFalse));
      });

      test('with seedValue and non-empty delegate - negative delegate only',
          () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 4, 6]),
          initialEvent: StreamEvent.data(8),
        );
        expect(stream.every(everyTest), completion(isFalse));
      });

      test('with seedValue and non-empty delegate - positive case', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([2, 4, 6]),
          initialEvent: StreamEvent.data(8),
        );
        expect(stream.every(everyTest), completion(isTrue));
      });

      test('replayed latest value - negative', () async {
        final controller = StreamController<int>();
        controller.add(2);
        controller.add(4);
        controller.add(5);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(6);
        controller.add(8);
        controller.add(10);
        expect(stream.every(everyTest), completion(isFalse));
        await controller.close();
      });
    });

    group('replay_stream.expand', () {
      Iterable<int> convert(int value) => [value, value];

      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(
          stream.expand(convert),
          emitsInOrder([
            emitsDone,
          ]),
        );
      });

      test('with non-empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        expect(
          stream.expand(convert),
          emitsInOrder([
            1,
            1,
            2,
            2,
            3,
            3,
            emitsDone,
          ]),
        );
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.expand(convert),
          emitsInOrder([
            4,
            4,
            emitsDone,
          ]),
        );
      });

      test('with seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.expand(convert),
          emitsInOrder([
            4,
            4,
            1,
            1,
            2,
            2,
            3,
            3,
            emitsDone,
          ]),
        );
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        controller.add(5);
        controller.add(6);
        final controllerDone = controller.close();
        expect(
          stream.expand(convert),
          emitsInOrder([
            3,
            3,
            4,
            4,
            5,
            5,
            6,
            6,
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.firstWhere', () {
      bool firstWhere(int value) => value % 2 == 0;

      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.firstWhere(firstWhere), throwsStateError);
      });

      test('with empty delegate and orElse', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(
          stream.firstWhere(firstWhere, orElse: () => 5),
          completion(equals(5)),
        );
      });

      test('with non-empty delegate - positive case', () {
        final stream =
            ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3, 4]));
        expect(stream.firstWhere(firstWhere), completion(equals(2)));
      });

      test('with non-empty delegate - negative case', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 3, 5]));
        expect(stream.firstWhere(firstWhere), throwsStateError);
      });

      test('with seedvalue and empty delegate - positive case', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(2),
        );
        expect(stream.firstWhere(firstWhere), completion(equals(2)));
      });

      test('with seedvalue and empty delegate - negative case', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(3),
        );
        expect(stream.firstWhere(firstWhere), throwsStateError);
      });

      test('with seedValue and non-empty delegate - positive seedValue only',
          () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 3]),
          initialEvent: StreamEvent.data(2),
        );
        expect(stream.firstWhere(firstWhere), completion(equals(2)));
      });

      test('with seedValue and non-empty delegate - positive delegate only',
          () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([2, 3]),
          initialEvent: StreamEvent.data(1),
        );
        expect(stream.firstWhere(firstWhere), completion(equals(2)));
      });

      test('with seedValue and non-empty delegate - both positive', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([4, 6]),
          initialEvent: StreamEvent.data(2),
        );
        expect(stream.firstWhere(firstWhere), completion(equals(2)));
      });

      test('with seedValue and non-empty delegate - negative case', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 3]),
          initialEvent: StreamEvent.data(5),
        );
        expect(stream.firstWhere(firstWhere), throwsStateError);
      });

      test('replayed latest value - positive case', () async {
        final controller = StreamController<int>();
        controller.add(2);
        controller.add(5);
        controller.add(6);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(8);
        expect(stream.firstWhere(firstWhere), completion(equals(6)));
        await controller.close();
      });
    });

    group('replay_stream.fold', () {
      String combine(String previous, int element) =>
          previous + element.toString();

      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.fold('foo', combine), completion(equals('foo')));
      });

      test('with non-empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        expect(stream.fold('foo', combine), completion(equals('foo123')));
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(1),
        );
        expect(stream.fold('foo', combine), completion(equals('foo1')));
      });

      test('with seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([2, 3, 4]),
          initialEvent: StreamEvent.data(1),
        );
        expect(stream.fold('foo', combine), completion(equals('foo1234')));
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        expect(stream.fold('foo', combine), completion(equals('foo34')));
        await controller.close();
      });
    });

    group('replay_stream.forEach', () {
      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        final values = <int>[];
        expect(
          stream.forEach(values.add),
          completion(DelegatingMatcher(values, equals([]))),
        );
      });

      test('with non-empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        final values = <int>[];
        expect(
          stream.forEach(values.add),
          completion(DelegatingMatcher(values, equals([1, 2, 3]))),
        );
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(4),
        );
        final values = <int>[];
        expect(
          stream.forEach(values.add),
          completion(DelegatingMatcher(values, equals([4]))),
        );
      });

      test('with seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        final values = <int>[];
        expect(
          stream.forEach(values.add),
          completion(DelegatingMatcher(values, equals([4, 1, 2, 3]))),
        );
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        final values = <int>[];
        expect(
          stream.forEach(values.add),
          completion(DelegatingMatcher(values, equals([3, 4]))),
        );
        await controller.close();
      });
    });

    group('replay_stream.handleError', () {
      test('error can be handled', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromFuture(Future<int>.error('error')),
          initialEvent: StreamEvent.data(1),
        );
        expect(
          stream.handleError((error) {}),
          emitsInOrder([
            1,
            emitsDone,
          ]),
        );
      });
    });

    group('replay_stream.join', () {
      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.join(','), completion(equals('')));
      });

      test('with non-empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        expect(stream.join(','), completion(equals('1,2,3')));
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(4),
        );
        expect(stream.join(','), completion(equals('4')));
      });

      test('with seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(stream.join(','), completion(equals('4,1,2,3')));
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        expect(stream.join(','), completion(equals('3,4')));
        await controller.close();
      });
    });

    group('replay_stream.lastWhere', () {
      bool lastWhere(int value) => value % 2 == 0;

      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.lastWhere(lastWhere), throwsStateError);
      });

      test('with empty delegate and orElse', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(
          stream.lastWhere(lastWhere, orElse: () => 5),
          completion(equals(5)),
        );
      });

      test('with non-empty delegate - positive case', () {
        final stream =
            ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3, 4]));
        expect(stream.lastWhere(lastWhere), completion(equals(4)));
      });

      test('with non-empty delegate - negative case', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 3, 5]));
        expect(stream.lastWhere(lastWhere), throwsStateError);
      });

      test('with seedvalue and empty delegate - positive case', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(2),
        );
        expect(stream.lastWhere(lastWhere), completion(equals(2)));
      });

      test('with seedvalue and empty delegate - negative case', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(3),
        );
        expect(stream.lastWhere(lastWhere), throwsStateError);
      });

      test('with seedValue and non-empty delegate - positive seedValue only',
          () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 3]),
          initialEvent: StreamEvent.data(2),
        );
        expect(stream.lastWhere(lastWhere), completion(equals(2)));
      });

      test('with seedValue and non-empty delegate - positive delegate only',
          () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([2, 3, 4]),
          initialEvent: StreamEvent.data(1),
        );
        expect(stream.lastWhere(lastWhere), completion(equals(4)));
      });

      test('with seedValue and non-empty delegate - both positive', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([4, 6]),
          initialEvent: StreamEvent.data(2),
        );
        expect(stream.lastWhere(lastWhere), completion(equals(6)));
      });

      test('with seedValue and non-empty delegate - negative case', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 3]),
          initialEvent: StreamEvent.data(5),
        );
        expect(stream.lastWhere(lastWhere), throwsStateError);
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(4);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(7);
        controller.add(9);
        final lastWhereFuture = stream.lastWhere(lastWhere);
        await controller.close();
        expect(lastWhereFuture, completion(equals(4)));
      });
    });

    group('replay_stream.map', () {
      String convert(int value) => 'foo$value';

      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(
          stream.map(convert),
          emitsInOrder([
            emitsDone,
          ]),
        );
      });

      test('with non-empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        expect(
          stream.map(convert),
          emitsInOrder([
            'foo1',
            'foo2',
            'foo3',
            emitsDone,
          ]),
        );
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.map(convert),
          emitsInOrder([
            'foo4',
            emitsDone,
          ]),
        );
      });

      test('with seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.map(convert),
          emitsInOrder([
            'foo4',
            'foo1',
            'foo2',
            'foo3',
            emitsDone,
          ]),
        );
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        controller.add(5);
        final controllerDone = controller.close();
        expect(
          stream.map(convert),
          emitsInOrder([
            'foo3',
            'foo4',
            'foo5',
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.pipe', () {
      // Ensure that the stream passed to the consumer is the actual
      // [ReplayStream].
      test('replay_stream passed to consumer', () async {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        final consumer = NoopStreamConsumer();
        await stream.pipe(consumer);
        expect(consumer.stream, equals(stream));
      });
    });

    group('replay_stream.reduce', () {
      // Sums up all values.
      int combine(int previous, int element) => previous + element;

      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.reduce(combine), throwsStateError);
      });

      test('with non-empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        expect(stream.reduce(combine), completion(equals(6)));
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(1),
        );
        expect(stream.reduce(combine), completion(equals(1)));
      });

      test('with seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([2, 3, 4]),
          initialEvent: StreamEvent.data(1),
        );
        expect(stream.reduce(combine), completion(equals(10)));
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        controller.add(5);
        final reduceFuture = stream.reduce(combine);
        await controller.close();
        expect(reduceFuture, completion(equals(12)));
      });
    });

    group('replay_stream.singleWhere', () {
      // Returns true if [value] is an even integer.
      bool whereTest(int value) => value % 2 == 0;

      test('seedValue is the only match', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(stream.singleWhere(whereTest), completion(equals(4)));
      });

      test('seedValue is also a match', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(stream.singleWhere(whereTest), throwsStateError);
      });

      test('replayed latest value is the only match', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(3);
        final controllerDone = controller.close();
        expect(stream.singleWhere(whereTest), completion(equals(2)));
        await controllerDone;
      });

      test('replayed latest value is also a match', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(3);
        controller.add(4);
        final controllerDone = controller.close();
        expect(stream.singleWhere(whereTest), throwsStateError);
        await controllerDone;
      });
    });

    group('replay_stream.skip', () {
      test('seedValue included', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.skip(2),
          emitsInOrder([
            2,
            3,
            emitsDone,
          ]),
        );
      });

      test('replayed latest value included', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(
          controller.stream,
          initialEvent: StreamEvent.data(4),
        );
        await pumpEventQueue();
        controller.add(5);
        controller.add(6);
        final controllerDone = controller.close();
        expect(
          stream.skip(2),
          emitsInOrder([
            6,
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.skipWhile', () {
      bool skip(int value) => value % 2 == 0;

      test('seedValue skipped', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.skipWhile(skip),
          emitsInOrder([
            1,
            2,
            3,
            emitsDone,
          ]),
        );
      });

      test('seedValue not skipped', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(5),
        );
        expect(
          stream.skipWhile(skip),
          emitsInOrder([
            5,
            1,
            2,
            3,
            emitsDone,
          ]),
        );
      });

      test('replayed latest value skipped', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(4);
        final stream = ReplayStream<int>(
          controller.stream,
          initialEvent: StreamEvent.data(6),
        );
        await pumpEventQueue();
        controller.add(7);
        controller.add(8);
        final controllerDone = controller.close();
        expect(
          stream.skipWhile(skip),
          emitsInOrder([
            7,
            8,
            emitsDone,
          ]),
        );
        await controllerDone;
      });

      test('replayed latest value not skipped', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(
          controller.stream,
          initialEvent: StreamEvent.data(6),
        );
        await pumpEventQueue();
        controller.add(7);
        controller.add(8);
        final controllerDone = controller.close();
        expect(
          stream.skipWhile(skip),
          emitsInOrder([
            3,
            7,
            8,
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.take', () {
      test('seedValue included', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3]),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.take(3),
          emitsInOrder([
            4,
            1,
            2,
            emitsDone,
          ]),
        );
      });

      test('replayed latest value included', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(
          controller.stream,
          initialEvent: StreamEvent.data(4),
        );
        await pumpEventQueue();
        controller.add(5);
        controller.add(6);
        controller.add(7);
        final controllerDone = controller.close();
        expect(
          stream.take(3),
          emitsInOrder([
            3,
            5,
            6,
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.takeWhile', () {
      bool condition(int value) => value % 2 == 0;

      test('seedValue taken', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([2, 4, 5, 6]),
          initialEvent: StreamEvent.data(8),
        );
        expect(
          stream.takeWhile(condition),
          emitsInOrder([
            8,
            2,
            4,
            emitsDone,
          ]),
        );
      });

      test('seedValue not taken', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([2, 4, 5, 6]),
          initialEvent: StreamEvent.data(7),
        );
        expect(
          stream.takeWhile(condition),
          emitsInOrder([
            emitsDone,
          ]),
        );
      });

      test('replayed latest value taken', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(4);
        final stream = ReplayStream<int>(
          controller.stream,
          initialEvent: StreamEvent.data(6),
        );
        await pumpEventQueue();
        controller.add(8);
        controller.add(9);
        final controllerDone = controller.close();
        expect(
          stream.takeWhile(condition),
          emitsInOrder([
            4,
            8,
            emitsDone,
          ]),
        );
        await controllerDone;
      });

      test('replayed latest value not taken', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(
          controller.stream,
          initialEvent: StreamEvent.data(6),
        );
        await pumpEventQueue();
        controller.add(8);
        controller.add(9);
        final controllerDone = controller.close();
        expect(
          stream.takeWhile(condition),
          emitsInOrder([
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.timeout', () {
      // Make sure the latest value is replayed.
      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(
          controller.stream,
          initialEvent: StreamEvent.data(4),
        );
        await pumpEventQueue();
        controller.add(5);
        final controllerDone = controller.close();
        expect(
          stream.timeout(Duration(seconds: 10)),
          emitsInOrder([
            3,
            5,
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.toList', () {
      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.toList(), completion(equals([])));
      });

      test('with non-empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3]));
        expect(stream.toList(), completion(equals([1, 2, 3])));
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(1),
        );
        expect(stream.toList(), completion(equals([1])));
      });

      test('with seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([2, 3, 4]),
          initialEvent: StreamEvent.data(1),
        );
        expect(stream.toList(), completion(equals([1, 2, 3, 4])));
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        controller.add(5);
        final toListFuture = stream.toList();
        await controller.close();
        expect(toListFuture, completion(equals([3, 4, 5])));
      });
    });

    group('replay_stream.toSet', () {
      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(stream.toSet(), completion(equals([])));
      });

      test('with non-empty delegate', () {
        final stream =
            ReplayStream<int>(Stream<int>.fromIterable([1, 2, 2, 3]));
        expect(stream.toSet(), completion(equals([1, 2, 3])));
      });

      test('with seedValue and empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(1),
        );
        expect(stream.toSet(), completion(equals([1])));
      });

      test('with distinct seedValue and non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([2, 3, 4]),
          initialEvent: StreamEvent.data(1),
        );
        expect(stream.toSet(), completion(equals([1, 2, 3, 4])));
      });

      test('with seedValue appearing in the non-empty delegate', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([2, 3, 4]),
          initialEvent: StreamEvent.data(2),
        );
        expect(stream.toSet(), completion(equals([2, 3, 4])));
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        controller.add(4);
        controller.add(5);
        final toSetFuture = stream.toSet();
        await controller.close();
        expect(toSetFuture, completion(equals([3, 4, 5])));
      });
    });

    group('replay_stream.transform', () {
      Stream<int> plusTen(Stream<int> stream) {
        final controller = StreamController<int>();
        stream.listen(
          (value) {
            try {
              controller.add(value + 10);
            } catch (error, stackTrace) {
              controller.addError(error, stackTrace);
            }
          },
          onError: controller.addError,
          onDone: controller.close,
        );
        return controller.stream;
      }

      test('seedValue forwarded to the transformer', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([2, 3, 4]),
          initialEvent: StreamEvent.data(1),
        );
        final transformer = StreamTransformer.fromBind(plusTen);
        expect(
          stream.transform(transformer),
          emitsInOrder([
            11,
            12,
            13,
            14,
            emitsDone,
          ]),
        );
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(3);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(4);
        controller.add(5);
        final controllerDone = controller.close();
        final transformer = StreamTransformer.fromBind(plusTen);
        expect(
          stream.transform(transformer),
          emitsInOrder([
            13,
            14,
            15,
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.where', () {
      // Returns true if [value] is an even integer.
      bool whereTest(int value) => value % 2 == 0;

      test('with empty delegate', () {
        final stream = ReplayStream<int>(Stream<int>.empty());
        expect(
          stream.where(whereTest),
          emitsInOrder([
            emitsDone,
          ]),
        );
      });

      test('with non-empty delegate', () {
        final stream =
            ReplayStream<int>(Stream<int>.fromIterable([1, 2, 3, 4, 5, 6]));
        expect(
          stream.where(whereTest),
          emitsInOrder([
            2,
            4,
            6,
            emitsDone,
          ]),
        );
      });

      test('with seedValue and empty delegate - positive case', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(4),
        );
        expect(
          stream.where(whereTest),
          emitsInOrder([
            4,
            emitsDone,
          ]),
        );
      });

      test('with seedValue and empty delegate - negative case', () {
        final stream = ReplayStream<int>(
          Stream<int>.empty(),
          initialEvent: StreamEvent.data(5),
        );
        expect(
          stream.where(whereTest),
          emitsInOrder([
            emitsDone,
          ]),
        );
      });

      test('with seedValue and non-empty delegate - positive case', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3, 4, 5, 6]),
          initialEvent: StreamEvent.data(8),
        );
        expect(
          stream.where(whereTest),
          emitsInOrder([
            8,
            2,
            4,
            6,
            emitsDone,
          ]),
        );
      });

      test('with seedValue and non-empty delegate - negative case', () {
        final stream = ReplayStream<int>(
          Stream<int>.fromIterable([1, 2, 3, 4, 5, 6]),
          initialEvent: StreamEvent.data(7),
        );
        expect(
          stream.where(whereTest),
          emitsInOrder([
            2,
            4,
            6,
            emitsDone,
          ]),
        );
      });

      test('replayed latest value', () async {
        final controller = StreamController<int>();
        controller.add(1);
        controller.add(2);
        controller.add(4);
        final stream = ReplayStream<int>(controller.stream);
        await pumpEventQueue();
        controller.add(6);
        controller.add(7);
        controller.add(8);
        final controllerDone = controller.close();
        expect(
          stream.where(whereTest),
          emitsInOrder([
            4,
            6,
            8,
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.dispose', () {
      String convert(int value) => 'foo$value';

      test('stops listening after dispose', () async {
        final controller = StreamController<int>();
        final stream = ReplayStream<int>(controller.stream);
        controller.add(1);
        controller.add(2);
        await pumpEventQueue();
        stream.dispose();
        controller.add(3);
        controller.add(4);
        await pumpEventQueue();
        final controllerDone = controller.close();
        expect(
          stream.asyncMap(convert),
          emitsInOrder([
            'foo2',
            emitsDone,
          ]),
        );
        await controllerDone;
      });
    });

    group('replay_stream.isListening', () {
      test('stops listening after dispose', () async {
        final controller = StreamController<int>();
        final stream = ReplayStream<int>(controller.stream);

        expect(stream.isListening, isTrue);

        stream.dispose();

        expect(stream.isListening, isFalse);
      });
    });
  });
}

/// A custom matcher that always returns the passed-in [delegate].
class DelegatingMatcher extends CustomMatcher {
  final dynamic _delegate;

  DelegatingMatcher(this._delegate, matcher)
      : super('Always returns delegate', 'delegate', matcher);

  @override
  Object featureValueOf(actual) => _delegate;
}

/// A [StreamConsumer] that does not do anything. It does, however, provide a
/// getter to the added [Stream] for test verification.
class NoopStreamConsumer extends StreamConsumer<int> {
  Stream<int>? _stream;

  Stream<int>? get stream => _stream;

  NoopStreamConsumer() : super();

  @override
  Future addStream(Stream<int> stream) {
    _stream = stream;
    return Future.value();
  }

  @override
  Future close() => Future.value();
}
