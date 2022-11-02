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

import 'package:auto_disposable/auto_disposable.dart';
import 'package:flutter_stream_extensions/flow.dart';
import 'package:flutter_stream_extensions/stream_event.dart';
import 'package:test/test.dart';

void main() {
  group('Node', () {
    group('disposal', () {
      test('does not forward events after disposal', () async {
        var counter = 0;
        final inputNode = Node<int>()
          ..withInitialData(counter)
          ..wire0()
          ..asSettable();
        final node = Node<int>()..wire1(inputNode, (int i) => counter = i);
        await pumpEventQueue();

        // access node.stream to ensure setup
        node.stream;

        inputNode.value = 1;
        await pumpEventQueue();

        // node is wired and not disposed, counter should update.
        expect(counter, 1);

        node.dispose();

        inputNode.value = 2;
        await pumpEventQueue();

        // node is disposed, counter should *not* update.
        expect(counter, 1);

        inputNode.dispose();
      });
    });

    group('before wiring', () {
      for (var testerFactory in [
        SingleNodeTesterFactory<int>(
          'newly constructed',
          () => Node<int>(),
        ),
        SingleNodeTesterFactory<int>(
          'with initial data',
          () => Node<int>()..withInitialData(999),
        ),
        SingleNodeTesterFactory<int>(
          'with initial event',
          () => Node<int>()..withInitialEvent(StreamEvent<int>.error('cat')),
        ),
        SingleNodeTesterFactory<int>(
          'settable',
          () => Node<int>()..asSettable(),
        ),
        SingleNodeTesterFactory<int>(
          'settable with initial data',
          () => Node<int>()
            ..asSettable()
            ..withInitialData(999),
        ),
        SingleNodeTesterFactory<int>(
          'settable with initial event',
          () => Node<int>()
            ..asSettable()
            ..withInitialEvent(StreamEvent<int>.error('cat')),
        ),
      ]) {
        group(testerFactory.description, () {
          late NodeTester<int> tester;

          setUp(() {
            tester = testerFactory.createTester();
          });

          tearDown(() => tester.dispose());

          test('throws when getting stream', () {
            expect(() => tester.outputNode.stream, throwsStateError);
          });

          test('throws when setting value', () {
            expect(() => tester.outputNode.value = 1, throwsStateError);
          });

          test('throws when setting error', () {
            expect(() => tester.outputNode.error = 'dog', throwsStateError);
          });

          test('throws when getting view', () {
            expect(() => tester.outputNode.view, throwsStateError);
          });

          test('throws when subscribing', () {
            expect(
              () => tester.outputNode.subscribePermanently(print),
              throwsStateError,
            );
          });

          test('throws when subscribing data-only', () {
            expect(
              () => tester.outputNode.subscribeToDataPermanently(print),
              throwsStateError,
            );
          });
        });
      }
    });

    group('when not settable', () {
      for (var testerFactory in [
        SingleNodeTesterFactory<int>(
          'wired with wire0',
          () => Node<int>()..wire0(),
        ),
        SingleNodeTesterFactory<int>(
          'with initial data and wired with wire0',
          () => Node<int>()
            ..withInitialData(999)
            ..wire0(),
        ),
        SingleNodeTesterFactory<int>(
          'with initial event and wired with wire0',
          () => Node<int>()
            ..withInitialEvent(StreamEvent<int>.error('cat'))
            ..wire0(),
        ),
        StreamInputNodeTesterFactory<int>(
          'wired as passthrough',
          (inputStream) => Node<int>()..wireAsPassthrough(inputStream),
        ),
        StreamInputNodeTesterFactory<int>(
          'wired as transformed stream',
          (inputStream) =>
              Node<int>()..wireAsTransformedStream(inputStream, whereEven()),
        ),
        SingleNodeInputNodeTesterFactory<int>(
          'wired as passthrough node',
          (inputNode) => Node<int>()..wireAsPassthroughNode(inputNode),
        ),
        SingleNodeInputNodeTesterFactory<int>(
          'wired as transformed node',
          (inputNode) =>
              Node<int>()..wireAsTransformedNode(inputNode, whereEven()),
        ),
      ]) {
        group(testerFactory.description, () {
          late NodeTester<int> tester;

          setUp(() {
            tester = testerFactory.createTester();
          });

          tearDown(() => tester.dispose());

          test('cannot be wired again', () {
            expectCannotBeWiredAgain(tester.outputNode);
          });

          test('returns itself as the view', () {
            expect(tester.outputNode.view, same(tester.outputNode));
          });

          test('throws when setting value', () {
            expect(() => tester.outputNode.value = 1, throwsStateError);
          });

          test('throws when setting error', () {
            expect(() => tester.outputNode.error = 'dog', throwsStateError);
          });
        });
      }
    });

    group('when settable and wired', () {
      for (var testerFactory in [
        SingleNodeTesterFactory<int>(
          'with wire0',
          () => Node<int>()
            ..asSettable()
            ..wire0(),
        ),
        SingleNodeTesterFactory<int>(
          'with initial data and wire0',
          () => Node<int>()
            ..asSettable()
            ..withInitialData(999)
            ..wire0(),
        ),
        SingleNodeTesterFactory<int>(
          'with initial event and wire0',
          () => Node<int>()
            ..asSettable()
            ..withInitialEvent(StreamEvent<int>.error('cat'))
            ..wire0(),
        ),
        StreamInputNodeTesterFactory<int>(
          'wired as passthrough',
          (inputStream) => Node<int>()
            ..asSettable()
            ..wireAsPassthrough(inputStream),
        ),
        StreamInputNodeTesterFactory<int>(
          'wired as transformed stream',
          (inputStream) => Node<int>()
            ..asSettable()
            ..wireAsTransformedStream(inputStream, whereEven()),
        ),
        SingleNodeInputNodeTesterFactory<int>(
          'wired as passthrough node',
          (inputNode) => Node<int>()
            ..asSettable()
            ..wireAsPassthroughNode(inputNode),
        ),
        SingleNodeInputNodeTesterFactory<int>(
          'wired as transformed node',
          (inputNode) => Node<int>()
            ..asSettable()
            ..wireAsTransformedNode(inputNode, whereEven()),
        ),
      ]) {
        group(testerFactory.description, () {
          late NodeTester<int> tester;

          setUp(() {
            tester = testerFactory.createTester();
          });

          tearDown(() => tester.dispose());

          test('cannot be wired again', () {
            expectCannotBeWiredAgain(tester.outputNode);
          });

          test('returns an unsettable view', () {
            tester.outputNode.value = 101;
            final view = tester.outputNode.view;
            tester.outputNode.value = 102;
            expect(view, isNot(same(tester.outputNode)));
            expect(view.settable, isFalse);
            expect(view.stream, emits(102));
            expect(view, same(tester.outputNode.view));
          });

          test('disposes of the view automatically', () {
            final view = tester.outputNode.view;
            tester.outputNode.dispose();
            expect(view.isDisposed, isTrue);
          });

          test('emits set events to subscriber', () async {
            final collector = EventCollector(tester.outputNode);

            tester.outputNode.value = 101;
            tester.outputNode.error = 'dog';
            await pumpEventQueue();

            expect(
              collector.emittedEvents.lastItems(2),
              [
                StreamEvent<int>.data(101),
                StreamEvent<int>.error('dog'),
              ],
            );
            expect(collector.emittedValues.last, 101);
          });

          test('emits set events to stream', () async {
            expect(
              tester.outputNode.stream,
              emitsInOrder([
                mayEmit(emitsError('cat')),
                mayEmit(999),
                101,
                emitsError('dog'),
              ]),
            );

            tester.outputNode.value = 101;
            tester.outputNode.error = 'dog';
            await pumpEventQueue();
          });
        });
      }
    });

    group('with initial data wired', () {
      for (var testerFactory in [
        SingleNodeTesterFactory<int>(
          'not settable with wire0',
          () => Node<int>()
            ..withInitialData(999)
            ..wire0(),
        ),
        SingleNodeTesterFactory<int>(
          'settable with wire0',
          () => Node<int>()
            ..asSettable()
            ..withInitialData(999)
            ..wire0(),
        ),
        StreamInputNodeTesterFactory<int>(
          'wired as passthrough',
          (inputStream) => Node<int>()
            ..withInitialData(999)
            ..wireAsPassthrough(inputStream),
        ),
        StreamInputNodeTesterFactory<int>(
          'wired as transformed stream',
          (inputStream) => Node<int>()
            ..withInitialData(999)
            ..wireAsTransformedStream(inputStream, whereEven()),
        ),
        SingleNodeInputNodeTesterFactory<int>(
          'wired as passthrough node',
          (inputNode) => Node<int>()
            ..withInitialData(999)
            ..wireAsPassthroughNode(inputNode),
        ),
        SingleNodeInputNodeTesterFactory<int>(
          'wired as transformed node',
          (inputNode) => Node<int>()
            ..withInitialData(999)
            ..wireAsTransformedNode(inputNode, whereEven()),
        ),
      ]) {
        group(testerFactory.description, () {
          late NodeTester<int> tester;

          setUp(() {
            tester = testerFactory.createTester();
          });

          tearDown(() => tester.dispose());

          test('emits initial event to subscriber', () async {
            final collector = EventCollector(tester.outputNode);
            await pumpEventQueue();

            expect(
              collector.emittedEvents,
              [StreamEvent<int>.data(999)],
            );
            expect(collector.emittedValues, [999]);
          });

          test('emits initial event to stream', () async {
            expect(
              tester.outputNode.stream,
              emits(999),
            );

            await pumpEventQueue();
          });
        });
      }
    });

    group('with initial error and wired', () {
      for (var testerFactory in [
        SingleNodeTesterFactory<int>(
          'not settable with wire0',
          () => Node<int>()
            ..withInitialEvent(StreamEvent<int>.error('cat'))
            ..wire0(),
        ),
        SingleNodeTesterFactory<int>(
          'settable with wire0',
          () => Node<int>()
            ..asSettable()
            ..withInitialEvent(StreamEvent<int>.error('cat'))
            ..wire0(),
        ),
        StreamInputNodeTesterFactory<int>(
          'wired as passthrough',
          (inputStream) => Node<int>()
            ..withInitialEvent(StreamEvent<int>.error('cat'))
            ..wireAsPassthrough(inputStream),
        ),
        StreamInputNodeTesterFactory<int>(
          'wired as transformed stream',
          (inputStream) => Node<int>()
            ..withInitialEvent(StreamEvent<int>.error('cat'))
            ..wireAsTransformedStream(inputStream, whereEven()),
        ),
        SingleNodeInputNodeTesterFactory<int>(
          'wired as passthrough node',
          (inputNode) => Node<int>()
            ..withInitialEvent(StreamEvent<int>.error('cat'))
            ..wireAsPassthroughNode(inputNode),
        ),
        SingleNodeInputNodeTesterFactory<int>(
          'wired as transformed node',
          (inputNode) => Node<int>()
            ..withInitialEvent(StreamEvent<int>.error('cat'))
            ..wireAsTransformedNode(inputNode, whereEven()),
        ),
      ]) {
        group(testerFactory.description, () {
          late NodeTester<int> tester;

          setUp(() {
            tester = testerFactory.createTester();
          });

          tearDown(() => tester.dispose());

          test('emits initial error to subscriber', () async {
            final collector = EventCollector(tester.outputNode);

            await pumpEventQueue();

            expect(
              collector.emittedEvents,
              [StreamEvent<int>.error('cat')],
            );
            expect(collector.emittedValues, []);
          });

          test('emits initial event to stream', () async {
            expect(
              tester.outputNode.stream,
              emitsError('cat'),
            );

            await pumpEventQueue();
          });
        });
      }
    });

    group('with no initial value or error and wired with [wire0]', () {
      for (var testerFactory in [
        SingleNodeTesterFactory<int>(
          'not settable',
          () => Node<int>()..wire0(),
        ),
        SingleNodeTesterFactory<int>(
          'settable',
          () => Node<int>()
            ..asSettable()
            ..wire0(),
        ),
      ]) {
        group(testerFactory.description, () {
          late NodeTester<int> tester;

          setUp(() {
            tester = testerFactory.createTester();
          });

          tearDown(() => tester.dispose());

          test('emits nothing subscriber', () async {
            final collector = EventCollector(tester.outputNode);

            await pumpEventQueue();

            expect(
              collector.emittedEvents,
              [],
            );
            expect(collector.emittedValues, []);
          });

          test('emits nothing to stream', () async {
            await expectStreamEmitsNothing(tester.outputNode.stream);
          });
        });
      }
    });

    group('wired as passthrough', () {
      for (var testerFactory in [
        StreamInputNodeTesterFactory<int>(
          'no initial data',
          (inputStream) => Node<int>()..wireAsPassthrough(inputStream),
        ),
        StreamInputNodeTesterFactory<int>(
          'with initial data',
          (inputStream) => Node<int>()
            ..withInitialData(10)
            ..wireAsPassthrough(inputStream),
        ),
        StreamInputNodeTesterFactory<int>(
          'with initial error',
          (inputStream) => Node<int>()
            ..withInitialEvent(StreamEvent<int>.error('initial error'))
            ..wireAsPassthrough(inputStream),
        ),
      ]) {
        group(testerFactory.description, () {
          late StreamInputNodeTester<int> tester;

          setUp(() {
            tester = testerFactory.createTester();
          });

          tearDown(() => tester.dispose());

          // A sequence of stream updates shared between the tests below.
          void triggerStreamUpdates() {
            tester.inputStreamController.add(20);
            tester.inputStreamController.add(25);
            tester.inputStreamController.addError('Out of range');
          }

          test('emits input stream events to subscriber', () async {
            final collector = EventCollector(tester.outputNode);

            triggerStreamUpdates();
            await pumpEventQueue();

            expect(
              collector.emittedEvents.lastItems(3),
              [
                StreamEvent<int>.data(20),
                StreamEvent<int>.data(25),
                StreamEvent<int>.error('Out of range'),
              ],
            );
            expect(collector.emittedValues.lastItems(2), [20, 25]);
          });

          test('emits input stream events to stream', () async {
            expect(
              tester.outputNode.stream,
              emitsInOrder([
                mayEmit(emitsError('initial error')),
                mayEmit(10),
                20,
                25,
                emitsError('Out of range'),
              ]),
            );

            triggerStreamUpdates();
            await pumpEventQueue();
          });
        });
      }
    });

    group('wired as transformed stream', () {
      for (var testerFactory in [
        StreamInputNodeTesterFactory<int>(
          'no initial data',
          (inputStream) =>
              Node<int>()..wireAsTransformedStream(inputStream, whereEven()),
        ),
        StreamInputNodeTesterFactory<int>(
          'with initial data',
          (inputStream) => Node<int>()
            ..withInitialData(10)
            ..wireAsTransformedStream(inputStream, whereEven()),
        ),
        StreamInputNodeTesterFactory<int>(
          'with initial error',
          (inputStream) => Node<int>()
            ..withInitialEvent(StreamEvent<int>.error('initial error'))
            ..wireAsTransformedStream(inputStream, whereEven()),
        ),
      ]) {
        group(testerFactory.description, () {
          late StreamInputNodeTester<int> tester;

          setUp(() {
            tester = testerFactory.createTester();
          });

          tearDown(() => tester.dispose());

          // A sequence of stream updates shared between the tests below.
          void triggerStreamUpdates() {
            tester.inputStreamController.add(20);
            tester.inputStreamController.add(21);
            tester.inputStreamController.add(22);
            tester.inputStreamController.add(23);
            tester.inputStreamController.addError('Out of range');
          }

          test('emits transformed input stream events to subscriber', () async {
            final collector = EventCollector(tester.outputNode);

            triggerStreamUpdates();
            await pumpEventQueue();

            expect(
              collector.emittedEvents.lastItems(3),
              [
                StreamEvent<int>.data(20),
                StreamEvent<int>.data(22),
                StreamEvent<int>.error('Out of range'),
              ],
            );
            expect(collector.emittedValues.lastItems(2), [20, 22]);
          });

          test('emits transformed input stream events to stream', () async {
            expect(
              tester.outputNode.stream,
              emitsInOrder([
                mayEmit(emitsError('initial error')),
                mayEmit(10),
                20,
                22,
                emitsError('Out of range'),
              ]),
            );

            triggerStreamUpdates();
            await pumpEventQueue();
          });
        });
      }
    });

    group('wired as passthrough node', () {
      for (var testerFactory in [
        SingleNodeInputNodeTesterFactory<int>(
          'no initial data',
          (inputNode) => Node<int>()..wireAsPassthroughNode(inputNode),
        ),
        SingleNodeInputNodeTesterFactory<int>(
          'with initial data',
          (inputNode) => Node<int>()
            ..withInitialData(10)
            ..wireAsPassthroughNode(inputNode),
        ),
        SingleNodeInputNodeTesterFactory<int>(
          'with initial error',
          (inputNode) => Node<int>()
            ..withInitialEvent(StreamEvent<int>.error('initial error'))
            ..wireAsPassthroughNode(inputNode),
        ),
      ]) {
        group(testerFactory.description, () {
          late SingleNodeInputNodeTester<int> tester;

          setUp(() {
            tester = testerFactory.createTester();
          });

          tearDown(() => tester.dispose());

          // A sequence of stream updates shared between the tests below.
          void triggerStreamUpdates() {
            tester.inputNode.value = 20;
            tester.inputNode.value = 25;
            tester.inputNode.error = 'Out of range';
          }

          test('emits input stream events to subscriber', () async {
            final collector = EventCollector(tester.outputNode);

            triggerStreamUpdates();
            await pumpEventQueue();

            expect(
              collector.emittedEvents.lastItems(3),
              [
                StreamEvent<int>.data(20),
                StreamEvent<int>.data(25),
                StreamEvent<int>.error('Out of range'),
              ],
            );
            expect(collector.emittedValues.lastItems(2), [20, 25]);
          });

          test('emits input stream events to stream', () async {
            expect(
              tester.outputNode.stream,
              emitsInOrder([
                mayEmit(emitsError('initial error')),
                mayEmit(10),
                20,
                25,
                emitsError('Out of range'),
              ]),
            );

            triggerStreamUpdates();
            await pumpEventQueue();
          });
        });
      }
    });

    group('wired as transformed node', () {
      for (var testerFactory in [
        SingleNodeInputNodeTesterFactory<int>(
          'no initial data',
          (inputNode) =>
              Node<int>()..wireAsTransformedNode(inputNode, whereEven()),
        ),
        SingleNodeInputNodeTesterFactory<int>(
          'with initial data',
          (inputNode) => Node<int>()
            ..withInitialData(10)
            ..wireAsTransformedNode(inputNode, whereEven()),
        ),
        SingleNodeInputNodeTesterFactory<int>(
          'with initial error',
          (inputNode) => Node<int>()
            ..withInitialEvent(StreamEvent<int>.error('initial error'))
            ..wireAsTransformedNode(inputNode, whereEven()),
        ),
      ]) {
        group(testerFactory.description, () {
          late SingleNodeInputNodeTester<int> tester;

          setUp(() {
            tester = testerFactory.createTester();
          });

          tearDown(() => tester.dispose());

          // A sequence of stream updates shared between the tests below.
          void triggerStreamUpdates() {
            tester.inputNode.value = 20;
            tester.inputNode.value = 21;
            tester.inputNode.value = 22;
            tester.inputNode.value = 23;

            tester.inputNode.error = 'Out of range';
          }

          test('emits transformed input stream events to subscriber', () async {
            final collector = EventCollector(tester.outputNode);

            triggerStreamUpdates();
            await pumpEventQueue();

            expect(
              collector.emittedEvents.lastItems(3),
              [
                StreamEvent<int>.data(20),
                StreamEvent<int>.data(22),
                StreamEvent<int>.error('Out of range'),
              ],
            );
            expect(collector.emittedValues.lastItems(2), [20, 22]);
          });

          test('emits transformed input stream events to stream', () async {
            expect(
              tester.outputNode.stream,
              emitsInOrder([
                mayEmit(emitsError('initial error')),
                mayEmit(10),
                20,
                22,
                emitsError('Out of range'),
              ]),
            );

            triggerStreamUpdates();
            await pumpEventQueue();
          });
        });
      }
    });

    // Test that data can flow from N input nodes to a single output node for
    // every wireN configuration.
    for (var testerFactory in [
      // Tests all wireN methods in a basic way
      WiredNodeTesterFactory(
        description: 'when wired with wire1',
        numInputs: 1,
      ),
      WiredNodeTesterFactory(
        description: 'when wired with wire2',
        numInputs: 2,
      ),
      WiredNodeTesterFactory(
        description: 'when wired with wire3',
        numInputs: 3,
      ),
      WiredNodeTesterFactory(
        description: 'when wired with wire4',
        numInputs: 4,
      ),
      WiredNodeTesterFactory(
        description: 'when wired with wire5',
        numInputs: 5,
      ),
      WiredNodeTesterFactory(
        description: 'when wired with wire6',
        numInputs: 6,
      ),
      WiredNodeTesterFactory(
        description: 'when wired with wire7',
        numInputs: 7,
      ),

      // Test [wire7] with several different configurations as a proxy for all
      // the other wireN methods.
      WiredNodeTesterFactory(
        description: 'when wired with wire7 and with initial data',
        numInputs: 3,
        initialData: 'initial data',
      ),
      WiredNodeTesterFactory(
        description: 'when wired with wire7 and with initial error',
        numInputs: 3,
        initialEvent: StreamEvent<String>.error('initial error'),
      ),
    ]) {
      group(testerFactory.description, () {
        late WiredNodeTester tester;
        setUp(() {
          tester = testerFactory.createTester();
        });

        tearDown(() => tester.dispose());

        test('cannot be wired again', () {
          var inputNode = Node<String>()
            ..asSettable()
            ..wire0();
          expect(
            () => tester.outputNode.wire1<String>(inputNode, (a) => a),
            throwsStateError,
          );
        });

        test('throws when setting value', () {
          expect(() => tester.outputNode.value = 'value', throwsStateError);
        });

        test('throws when setting error', () {
          expect(
            () => tester.outputNode.error = 'error description',
            throwsStateError,
          );
        });

        // A sequence of node updates shared between the tests below.
        void triggerNodeUpdates() {
          // Set each node to 'a', 'b', 'c'... etc.
          tester.setAscendingAlphabetValuesOnInputs();

          // Update first node to 'A'.
          tester.inputNodes[0].value = 'A';

          // Update last node to 'Z'.
          tester.inputNodes[testerFactory.numInputs - 1].value = 'Z';

          // Set error on first node.
          tester.inputNodes[0].error = 'broken';
        }

        // Expected output events for the input events above.

        final alphabet = 'abcdefg';

        // The first event should contain 'a', 'b', 'c' etc for N input nodes.
        final expectedOutput1 = alphabet.substring(0, testerFactory.numInputs);

        // Replace the first 'a' with 'A'.
        final expectedOutput2 = 'A' + expectedOutput1.substring(1);

        // Replace the last letter with 'Z'.
        final expectedOutput3 =
            expectedOutput2.substring(0, expectedOutput2.length - 1) + 'Z';

        // Emit an error that overrides.
        final expectedError4 = 'broken';

        test('forwards converted input', () async {
          expect(
            tester.outputNode.stream,
            emitsInOrder([
              if (testerFactory.initialData != null) testerFactory.initialData!,
              if (testerFactory.initialEvent != null)
                emitsError('initial error'),
              expectedOutput1,
              expectedOutput2,
              expectedOutput3,
              emitsError(expectedError4),
            ]),
          );

          triggerNodeUpdates();
          await pumpEventQueue();
        });

        test('forwards converted input to subscribers', () async {
          final collector = EventCollector(tester.outputNode);

          triggerNodeUpdates();
          await pumpEventQueue();

          expect(
            collector.emittedEvents,
            [
              if (testerFactory.initialData != null)
                StreamEvent<String>.data(testerFactory.initialData!),
              if (testerFactory.initialEvent != null)
                testerFactory.initialEvent,
              StreamEvent<String>.data(expectedOutput1),
              StreamEvent<String>.data(expectedOutput2),
              StreamEvent<String>.data(expectedOutput3),
              StreamEvent<String>.error(expectedError4),
            ],
          );

          expect(collector.emittedValues, [
            if (testerFactory.initialData != null) testerFactory.initialData,
            expectedOutput1,
            expectedOutput2,
            expectedOutput3,
          ]);
        });
      });
    }

    // Test that the ability to set values on nodes directly still works for
    // nodes that are both settable *and* have wired inputs. wire3 is
    // arbitrarily chosen as a representative test case for all wireN methods.
    group('when wired to input nodes and also settable', () {
      late WiredNodeTester tester;
      setUp(() {
        tester = WiredNodeTester(numInputs: 3, settable: true);
      });

      tearDown(() => tester.dispose());

      // A sequence of node updates shared between the tests below.
      void triggerNodeUpdates() {
        tester.outputNode.value = 'output node value';
        tester.outputNode.error = 'output node error';
        tester.inputNodes[0].value = 'valueA';
        tester.inputNodes[1].value = 'valueB';
        tester.inputNodes[2].value = 'valueC';
        tester.inputNodes[0].error = 'input node error';
        tester.outputNode.value = 'output node later value';
        tester.outputNode.error = 'output node later error';
      }

      test('forwards converted input', () async {
        expect(
          tester.outputNode.stream,
          emitsInOrder([
            'output node value',
            emitsError('output node error'),
            'valueAvalueBvalueC',
            emitsError('input node error'),
            'output node later value',
            emitsError('output node later error'),
          ]),
        );

        triggerNodeUpdates();

        await pumpEventQueue();
      });

      test('forwards converted input to subscribers', () async {
        final collector = EventCollector(tester.outputNode);

        triggerNodeUpdates();

        expect(
          collector.emittedEvents,
          [
            StreamEvent<String>.data('output node value'),
            StreamEvent<String>.error('output node error'),
            StreamEvent<String>.data('valueAvalueBvalueC'),
            StreamEvent<String>.error('input node error'),
            StreamEvent<String>.data('output node later value'),
            StreamEvent<String>.error('output node later error'),
          ],
        );

        expect(collector.emittedValues, [
          'output node value',
          'valueAvalueBvalueC',
          'output node later value',
        ]);
      });
    });

    // Test that values are still propagated correctly for nodes wired with an
    // async converter function. Wire2 is arbitrarily chosen as a representative
    // test case for all wireN methods.
    group('when wired to inputs nodes with an async converter function', () {
      late Node<String> inputNode1;
      late Node<String> inputNode2;
      late Node<String> outputNode;

      setUp(() {
        inputNode1 = Node()
          ..wire0()
          ..asSettable();
        inputNode2 = Node()
          ..wire0()
          ..asSettable();
        outputNode = Node()
          ..wire2<String, String>(inputNode1, inputNode2, (v0, v1) async {
            return v0 + v1;
          });
      });

      tearDown(() {
        inputNode1.dispose();
        inputNode2.dispose();
        outputNode.dispose();
      });

      // A sequence of node updates shared between the tests below.
      Future<void> triggerNodeUpdates() async {
        // Note that due to the asynchronous converter function, you need to
        // pump the event queue after every event to ensure results are received
        // in order.

        inputNode1.value = 'a';
        inputNode2.value = '1';
        await pumpEventQueue();

        inputNode1.value = 'b';
        await pumpEventQueue();

        inputNode2.value = '2';
        await pumpEventQueue();

        inputNode1.error = 'error';
        await pumpEventQueue();

        inputNode1.value = 'c';
        await pumpEventQueue();
      }

      test('forwards converted input', () async {
        expect(
          outputNode.stream,
          emitsInOrder([
            'a1',
            'b1',
            'b2',
            emitsError('error'),
            'c2',
          ]),
        );

        await triggerNodeUpdates();
      });

      test('forwards converted input to subscribers', () async {
        final collector = EventCollector(outputNode);

        await triggerNodeUpdates();

        expect(
          collector.emittedEvents,
          [
            StreamEvent<String>.data('a1'),
            StreamEvent<String>.data('b1'),
            StreamEvent<String>.data('b2'),
            StreamEvent<String>.error('error'),
            StreamEvent<String>.data('c2'),
          ],
        );

        expect(collector.emittedValues, [
          'a1',
          'b1',
          'b2',
          'c2',
        ]);
      });
    });
  });
}

