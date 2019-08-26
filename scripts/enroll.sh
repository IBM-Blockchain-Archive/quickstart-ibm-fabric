#!/bin/bash
#
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -x

ID=$1
SECRET=$2
CA_URL=$3
CA_NAME=$4
TLS_CA_NAME=${5}
CA_TLS_CERTCHAIN="$6"
DATADIR="/data/ibmblockchain"
BINDIR="/opt/ibmblockchain/bin"
CA_EP=`echo -n ${CA_URL} |awk -F "//" '{print $2}'`
CA_HOST=`echo -n ${CA_EP} |awk -F ":" '{print $1}'`
CA_PORT=`echo -n ${CA_EP} |awk -F ":" '{print $2}'`
CA_PORT=${CA_PORT:-443}
FABRIC_CA_CLIENT_HOME=${DATADIR}/$1


FQDN=`curl --silent http://169.254.169.254/latest/meta-data/public-hostname`
LOCALFQDN=`curl --silent http://169.254.169.254/latest/meta-data/local-hostname`

# create fabric-ca-client home
if [ ! -d "${FABRIC_CA_CLIENT_HOME}" ]; then
  mkdir -p ${FABRIC_CA_CLIENT_HOME}
fi

# create msp directory
mkdir -p ${FABRIC_CA_CLIENT_HOME}/msp

# set the TLS root certificates for the CA
cat ${CA_TLS_CERTCHAIN} | base64 --decode > cachain1.pem
#sed  -e 's/\\r\\n/,/g' cachain1.pem |tr ',' '\n' > cachain2.pem
#sed  -e 's/\\n\\r/,/g' cachain2.pem |tr ',' '\n' > cachain3.pem
CERT=`cat cachain1.pem`
echo -e "$CERT" > ${FABRIC_CA_CLIENT_HOME}/cachain.pem

# Enrollment cert
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

# TLS certs
${BINDIR}/fabric-ca-client enroll -d \
  -M ${FABRIC_CA_CLIENT_HOME}/tls2 \
  -u https://${ID}:${SECRET}@${CA_EP} \
  --caname ${TLS_CA_NAME} \
  --tls.certfiles ${FABRIC_CA_CLIENT_HOME}/cachain.pem \
  --csr.hosts "${FQDN},${LOCALFQDN},localhost"

mkdir ${FABRIC_CA_CLIENT_HOME}/tls
cat ${FABRIC_CA_CLIENT_HOME}/tls2/keystore/* > ${FABRIC_CA_CLIENT_HOME}/tls/server.key
cat ${FABRIC_CA_CLIENT_HOME}/tls2/signcerts/* > ${FABRIC_CA_CLIENT_HOME}/tls/server.crt
cat ${FABRIC_CA_CLIENT_HOME}/tls2/cacerts/* > ${FABRIC_CA_CLIENT_HOME}/tls/ca.crt

chown -R fabric:fabric ${FABRIC_CA_CLIENT_HOME}/tls