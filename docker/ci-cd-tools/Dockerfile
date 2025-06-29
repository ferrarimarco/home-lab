FROM node:24.3.0-bookworm

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get --assume-yes --no-install-recommends install \
  jq \
  && rm -rf /var/lib/apt/lists/*

ENV APP_DIR=/app
WORKDIR "${APP_DIR}"

COPY package.json package-lock.json ./

RUN npm ci \
  && npm audit \
  && rm -rf ~/.npm

ENV NODE_PATH="${APP_DIR}/node_modules"
ENV PATH="${NODE_PATH}/.bin:${PATH}"

ARG USERNAME=home-lab-dev
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} -o "${USERNAME}" \
  && useradd -m -u ${UID} -g ${GID} -o -s /bin/bash -l "${USERNAME}"
USER $USERNAME

RUN git config --global --add safe.directory /source-repository
