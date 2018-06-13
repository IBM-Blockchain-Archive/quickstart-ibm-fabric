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

mkdir /opt/ibmblockchain
cd /opt/ibmblockchain

# fabric binaries
curl https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric/hyperledger-fabric/linux-amd64-1.1.0/hyperledger-fabric-linux-amd64-1.1.0.tar.gz -o tools.tar.gz \
  && tar xvf tools.tar.gz \
  && rm tools.tar.gz

# fabric-ca-client
curl https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric-ca/hyperledger-fabric-ca/linux-amd64-1.1.0/hyperledger-fabric-ca-linux-amd64-1.1.0.tar.gz -o ca.tar.gz \
  && tar xvf ca.tar.gz \
  && rm ca.tar.gz