/// A function that returns a Node.
typedef NodeProvider<T> = Node<T> Function();

/// A node tester which provides a main 'outputNode' under test.
abstract class NodeTester<T> implements Disposable {
  Node<T> get outputNode;
}

/// A factory to create a [NodeTester].
///
/// Tests should be parameterized with [NodeTesterFactory] instances rather than
/// [NodeTester] so that the latter can easily be regenerated in a [setUp]
/// function before each test method and to provide a description of the type of
/// tester being created.
abstract class NodeTesterFactory<T> {
  /// A description of the tester being created.
  String get description;

  /// Creates and returns a new [WiredNodeTester] to be used in a single test.
  NodeTester<T> createTester();
}

/// A factory that creates a particular type of [Node] for testing.
class SingleNodeTesterFactory<T> implements NodeTesterFactory<T> {
  SingleNodeTesterFactory(
    this.description,
    this.nodeProvider,
  );

  @override
  final String description;

  /// Function which creates a node to be tested.
  final NodeProvider<T> nodeProvider;

  @override
  SingleNodeTester<T> createTester() => SingleNodeTester(nodeProvider());
}

class SingleNodeTester<T> implements NodeTester<T> {
  @override
  late final Node<T> outputNode;

  SingleNodeTester(this.outputNode);

  @override
  void dispose() {
    outputNode.dispose();
  }
}

