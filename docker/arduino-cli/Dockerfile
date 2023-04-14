FROM debian:bullseye

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG ARDUINO_CLI_VERSION="0.32.2"

# Install arduino-cli using the provided installation script
# https://arduino.github.io/arduino-cli/latest/installation/
RUN curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=/usr/local/bin sh -s "${ARDUINO_CLI_VERSION}"
