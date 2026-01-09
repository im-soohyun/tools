/**
 * @kind path-problem
 * @id python/taint-tracking
 */

 import python
 import semmle.python.dataflow.new.DataFlow
 import semmle.python.dataflow.new.TaintTracking
 import semmle.python.dataflow.new.RemoteFlowSources

 module Config implements DataFlow::ConfigSig {
   predicate isSource(DataFlow::Node source) {
     source instanceof RemoteFlowSource
   }

   predicate isSink(DataFlow::Node sink) {
     any()
   }
 }

 module Flow = TaintTracking::Global<Config> config;
 import Flow::PathGraph

 from Flow::PathNode source, Flow::PathNode sink
 where config::flowPath(source, sink)
 select sink.getNode(), source, sink
