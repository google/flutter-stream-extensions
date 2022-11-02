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

/// A library that makes stream transformer based data flow easier to reason
/// about.
///
/// In a [Stream]-heavy class, there is often a mixture of [Stream],
/// [StreamController], and various types of stream transformers glued together
/// with [Stream.transform] or methods from `combiners.dart`. This `flow`
/// library encapsulates common patterns and provides a single [Node] class. A
/// [Node] represents a single stage of computation where zero or more [Stream]s
/// are the input and a single [Stream] is the output.
///
/// By wiring multiple [Node]s together through pure functions, they form a
/// flow of data.

import 'dart:async';

import 'package:auto_disposable/auto_disposable.dart';
import 'package:quiver/check.dart';

import 'combiners.dart';
import 'replay_stream.dart';
import 'stream_event.dart';

/// A node in a data flow graph that remains idle until wired and used.
///
/// After you construct a [Node], call one of the [wire*] methods to configure
/// wiring. Wiring logic is always lazily executed until this [Node] has an
/// actual user. Specifically, a [Node] is considered used after the first call
/// to any of:
/// - [value]/[error] if this is settable.
/// - [stream] getter.
/// - [subscribePermanently].
/// - [subscribeToDataPermanently].
///
/// To fetch the latest stream event, simply use the [stream] getter.
///
/// ```dart
/// final latestEvent = myNode.stream.event;
/// ```
///
/// See [ReplayStream] for more details.
///
/// If a [Node] depends on one or more other [Node]s, for example:
///
/// ```dart
/// final myNode = Node()..wire2(node1, node2, converter);
/// ```
///
/// When `myNode` is first used, the wiring logic of `node1` and `node2` will be
/// executed if they have not been.
///
/// # Modifiers
///
/// You may modify the properties of a [Node] before using it. There are two
/// methods.
///
/// ## [asSettable]
///
/// Allows this [Node] to be settable. This modifier makes sure that the
/// [value] and [error] setters are properly configured when this [Node] is
/// wired.
///
/// ## [withInitialEvent]
///
/// Allows an initial event to be set to [stream].
///
/// # Wiring Methods
///
/// The [Node] class supports a number of wiring methods. They all start with
/// `wire`. Here is the full list:
/// - [wireAsPassthrough]
/// - [wireAsPassthroughNode]
/// - [wireAsTransformedStream]
/// - [wireAsTransformedNode]
/// - [wire0]
/// - [wire1]
/// - [wire2]
/// - [wire3]
/// - [wire4]
/// - [wire5]
/// - [wire6]
/// - [wire7]
///
/// A specific [Node] object can only accept a single wiring method call, which
/// updates the object from the 'ReadyToConfigure' state to the 'ReadyToWire'
/// state.
///
/// See `Lifecycle of a Node` section for more details.
///
/// # Usage Methods
///
/// A usage method makes use of the [Node]'s output. A [Node] must already be
/// configured or wired before any usage method can be called. Currently, [Node]
/// supports the following usage methods:
/// - [value]/[error] only when the [Node] is settable.
/// - [view] getter.
/// - [stream] getter.
/// - [subscribePermanently].
/// - [subscribeToDataPermanently].
///
/// # Lifecycle of a [Node]
///
/// Here is a graph showing the lifecycle of a [Node]:
///
/// *ReadyToConfigure*
///        |
///        |  wireAs*, wire0, wire1, wire2, ...
///        V
///  *ReadyToWire*
///        |
///        |  first usage call (subscribe*, stream, value, error, view)
///        V
///     *Wired*
///        |
///        |  any number of usage calls
///        |
///        |  dispose
///        V
///    *Disposed*
///
/// As soon as a [Node] object is constructed, it is ready to configure. At this
/// stage, no usage method can be called as the [Node] has not been configured
/// or wired.
///
/// User code must call a SINGLE wiring method to configure the [Node]. A [Node]
/// cannot be wired more than once. After this call, the [Node] is updated to
/// the `ReadyToWire` state.
///
/// Because wiring is done lazily, the [Node] remains idle until the first usage
/// call, which invokes the necessary logic to actually wire this [Node]. At
/// this point this [Node] becomes wired and all stream subscriptions/transforms
/// are operational. Usage methods can be called an unlimited number of times
/// until this [Node] is disposed of.
class Node<T> with AutoDisposerMixin {
  /// Constructs a [Node].
  Node() {
    autoDisposeCustom(() {
      _stream?.dispose();
      _stream = null;
      _wiringCallback = null;
    });
  }

