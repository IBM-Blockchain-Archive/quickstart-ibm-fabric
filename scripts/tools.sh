#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -x

VERSION=$1

mkdir /opt/ibmblockchain
cd /opt/ibmblockchain

# fabric binaries
curl https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric/hyperledger-fabric/linux-amd64-${VERSION}/hyperledger-fabric-linux-amd64-${VERSION}.tar.gz -o tools.tar.gz \
  && tar xvf tools.tar.gz \
  && rm tools.tar.gz

# fabric-ca-client
curl https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric-ca/hyperledger-fabric-ca/linux-amd64-${VERSION}/hyperledger-fabric-ca-linux-amd64-${VERSION}.tar.gz -o ca.tar.gz \
  && tar xvf ca.tar.gz \
  && rm ca.tar.gz