typedef StreamInputNodeProvider<T> = Node<T> Function(Stream<T> inputStream);

/// A factory for a node tester with a node that is wired from an input stream.
///
/// This deserves its own kind of factory because the lifecycle of the input
/// stream has to be managed which is non-trivial because the future returned by
/// [StreamController.close()] never returns if it hasn't been wired.
/// See https://github.com/dart-lang/sdk/issues/19095.
class StreamInputNodeTesterFactory<T> implements NodeTesterFactory<T> {
  StreamInputNodeTesterFactory(
    this.description,
    this.nodeProvider,
  );

  @override
  final String description;

  /// Function which creates the node to be tested, wiring it to the input
  /// stream.
  final StreamInputNodeProvider<T> nodeProvider;

  @override
  StreamInputNodeTester<T> createTester() {
    final inputStreamController = StreamController<T>();
    return StreamInputNodeTester(
      nodeProvider(inputStreamController.stream),
      inputStreamController,
    );
  }
}

/// A node tester for a node with an input stream i.e. passthrough or
/// transformed.
class StreamInputNodeTester<T> implements NodeTester<T> {
  @override
  late final Node<T> outputNode;

  StreamController<T> inputStreamController;

  StreamInputNodeTester(this.outputNode, this.inputStreamController);

  @override
  void dispose() {
    outputNode.dispose();
    inputStreamController.close();
  }
}

