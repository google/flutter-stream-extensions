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

/// A library that supports executing the same async function multiple times in
/// an orderly fashion.

import 'dart:async';
import 'dart:collection';

import 'package:auto_disposable/auto_disposable.dart';
import 'package:quiver/check.dart';

import 'flow.dart';

/// Final status of an individual execution.
enum ExecutionStatus {
  /// This execution has completed and its result, data or error, was emitted.
  done,

  /// This execution was preempted by a later execution started before this
  /// execution was able to complete. As a result, its result was simply not
  /// emitted.
  preempted,

  /// This execution was aborted because it did not complete before this
  /// [OrderedExecutor] was disposed.
  aborted,
}

/// An executor that supports running the same async function multiple times
/// with different params.
///
/// This executor enforces the ordering of those executions. While multiple
/// execution may occur, only the last one may emit value/error and others are
/// simply preempted and their results ignored.
///
/// If a new execution is scheduled by [run()] when there is already a pending
/// execution with the same [Param], this executor does not start a new
/// execution. This is useful to avoid running duplicate async functions that
/// are expensive.
///
/// See [ExecutionStatus] for supported execution outcomes.
///
/// # When to use
///
/// This class is best suited if you have an existing data flow that depends on
/// some async function to update. See `flow.dart`.
///
/// Particularly, this is useful when updates are expensive and dependent on
/// user interactions. For example, a user can potentially attempt to refresh
/// some data a few times within a short amount of time. And each refresh
/// function involves an expensive RPC. If an RPC is in-flight, you can make use
/// of an [OrderedExecutor] to avoid sending a duplicate one.
///
/// # Side effects
///
/// Note you cannot terminate an async function. So any side effect in your
/// callback remains effective. For example, if your callback updates a cache,
/// the ordering of those cache updates is undefined:
///
/// ```dart
/// Future<bool> fetchBooks(String bookType) async {
///   final List<Book> books = await expensiveRpc(bookType);
///   _cache.update(bookType, books);
///   return true;
/// }
/// ```
/// In this example, [fetchBooks] has a side effect - it updates the cache
/// inside the function. If multiple [fetchBooks] are running, the cache updates
/// happen in an undefined order. It is generally recommended that you remove
/// side effects from the callback function:
///
/// ```dart
/// /// Might be better to replace [Tuple2] with your own data structure.
/// Future<Tuple2<String, List<Book>>> fetchBooks(String bookType) async {
///   final books = await expensiveRpc(bookType);
///   return Tuple2(bookType, books);
/// }
///
/// final executor = OrderedExecutor(fetchBooks);
///
/// executor.result.subscribeToDataPermanently((tuple2) {
///   _cache.update(tuple2.item1, tuple2.item2);
/// });
/// ```
class OrderedExecutor<Param, Result> with AutoDisposerMixin {
  /// Constructs an [OrderedExecutor] with the async function to run.
  ///
  /// The async function is allowed to return `null`s or throw. The result,
  /// either data or error, is emitted to [result] if and only if the execution
  /// returns [ExecutionStatus.done]. See [run()] for details.
  OrderedExecutor(this._callback) {
    result
      ..asSettable()
      ..wire0();
    autoDispose(result);

    busy
      ..withInitialData(false)
      ..asSettable()
      ..wire0();
    autoDispose(busy);
  }

  /// Async function to run by this executor.
  final Future<Result> Function(Param) _callback;

  /// Result [Node] of the executions.
  final result = Node<Result>();

  /// Status [Node] of whether this executor is busy running.
  final busy = Node<bool>();

  /// Pending executions.
  final _pending = HashMap<Param, Completer<ExecutionStatus>>();

  /// [Param] of the latest execution.
  Param? _latest;

  /// Starts an execution with [param] and returns a [Future] with the final
  /// status of this execution. The returned [Future] never throws.
  ///
  /// See [ExecutionStatus] for when a specific value is returned.
  ///
  /// If there is a pending execution with the same [param], this method does
  /// not start a new execution. It simply returns a [Future] that binds to the
  /// same pending execution.
  Future<ExecutionStatus> run(Param param) async {
    checkDisposed();
    checkArgument(
      param != null,
      message: 'Param is required',
    );
    // Update [_latest] immediately as it determines which execution should emit
    // when it is complete.
    _latest = param;
    final matchingExecution = _pending[param];
    if (matchingExecution != null) {
      // Return immediately when there is a matching execution, without starting
      // a new one.
      return matchingExecution.future;
    }
    return _startExecution(param);
  }

  /// Starts a new execution with non-null [param] assuming there is no pending
  /// execution with the same [param].
  Future<ExecutionStatus> _startExecution(Param param) {
    assert(param != null);
    if (_pending.isEmpty) {
      busy.value = true;
    }
    final completer = Completer<ExecutionStatus>();
    _pending[param] = completer;
    _runGuarded(param);
    return completer.future;
  }

  void _runGuarded(Param param) async {
    try {
      _completeWithResult(param, await _callback(param));
    } catch (error) {
      _completeWithError(param, error);
    }
  }

  void _completeWithResult(Param param, Result value) {
    final completer = _complete(param);
    if (completer != null) {
      result.value = value;
      completer.complete(ExecutionStatus.done);
    }
  }

  void _completeWithError(Param param, Object error) {
    final completer = _complete(param);
    if (completer != null) {
      result.error = error;
      completer.complete(ExecutionStatus.done);
    }
  }

  Completer<ExecutionStatus>? _complete(Param param) {
    final completer = _pending.remove(param);
    if (completer == null) {
      return null;
    }
    if (isDisposed) {
      completer.complete(ExecutionStatus.aborted);
      return null;
    }
    if (_pending.isEmpty) {
      busy.value = false;
    }
    if (param != _latest) {
      completer.complete(ExecutionStatus.preempted);
      return null;
    }
    return completer;
  }
}
