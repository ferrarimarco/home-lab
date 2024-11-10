FROM python:3.13.0-bookworm AS ansible

ENV PYTHONFAULTHANDLER=1 \
  PYTHONHASHSEED=random \
  PYTHONUNBUFFERED=1 \
  PIP_DEFAULT_TIMEOUT=100 \
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  PIP_NO_CACHE_DIR=1

RUN apt-get update \
  && apt-get --assume-yes --no-install-recommends install \
  ca-certificates \
  vim \
  && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /

RUN pip3 install --upgrade pip setuptools wheel \
  && pip3 install -r requirements.txt \
  && rm requirements.txt \
  && ansible --version \
  && ansible-galaxy --version

# Hadolint has no way of knowing that this --from doesn't reference a FROM statement
# so we disable this check
# hadolint ignore=DL3022
COPY --from=ansible-configuration requirements.yml /etc/ansible/requirements.yml

RUN ansible-galaxy install -r /etc/ansible/requirements.yml \
  && rm /etc/ansible/requirements.yml

FROM ansible AS molecule

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get --assume-yes --no-install-recommends install \
  curl \
  gnupg \
  lsb-release \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /etc/apt/keyrings \
  && chmod 0755 /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && apt-get update \
  && apt-get --assume-yes --no-install-recommends install \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  && rm -rf /var/lib/apt/lists/*

COPY molecule/requirements.txt /

RUN pip3 install -r requirements.txt \
  && rm requirements.txt \
  && molecule --version
