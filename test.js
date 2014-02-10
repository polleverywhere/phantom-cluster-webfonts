// Generated by CoffeeScript 1.6.3
(function() {
  var WEBSITES, cluster, objectLength, phantomCluster;

  phantomCluster = require("./index");

  cluster = require("cluster");

  WEBSITES = {
    "http://www.themuse.com/": "The Muse - Career advice and better job search",
    "http://www.themuse.com/companies": "Companies | The Muse",
    "http://www.themuse.com/jobs": "Jobs | The Muse"
  };

  objectLength = function(obj) {
    var count, _;
    count = 0;
    for (_ in obj) {
      count++;
    }
    return count;
  };

  exports.testPhantomClusterServer = function(test) {
    var s;
    test.expect(6);
    s = new phantomCluster.PhantomClusterServer({
      workers: 4
    });
    test.equal(s.numWorkers, 4);
    test.equal(objectLength(s.workers), 0);
    test.equal(s.done, false);
    s.start();
    test.equal(objectLength(s.workers), 4);
    test.equal(s.done, false);
    s.stop();
    s.stop();
    test.equal(s.done, true);
    return test.done();
  };

  exports.testPhantomClusterClient = function(test) {
    var c;
    test.expect(8);
    cluster.worker = {
      id: 1
    };
    c = new phantomCluster.PhantomClusterClient({});
    test.equal(c.ph, null);
    test.equal(c.done, false);
    c.on("started", function() {
      return test.ok(true);
    });
    c.on("phantomStarted", function() {
      test.notEqual(c.ph, null);
      test.equal(c.iterations, 100);
      test.ok(true);
      c.next();
      test.equal(c.iterations, 99);
      return setTimeout(function() {
        test.equal(c.iterations, 98);
        return test.done();
      }, 0);
    });
    return c.start();
  };

  exports.testQueueItem = function(test) {
    var i1;
    test.expect(12);
    i1 = new phantomCluster.QueueItem(1, {
      foo: true
    });
    test.equal(i1.id, 1);
    test.deepEqual(i1.request, {
      foo: true
    });
    test.equal(i1.timeout, null);
    test.equal(i1.state, 0);
    i1.on("response", function() {
      return test.ok(false, "i1 should not respond");
    });
    i1.on("timeout", function() {
      var i2;
      test.ok(true, "i1 should time out");
      i2 = new phantomCluster.QueueItem(2, {
        foo: false
      });
      i2.on("response", function() {
        test.equal(i2.state, 2);
        test.equal(i2.response, "yep");
        return test.equal(i2.timeout, null);
      });
      i2.on("timeout", function() {
        return test.ok(false, "i2 should not time out");
      });
      i2.start(1000);
      i2.finish("yep");
      test.throws(function() {
        return i2.finish("nope");
      });
      return test.done();
    });
    test.throws(function() {
      return i1.finish("nope");
    });
    i1.start(1000);
    test.equal(i1.state, 1);
    return test.throws(function() {
      return i1.start(1000);
    });
  };

}).call(this);
