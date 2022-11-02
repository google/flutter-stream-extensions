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
import 'dart:collection';

import 'package:meta/meta.dart';

import 'stream_event.dart';

/// A [Stream] implementation that replays the latest event.
///
/// A [ReplayStream] is always a broadcast stream. [ReplayStream.isBroadcast]
/// always returns `true`. All types of events can be replayed, including data
/// and errors.
///
/// # Construction
///
/// A [ReplayStream] can be created from an existing [Stream]:
///
/// ```dart
/// final replayStream = ReplayStream(myStream);
/// ```
///
/// [ReplayStream]s created this way do not have an event to replay until the
/// delegate (`myStream` in the example) notifies it of some event. To ensure
/// that an event is always available to replay, you may pass an `initialEvent`
/// to the constructor:
///
/// ```dart
/// final replayStream = ReplayStream(
///     myStream,
///     initialEvent: StreamEvent<int>.data(123),
/// );
/// ```
///
/// # Contract
///
/// By default, the delegate [Stream] is subscribed to once this [ReplayStream]
/// is constructed.
///
/// If [idleUntilFirstSubscription] is `true`, however, the delegate [Stream] is
/// only subscribed to when this [ReplayStream] has its first subscriber.
///
/// Note that [ReplayStream] does not have time-travel abilities. Only the
/// latest event emitted from the delegate [Stream] AFTER this [ReplayStream]
/// subscribes to the former can be replayed.
///
/// The latest event can be retrieved synchronously using the [event] property:
///
/// ```dart
/// final event = replayStream.event;
/// ```
///
/// Once a [ReplayStream] subscribes to the delegate [Stream], it keeps the
/// subscription active until the delegate [Stream] is closed. There is no way
/// to cancel the subscription prematurely.
///
/// # Closed streams
///
/// If the delegate [Stream] closes, this [ReplayStream] forwards the `done`
/// event to current subscribers and closes them. Future subscribers will
/// receive the latest event if available, followed immediately by a `done`
/// event.
///
/// Even if a [ReplayStream] is closed, its `event` property is still
/// accessible. It contains the latest event received before the closure.
///
/// # Idle until first subscription
///
/// A common pattern around streams is to start generating events only after
/// the stream has been subscribed to. For example:
///
/// ```dart
/// final controller = StreamController<int>(onListen: _generateData);
/// Stream<int> get stream => controller.stream;
///
/// ...
///
/// stream.listen(...);
///
/// ```
///
/// `_generateData` is only called after the stream is subscribed to so it can
/// start adding data to the controller.
///
/// This pattern does not work with the default [ReplayStream], because
/// [ReplayStream] needs to subscribe to the delegate [Stream] to get the latest
/// event recorded.
///
/// If this behavior is undesired, you may pass `true` to the
/// [idleUntilFirstSubscription] constructor argument. As a result,
/// [ReplayStream] stays docile and does not listen to the delegate stream. When
/// this [ReplayStream] is first subscribed to, it will start listening to the
/// delegate stream and recording the latest event.
///
/// # Callback ordering
///
/// When a [ReplayStream] has multiple subscribers, the order in which they are
/// notified of a new event is undefined but stable. For details, see the
/// iteration order of [HashSet].
class ReplayStream<T> extends Stream<T> {
  /// Creates a [ReplayStream] from [_stream] that replays the latest event from
  /// [_stream] to new subscribers.
  ///
  /// If [initialEvent] is not null, it is replayed to new subscribers until
  /// there is an event from [_stream].
  ///
  /// If [idleUntilFirstSubscription] is true, this [ReplayStream] does not
  /// listen to [_stream] until it has its first subscriber. Note if [_stream]
  /// is a hot stream and has other subscribers, any event emitted will be lost
  /// until this [ReplayStream]'s first subscription.
  ///
  /// If [idleUntilFirstSubscription] is false (default behavior), this
  /// [ReplayStream] starts listening to [_stream] immediately.
  ReplayStream(
    this._stream, {
    StreamEvent<T>? initialEvent,
    bool idleUntilFirstSubscription = false,
  }) : _event = initialEvent {
    if (!idleUntilFirstSubscription) {
      _ensureConfigured();
    }
  }

  /// A [ReplayStream] is always broadcast.
  @override
  bool get isBroadcast => true;

