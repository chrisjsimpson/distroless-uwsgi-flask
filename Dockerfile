# syntax = docker/dockerfile:1.3
FROM python:3-slim AS build-env
COPY . /app
WORKDIR /app

RUN echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
  apt-get update && apt-get install -y build-essential python python-dev

RUN pip install --no-cache-dir -r requirements.txt

RUN cp -a --parents /lib/x86_64-linux-gnu/libpcre.so.* /opt
RUN cp -a --parents /usr/local/lib/libpython3.* /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_posixsubprocess.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/math.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/select.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_socket.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/array.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_random.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_md5.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_sha1.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_sha3.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_sha256.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_sha512.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_blake2.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_struct.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/binascii.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/unicodedata.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/zlib.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_ssl.cpython-310-x86_64-linux-gnu.so /opt
RUN cp /usr/local/lib/python3.10/lib-dynload/_contextvars.cpython-310-x86_64-linux-gnu.so /opt



FROM gcr.io/distroless/python3
COPY --from=build-env /app /app
COPY --from=build-env /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=build-env /usr/local/bin/uwsgi /usr/local/bin/uwsgi
COPY --from=build-env /opt/_posixsubprocess.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/select.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/math.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/_socket.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/array.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/_random.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/_md5.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/_sha1.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/_sha3.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/_sha256.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/_sha512.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/_blake2.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/_struct.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/binascii.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/unicodedata.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/zlib.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/_ssl.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/_contextvars.cpython-310-x86_64-linux-gnu.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt/.*.so /usr/lib/python3.9/lib-dynload
COPY --from=build-env /opt /

WORKDIR /app
ENV PYTHONPATH=/usr/local/lib/python3.10/site-packages:/usr/lib/python3.9/lib-dynload:/usr/lib/python3.9
ENV PYTHONHOME=/usr/lib/python3.9
ENTRYPOINT ["./entrypoint.sh"]
