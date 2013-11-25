# phantom-cluster

Phantom-cluster is a cluster of node.js workers for processing requests with
phantomjs instances.

Because you can spawn multiple workers, requests can be processed in parallel.
At the same time, the limited number of workers prevents you from spinning up
too many memory-intensive phantomjs instances. Further, there's some added
logic to automatically restart workers after a few iterations to prevent
memory leaks.

For a full example, see
[example.coffee](https://github.com/dailymuse/phantom-cluster/blob/master/example.coffee).

## Communication-agnostic engines

If you want to use a custom communication mechanism, or do not wish to use a
FIFO queue, you can use the communication-agnostic engines, represented with
`PhantomClusterServer` and `PhantomClusterClient`. In this mode, the server
spins up workers, and workers coordinate access to the phantomjs process, but
that's it. It's up to you to figure out how to get the server to send requests
to clients.

Spin up new instances of these classes via `create()`, i.e.:

    var phantomCluster = require("phantom-cluster");
    var engine = phantomCluster.create({ ...options... });
    ...

The options for `create`:

* `numWorkers`: The number of workers to spin up (defaults to the number of
  CPUs available.)
* `iterations`: The number of work iterations to execute before killing this
  worker and restarting it. This is available to prevent phantomjs memory
  leaks from exhausting all the system memory (defaults to 100.)
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

* `addWorker`: Adds a new worker.
* `start`: Starts the server and spins up the workers.
* `stop`: Stops the server and kills the workers.

#### Events

* `workerStarted`: A new worker has been added to the pool.
* `workerDied`: A worker has died.
* `started`: The engine has started.
* `stopped`: The engine has stopped.

#### Properties

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

## Queued engines

phantom-cluster exposes a server/client setup that builds on the
communication-agnostic server/client that processes requests via a FIFO queue.
Communication between the server and workers is facilitated via node.js'
built-in IPC mechanism. This should suit most needs and is the default setup.

In this setup, requests should be
[idempotent](https://en.wikipedia.org/wiki/Idempotence) - that is, multiple
executions of the request should yield the same result. This is because
requests have a built-in timeout. This is to prevent lost requests from, e.g.
workers that suddenly die.

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

### PhantomQueuedClusterClient

This extends `PhantomClusterClient`, so it includes all of their
methods/events/properties.

#### Methods

* `queueItemResponse`: Call this method instead of `next` when you've 
  processing the current request, as it notify the server. Pass the response
  as an argument, which will in turn be passed to the server.

#### Events

* `queueItemReady`: Listen for this method instead of `workerReady`, as it
  will be called only when both the phantom process is ready and there's a
  request from the server that should be processed.

### QueueItem

This is the object returned by `PhantomQueuedClusterServer`'s `enqueue`
method.

#### Events

* `response`: Fired when there is a response that's been returned from a
  worker.
* `timeout`: Fired when the request has timed out.

#### Properties

* `id`: The item's unique ID.
* `request`: The request object.
* `response`: The response object - set to null until a response has come in.
