#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -x


CRYPTO_DIR="/tmp/crypto"
ENROLL_ID=$1
ENROLL_SECRET=$2
CA_URL=$3
CA_NAME=$4
TLSCA_NAME=$5
CA_TLS_CERTCHAIN="$6"
MSPID=$7
STATE_DB=$8
VERSION=$9
EIP=${10}
LICENSE_AGREEMENT="${11}"

COUCHDB_VERSION=${VERSION}
DATA_DIR="/data/ibmblockchain"
COUCHDB_USER=admin
COUCHDB_PASSWORD=`openssl rand -base64 32`

# log settings
MAX_SIZE=50m
MAX_FILE=100

# DNS info
PUBLIC_FQDN=`curl --silent http://169.254.169.254/latest/meta-data/public-hostname`
DOMAIN=`echo ${PUBLIC_FQDN} |awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//'`
HOSTNAME=ec2-${EIP//./-}
PUBLIC_DNS="${HOSTNAME}.${DOMAIN}"



# utility functions
# source:  https://github.com/aws-quickstart/quickstart-linux-utilities/blob/master/quickstart-cfn-tools.source
function qs_err() {
        touch /var/tmp/stack_failed
        echo "[FAILED] @ $1" >>/var/tmp/stack_failed
        echo "[FAILED] @ $1"
}

function qs_status() {
    if [ -f /var/tmp/stack_failed ]; then
        printf "stack failed";
        exit 1;
    fi
}

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
	-e LICENSE=accept \
	ibmblockchain/fabric-couchdb:${COUCHDB_VERSION}

	if [ $? -ne 0 ]; then
		qs_err "failed to start CouchDB"
	fi
}

# create user-defined network so name resolution works inside containers
dockerNetwork() {
	docker network create ibmblockchain
	if [ $? -ne 0 ]; then
		qs_err "failed to create Docker network"
	fi
}

# enroll the peer
enrollPeer() {
	/opt/ibmblockchain/bin/enroll.sh ${ENROLL_ID} ${ENROLL_SECRET} ${CA_URL} ${CA_NAME} ${TLSCA_NAME} ${CA_TLS_CERTCHAIN}
	if [ $? -ne 0 ]; then
		qs_err "failed to enroll peer"
	fi
	# check that enrollment succeeded
	if [ -z "$(ls -A /data/ibmblockchain/${ENROLL_ID}/msp/signcerts)" ]; then
		qs_err "failed to enroll peer"
	fi

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
	#mv /tmp/crypto/peerOrganizations/${DOMAIN}/peers/${PUBLIC_DNS}/tls ${DATA_DIR}/${ENROLL_ID}
	#chown -R fabric:fabric ${DATA_DIR}/${ENROLL_ID}/tls

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
	-e CORE_PEER_NETWORKID=aws_${MSPID} \
	-e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/${ENROLL_ID}/msp \
	-e CORE_PEER_LOCALMSPID=${MSPID} \
	-e CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=ibmblockchain \
	-e CORE_CHAINCODE_BUILDER=ibmblockchain/fabric-ccenv:${VERSION} \
	-e CORE_CHAINCODE_GOLANG_RUNTIME=ibmblockchain/fabric-baseos::${VERSION} \
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
	-e LICENSE=accept \
	ibmblockchain/fabric-peer:${VERSION} \
	peer node start

	if [ $? -ne 0 ]; then
		qs_err "failed to start peer"
	fi
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
	qs_status
	# create docker network
	dockerNetwork
	qs_status

	if [ "$STATE_DB" = "CouchDB" ];then
		startCouch
	fi

	# start the peer
	startPeer
	qs_status

	# create local client env
	createEnv
	qs_status
}

main