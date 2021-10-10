# Distroless uwsgi and flask

Goals: Can we containerize uwsgi and flask to run distroless?

- Build a distroless uwsgi + flask container using as minimal resources as possible
- Run uwsgi as nonroot (aka nobody)
- Run container with zero shells, or excess binaries (this is the point of distroless containers)
- Play with uwsgi dynamically scale the number of running workers , very cool, using [The uWSGI cheaper subsystem](https://uwsgi-docs.readthedocs.io/en/latest/Cheaper.html)
- Observe the resources used (amount of RAM, and image size) because these impact cost
  - Total size: ~92MB with required pythong libraries, uwsgi + flask
  - Memory footprint: It depends on the number of processes you spawn (that's the point of uwsgi's dynamic scaling of workers). With a single process and no workers, the total RAM used of a container running cold is: 22.76MiB (but you would probably not want to do that, instead use uwsgi's `--cheaper-algo busyness` setting(s) and set an inital number of processes (`--cheaper-initial 16`). See `entrypoint.sh` for an example. Note this is at odds with the 'single process per container' mantra, but is justified in this context, because, the reverse could be starting new containers at increased load e.g. using a [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/), but actually, uwsgi would be *faster* at spawning new workers within the container than starting a new container and waiting for `uwsgi` to start, the memory footprint is also smaller. When would you scale the number of containers? Perhaps for *availability* and redundancy reasons

- Complexity. How complex is this to do?

Why?

- Smaller images , less memory footprint
- Less code shipped generally a good thing
- Is it more secure? It depends. [See also](https://github.com/GoogleContainerTools/distroless/issues/733)
- Fun and interesting learning
- uwsgi is so very flexible, seems to be used / mentioned less in the cloud native world (does it have a place?)
  - The art of the possible
  - Note uwsgi supports [Running uWSGI in a Linux CGroup](https://uwsgi-docs.readthedocs.io/en/latest/Cgroups.html), to be explored! In addition to [Kernel Samepage Merging](https://uwsgi-docs.readthedocs.io/en/latest/KSM.html), allowing to reduce memory usage further.

Learnings:
- The [default distroless python image from GoogleContainerTools](https://github.com/GoogleContainerTools/distroless/blob/631e2056b056bdade58637a38b3e86b8d6d02331/examples/python3/Dockerfile#L5) does not contain a lot of the python standard library tooling which [uwsgi](https://uwsgi-docs.readthedocs.io/en/latest/) and [werkzeug](https://github.com/pallets/werkzeug) need in order to run.
  - This is expected (that's the point of distroless) so required adding all the specific core python library shared objects
    manually. This was a great deep dive into python internals e.g. `_posixsubprocess` is needed, the `_` is a hint that this
    module is implemented in C and private.
  - The understanding for learning how to add the required shared objects came by, looking at [nginx-distroless](https://github.com/kyos0109/nginx-distroless/blob/4fa36b8c066303f34e490aad7b407d447ade4b7d/Dockerfile#L7) as a reference, then the pythong import errors (e.g. cannot import `_posixsubprocess`) then locating the missing shared object file (`.so`) from the parent build image.
- Copying files out of the parent container image / aka "How to I fiew the files/filesystem of a container easily, can I extract them? When building distroless containers you need to know which files and exaclty *where* they may be copied from in the parent image, extracting and `grep`'ing the parent image's files is one way to do that (so you don't have yo guess the `COPY` paths). How?
  - Like this:
    ```
    docker export <container-id> > out.tar
    tar xvf out.tar
    ```
    [src](https://stackoverflow.com/a/53481010/885983)
    You can also extract non-running containers, by using `docker create --name="test" image:tag`
- I'm not yet understanding/keen on [Bazel](https://github.com/bazelbuild/rules_docker) as a consume of it, feel much more comfortable expressing a container in terms of a line-by-line `Dockerfile` and find the Bazel syntax confusing at the moment by comparrison, so happy it's possible to build ontop of the abstraction.


### Benchmarks

## Start each container

```
./run
./run2
./run3
./run4
```
## Run apache bench against all containers at the same time


```
ab -n 999999 -c 20 http://127.0.0.1:9090/
ab -n 999999 -c 20 http://127.0.0.1:9094/
ab -n 999999 -c 20 http://127.0.0.1:9093/
ab -n 999999 -c 20 http://127.0.0.1:9092/
ab -n 999999 -c 20 http://127.0.0.1:9091/
```

Now watch to see additionall processes automatically spawn to handle the
spike in traffic by using `docker stats` (and docker logs from each `./run` output).

## Docker status


Notice how the number of processes (PIDS) go up automatically whilst apache
bench runs. This is uwsgo automatically spawning new processes to respond to the
additional spike in requrests, and also scaling them back down automatically.

Before run:

```
docker stats
CONTAINER ID   NAME                CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O     PIDS
6b5de5104a8d   practical_hermann   0.02%     140.3MiB / 19.46GiB   0.70%     68.9MB / 70.4MB   73.7kB / 0B   13
5fc25537a6ef   elated_diffie       0.02%     145.7MiB / 19.46GiB   0.73%     75.1MB / 76.7MB   369kB / 0B    14
7a5a463acc61   frosty_panini       0.02%     220MiB / 19.46GiB     1.10%     108MB / 110MB     0B / 0B       29
00a96b15471e   vibrant_northcutt   0.02%     140.3MiB / 19.46GiB   0.70%     69MB / 70.5MB     0B / 0B       13
50d131fb416a   gifted_hamilton     0.01%     140.6MiB / 19.46GiB   0.71%     68.2MB / 69.7MB   0B / 0B       13
```

During run: (see increase in processes (PIDs))

During testing the number of PIDs went up to 25, then settled at 19 automatically because, for the system
being ran on that was the number of processes which were sufficent to keep handling all the concurrent requests.

```
CONTAINER ID   NAME                CPU %     MEM USAGE / LIMIT     MEM %     NET I/O         BLOCK I/O     PIDS
50d131fb416a   gifted_hamilton     78.29%    192.7MiB / 19.46GiB   0.97%     175MB / 179MB   36.9kB / 0B   19
00a96b15471e   vibrant_northcutt   66.50%    192.3MiB / 19.46GiB   0.96%     165MB / 169MB   0B / 0B       19
6b5de5104a8d   practical_hermann   81.72%    192.1MiB / 19.46GiB   0.96%     163MB / 166MB   73.7kB / 0B   19
5fc25537a6ef   elated_diffie       67.85%    192.8MiB / 19.46GiB   0.97%     165MB / 169MB   369kB / 0B    19
7a5a463acc61   frosty_panini       70.54%    193.5MiB / 19.46GiB   0.97%     199MB / 203MB   0B / 0B       19
```

### uwsgi automatically killing off uneeded processes
With the `busyness` setting `--cheaper-algo busyness` uwsgi will automatically kill excess processes (saving memory)
when the average busyness falls below the given threshold.

```
[busyness] 1s average busyness is at 0%, cheap one of 18 running workers
worker 38 killed successfully (pid: 53)
uWSGI worker 38 cheaped.
[busyness] 1s average busyness is at 0%, cheap one of 17 running workers
worker 40 killed successfully (pid: 55)
uWSGI worker 40 cheaped.
[busyness] 1s average busyness is at 0%, cheap one of 16 running workers
worker 1 killed successfully (pid: 56)
uWSGI worker 1 cheaped.
[busyness] 1s average busyness is at 0%, cheap one of 15 running workers
worker 2 killed successfully (pid: 57)
```

## Review apache bench status

After exiting apache bench (`Ctrl + c`) the summary of response time stats is displayed:

```
Server Hostname:        127.0.0.1
Server Port:            9091

Document Path:          /
Document Length:        13 bytes

Concurrency Level:      20
Time taken for tests:   395.570 seconds
Complete requests:      551182
Failed requests:        0
Total transferred:      50708744 bytes
HTML transferred:       7165366 bytes
Requests per second:    1393.39 [#/sec] (mean)
Time per request:       14.354 [ms] (mean)
Time per request:       0.718 [ms] (mean, across all concurrent requests)
Transfer rate:          125.19 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.6      0      33
Processing:     1   14  12.9     11     334
Waiting:        0   13  12.2     10     334
Total:          1   14  12.9     11     336

Percentage of the requests served within a certain time (ms)
  50%     11
  66%     14
  75%     16
  80%     18
  90%     24
  95%     34
  98%     53
  99%     71
 100%    336 (longest request)
```

Means, 50% of the 551182 requests took 11 milliseconds to be served (this does *not* mean it
took 11 milliseconds to serve 275591 requests).


# Links

- https://github.com/GoogleContainerTools/distroless/commits/main/examples/python3/Dockerfile
- https://github.com/kyos0109/nginx-distroless/blob/master/Dockerfile#L7
- https://github.com/GoogleContainerTools/distroless/tree/main/package_manager
- https://github.com/GoogleContainerTools/distroless/blob/main/experimental/python3/BUILD
- docker unpack image https://stackoverflow.com/questions/44769315/how-to-see-docker-image-contents

## Learning bout python shared objects / required libraries for uwsgi/flask which have been stripped out of distroless by default, PYTHONHOME and PYTHONPATH confusion


-  `PYTHONPATH recursive` tldr: I thought `PYTHONPATH` behaved with `$PATH` in bash. It does not, it's not recursive. It's simply a list see:  https://serverfault.com/questions/80227/pythonpath-environment-variable-how-do-i-make-every-subdirectory-afterwards'
- `ModuleNotFoundError: No module named '_posixsubprocess'` https://stackoverflow.com/questions/12508243/python-error-the-posixsubprocess-module-is-not-being-used
- "uwsgi: error while loading shared libraries: libpcre.so.3 "https://stackoverflow.com/questions/65526849/uwsgi-error-with-pcre-ubuntu-20-04-error-while-loading-shared-libraries-libpcre

- "Could not find platform independent libraries" https://stackoverflow.com/questions/19292957/how-can-i-troubleshoot-python-could-not-find-platform-independent-libraries-pr 
- "python encodings module" / "ImportError: No module named 'encodings'" https://bugs.python.org/issue27054 / https://stackoverflow.com/questions/7850908/what-exactly-should-be-set-in-pythonpath / http://docs.python.org/using/cmdline.html#envvar-PYTHONPATH
- https://stackoverflow.com/questions/28913559/how-to-start-uwsgi-with-flask-and-nginx

## Speeding up container build time with `BUILDKIT` and caching

- https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/syntax.md

Still need to make apt-get cache properly.