typedef SingleNodeInputNodeProvider<T> = Node<T> Function(Node<T> inputNode);

/// A factory for a node tester with a node that is wired from a single settable
/// input node.
class SingleNodeInputNodeTesterFactory<T> implements NodeTesterFactory<T> {
  SingleNodeInputNodeTesterFactory(
    this.description,
    this.nodeProvider,
  );

  @override
  final String description;

  /// Function which creates the node to be tested, wiring it to the input node.
  final SingleNodeInputNodeProvider<T> nodeProvider;

  @override
  SingleNodeInputNodeTester<T> createTester() {
    final inputNode = Node<T>()
      ..asSettable()
      ..wire0();
    return SingleNodeInputNodeTester(
      nodeProvider(inputNode),
      inputNode,
    );
  }
}

/// A node tester for a node with a single settable input node.
class SingleNodeInputNodeTester<T> implements NodeTester<T> {
  @override
  late final Node<T> outputNode;

  Node<T> inputNode;

  SingleNodeInputNodeTester(this.outputNode, this.inputNode);

  @override
  void dispose() {
    outputNode.dispose();
    inputNode.dispose();
  }
}

/// A factory to create a [WiredNodeTester].
class WiredNodeTesterFactory implements NodeTesterFactory<String> {
  @override
  String description;

