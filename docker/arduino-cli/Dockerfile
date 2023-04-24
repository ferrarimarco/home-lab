FROM debian:bullseye

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG ARDUINO_CLI_VERSION="0.32.2"

RUN apt-get update \
  && apt-get --assume-yes --no-install-recommends install \
  ca-certificates \
  curl \
  && rm -rf /var/lib/apt/lists/*

# Install arduino-cli using the provided installation script
# https://arduino.github.io/arduino-cli/latest/installation/
RUN curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=/usr/local/bin sh -s "${ARDUINO_CLI_VERSION}" \
  && arduino-cli version

# Install Arduino libraries
# https://www.arduino.cc/reference/en/libraries/arduino_apds9960/
# https://www.arduino.cc/reference/en/libraries/arduinoble/
# https://www.arduino.cc/reference/en/libraries/arduino_hts221/
# https://www.arduino.cc/reference/en/libraries/arduino_lsm9ds1/
# https://www.arduino.cc/reference/en/libraries/dht-sensor-library/
RUN arduino-cli lib install \
  Arduino_APDS9960 \
  ArduinoBLE \
  Arduino_HTS221 \
  Arduino_LSM9DS1 \
  "DHT sensor library" \
  && arduino-cli core update-index

ENTRYPOINT [ "/bin/bash", "-c" ]
