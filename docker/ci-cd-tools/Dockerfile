FROM node:26.10.0-bookworm

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get --assume-yes --no-install-recommends install \
  jq \
  && rm -rf /var/lib/apt/lists/*

ENV APP_DIR=/app
WORKDIR "${APP_DIR}"

COPY package.json package-lock.json ./

RUN npm ci \
  && rm -rf ~/.npm

ENV NODE_PATH="${APP_DIR}/node_modules"
ENV PATH="${NODE_PATH}/.bin:${PATH}"

ARG DEV_USER=home-lab-dev
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} -o "${DEV_USER}" \
  && useradd -m -u ${UID} -g ${GID} -o -s /bin/bash -l "${DEV_USER}"
USER $DEV_USER

RUN git config --global --add safe.directory /source-repository
