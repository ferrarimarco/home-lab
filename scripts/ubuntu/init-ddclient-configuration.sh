#!/bin/sh

echo "Removing old ddclient configuration"
rm -rf /etc/ddclient

echo "Moving ddclient configuration directory"
mv /tmp/ddclient /etc/ddclient
