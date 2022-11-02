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

/// Useful converters for the flow library.

import 'dart:async';

import 'package:tuple/tuple.dart';

import 'stream_event.dart';

/// Converts a pair of values into a [Tuple2], useful for wiring a `Node` with
/// two inputs.
Tuple2<E1, E2> convertToTuple2<E1, E2>(E1 v1, E2 v2) => Tuple2<E1, E2>(v1, v2);

/// Converts a triplet of values into a [Tuple3], useful for wiring a `Node`
/// with three inputs.
Tuple3<E1, E2, E3> convertToTuple3<E1, E2, E3>(E1 v1, E2 v2, E3 v3) =>
    Tuple3<E1, E2, E3>(v1, v2, v3);

/// Converts a quadruplet of values into a [Tuple4], useful for wiring a `Node`
/// with four inputs.
Tuple4<E1, E2, E3, E4> convertToTuple4<E1, E2, E3, E4>(
  E1 v1,
  E2 v2,
  E3 v3,
  E4 v4,
) =>
    Tuple4<E1, E2, E3, E4>(v1, v2, v3, v4);

/// Converts a quintuple of values into a [Tuple5], useful for wiring a `Node`
/// with five inputs.
Tuple5<E1, E2, E3, E4, E5> convertToTuple5<E1, E2, E3, E4, E5>(
  E1 v1,
  E2 v2,
  E3 v3,
  E4 v4,
  E5 v5,
) =>
    Tuple5<E1, E2, E3, E4, E5>(v1, v2, v3, v4, v5);

/// Converts a six-tuple of values into a [Tuple6], useful for wiring a `Node`
/// with six inputs.
Tuple6<E1, E2, E3, E4, E5, E6> convertToTuple6<E1, E2, E3, E4, E5, E6>(
  E1 v1,
  E2 v2,
  E3 v3,
  E4 v4,
  E5 v5,
  E6 v6,
) =>
    Tuple6<E1, E2, E3, E4, E5, E6>(v1, v2, v3, v4, v5, v6);

/// Converts a seven-tuple of values into a [Tuple7], useful for wiring a `Node`
/// with seven inputs.
Tuple7<E1, E2, E3, E4, E5, E6, E7> convertToTuple7<E1, E2, E3, E4, E5, E6, E7>(
  E1 v1,
  E2 v2,
  E3 v3,
  E4 v4,
  E5 v5,
  E6 v6,
  E7 v7,
) =>
    Tuple7<E1, E2, E3, E4, E5, E6, E7>(v1, v2, v3, v4, v5, v6, v7);

/// A [StreamTransformer] that applies [converter] to each source [StreamEvent]
/// and emits another [StreamEvent].
///
/// Unlike a regular converter function which only converts data values, this
/// transformer accepts a converter function that takes both data values and
/// errors.
///
/// When [converter] returns a data [StreamEvent], the value is emitted.
///
/// When [converter] returns an error [StreamEvent] or throws, the error is
/// emitted.
StreamTransformer<S, T> convertStreamEvent<S, T>(
  StreamEvent<T> Function(StreamEvent<S>) converter,
) =>
    StreamTransformer<S, T>.fromHandlers(
      handleData: (S data, EventSink<T> sink) =>
          _convertAndEmit(sink, StreamEvent<S>.data(data), converter),
      handleError: (Object error, StackTrace stackTrace, EventSink<T> sink) =>
          _convertAndEmit(
        sink,
        StreamEvent<S>.error(error, stackTrace),
        converter,
      ),
      handleDone: (EventSink<T> sink) => sink.close(),
    );

void _convertAndEmit<S, T>(
  EventSink<T?> sink,
  StreamEvent<S> input,
  StreamEvent<T> Function(StreamEvent<S>) converter,
) {
  try {
    final output = converter(input);
    if (output.hasData) {
      sink.add(output.data);
    } else {
      sink.addError(output.error, output.stackTrace);
    }
  } catch (error, stackTrace) {
    sink.addError(error, stackTrace);
  }
}
