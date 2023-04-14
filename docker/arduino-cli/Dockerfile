FROM debian:bullseye

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get --assume-yes --no-install-recommends install \
  ca-certificates \
  locale \
  && rm -rf /var/lib/apt/lists/*

# Install arduino-cli using the provided installation script
# https://arduino.github.io/arduino-cli/latest/installation/
RUN curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=/usr/local/bin sh
