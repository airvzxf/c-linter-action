FROM ubuntu:22.10

ARG DEBIAN_FRONTEND=noninteractive

RUN apt update
RUN apt --assume-yes install \
    curl jq cmake clang clang-tidy clang-format cppcheck pkg-config

WORKDIR /build
COPY entry_point.sh /entrypoint.sh
COPY . .
CMD ["bash", "/entrypoint.sh"]
