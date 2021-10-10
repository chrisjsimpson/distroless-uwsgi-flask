#!/bin/sh
exec uwsgi --http-socket 0.0.0.0:9090 --uid nobody --gid 65534 --manage-script-name --mount /=app:app
