FROM ubuntu:latest

LABEL com.github.actions.name="C-Linter -> Check"
LABEL com.github.actions.description="Linted your code with C-Linter."
LABEL com.github.actions.icon="check-square"
LABEL com.github.actions.color="green"

LABEL repository="https://github.com/airvzxf/c-linter-action"
LABEL maintainer="Israel Roldan <israel.alberto.rv@gmail.com>"

RUN apt-get update
RUN apt --assume-yes install \
        curl clang-tidy cmake jq clang cppcheck clang-format

WORKDIR /build
COPY entry_point.sh /entrypoint.sh
RUN pwd
RUN ls -lha .
COPY . .
RUN ls -lha .
CMD ["bash", "/entrypoint.sh"]
