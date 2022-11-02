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
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:quiver/check.dart';
import 'package:quiver/core.dart';

/// One of the two possible states of [StreamEvent]. They are mutually
/// exclusive.
enum _StreamEventState {
  hasData,
  hasError,
}

/// An immutable class representing an event from a [Stream<T>].
@immutable
class StreamEvent<T> {
  /// State of this [StreamEvent].
  final _StreamEventState _state;

  /// Whether this event contains `data`.
  ///
  /// [hasData] is always the negate of [hasError].
  bool get hasData => _state == _StreamEventState.hasData;

  /// Whether this event contains `error`.
  ///
  /// [hasData] is always the negate of [hasError].
  bool get hasError => _state == _StreamEventState.hasError;

  /// Data of this event.
  ///
  /// Access to this getter is prohibited when [hasData] is `false`. This field
  /// can be `null`.
  T? get data {
    checkState(hasData);
    return _data;
  }

  final T? _data;

  /// Error of this event.
  ///
  /// Access to this getter is prohibited when [hasError] is `false`.
  Object get error {
    checkState(hasError);
    return _error!;
  }

  final Object? _error;

  /// StackTrace of this event.
  ///
  /// Access to this getter is prohibited when [hasError] is `false`. This field
  /// can be `null`.
  StackTrace? get stackTrace {
    checkState(hasError);
    return _stackTrace;
  }

  final StackTrace? _stackTrace;

  /// Constructs a [StreamEvent] with data and no error.
  const StreamEvent.data(T data)
      : _state = _StreamEventState.hasData,
        _data = data,
        _error = null,
        _stackTrace = null;

  /// Constructs a [StreamEvent] with error and no data.
  const StreamEvent.error(
    Object error, [
    StackTrace stackTrace = StackTrace.empty,
  ])  : _state = _StreamEventState.hasError,
        _data = null,
        _error = error,
        _stackTrace = stackTrace;

  /// Emits this event to the given [controller].
  void emitToController(StreamController<T?> controller) {
    if (hasData) {
      controller.add(data);
    } else {
      controller.addError(error, stackTrace);
    }
  }

  @override
  bool operator ==(other) {
    if (other is StreamEvent<T>) {
      return other._state == _state &&
          other._data == _data &&
          other._error == _error &&
          other._stackTrace == _stackTrace;
    }
    return false;
  }

  @override
  int get hashCode => hashObjects([
        _state,
        _data,
        _error,
        _stackTrace,
      ]);

  @override
  String toString() {
    var stackTraceString = _stackTrace?.toString() ?? '';
    return '$runtimeType($_state, $_data, $_error'
        ', ${stackTraceString.substring(0, min(10, stackTraceString.length))})';
  }
}
