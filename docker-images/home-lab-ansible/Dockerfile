FROM ferrarimarco/open-development-environment-ansible:pip-alpine-1.0.14

LABEL maintainer "ferrari.marco@gmail.com"

RUN apk add --update \
  sshpass \
  && rm /var/cache/apk/*

ADD requirements.yml /tmp/requirements.yml
RUN ansible-galaxy install -r /tmp/requirements.yml \
  && rm /tmp/requirements.yml

ADD inventory /etc/ansible/hosts

RUN mkdir -p /opt/provisioning
WORKDIR /opt/provisioning
ADD opt/provisioning/ /opt/provisioning/
WORKDIR /opt/provisioning/playbooks
