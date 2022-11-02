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

/// A library that supports executing different async functions in sequential
/// order.

import 'dart:collection';

import 'package:quiver/check.dart';

/// A sequencer of asynchronous tasks.
///
/// If there is no pending task, a newly added task starts executing at a later
/// microtask but as soon as Dart allows. The small gap is to allow the caller
/// attach error catchers.
///
/// If there are pending tasks, a newly added task waits until all of them are
/// completed before it starts to execute. Even if some tasks threw, the new
/// task is not affected and continues to execute.
///
/// # Zones
///
/// [SequentialExecutor] does not have any special handling of Dart zones. Apps
/// should execute the usual caution in a multi-zone environment, especially
/// around error-handling. See
/// https://dart.dev/articles/archive/zones#handling-asynchronous-errors for
/// details.
class SequentialExecutor {
  /// Queued tasks.
  final _queue = Queue<Future>();

  /// Submits a new [task] into the internal queue and returns a [Future] that
  /// completes with [task]'s result.
  ///
  /// [task] is not run until pending tasks added earlier are completed.
  Future<T> run<T>(Future<T> Function() task) {
    checkArgument(task != null);
    if (_queue.isEmpty) {
      return _enqueue<T>(_run(task));
    }
    // Wait for the last queued task to finish, then execute this [task].
    return _enqueue<T>(_chain<T>(_queue.last, task));
  }

  /// Enqueues [future] and make it remove itself from the queue when completed.
  Future<T> _enqueue<T>(Future<T> future) {
    _queue.add(future);
    return future.whenComplete(_queue.removeFirst);
  }

  /// Runs [task] at a later microtask to ensure the caller has a chance to
  /// attach error catchers.
  Future<T> _run<T>(Future<T> Function() task) async => await task();

  /// Runs [task] after [future] is done and returns the task's result.
  Future<T> _chain<T>(Future future, Future<T> Function() task) async {
    try {
      await future;
    } catch (e) {
      // Intentionally catch all. The previous task's status doesn't matter.
    }
    return await task();
  }
}
