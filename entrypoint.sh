#!/bin/sh
exec uwsgi --master --uid nobody --gid 65534 --cheaper-algo busyness --cheaper 8 --cheaper-initial 16 --cheaper-overload 1 --cheaper-step 16 --processes 500 --http-socket 0.0.0.0:9090  --manage-script-name --mount /=app:app