  /// The number of input nodes to create and wire to the output node.
  int numInputs;

  /// Initial data to populate on the output node.
  String? initialData;

  /// An initial event to populate on the output node.
  StreamEvent<String>? initialEvent;

  /// Whether the output node should be settable.
  bool settable = false;

  WiredNodeTesterFactory({
    required this.description,
    required this.numInputs,
    this.initialData,
    this.initialEvent,
    this.settable = false,
  });

  @override
  WiredNodeTester createTester() => WiredNodeTester(
        numInputs: numInputs,
        initialData: initialData,
        initialEvent: initialEvent,
        settable: settable,
      );
}

/// A tester object that creates and wires N [inputNodes] to a [outputNode]
/// under test.
class WiredNodeTester implements Disposable, NodeTester<String> {
  final List<Node<String>> inputNodes = [];

  @override
  late final Node<String> outputNode = Node<String>();

  /// Creates a new tester with the given parameters. See
  /// [WiredNodeTesterFactory] for parameter documentation.
  WiredNodeTester({
    required int numInputs,
    String? initialData,
    StreamEvent<String>? initialEvent,
    bool settable = false,
  }) {
    for (var i = 0; i < numInputs; i++) {
      var node = Node<String>()
        ..asSettable()
        ..wire0();
      inputNodes.add(node);
    }

    if (initialData != null) {
      outputNode.withInitialData(initialData);
    } else if (initialEvent != null) {
      outputNode.withInitialEvent(initialEvent);
    }

    if (settable) {
      outputNode.asSettable();
    }

    switch (numInputs) {
      case 1:
        outputNode.wire1<String>(inputNodes[0], (v1) => v1);
        break;
      case 2:
        outputNode.wire2<String, String>(
          inputNodes[0],
          inputNodes[1],
          (v1, v2) => v1 + v2,
        );
        break;
      case 3:
        outputNode.wire3<String, String, String>(
          inputNodes[0],
          inputNodes[1],
          inputNodes[2],
          (v1, v2, v3) => v1 + v2 + v3,
        );
        break;
      case 4:
        outputNode.wire4<String, String, String, String>(
          inputNodes[0],
          inputNodes[1],
          inputNodes[2],
          inputNodes[3],
          (v1, v2, v3, v4) => v1 + v2 + v3 + v4,
        );
        break;
      case 5:
        outputNode.wire5<String, String, String, String, String>(
          inputNodes[0],
          inputNodes[1],
          inputNodes[2],
          inputNodes[3],
          inputNodes[4],
          (v1, v2, v3, v4, v5) => v1 + v2 + v3 + v4 + v5,
        );
        break;
      case 6:
        outputNode.wire6<String, String, String, String, String, String>(
          inputNodes[0],
          inputNodes[1],
          inputNodes[2],
          inputNodes[3],
          inputNodes[4],
          inputNodes[5],
          (v1, v2, v3, v4, v5, v6) => v1 + v2 + v3 + v4 + v5 + v6,
        );
        break;
      case 7:
        outputNode
            .wire7<String, String, String, String, String, String, String>(
          inputNodes[0],
          inputNodes[1],
          inputNodes[2],
          inputNodes[3],
          inputNodes[4],
          inputNodes[5],
          inputNodes[6],
          (v1, v2, v3, v4, v5, v6, v7) => v1 + v2 + v3 + v4 + v5 + v6 + v7,
        );
        break;

      default:
        throw FallThroughError();
    }
  }

