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

/// Utility combiners based on `package:stream_transform`.
///
/// All methods delegate to the [combineLatest] function.

import 'dart:async';

import 'package:stream_transform/stream_transform.dart';
import 'package:tuple/tuple.dart';

import 'flow_converters.dart';

/// Combines the latest values from [t1] and [t2] using [combiner].
///
/// This is just syntactic sugar for [transform()] and [combineLatest()].
Stream<Output> combineLatest2<T1, T2, Output>(
  Stream<T1> t1,
  Stream<T2> t2,
  FutureOr<Output> Function(T1, T2) combiner,
) =>
    t1.combineLatest(t2, combiner);

/// Combines the latest values from [t1] and [t2] and returns a tuple stream.
///
/// This method delegates to [combineLatest2()].
Stream<Tuple2<T1, T2>> combineLatestTuple2<T1, T2>(
  Stream<T1> t1,
  Stream<T2> t2,
) =>
    combineLatest2(t1, t2, convertToTuple2);

/// Combines the latest values from [t1], [t2], and [t3] using [combiner].
///
/// This is just syntactic sugar for [transform()] and [combineLatest()].
Stream<Output> combineLatest3<T1, T2, T3, Output>(
  Stream<T1> t1,
  Stream<T2> t2,
  Stream<T3> t3,
  FutureOr<Output> Function(T1, T2, T3) combiner,
) =>
    combineLatest2<Tuple2<T1, T2>, T3, Output>(
      combineLatestTuple2(t1, t2),
      t3,
      (tuple, v3) => combiner(tuple.item1, tuple.item2, v3),
    );

/// Combines the latest values from [t1], [t2], and [t3] and returns a tuple
/// stream.
///
/// This method delegates to [combineLatest3()].
Stream<Tuple3<T1, T2, T3>> combineLatestTuple3<T1, T2, T3>(
  Stream<T1> t1,
  Stream<T2> t2,
  Stream<T3> t3,
) =>
    combineLatest3(t1, t2, t3, convertToTuple3);

/// Combines the latest values from [t1], [t2], [t3], and [t4] using [combiner].
///
/// This is just syntactic sugar for [transform()] and [combineLatest()].
Stream<Output> combineLatest4<T1, T2, T3, T4, Output>(
  Stream<T1> t1,
  Stream<T2> t2,
  Stream<T3> t3,
  Stream<T4> t4,
  FutureOr<Output> Function(T1, T2, T3, T4) combiner,
) =>
    combineLatest2<Tuple3<T1, T2, T3>, T4, Output>(
      combineLatestTuple3(t1, t2, t3),
      t4,
      (tuple, v4) => combiner(tuple.item1, tuple.item2, tuple.item3, v4),
    );

/// Combines the latest values from [t1], [t2], [t3], and [t4] and returns a
/// tuple stream.
///
/// This method delegates to [combineLatest4()].
Stream<Tuple4<T1, T2, T3, T4>> combineLatestTuple4<T1, T2, T3, T4>(
  Stream<T1> t1,
  Stream<T2> t2,
  Stream<T3> t3,
  Stream<T4> t4,
) =>
    combineLatest4(t1, t2, t3, t4, convertToTuple4);

/// Combines the latest values from [t1], [t2], [t3], [t4], and [t5] using
/// [combiner].
///
/// This is just syntactic sugar for [transform()] and [combineLatest()].
Stream<Output> combineLatest5<T1, T2, T3, T4, T5, Output>(
  Stream<T1> t1,
  Stream<T2> t2,
  Stream<T3> t3,
  Stream<T4> t4,
  Stream<T5> t5,
  FutureOr<Output> Function(T1, T2, T3, T4, T5) combiner,
) =>
    combineLatest2<Tuple4<T1, T2, T3, T4>, T5, Output>(
      combineLatestTuple4(t1, t2, t3, t4),
      t5,
      (tuple, v5) =>
          combiner(tuple.item1, tuple.item2, tuple.item3, tuple.item4, v5),
    );

