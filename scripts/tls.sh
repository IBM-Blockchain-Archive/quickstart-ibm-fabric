#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Specifically, this script is intended SOLELY to support the Confluent
# Quick Start offering in Amazon Web Services. It is not recommended
# for use in any other production environment.
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