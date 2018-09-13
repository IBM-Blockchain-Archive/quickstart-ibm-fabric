#!/bin/bash
#
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -x

# generate crypto-config.yaml

set -x

FQDN=`curl --silent http://169.254.169.254/latest/meta-data/public-hostname`
HOSTNAME=`echo $FQDN |awk -F. '{ print $1 }'`
DOMAIN=`echo $FQDN |awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//'`
LOCALFQDN=`curl --silent http://169.254.169.254/latest/meta-data/local-hostname`

if [ -f "/tmp/crypto-config.yaml" ];then
  rm /tmp/crypto-config.yaml
fi
cat << EOF > /tmp/crypto-config.yaml
PeerOrgs:
  - Name: Org1
    Domain: ${DOMAIN}
    EnableNodeOUs: false
    Specs:
      - Hostname: ${HOSTNAME}
        SANS:
          - ${LOCALFQDN}
          - localhost
EOF