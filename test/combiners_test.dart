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

import 'package:flutter_stream_extensions/combiners.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

void main() {
  group('combineLatestTuple2', () {
    test('emits nothing when both inputs streams are empty', () {
      final stream =
          combineLatestTuple2(Stream<int>.empty(), Stream<int>.empty());
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when first input stream is empty', () {
      final stream = combineLatestTuple2(
        Stream<int>.empty(),
        Stream<int>.fromIterable([1, 2, 3]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when second input stream is empty', () {
      final stream = combineLatestTuple2(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.empty(),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits combined latest values from inputs', () {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();
      final stream =
          combineLatestTuple2(controller1.stream, controller2.stream);
      controller1.add(1);
      controller1.add(2);
      controller2.add(100);
      controller2.add(1000);
      controller1.close();
      controller2.close();
      expect(
        stream,
        emitsInOrder([
          Tuple2(1, 100),
          Tuple2(2, 100),
          Tuple2(2, 1000),
          emitsDone,
        ]),
      );
    });
  });

  group('combineLatestTuple3', () {
    test('emits nothing when all input streams are empty', () {
      final stream = combineLatestTuple3(
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when first input stream is empty', () {
      final stream = combineLatestTuple3(
        Stream<int>.empty(),
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when second input stream is empty', () {
      final stream = combineLatestTuple3(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([100, 1000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when third input stream is empty', () {
      final stream = combineLatestTuple3(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.empty(),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits combined latest values from inputs', () {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();
      final controller3 = StreamController<int>();
      final stream = combineLatestTuple3(
        controller1.stream,
        controller2.stream,
        controller3.stream,
      );
      controller1.add(1);
      controller1.add(2);
      controller2.add(100);
      controller2.add(1000);
      controller3.add(10000);
      controller1.close();
      controller2.close();
      controller3.close();
      expect(
        stream,
        emitsInOrder([
          Tuple3(1, 100, 10000),
          Tuple3(2, 100, 10000),
          Tuple3(2, 1000, 10000),
          emitsDone,
        ]),
      );
    });
  });

  group('combineLatestTuple4', () {
    test('emits nothing when all input streams are empty', () {
      final stream = combineLatestTuple4(
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when first input stream is empty', () {
      final stream = combineLatestTuple4(
        Stream<int>.empty(),
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when second input stream is empty', () {
      final stream = combineLatestTuple4(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when third input stream is empty', () {
      final stream = combineLatestTuple4(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([10000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when fourth input stream is empty', () {
      final stream = combineLatestTuple4(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.empty(),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits combined latest values from inputs', () {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();
      final controller3 = StreamController<int>();
      final controller4 = StreamController<int>();
      final stream = combineLatestTuple4(
        controller1.stream,
        controller2.stream,
        controller3.stream,
        controller4.stream,
      );
      controller1.add(1);
      controller1.add(2);
      controller2.add(100);
      controller2.add(1000);
      controller3.add(10000);
      controller4.add(100000);
      controller1.close();
      controller2.close();
      controller3.close();
      controller4.close();
      expect(
        stream,
        emitsInOrder([
          Tuple4(1, 100, 10000, 100000),
          Tuple4(2, 100, 10000, 100000),
          Tuple4(2, 1000, 10000, 100000),
          emitsDone,
        ]),
      );
    });
  });

  group('combineLatestTuple5', () {
    test('emits nothing when all input streams are empty', () {
      final stream = combineLatestTuple5(
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when first input stream is empty', () {
      final stream = combineLatestTuple5(
        Stream<int>.empty(),
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when second input stream is empty', () {
      final stream = combineLatestTuple5(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when third input stream is empty', () {
      final stream = combineLatestTuple5(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when fourth input stream is empty', () {
      final stream = combineLatestTuple5(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([100000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when fifth input stream is empty', () {
      final stream = combineLatestTuple5(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
        Stream<int>.empty(),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits combined latest values from inputs', () {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();
      final controller3 = StreamController<int>();
      final controller4 = StreamController<int>();
      final controller5 = StreamController<int>();
      final stream = combineLatestTuple5(
        controller1.stream,
        controller2.stream,
        controller3.stream,
        controller4.stream,
        controller5.stream,
      );
      controller1.add(1);
      controller1.add(2);
      controller2.add(100);
      controller2.add(1000);
      controller3.add(10000);
      controller4.add(100000);
      controller5.add(9000000);
      controller1.close();
      controller2.close();
      controller3.close();
      controller4.close();
      controller5.close();
      expect(
        stream,
        emitsInOrder([
          Tuple5(1, 100, 10000, 100000, 9000000),
          Tuple5(2, 100, 10000, 100000, 9000000),
          Tuple5(2, 1000, 10000, 100000, 9000000),
          emitsDone,
        ]),
      );
    });
  });

  group('combineLatestTuple6', () {
    test('emits nothing when all input streams are empty', () {
      final stream = combineLatestTuple6(
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when first input stream is empty', () {
      final stream = combineLatestTuple6(
        Stream<int>.empty(),
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
        Stream<int>.fromIterable([1000000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when second input stream is empty', () {
      final stream = combineLatestTuple6(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
        Stream<int>.fromIterable([1000000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when third input stream is empty', () {
      final stream = combineLatestTuple6(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
        Stream<int>.fromIterable([1000000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when fourth input stream is empty', () {
      final stream = combineLatestTuple6(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([100000]),
        Stream<int>.fromIterable([1000000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when fifth input stream is empty', () {
      final stream = combineLatestTuple6(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([1000000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when sixth input stream is empty', () {
      final stream = combineLatestTuple6(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
        Stream<int>.fromIterable([1000000]),
        Stream<int>.empty(),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits combined latest values from inputs', () {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();
      final controller3 = StreamController<int>();
      final controller4 = StreamController<int>();
      final controller5 = StreamController<int>();
      final controller6 = StreamController<int>();
      final stream = combineLatestTuple6(
        controller1.stream,
        controller2.stream,
        controller3.stream,
        controller4.stream,
        controller5.stream,
        controller6.stream,
      );
      controller1.add(1);
      controller1.add(2);
      controller2.add(100);
      controller2.add(1000);
      controller3.add(10000);
      controller4.add(100000);
      controller5.add(9000000);
      controller6.add(123);
      controller1.close();
      controller2.close();
      controller3.close();
      controller4.close();
      controller5.close();
      controller6.close();
      expect(
        stream,
        emitsInOrder([
          Tuple6(1, 100, 10000, 100000, 9000000, 123),
          Tuple6(2, 100, 10000, 100000, 9000000, 123),
          Tuple6(2, 1000, 10000, 100000, 9000000, 123),
          emitsDone,
        ]),
      );
    });
  });

  group('combineLatestTuple7', () {
    test('emits nothing when all input streams are empty', () {
      final stream = combineLatestTuple7(
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
        Stream<int>.empty(),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when first input stream is empty', () {
      final stream = combineLatestTuple7(
        Stream<int>.empty(),
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
        Stream<int>.fromIterable([1000000]),
        Stream<int>.fromIterable([10000000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when second input stream is empty', () {
      final stream = combineLatestTuple7(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
        Stream<int>.fromIterable([1000000]),
        Stream<int>.fromIterable([10000000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when third input stream is empty', () {
      final stream = combineLatestTuple7(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
        Stream<int>.fromIterable([1000000]),
        Stream<int>.fromIterable([10000000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when fourth input stream is empty', () {
      final stream = combineLatestTuple7(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([100000]),
        Stream<int>.fromIterable([1000000]),
        Stream<int>.fromIterable([10000000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when fifth input stream is empty', () {
      final stream = combineLatestTuple7(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([1000000]),
        Stream<int>.fromIterable([10000000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when sixth input stream is empty', () {
      final stream = combineLatestTuple7(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
        Stream<int>.fromIterable([1000000]),
        Stream<int>.empty(),
        Stream<int>.fromIterable([10000000]),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits nothing when seventh input stream is empty', () {
      final stream = combineLatestTuple7(
        Stream<int>.fromIterable([1, 2, 3]),
        Stream<int>.fromIterable([100, 1000]),
        Stream<int>.fromIterable([10000]),
        Stream<int>.fromIterable([100000]),
        Stream<int>.fromIterable([1000000]),
        Stream<int>.fromIterable([10000000]),
        Stream<int>.empty(),
      );
      expect(stream, emits(emitsDone));
    });

    test('emits combined latest values from inputs', () {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();
      final controller3 = StreamController<int>();
      final controller4 = StreamController<int>();
      final controller5 = StreamController<int>();
      final controller6 = StreamController<int>();
      final controller7 = StreamController<int>();
      final stream = combineLatestTuple7(
        controller1.stream,
        controller2.stream,
        controller3.stream,
        controller4.stream,
        controller5.stream,
        controller6.stream,
        controller7.stream,
      );
      controller1.add(1);
      controller1.add(2);
      controller2.add(100);
      controller2.add(1000);
      controller3.add(10000);
      controller4.add(100000);
      controller5.add(9000000);
      controller6.add(123);
      controller7.add(456);
      controller1.close();
      controller2.close();
      controller3.close();
      controller4.close();
      controller5.close();
      controller6.close();
      controller7.close();
      expect(
        stream,
        emitsInOrder([
          Tuple7(1, 100, 10000, 100000, 9000000, 123, 456),
          Tuple7(2, 100, 10000, 100000, 9000000, 123, 456),
          Tuple7(2, 1000, 10000, 100000, 9000000, 123, 456),
          emitsDone,
        ]),
      );
    });
  });
}