  /// Returns `true` if this [Node] is configured as a settable.
  bool get settable => _settable;
  bool _settable = false;

  /// Returns a read-only view of this [Node].
  ///
  /// If this node is not settable, returns itself.
  ///
  /// If this node is settable, returns a passthrough [Node] that emits the same
  /// events. Multiple calls to this getter return the same [Node] instance.
  ///
  /// This is a usage API - this [Node] will be wired if it has not been.
  Node<T> get view {
    _ensureWired();
    _view ??= _newView;
    return _view!;
  }

  Node<T> get _newView {
    if (!settable) return this;
    final viewNode = Node<T>()..wireAsPassthroughNode(this);
    autoDispose(viewNode);
    return viewNode;
  }

  Node<T>? _view;

  /// An optional initial event passed to [stream] when this [Node] is wired.
  StreamEvent<T>? _initialEvent;

  /// Optional function to enable the [value] and [error] setters.
  ///
  /// This function is set by one of the [wire*] methods when this [Node] is
  /// constructed as a settable.
  void Function(StreamEvent<T> event)? _setter;

  /// Output of this [Node] that remains `null` until this [Node] is configured
  /// and wired.
  ReplayStream<T>? _stream;

  /// Callback that actually sets up the wiring of this [Node].
  ///
  /// During configuration (via one of the [wire*] methods), this callback
  /// becomes `non-null`. The first time this [Node] is used, this callback is
  /// invoked to set up the wiring. After this is called, [_stream] and
  /// optionally '_setter' become `non-null`. See [_ensureWired].
  void Function()? _wiringCallback;

  /// Output of this [Node].
  ///
  /// Requires that this [Node]:
  /// - has been configured via one of the [wire*] methods; OR
  /// - has been wired.
  ReplayStream<T> get stream {
    _ensureWired();
    return _stream!;
  }

  /// Sets the current value to be added to the output [stream].
  ///
  /// Requires that this [Node] is constructed as a settable and that it has
  /// been configured or wired.
  set value(T value) {
    _ensureWired();
    checkState(_setter != null, message: '$this is not settable');
    _setter!(StreamEvent<T>.data(value));
  }

  /// Sets the current error to be added to the output [stream].
  ///
  /// Requires that this [Node] is constructed as a settable and that it has
  /// been configured or wired.
  set error(Object error) {
    _ensureWired();
    checkState(_setter != null, message: '$this is not settable');
    _setter!(StreamEvent<T>.error(error));
  }

  /// Subscribes to the output of this [Node] permanently.
  ///
  /// The subscription is canceled only when this [Node] is disposed of. One can
  /// still subscribe to [stream] manually if it is desired to cancel their
  /// subscription before disposal.
  ///
  /// This method is useful when some of your data flow has more complex
  /// side effects than emitting to another stream or node. Because it is part
  /// of the data flow, the subscription is only canceled when the entire data
  /// flow is disposed of. With [subscribePermanently], you won't have to think
  /// about the disposal state.
  ///
  /// Requires that this [Node]:
  /// - has been configured via one of the [wire*] methods; OR
  /// - has been wired.
  void subscribePermanently(void Function(StreamEvent<T> event) callback) {
    _ensureWired();
    final subscriber = _stream!.listen(
      (data) => callback(StreamEvent<T>.data(data)),
      onError: (error, stackTrace) =>
          callback(StreamEvent<T>.error(error, stackTrace)),
    );
    autoDisposeCustom(subscriber.cancel);
  }

