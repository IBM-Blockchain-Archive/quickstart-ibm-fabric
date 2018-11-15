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

# set the TLS root certificates for the CA
sed  -e 's/\\r\\n/,/g' ${CA_TLS_CERTCHAIN} |tr ',' '\n' > cachain1.pem
sed  -e 's/\\n\\r/,/g' cachain1.pem |tr ',' '\n' > cachain2.pem
CERT=`cat cachain2.pem`
echo -e "$CERT" > ${FABRIC_CA_CLIENT_HOME}/cachain.pem

sed  -e 's/\\r\\n/,/g' ${CA_TLS_CERTCHAIN} |tr ',' '\n' > ${FABRIC_CA_CLIENT_HOME}/cachain.pem

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