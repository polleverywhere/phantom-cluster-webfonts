# phantom-cluster

Phantom-cluster is a cluster of node.js workers for processing requests with
phantomjs instances in parallel. Built-in functionality prevents memory leaks
from phantomjs processes: the number of pages open at a time is capped, and
workers are automatically restarted after a few iterations.

Two modes are supported. `PhantomClusterServer` and `PhantomClusterClient`
provide bare-bones functionality: they simply handle the clustering
functionality, and leave it to you to determine how the server and clients
should coordinate work. The second, provided by `PhantomQueuedClusterServer`
and `PhantomQueuedClusterClient` is opinionated on communication and worker
methodology.

For a full example, see
[example.coffee](https://github.com/dailymuse/phantom-cluster/blob/master/example.coffee).

## Bare-bones engines

If you want to use a custom communication mechanism, or do not wish to use a
FIFO queue, you can use the bare-bones engines, represented with
`PhantomClusterServer` and `PhantomClusterClient`. In this mode, the server
spins up workers, and workers coordinate access to the phantomjs process, but
that's it. It's up to you to figure out how and when to get the server to send
requests to clients.

Spin up new instances of these classes via `create()`, i.e.:

    var phantomCluster = require("phantom-cluster");
    var engine = phantomCluster.create({ ...options... });
    ...

The options for `create`:

* `workers`: The number of workers to spin up (defaults to the number of
  CPUs available.)
* `workerIterations`: The number of work iterations to execute before killing this
  worker and restarting it. This is available to prevent phantomjs memory
  leaks from exhausting all the system memory (defaults to 100.)
* `workerParallelism`: The number of items each worker can handle in parallel.
  This determines the number of phantomjs pages open per worker.
* `phantomArguments`: An array of strings specifying command-line arguments to
  pass into the phantomjs process. See
  [the phantomjs docs](https://github.com/ariya/phantomjs/wiki/API-Reference#command-line-options)
  for a list of available arguments. Defaults to no arguments.
* `phantomBinary`: A string specifying the location of the phantomjs binary.
  By default this is auto-detected.
* `phantomBasePort`: The base port from which workers should create unique
  ports to communicate with the phantomjs process.

If the process is a worker, you'll be returned an instance of
`PhantomClusterClient`. Otherwise you'll be returned an instance of
`PhantomClusterServer`.

### PhantomClusterServer

#### Methods

* `addWorker`: Adds a new worker. This is called internally, so it probably
  doesn't need to be called unless you wish to dynamically resize the number
  of operating workers.
* `start`: Starts the server and spins up the workers.
* `stop`: Stops the server and kills the workers.

#### Events

* `workerStarted`: A new worker has been added to the pool.
* `workerDied`: A worker has died.
* `started`: The engine has started.
* `stopped`: The engine has stopped.

#### Properties

* `numWorkers`: The number of workers to run simultaneously.
* `workers`: Mapping of worker IDs to worker objects.
* `done`: Whether the engine is done (i.e. whether `stop()` has been called.)

### PhantomClusterClient

#### Methods

* `next`: Call this method when you've finished processing a request.
* `start`: Starts the client.
* `stop`: Stops the client.

#### Events

* `phantomStarted`: The phantom instance has started up.
* `phantomDied`: The phantom instance has died.
* `workerReady`: Attach a listener to this event to handle a request. It will
  be called when phantomjs is ready.
* `started`: The engine has started.
* `stopped`: The engine has stopped.

#### Properties

* `ph`: The phantom instance. See the
  [phantomjs-node documentation](https://github.com/sgentle/phantomjs-node) on
  how to use it.
* `iterations`: The number of iterations left before this worker is killed.
* `done`: Whether the engine is done (i.e. whether `stop()` has been called.)

## Queued engines

phantom-cluster exposes a server/client setup that builds on the bare-bones
server/client that processes requests via a FIFO queue. Communication between
the server and workers is facilitated via node.js' built-in IPC mechanism.
This should suit most needs and is the default setup.

In this setup, requests should be
[idempotent](https://en.wikipedia.org/wiki/Idempotence) - that is, multiple
executions of the request should yield the same result. This is because
requests have a built-in timeout to prevent lost requests.

Spin up new instances of these classes via `createQueued()`, i.e.:

    var phantomCluster = require("phantom-cluster");
    var engine = phantomCluster.createQueued({ ...options... });
    ...

The options for `createQueued` including all of the options for `create`, and
additionally:

* `messageTimeout`: Sets the timeout for requests. After this timeout the
  request is re-enqueued. Again, you'll be returned either a
  `PhantomQueuedClusterServer` or `PhantomQueuedClusterClient` depending on
  whether this is a worker process or not.

### PhantomQueuedClusterServer

This extends `PhantomClusterServer`, so it includes all of their
methods/events/properties.

#### Methods

* `enqueue`: Enqueues a new item. The item will later be passed off to a
  worker, and can be any JSON-serializable object. This method returns an
  instance of `QueueItem`.

#### Properties

* `queue`: Contains the queue of unprocessed requests.
* `clientsQueue`: Contains the queue of clients waiting to work on requests.

### PhantomQueuedClusterClient

This extends `PhantomClusterClient`, so it includes all of their
methods/events/properties.

#### Events

* `request`: Listen for this method instead of `workerReady`, as it will fire
  only when both a phantomjs process is ready and a request is ready to be
  processed. Event listeners are passed a phantomjs `page` object, and a
  `QueueItem` representing the request to process.

### QueueItem

Represents an item for processing for queued engines. Used by both servers
(returned via `enqueue`) and by clients (passed to event listeners of
`request`.)

#### Methods

* `start`: Starts the `QueueItem`. Pass in a `timeout` in milliseconds to
  indicate how long the `QueueItem` should run for before being considered
  timed out. This should only be called internally.
* `finish`: Finishes the `QueueItem`. Pass in a response object. The timer
  will be canceled.

#### Events

* `response`: Fired when there is a response that's been returned from a
  worker.
* `timeout`: Fired when the request has timed out.

#### Properties

* `id`: The item's unique ID.
* `request`: The request object.
* `response`: The response object - set to null until a response has come in.