  /// Subscribes to the data output of this [Node] permanently.
  ///
  /// This method works similarly to [subscribePermanently], except that errors
  /// are simply ignored.
  void subscribeToDataPermanently(void Function(T data) callback) {
    _ensureWired();
    final subscriber = _stream!.listen(
      callback,
      onError: (error, stackTrace) {},
    );
    autoDisposeCustom(subscriber.cancel);
  }

  /// Modifier function: instructs the [Node] to be settable.
  ///
  /// Requires that this [Node] is in either the `ReadToConfigure` or the
  /// `ReadyToWire` state. See the `Lifecycle of a [Node]` section of the class
  /// documentation.
  ///
  /// Common usage:
  ///
  /// ```dart
  /// final myNode = Node<String>();
  ///
  /// myNode
  ///     ..asSettable()
  ///     ..wire0();
  /// ```
  /// You may also call [wire0] before [asSettable].
  void asSettable() {
    checkDisposed();
    checkState(_stream == null, message: '$this has been wired');
    _settable = true;
  }

  /// Modifier function: sets the initial event to [event].
  ///
  /// Requires that this [Node] is in either the `ReadToConfigure` or the
  /// `ReadyToWire` state. See the `Lifecycle of a [Node]` section of the class
  /// documentation.
  ///
  /// Common usage:
  ///
  /// ```dart
  /// final myNode = Node<String>();
  ///
  /// myNode
  ///     ..withInitialEvent(StreamEvent<String>.data('Hello'))
  ///     ..wire0();
  /// ```
  /// You may also call [wire0] before [withInitialEvent].
  void withInitialEvent(StreamEvent<T> event) {
    checkDisposed();
    checkState(_stream == null, message: '$this has been wired');
    _initialEvent = event;
  }

  /// Sets the initial event to [data].
  void withInitialData(T data) => withInitialEvent(StreamEvent<T>.data(data));

  /// Wires this [Node] such that events from [source] are passed through this
  /// to its output without processing.
  ///
  /// [source] is not listened to until this [Node] is used.
  void wireAsPassthrough(Stream<T> source) {
    _ensureReadyToConfigure();
    _wireFromSource(() => source);
  }

  /// Wires this [Node] such that events from [source] are passed through this
  /// to its output without processing.
  ///
  /// [source] is not accessed until this [Node] is used.
  void wireAsPassthroughNode(Node<T> source) {
    _ensureReadyToConfigure();
    _wireFromSource(() => source.stream);
  }

  /// Wires this [Node] such that events from [source] are transformed by
  /// [transformer] before emitted to its output stream.
  ///
  /// An alternative is to transform the source stream directly and pass the
  /// transformed stream to [wireAsPassthrough]:
  ///
  /// ```dart
  /// final stream = source.transform(debounce(Duration(milliseconds: 500)));
  /// final node = Node<String>()..wireAsPassThrough(stream);
  /// ```
  ///
  /// The disadvantage is: the debounce logic is evaluated immediately and data
  /// starts to flow as soon as they are emitted.
  ///
  /// With [wireAsTransformedStream], the wiring logic where the transformer is
  /// applied is evaluated lazily. So the debounce logic will not execute until
  /// there is an actual user of this [Node].
  ///
  /// ```dart
  /// final node = Node<String>()
  ///     ..wireAsTransformedStream(
  ///         source,
  ///         debounce(Duration(milliseconds: 500)));
  /// ```
  void wireAsTransformedStream<S>(
    Stream<S> source,
    StreamTransformer<S, T> transformer,
  ) {
    _ensureReadyToConfigure();
    _wireFromSource(() => source.transform(transformer));
  }

