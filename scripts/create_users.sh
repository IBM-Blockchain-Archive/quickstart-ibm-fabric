#!/bin/bash
#
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -x

# create fabric user and add to docker group
useradd -u 7051 -G docker fabric

# add ec2-user to fabric group
usermod -a -G fabric ec2-user

# create couchdb user
groupadd -g 999 couchdb
useradd -u 1000 -g couchdb couchdb