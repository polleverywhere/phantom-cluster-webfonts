# phantom-cluster

Phantom-cluster is a cluster of node.js workers for processing requests to
phantomjs instances.

## Benefits

* You can process requests in parallel, greatly improving performance.
* Because phantomjs processes are isolated to workers, memory leaks in them do
  not affect your master process. There's some added logic to automatically
  kill workers after a few iterations to prevent memory leaks from gobbling up
  all of your memory as well.
