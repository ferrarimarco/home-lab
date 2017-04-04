FROM ferrarimarco/open-development-environment-ansible:pip-alpine-1.0.14

LABEL maintainer "ferrari.marco@gmail.com"

ADD requirements.yml /tmp/requirements.yml
RUN ansible-galaxy install -r requirements.yml \
  && rm /tmp/requirements.yml
