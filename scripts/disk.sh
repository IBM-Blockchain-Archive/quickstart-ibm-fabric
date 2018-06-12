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

# mount the EBS volume for persistent config and ledger storage
DEV="/dev/xvdl" # volume mapping
MOUNT="/data/ibmblockchain"

mkdir -p $MOUNT
mkfs -t xfs $DEV
mount $DEV $MOUNT
# update fstab
echo "$DEV  $MOUNT  xfs  defaults  0  0" >> /etc/fstab

# make required directories for the peer
mkdir $MOUNT/config
mkdir $MOUNT/msp
mkdir $MOUNT/production