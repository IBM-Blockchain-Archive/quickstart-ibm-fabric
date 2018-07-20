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

PUBLIC_FQDN=`curl --silent http://169.254.169.254/latest/meta-data/public-hostname`
DOMAIN=`echo -n ${PUBLIC_FQDN}|awk -F '[.]' '{print $2"."$3"."$4"."$5}'`
PUBLIC_HOSTNAME=`echo -n ${PUBLIC_FQDN}|cut -d. -f1`


PUBLIC_FQDN=`curl --silent http://169.254.169.254/latest/meta-data/public-hostname`
PUBLIC_HOSTNAME=`echo ${PUBLIC_FQDN} |awk -F. '{ print $1 }'`
DOMAIN=`echo ${PUBLIC_FQDN} |awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//'`


CRYPTO_DIR="/tmp/crypto"
ENROLL_ID=$1
ENROLL_SECRET=$2
CA_URL=$3
MSPID=$4
NETWORK_ID=$5
STATE_DB=$6
VERSION=$7
DATA_DIR="/data/ibmblockchain"
COUCHDB_USER=admin
COUCHDB_PASSWORD=`openssl rand -base64 32`

# log settings
MAX_SIZE=50m
MAX_FILE=100

# start CouchDB based on STATE_DB setting
startCouch() {
	# create data volume
	couch_dir=${DATA_DIR}/${ENROLL_ID}/couchdb
	mkdir -p ${couch_dir}/data
	chown -R couchdb:couchdb ${couch_dir}
	docker run -d \
	--name couchdb \
	--hostname couchdb \
	--network ibmblockchain \
	--restart=always \
	--volume=${couch_data}:/opt/couchdb/data \
	--log-driver json-file \
	--log-opt max-size=${MAX_SIZE}  \
	--log-opt max-file=${MAX_FILE}  \
	--log-opt labels=${ENROLL_ID}-couchdb \
	-e COUCHDB_USER=${COUCHDB_USER} \
	-e COUCHDB_PASSWORD=${COUCHDB_PASSWORD} \
	ibmblockchain/fabric-couchdb:0.4.6
}

# create user-defined network so name resolution works inside containers
dockerNetwork() {
	docker network create ibmblockchain
}

# enroll the peer
enrollPeer() {
	/opt/ibmblockchain/bin/enroll.sh ${ENROLL_ID} ${ENROLL_SECRET} ${CA_URL}
}

startPeer() {
	# create directory for ledger
	ledger_dir=${DATA_DIR}/${ENROLL_ID}/ledger
	mkdir -p ${ledger_dir}
	# change owner
	chown -R fabric:fabric ${ledger_dir}

	# user / group env variables
	username="fabric"
	user_id="7051"
	group_id=`getent group docker | cut -d: -f3`

	# generate crypto material
	generateCrypto
	# get the TLS certs
	mv /tmp/crypto/peerOrganizations/${DOMAIN}/peers/${PUBLIC_FQDN}/tls ${DATA_DIR}/${ENROLL_ID}
	chown -R fabric:fabric ${DATA_DIR}/${ENROLL_ID}/tls

	docker run -d \
	--name peer \
	--hostname peer \
	--network ibmblockchain \
	--restart always \
	--log-driver json-file \
	--log-opt max-size=${MAX_SIZE}  \
	--log-opt max-file=${MAX_FILE}  \
	--log-opt labels=${ENROLL_ID}-peer \
	--volume=${ledger_dir}:/var/hyperledger/production \
	--volume=${DATA_DIR}/${ENROLL_ID}/msp:/etc/hyperledger/${ENROLL_ID}/msp \
	--volume=${DATA_DIR}/${ENROLL_ID}/tls:/etc/hyperledger/${ENROLL_ID}/tls \
	--volume=/var/run/docker.sock:/var/run/docker.sock \
	--publish 7051:7051 \
	-e CORE_PEER_ID=${ENROLL_ID} \
	-e CORE_PEER_NETWORKID=${NETWORK_ID} \
	-e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/${ENROLL_ID}/msp \
	-e CORE_PEER_LOCALMSPID=${MSPID} \
	-e CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=ibmblockchain \
	-e CORE_LEDGER_STATE_STATEDATABASE=${STATE_DB} \
	-e CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb:5984 \
	-e CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=${COUCHDB_USER} \
	-e CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=${COUCHDB_PASSWORD} \
	-e CORE_LEDGER_STATE_COUCHDBCONFIG_MAXRETRIESONSTARTUP=20 \
	-e CORE_PEER_TLS_ENABLED=true \
	-e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/${ENROLL_ID}/tls/server.key \
	-e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/${ENROLL_ID}/tls/server.crt \
	-e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/${ENROLL_ID}/tls/ca.crt \
	-e USERNAME=${username} \
	-e USER_ID=${user_id} \
	-e GROUP_ID=${group_id} \
	ibmblockchain/fabric-peer:${VERSION} \
	peer node start
}

createEnv() {
cat << EOF > /opt/ibmblockchain/bin/env.sh
#!/bin/bash
export CORE_PEER_LOCALMSPID=${MSPID}
export CORE_PEER_MSPCONFIGPATH=${DATA_DIR}/${ENROLL_ID}/msp
export CORE_PEER_ADDRESS=localhost:7051
export CORE_LOGGING_LEVEL=info
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_ROOTCERT_FILE=${DATA_DIR}/${ENROLL_ID}/tls/ca.crt
export PATH=$PATH:/opt/ibmblockchain/bin
export FABRIC_CFG_PATH=/opt/ibmblockchain/config
EOF

	chmod +x /opt/ibmblockchain/bin/env.sh
	chown ec2-user:ec2-user /opt/ibmblockchain/bin/env.sh
}

generateCrypto() {
	# run cryptogen
	/opt/ibmblockchain/bin/cryptogen generate --config /tmp/crypto-config.yaml --output ${CRYPTO_DIR}
}

main() {
	# enroll the peer user
	enrollPeer
	# create docker network
	dockerNetwork

	if [ "$STATE_DB" = "CouchDB" ];then
		startCouch
	fi

	# start the peer
	startPeer

	# create local client env
	createEnv
}

main