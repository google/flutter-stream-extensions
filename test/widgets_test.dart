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

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:streams/widgets.dart';

void main() {
  group(DistinctStreamBuilder, () {
    late MockBuildWithValue builder1;
    late MockBuildWithValue builder2;
    late Key key;

    setUp(() {
      builder1 = MockBuildWithValue();
      builder2 = MockBuildWithValue();
      key = GlobalKey();
    });

    tearDown(() {
      verifyNoMoreInteractions(builder1);
      verifyNoMoreInteractions(builder2);
    });

    /// Returns a [DistinctStreamBuilder] with [stream] and [initialValue].
    ///
    /// Widgets returned by this method shares the same [key].
    Widget withBuilder(
      BuildWithValue builder,
      Stream<String?> stream,
      String initialValue,
    ) =>
        DistinctStreamBuilder(
          stream: stream,
          initialValue: initialValue,
          builder: (context, child, dynamic value) {
            builder(value);
            return Container();
          },
          key: key,
        );

    testWidgets('builds with initial value', (tester) async {
      await tester
          .pumpWidget(withBuilder(builder1, Stream<String>.empty(), 'aaa'));
      verify(builder1.call('aaa'));
    });

    testWidgets('builds with values from stream', (tester) async {
      final controller = StreamController<String?>();
      await tester.pumpWidget(withBuilder(builder1, controller.stream, 'aaa'));
      controller.add('aaa');
      await tester.pumpAndSettle();
      controller.add('bbb');
      await tester.pumpAndSettle();
      controller.add('bbb');
      await tester.pumpAndSettle();
      controller.add('ccc');
      await tester.pumpAndSettle();
      controller.add(null);
      await tester.pumpAndSettle();
      controller.add('ddd');
      await tester.pumpAndSettle();
      verifyInOrder([
        builder1.call('aaa'),
        builder1.call('bbb'),
        builder1.call('ccc'),
        builder1.call(null),
        builder1.call('ddd'),
      ]);
    });

    group('when only builder changed', () {
      testWidgets('builds current value with new builder', (tester) async {
        final stream = Stream<String>.fromIterable(['bbb']);
        // Note both widgets are built with the same global [key].
        await tester.pumpWidget(withBuilder(builder1, stream, 'aaa'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(withBuilder(builder2, stream, 'aaa'));
        await tester.pumpAndSettle();
        verifyInOrder([
          builder1.call('aaa'),
          builder1.call('bbb'),
          builder2.call('bbb'),
        ]);
      });
    });

    group('when builder and initial value changed', () {
      testWidgets('builds initial value with new builder', (tester) async {
        final stream = Stream<String>.fromIterable(['bbb']);
        // Note both widgets are built with the same global [key].
        await tester.pumpWidget(withBuilder(builder1, stream, 'aaa'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(withBuilder(builder2, stream, 'ccc'));
        await tester.pumpAndSettle();
        verifyInOrder([
          builder1.call('aaa'),
          builder1.call('bbb'),
          builder2.call('ccc'),
        ]);
      });
    });

    group('when only initial value changed', () {
      testWidgets('builds new initial value', (tester) async {
        final stream = Stream<String>.fromIterable(['bbb']);
        // Note both widgets are built with the same global [key].
        await tester.pumpWidget(withBuilder(builder1, stream, 'aaa'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(withBuilder(builder1, stream, 'bbb'));
        await tester.pumpAndSettle();
        verifyInOrder([
          builder1.call('aaa'),
          builder1.call('bbb'),
          builder1.call('bbb'),
        ]);
      });
    });

    group('when only stream changed', () {
      testWidgets('resets current value and stream', (tester) async {
        // Note both widgets are built with the same global [key].
        await tester.pumpWidget(
          withBuilder(builder1, Stream<String>.fromIterable(['bbb']), 'aaa'),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          withBuilder(builder1, Stream<String>.fromIterable(['ccc']), 'aaa'),
        );
        await tester.pumpAndSettle();
        verifyInOrder([
          builder1.call('aaa'),
          builder1.call('bbb'),
          builder1.call('aaa'),
          builder1.call('ccc'),
        ]);
      });
    });

    group('when stream and initial value changed', () {
      testWidgets('resets current value and stream', (tester) async {
        // Note both widgets are built with the same global [key].
        await tester.pumpWidget(
          withBuilder(builder1, Stream<String>.fromIterable(['bbb']), 'aaa'),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          withBuilder(builder1, Stream<String>.fromIterable(['ccc']), 'ddd'),
        );
        await tester.pumpAndSettle();
        verifyInOrder([
          builder1.call('aaa'),
          builder1.call('bbb'),
          builder1.call('ddd'),
          builder1.call('ccc'),
        ]);
      });
    });

    group('when all three changed', () {
      testWidgets('resets current value and stream', (tester) async {
        // Note both widgets are built with the same global [key].
        await tester.pumpWidget(
          withBuilder(builder1, Stream<String>.fromIterable(['bbb']), 'aaa'),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          withBuilder(builder2, Stream<String>.fromIterable(['ccc']), 'ddd'),
        );
        await tester.pumpAndSettle();
        verifyInOrder([
          builder1.call('aaa'),
          builder1.call('bbb'),
          builder2.call('ddd'),
          builder2.call('ccc'),
        ]);
      });
    });
  });
}

abstract class BuildWithValue {
  void call(String? value);
}

class MockBuildWithValue extends Mock implements BuildWithValue {}