  /// Returns the latest event emitted from the stream, if available.
  ///
  /// [event] is guaranteed to be updated with a value `X` before any
  /// subscriber of this [ReplayStream] learn of this value.
  StreamEvent<T>? get event => _event;

  /// Whether this [ReplayStream] has been configured.
  bool _configured = false;

  /// The delegate stream from the constructor argument.
  final Stream<T> _stream;

  /// Subscription on the delegate stream.
  StreamSubscription<T>? _listener;

  /// The latest value of the delegate stream.
  StreamEvent<T>? _event;

  /// Current subscribers.
  ///
  /// Each subscriber is identified by its private [StreamController] object.
  /// [_subscribers] is `null` when [_configured] is `false`. It is also set to
  /// `null` when the delegate stream is closed.
  Set<StreamController<T>>? _subscribers;

  /// Returns true if this [ReplayStream] has seen the `done` event.
  bool get _isClosed => _configured && _subscribers == null;

  /// Configures this [ReplayStream] so it starts to record the latest event.
  ///
  /// This method is idempotent.
  void _ensureConfigured() {
    if (_configured) {
      return;
    }
    _configured = true;
    _subscribers = HashSet<StreamController<T>>();
    _listener = _stream.listen(_onData, onError: _onError, onDone: _onDone);
  }

  /// Updates [event] and forwards [data] to current subscribers.
  void _onData(T data) {
    _event = StreamEvent<T>.data(data);
    _forwardEvent(_event!);
  }

  /// Updates [event] and forwards [error] and [stackTrace] to current
  /// subscribers.
  void _onError(Object error, StackTrace stackTrace) {
    _event = StreamEvent<T>.error(error, stackTrace);
    _forwardEvent(_event!);
  }

  /// Cancels [_listener] on the delegate stream and closes all existing
  /// subscribers.
  ///
  /// After this call, [_subscribers] is `null`.
  void _onDone() {
    if (_listener != null) {
      _listener!.cancel();
      _listener = null;
    }
    if (_subscribers != null) {
      final subscribers = _subscribers!.toList(growable: false);
      _subscribers = null;
      for (final controller in subscribers) {
        // Close the [controller] to send a `done` event.
        controller.close();
      }
    }
  }

  void dispose() {
    _onDone();
  }

  /// Forwards [event] to current subscribers.
  ///
  /// A defensive copy of [_subscriber] is made immediately in case of
  /// subscriptions/unsubscriptions during this call. A subscriber added in one
  /// of the callbacks will not get this [event]. A subscriber removed in one of
  /// the callbacks may or may not get this [event] depending on the order of
  /// the callbacks.
  void _forwardEvent(StreamEvent<T> event) {
    final subscribers = _subscribers!.toList(growable: false);
    for (final controller in subscribers) {
      if (_subscribers!.contains(controller)) {
        event.emitToController(controller);
      }
    }
  }

  /// Listens to the [ReplayStream]. If a latest [event] is available, it is
  /// passed to the listener as if it is the first event on the stream.
  ///
  /// For synchronous access to the latest event, use the [event] getter
  /// directly.
  @override
  StreamSubscription<T> listen(
    void Function(T data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _ensureConfigured();
    StreamController<T>? controller;
    controller = StreamController<T>(
      // Forwarding only.
      sync: true,
      onCancel: () {
        _unsubscribe(controller);
      },
    );
    _replayEvent(controller);
    if (_isClosed) {
      controller.close();
    } else {
      _subscribe(controller);
    }
    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// Emits [_event] to [controller], if [_event] is not `null`.
  void _replayEvent(StreamController<T> controller) =>
      _event?.emitToController(controller);

  /// Adds a new subscriber identified by [controller].
  void _subscribe(StreamController<T> controller) {
    assert(_subscribers != null);
    _subscribers!.add(controller);
  }

  /// Removes an existing subscriber identified by [controller].
  ///
  /// This method does nothing if an existing subscriber cannot be found. Note
  /// there is no need to close the [controller] as there is no cleanup other
  /// than removing it from the [_subscribers] set.
  void _unsubscribe(StreamController<T>? controller) =>
      _subscribers?.remove(controller);

  /// Returns true if this stream is listening to the stream it's replaying.
  ///
  /// This becomes true when the stream being replayed starts being listened to
  /// and becomes false when the stream being listened to is done or this
  /// stream is disposed.
  @visibleForTesting
  bool get isListening => _listener != null;
}
