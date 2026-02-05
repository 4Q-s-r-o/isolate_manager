import 'dart:collection';

import 'package:isolate_manager/src/models/isolate_queue.dart';
import 'package:isolate_manager/src/priority.dart';

/// Strategy to control a new (incoming) computation if the maximum number of Queues
/// is reached.
///
/// Some of strategies:
///   - [UnlimitedStrategy] - is default.
///   - [RejectIncomingStrategy]
abstract class QueueStrategy<R, P> {
  /// Strategy to control a new (incoming) computation if the maximum number of Queues
  /// is reached. The maximum number is unlimited if [maxCount] <= 0 (by default).
  ///
  /// Isolates count should be the same as concurrent isolates for best performance
  ///
  /// Some of strategies:
  ///   - [UnlimitedStrategy] is default.
  ///   - [RejectIncomingStrategy]
  QueueStrategy({this.maxCount = 0, required int isolatesCount}){

    for (var i=0;i<isolatesCount;i++){
      queues.add({
        for (final priority in Priority.values)
        priority: Queue()
      });
      isolatesLoad.add(0);
    }
  }

  /// Priority Queues for each isolate
  final List<Map<Priority, Queue<IsolateQueue<R, P>>>> queues = [];

  /// Tasks left per isolate
  final List<int> isolatesLoad = []; 

  /// Max number of queued computations.
  ///
  /// If this value <= 0, the number of queues is unlimited (default).
  final int maxCount;

  /// Number of the current queues.
  int get queuesCount => isolatesLoad.reduce((a,b) => a+b);

  /// Determines if a new computation should be added to the queue when
  /// the maximum count is exceeded.
  ///
  /// Returns:
  ///   - true: to continue adding the new computation to the queue.
  ///   - false: to stop adding new computations.
  bool continueIfMaxCountExceeded();

  /// Add a new computation to the Queue.
  void add(IsolateQueue<R, P> queue, {Priority priority = Priority.low, int? onIsolateIdx}) {
    if (maxCount > 0 && queuesCount >= maxCount) {
      if (!continueIfMaxCountExceeded()) return;
    }
    if (onIsolateIdx == null){
      var bestLoad = 0;
      var bestIdx = 0;
      for (final (int idx, int load) in isolatesLoad.indexed){
        if (load < bestLoad){
          bestLoad = load;
          bestIdx = idx;
        }
      }
      isolatesLoad[bestIdx] += 1;
      queues[bestIdx][priority]!.add(queue);
    } else {
      isolatesLoad[onIsolateIdx] += 1;
      queues[onIsolateIdx][priority]!.add(queue);
    }
  }

  /// Check if the Queue is not empty.
  bool hasNext([int? onIsolateIdx]) {
    if (onIsolateIdx == null){
      return isolatesLoad.any((load) => load > 0);
    } else {
      return isolatesLoad[onIsolateIdx] > 0;
    }
  }

  /// Get the next computation.
  IsolateQueue<R, P> getNext([int? onIsolateIdx]) {
    assert(hasNext(), 'Can only `getNext` when there is a next element');
    for (final priority in Priority.sorted) {
      if (onIsolateIdx == null) {
        for (final (idx, isolate) in queues.indexed){
          if (isolate[priority]!.isNotEmpty){
            isolatesLoad[idx] -= 1; 
            return isolate[priority]!.removeFirst();
          }
        }
      } else {
        if (queues[onIsolateIdx][priority]!.isNotEmpty) {
          isolatesLoad[onIsolateIdx] -= 1;
          return queues[onIsolateIdx][priority]!.removeFirst();
        }
      }
    }
    throw Exception('No next element available');
  }

  /// Clear all queues.
  void clear() {
    for (final isolate in queues) {
      isolate.forEach((_, queue) => queue.clear());
    }
  }
}

/// Unlimited queued computations.
class UnlimitedStrategy<R, P> extends QueueStrategy<R, P> {
  /// Unlimited queued computations.
  UnlimitedStrategy({required super.isolatesCount});

  @override
  bool continueIfMaxCountExceeded() => true;
}


/// Discard the new incoming computation if the [maxCount] is exceeded.
class RejectIncomingStrategy<R, P> extends QueueStrategy<R, P> {
  /// Discard the new incoming computation if the [maxCount] is exceeded.
  RejectIncomingStrategy({required super.isolatesCount, super.maxCount = 0});

  @override
  bool continueIfMaxCountExceeded() {
    // It means the current computation should NOT be added to the Queue.
    return false;
  }
}
