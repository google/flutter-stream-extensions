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

/// A library with classes that provide Flutter support.

import 'dart:async';

import 'package:flutter/widgets.dart';

/// A widget that builds itself based on the latest DISTINCT value from a
/// [Stream].
///
/// This widget is more restrictive than [StreamBuilder] in the following ways:
/// - [DistinctStreamBuilder] expects that the [Stream] does not throw errors.
/// - If a new value from the [Stream] is the same as the previous value,
///   nothing happens.
///
/// # Configuration change.
///
/// This widget resets the current value to [initialValue] and builds the next
/// frame using [builder]. The current stream subscription is retained if
/// [stream] is not changed. Otherwise, it is canceled and a new stream
/// subscription created from the new [stream].
///
/// The only exception is when both [initialValue] and [stream] remain the same
/// - this widget retains the current value and stream subscription. It builds
/// the next frame with the current value and updated [builder].
class DistinctStreamBuilder<T> extends StatefulWidget {
  const DistinctStreamBuilder({
    required this.stream,
    required this.builder,
    this.initialValue,
    this.child,
    Key? key,
  }) : super(key: key);

  final Stream<T> stream;
  final Widget Function(BuildContext, Widget?, T?) builder;
  final T? initialValue;
  final Widget? child;

  @override
  _DistinctStreamBuilderState createState() => _DistinctStreamBuilderState<T>();
}

/// [State] created by [DistinctStreamBuilder].
class _DistinctStreamBuilderState<T> extends State<DistinctStreamBuilder<T?>> {
  T? _value;
  StreamSubscription<T?>? _listener;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _subscribe();
  }

  @override
  void didUpdateWidget(DistinctStreamBuilder<T?> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream == widget.stream &&
        oldWidget.initialValue == widget.initialValue) {
      return;
    }
    _value = widget.initialValue;
    if (oldWidget.stream != widget.stream) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.child, _value);

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    assert(_listener == null);
    _listener = widget.stream.listen((value) {
      if (value != _value) {
        setState(() => _value = value);
      }
    });
  }

  void _unsubscribe() {
    if (_listener != null) {
      _listener!.cancel();
      _listener = null;
    }
  }
}