  /// Wires this [Node] such that output events from [source] are transformed by
  /// [transformer] before emitted to its output stream.
  ///
  /// This is functionally the same as [wireAsTransformedStream], except that it
  /// takes a [Node] rather than a direct [Stream]. The alternative is to call
  /// [wireAsTransformedStream] directly:
  ///
  /// ```dart
  /// final node = Node<String>()
  ///     ..wireAsTransformedStream(
  ///         sourceNode.stream,
  ///         debounce(Duration(milliseconds: 500)));
  /// ```
  ///
  /// However, [stream] getter is called on `sourceNode` immediately, resulting
  /// in the actual wiring of `sourceNode`. With [wireAsTransformedNode], the
  /// wiring of [sourceNode] is delayed until there is an actual user of this
  /// [Node]. Otherwise, these two approaches are equivalent.
  void wireAsTransformedNode<S>(
    Node<S> source,
    StreamTransformer<S, T> transformer,
  ) {
    _ensureReadyToConfigure();
    _wireFromSource(() => source.stream.transform(transformer));
  }

  /// Wires this [Node] such that it has no dependency.
  ///
  /// Here are some examples with [wire0]:
  ///
  /// ```dart
  /// // A node with no value.
  /// final idleNode = Node<int>..wire0();
  ///
  /// // A node with a single value that does not change.
  /// final singleValueNode = Node<int>..withInitialData(123)..wire0();
  ///
  /// // A node that emits whatever is set.
  /// final settableNode = Node<int>..asSettable()..wire0();
  /// ```
  void wire0() {
    _ensureReadyToConfigure();
    _wireFromSource(() => Stream<T>.empty());
  }

  /// Wires this [Node] such that it has one input node.
  ///
  /// The latest value from the input is converted by [converter] and passed to
  /// this [Node]'s output. Errors are forwarded.
  void wire1<E1>(Node<E1> n1, FutureOr<T> Function(E1) converter) {
    _ensureReadyToConfigure();
    _wireFromSource(() => n1.stream.asyncMap<T>(converter));
  }

  /// Wires this [Node] such that it has two input nodes.
  ///
  /// Latest values from the inputs are converted by [converter] and passed to
  /// this [Node]'s output. Errors are forwarded.
  void wire2<E1, E2>(
    Node<E1> n1,
    Node<E2> n2,
    FutureOr<T> Function(E1, E2) converter,
  ) {
    _ensureReadyToConfigure();
    _wireFromSource(
      () => combineLatest2<E1, E2, T>(n1.stream, n2.stream, converter),
    );
  }

  /// Wires this [Node] such that it has three input nodes.
  ///
  /// Latest values from the inputs are converted by [converter] and passed to
  /// this [Node]'s output. Errors are forwarded.
  void wire3<E1, E2, E3>(
    Node<E1> n1,
    Node<E2> n2,
    Node<E3> n3,
    FutureOr<T> Function(E1, E2, E3) converter,
  ) {
    _ensureReadyToConfigure();
    _wireFromSource(
      () => combineLatest3<E1, E2, E3, T>(
        n1.stream,
        n2.stream,
        n3.stream,
        converter,
      ),
    );
  }

  /// Wires this [Node] such that it has four input nodes.
  ///
  /// Latest values from the inputs are converted by [converter] and passed to
  /// this [Node]'s output. Errors are forwarded.
  void wire4<E1, E2, E3, E4>(
    Node<E1> n1,
    Node<E2> n2,
    Node<E3> n3,
    Node<E4> n4,
    FutureOr<T> Function(E1, E2, E3, E4) converter,
  ) {
    _ensureReadyToConfigure();
    _wireFromSource(
      () => combineLatest4<E1, E2, E3, E4, T>(
        n1.stream,
        n2.stream,
        n3.stream,
        n4.stream,
        converter,
      ),
    );
  }

  /// Wires this [Node] such that it has five input nodes.
  ///
  /// Latest values from the inputs are converted by [converter] and passed to
  /// this [Node]'s output. Errors are forwarded.
  void wire5<E1, E2, E3, E4, E5>(
    Node<E1> n1,
    Node<E2> n2,
    Node<E3> n3,
    Node<E4> n4,
    Node<E5> n5,
    FutureOr<T> Function(E1, E2, E3, E4, E5) converter,
  ) {
    _ensureReadyToConfigure();
    _wireFromSource(
      () => combineLatest5<E1, E2, E3, E4, E5, T>(
        n1.stream,
        n2.stream,
        n3.stream,
        n4.stream,
        n5.stream,
        converter,
      ),
    );
  }

