FROM ferrarimarco/open-development-environment-ansible:pip-alpine-1.0.14

LABEL maintainer "ferrari.marco@gmail.com"

ADD requirements.yml /tmp/requirements.yml
RUN ansible-galaxy install -r /tmp/requirements.yml \
  && rm /tmp/requirements.yml

ADD inventory /etc/ansible/hosts

RUN mkdir /opt/provisioning
WORKDIR /opt/provisioning
ADD playbooks/ playbooks/