  @override
  void dispose() {
    for (var inputNode in inputNodes) {
      inputNode.dispose();
    }
    outputNode.dispose();
  }

  /// Sets the strings 'a', 'b', 'c'... etc on the input nodes successively.
  void setAscendingAlphabetValuesOnInputs() {
    var i = 0;
    for (var node in inputNodes) {
      node.value = String.fromCharCode('a'.codeUnitAt(0) + i);
      i++;
    }
  }
}

/// Collects and stores events as both a subscriber and data subscriber to a
/// [Node].
class EventCollector<T> {
  final Node<T> node;

  /// Values emitted via [subscribePermanently] in chronological order.
  final emittedValues = <T>[];

  /// Values emitted via [subscribeToDataPermanently] in chronological order.
  final emittedEvents = <StreamEvent<T>>[];

  EventCollector(this.node) {
    node.subscribePermanently(emittedEvents.add);
    node.subscribeToDataPermanently(emittedValues.add);
  }
}

Future<void> expectStreamEmitsNothing(Stream<int> stream) async {
  final emitted = <StreamEvent<int>>[];
  final listener = stream.listen(
    (int data) => emitted.add(StreamEvent<int>.data(data)),
    onError: (Object error) => emitted.add(StreamEvent<int>.error(error)),
  );
  await pumpEventQueue();
  await listener.cancel();
  expect(emitted, isEmpty);
}