/// Combines the latest values from [t1], [t2], [t3], [t4], and [t5] and returns
/// a tuple stream.
///
/// This method delegates to [combineLatest5()].
Stream<Tuple5<T1, T2, T3, T4, T5>> combineLatestTuple5<T1, T2, T3, T4, T5>(
  Stream<T1> t1,
  Stream<T2> t2,
  Stream<T3> t3,
  Stream<T4> t4,
  Stream<T5> t5,
) =>
    combineLatest5(t1, t2, t3, t4, t5, convertToTuple5);

/// Combines the latest values from [t1], [t2], [t3], [t4], [t5], and [t6] using
/// [combiner].
///
/// This is just syntactic sugar for [transform()] and [combineLatest()].
Stream<Output> combineLatest6<T1, T2, T3, T4, T5, T6, Output>(
  Stream<T1> t1,
  Stream<T2> t2,
  Stream<T3> t3,
  Stream<T4> t4,
  Stream<T5> t5,
  Stream<T6> t6,
  FutureOr<Output> Function(T1, T2, T3, T4, T5, T6) combiner,
) =>
    combineLatest2<Tuple5<T1, T2, T3, T4, T5>, T6, Output>(
      combineLatestTuple5(t1, t2, t3, t4, t5),
      t6,
      (tuple, v6) => combiner(
        tuple.item1,
        tuple.item2,
        tuple.item3,
        tuple.item4,
        tuple.item5,
        v6,
      ),
    );

/// Combines the latest values from [t1], [t2], [t3], [t4], [t5], and [t6] and
/// returns a tuple stream.
///
/// This method delegates to [combineLatest6()].
Stream<Tuple6<T1, T2, T3, T4, T5, T6>>
    combineLatestTuple6<T1, T2, T3, T4, T5, T6>(
  Stream<T1> t1,
  Stream<T2> t2,
  Stream<T3> t3,
  Stream<T4> t4,
  Stream<T5> t5,
  Stream<T6> t6,
) =>
        combineLatest6(t1, t2, t3, t4, t5, t6, convertToTuple6);

/// Combines the latest values from [t1], [t2], [t3], [t4], [t5], [t6] and [t7]
/// using [combiner].
///
/// This is just syntactic sugar for [transform()] and [combineLatest()].
Stream<Output> combineLatest7<T1, T2, T3, T4, T5, T6, T7, Output>(
  Stream<T1> t1,
  Stream<T2> t2,
  Stream<T3> t3,
  Stream<T4> t4,
  Stream<T5> t5,
  Stream<T6> t6,
  Stream<T7> t7,
  FutureOr<Output> Function(T1, T2, T3, T4, T5, T6, T7) combiner,
) =>
    combineLatest2<Tuple6<T1, T2, T3, T4, T5, T6>, T7, Output>(
      combineLatestTuple6(t1, t2, t3, t4, t5, t6),
      t7,
      (tuple, v7) => combiner(
        tuple.item1,
        tuple.item2,
        tuple.item3,
        tuple.item4,
        tuple.item5,
        tuple.item6,
        v7,
      ),
    );

/// Combines the latest values from [t1], [t2], [t3], [t4], [t5], [t6], and [t7]
/// and returns a tuple stream.
///
/// This method delegates to [combineLatest7()].
Stream<Tuple7<T1, T2, T3, T4, T5, T6, T7>>
    combineLatestTuple7<T1, T2, T3, T4, T5, T6, T7>(
  Stream<T1> t1,
  Stream<T2> t2,
  Stream<T3> t3,
  Stream<T4> t4,
  Stream<T5> t5,
  Stream<T6> t6,
  Stream<T7> t7,
) =>
        combineLatest7(t1, t2, t3, t4, t5, t6, t7, convertToTuple7);
