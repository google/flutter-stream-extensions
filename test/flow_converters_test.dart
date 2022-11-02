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

import 'package:streams/flow_converters.dart';
import 'package:streams/stream_event.dart';
import 'package:test/test.dart';

void main() {
  group('convertStreamEvent', () {
    late StreamController<int> controller;

    setUp(() {
      controller = StreamController<int>();
    });

    tearDown(() {
      controller.close();
    });

    group('when converting to data', () {
      late Stream<String> output;

      setUp(() {
        output = controller.stream.transform(convertStreamEvent(convertToData));
      });

      test('emits properly when input is also data', () {
        controller.add(123);
        controller.add(456);
        expect(
          output,
          emitsInOrder([
            'data 123',
            'data 456',
          ]),
        );
      });

      test('emits properly when input is error', () {
        controller.addError('dog');
        controller.addError('cat');
        expect(
          output,
          emitsInOrder([
            'error dog',
            'error cat',
          ]),
        );
      });
    });

    group('when converting to error', () {
      late Stream<String> output;

      setUp(() {
        output =
            controller.stream.transform(convertStreamEvent(convertToError));
      });

      test('emits properly when input is data', () {
        controller.add(123);
        controller.add(456);
        expect(
          output,
          emitsInOrder([
            emitsError('123'),
            emitsError('456'),
          ]),
        );
      });

      test('emits properly when input is also error', () {
        controller.addError('dog');
        controller.addError('cat');
        expect(
          output,
          emitsInOrder([
            emitsError('dog'),
            emitsError('cat'),
          ]),
        );
      });
    });

    group('when converter throws', () {
      late Stream<String> output;

      setUp(() {
        output =
            controller.stream.transform(convertStreamEvent(convertToError));
      });

      test('emits properly when input is data', () {
        controller.add(123);
        controller.add(456);
        expect(
          output,
          emitsInOrder([
            emitsError('123'),
            emitsError('456'),
          ]),
        );
      });

      test('emits properly when input is error', () {
        controller.addError('dog');
        controller.addError('cat');
        expect(
          output,
          emitsInOrder([
            emitsError('dog'),
            emitsError('cat'),
          ]),
        );
      });
    });
  });
}

StreamEvent<String> convertToData(StreamEvent<int> input) {
  if (input.hasData) {
    return StreamEvent<String>.data('data ${input.data}');
  }
  return StreamEvent<String>.data('error ${input.error}');
}

StreamEvent<String> convertToError(StreamEvent<int> input) {
  if (input.hasData) {
    return StreamEvent<String>.error('${input.data}');
  } else {
    return StreamEvent<String>.error('${input.error}');
  }
}

StreamEvent<String> convertToThrows(StreamEvent<int> input) {
  if (input.hasData) {
    throw '${input.data}';
  } else {
    throw '${input.error}';
  }
}
