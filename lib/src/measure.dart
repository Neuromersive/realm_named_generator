// Copyright 2021 MongoDB, Inc.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:build/build.dart'; // for shared logging instance log

// NOTE: humanReadable is copied from `package:build_runner_core`.
// Added rendering of durations less than a microsecond.
String humanReadable(Duration duration) {
  if (duration < const Duration(milliseconds: 1)) {
    return '${duration.inMicroseconds}μs';
  }
  if (duration < const Duration(seconds: 1)) {
    return '${duration.inMilliseconds}ms';
  }
  if (duration < const Duration(minutes: 1)) {
    return '${(duration.inMilliseconds / 1000.0).toStringAsFixed(1)}s';
  }
  if (duration < const Duration(hours: 1)) {
    final minutes = duration.inMinutes;
    final remaining = duration - Duration(minutes: minutes);
    return '${minutes}m ${remaining.inSeconds}s';
  }
  final hours = duration.inHours;
  final remaining = duration - Duration(hours: hours);
  return '${hours}h ${remaining.inMinutes}m';
}

FutureOr<T> measure<T>(FutureOr<T> Function() action, {String tag = '', int repetitions = 1}) async {
  return [
    for (int i = 0; i < repetitions; ++i)
      await (() async {
        final stopwatch = Stopwatch()..start();
        try {
          return await action();
        } finally {
          stopwatch.stop();
          final time = humanReadable(stopwatch.elapsed);
          log.info('[$tag ($i)] completed, took $time');
        }
      })()
  ].last;
}