/// Returns a stream transformer that retains only even integers.
StreamTransformer<int, int> whereEven() => StreamTransformer.fromBind(
      (stream) => stream.where((value) => value % 2 == 0),
    );

void expectCannotBeWiredAgain(Node<int> node) {
  expect(() => node.wireAsPassthrough(Stream<int>.empty()), throwsStateError);
  expect(() => node.wire0(), throwsStateError);
  final node2 = Node<int>()..wire0();
  expect(() => node.wire1<int>(node2, (a) => a), throwsStateError);
  expect(
    () => node.wire2<int, int>(node2, node2, (a, b) => a + b),
    throwsStateError,
  );
  expect(
    () => node.wire3<int, int, int>(
      node2,
      node2,
      node2,
      (a, b, c) => a + b + c,
    ),
    throwsStateError,
  );
  expect(
    () => node.wire4<int, int, int, int>(
      node2,
      node2,
      node2,
      node2,
      (a, b, c, d) => a + b + c + d,
    ),
    throwsStateError,
  );
  expect(
    () => node.wireAsTransformedNode(node2, whereEven()),
    throwsStateError,
  );
  expect(
    () => node.wireAsTransformedStream(node2.stream, whereEven()),
    throwsStateError,
  );
}

/// Extension to provide convenience methods on [List].
extension ListConveniences<T> on List<T> {
  // Returns a sublist of the last N items in the list.
  List<T> lastItems(int n) {
    return sublist(length - n);
  }
}
