# syntax = docker/dockerfile:1.3
FROM python:3-slim AS build-env
COPY . /app
WORKDIR /app

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
  apt-get update && apt-get install -y build-essential python python-dev
RUN pip install --no-cache-dir -r requirements.txt
RUN cp -a --parents /lib/x86_64-linux-gnu/libpcre.so.* /opt
RUN cp -a --parents /usr/local/lib/libpython3.* /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_posixsubprocess.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/math.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/select.cpython-310-x86_64-linux-gnu.so /opt



FROM gcr.io/distroless/python3
COPY --from=build-env /app /app
COPY --from=build-env /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=build-env /usr/local/bin/uwsgi /usr/local/bin/uwsgi
COPY --from=build-env /opt/_posixsubprocess.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/select.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/math.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/.*.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt /
##
WORKDIR /app
ENV PYTHONPATH=/usr/local/lib/python3.10/site-packages:/usr/lib/python3.9/lib-dynload:/usr/lib/python3.9
ENV PYTHONHOME=/usr/lib/python3.9
ENTRYPOINT ["./entrypoint.sh"]
