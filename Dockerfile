FROM ubuntu:latest

LABEL com.github.actions.name="C-Linter -> Check"
LABEL com.github.actions.description="Linted your code with C-Linter."
LABEL com.github.actions.icon="check-square"
LABEL com.github.actions.color="green"

LABEL repository="https://github.com/airvzxf/c-linter-action"
LABEL maintainer="Israel Roldan <israel.alberto.rv@gmail.com>"

RUN apt update
RUN apt --assume-yes install \
        curl jq cmake clang clang-tidy clang-format cppcheck pkg-config

WORKDIR /build
COPY entry_point.sh /entrypoint.sh
COPY . .
CMD ["bash", "/entrypoint.sh"]
