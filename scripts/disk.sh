#!/bin/bash
#
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
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