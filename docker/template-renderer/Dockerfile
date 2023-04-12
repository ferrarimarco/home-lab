FROM python:3.11.3-bullseye as base

ENV PYTHONFAULTHANDLER=1 \
  PYTHONHASHSEED=random \
  PYTHONUNBUFFERED=1

RUN apt-get update \
  && apt-get --assume-yes --no-install-recommends install \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

ARG POETRY_VERSION=1.1.12
ENV POETRY_VERSION="${POETRY_VERSION}"

FROM base as build

ENV PIP_DEFAULT_TIMEOUT=100 \
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  PIP_NO_CACHE_DIR=1

RUN pip3 install "poetry==${POETRY_VERSION}"

COPY pyproject.toml poetry.lock ./

RUN python -m venv --copies .venv \
  && poetry install

COPY . /usr/src/app

RUN python -m venv --copies .venv \
  && poetry install --no-dev

FROM base as final

COPY --from=build /usr/src/app /usr/src/app

ENV PATH="/usr/src/app/.venv/bin:${PATH}"

WORKDIR /usr/src/app
ENTRYPOINT [ "python3", "/usr/src/app/template_renderer.py" ]
