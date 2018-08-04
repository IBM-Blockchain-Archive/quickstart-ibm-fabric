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

ID=$1
SECRET=$2
CA_URL=$3
CA_NAME=$4
CA_TLS_CERTCHAIN="$5"
DATADIR="/data/ibmblockchain"
BINDIR="/opt/ibmblockchain/bin"
CA_EP=`echo -n ${CA_URL} |awk -F "//" '{print $2}'`
CA_HOST=`echo -n ${CA_EP} |awk -F ":" '{print $1}'`
CA_PORT=`echo -n ${CA_EP} |awk -F ":" '{print $2}'`
CA_PORT=${CA_PORT:-443}
FABRIC_CA_CLIENT_HOME=${DATADIR}/$1

# create fabric-ca-client home
if [ ! -d "${FABRIC_CA_CLIENT_HOME}" ]; then
  mkdir -p ${FABRIC_CA_CLIENT_HOME}
fi

# create msp directory
mkdir -p ${FABRIC_CA_CLIENT_HOME}/msp

# get the TLS root certificates for the CA
#echo -n | openssl s_client -showcerts  -connect ${CA_HOST}:${CA_PORT} | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ${FABRIC_CA_CLIENT_HOME}/cachain.pem
#echo -e ${CA_TLS_CERTCHAIN} > ${FABRIC_CA_CLIENT_HOME}/cachain.pem
mv /tmp/cachain.pem ${FABRIC_CA_CLIENT_HOME}/cachain.pem

${BINDIR}/fabric-ca-client enroll -d \
  -H ${FABRIC_CA_CLIENT_HOME} \
  -u https://${ID}:${SECRET}@${CA_EP} \
  --caname ${CA_NAME} \
  --tls.certfiles ${FABRIC_CA_CLIENT_HOME}/cachain.pem

# add the peer cert to admin certs
mkdir ${FABRIC_CA_CLIENT_HOME}/msp/admincerts
cp ${FABRIC_CA_CLIENT_HOME}/msp/signcerts/* ${FABRIC_CA_CLIENT_HOME}/msp/admincerts/

# make fabric:fabric owner for msp folder
chown -R fabric:fabric ${FABRIC_CA_CLIENT_HOME}/msp