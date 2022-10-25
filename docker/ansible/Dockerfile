FROM python:3.11.0-bullseye as base

ENV PYTHONFAULTHANDLER=1 \
    PYTHONHASHSEED=random \
    PYTHONUNBUFFERED=1 \
    PIP_DEFAULT_TIMEOUT=100 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get --assume-yes --no-install-recommends install \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /

RUN pip3 install --upgrade pip setuptools wheel \
    && pip3 install -r requirements.txt \
    && rm requirements.txt \
    && ansible --version

COPY etc/ansible/requirements.yml /etc/ansible/requirements.yml

RUN ansible-galaxy install -r /etc/ansible/requirements.yml

COPY etc/ /etc/

CMD [ "ansible" ]