  /// Wires this [Node] such that it has six input nodes.
  ///
  /// Latest values from the inputs are converted by [converter] and passed to
  /// this [Node]'s output. Errors are forwarded.
  void wire6<E1, E2, E3, E4, E5, E6>(
    Node<E1> n1,
    Node<E2> n2,
    Node<E3> n3,
    Node<E4> n4,
    Node<E5> n5,
    Node<E6> n6,
    FutureOr<T> Function(E1, E2, E3, E4, E5, E6) converter,
  ) {
    _ensureReadyToConfigure();
    _wireFromSource(
      () => combineLatest6<E1, E2, E3, E4, E5, E6, T>(
        n1.stream,
        n2.stream,
        n3.stream,
        n4.stream,
        n5.stream,
        n6.stream,
        converter,
      ),
    );
  }

  /// Wires this [Node] such that it has seven input nodes.
  ///
  /// Latest values from the inputs are converted by [converter] and passed to
  /// this [Node]'s output. Errors are forwarded.
  void wire7<E1, E2, E3, E4, E5, E6, E7>(
    Node<E1> n1,
    Node<E2> n2,
    Node<E3> n3,
    Node<E4> n4,
    Node<E5> n5,
    Node<E6> n6,
    Node<E7> n7,
    FutureOr<T> Function(E1, E2, E3, E4, E5, E6, E7) converter,
  ) {
    _ensureReadyToConfigure();
    _wireFromSource(
      () => combineLatest7<E1, E2, E3, E4, E5, E6, E7, T>(
        n1.stream,
        n2.stream,
        n3.stream,
        n4.stream,
        n5.stream,
        n6.stream,
        n7.stream,
        converter,
      ),
    );
  }

  /// Ensures this [Node] is wired and not disposed of.
  ///
  /// This method calls [_wiringCallback] if this [Node] has been configured but
  /// not wired.
  void _ensureWired() {
    if (_stream != null) {
      return;
    }
    checkState(
      _wiringCallback != null,
      message: '$this has not been configured for wiring.',
    );
    _wiringCallback!();
    _wiringCallback = null;
    _initialEvent = null;
    checkState(_stream != null);
  }

  /// Ensures this [Node] is not wired, not disposed of, and not configured for
  /// wiring.
  void _ensureReadyToConfigure() {
    checkState(_stream == null, message: '$this has been wired');
    checkState(
      _wiringCallback == null,
      message: '$this has been configured for wiring',
    );
  }

  /// Sets [_wiringCallback] from the [Stream] returned by [sourceBuilder].
  ///
  /// [sourceBuilder] is called within the [_wiringCallback] to ensure any
  /// action performed by [sourceBuilder] is done lazily.
  void _wireFromSource(Stream<T> Function() sourceBuilder) {
    assert(_wiringCallback == null);
    _wiringCallback = () {
      final source = sourceBuilder();
      if (_settable) {
        // A settable [Node] requires its own [StreamController] and is thus
        // slightly more expensive.
        final controller = StreamController<T>(
          // Forwarding only.
          sync: true,
        );
        autoDisposeCustom(controller.close);

        // Set up the forwarding of events from [source].
        final listener = source.listen(
          controller.add,
          onError: controller.addError,
        );
        autoDisposeCustom(listener.cancel);

        _stream = ReplayStream(controller.stream, initialEvent: _initialEvent);
        _setter = (StreamEvent<T> event) => event.emitToController(controller);
      } else {
        _stream = ReplayStream(source, initialEvent: _initialEvent);
      }
    };
  }

  @override
  String toString() {
    if (isDisposed) {
      return 'Node<$T>.disposed';
    }
    if (_stream != null) {
      final settable = _setter == null ? '' : '.settable';
      return 'Node<$T>.wired$settable';
    }
    if (_wiringCallback == null) {
      return 'Node<$T>.constructed';
    }
    return 'Node<$T>.configured';
  }
}
