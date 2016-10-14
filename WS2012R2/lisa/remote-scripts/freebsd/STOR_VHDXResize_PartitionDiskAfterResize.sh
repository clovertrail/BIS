#!/bin/bash

########################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved.
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
########################################################################
# STOR_VHDXResize_PartitionDisk.sh
# Description:
#     This script will verify if you can create, format, mount, perform
#     read/write operation, unmount and deleting a partition on
#     a VHDx file
#     Hyper-V setting pane. The test performs the following
#     step
#    1. Make sure we have a constants.sh file.
#    2. Creates partition
#    3. Creates filesystem
#    4. Performs read/write operations
#    5. Unmounts partition
#    6. Deletes partition
#
########################################################################

ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error while performing the test

CONSTANTS_FILE="constants.sh"

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
}

cd ~

UpdateTestState()
{
    echo $1 > $HOME/state.txt
}

if [ -e ~/summary.log ]; then
    LogMsg "Cleaning up previous copies of summary.log"
    rm -rf ~/summary.log
fi

LogMsg "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING

# Source the constants file
if [ -e ~/${CONSTANTS_FILE} ]; then
    source ~/${CONSTANTS_FILE}
else
    msg="Error: no ${CONSTANTS_FILE} file"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure constants.sh contains the variables we expect
#
if [ "${TC_COVERED:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter TC_COVERED is not defined in ${CONSTANTS_FILE}"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

#
# Echo TCs we cover
#
echo "Covers ${TC_COVERED}" > ~/summary.log


if [ "${fileSystems:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter fileSystems is not defined in constants file."
    LogMsg "$msg"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

#
# Verify if guest sees the new drive
#
if [ ! -e "/dev/da1" ]; then
    msg="The Linux guest cannot detect the drive"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi
LogMsg "The Linux guest detected the drive"

#
# Create the new partition
# delete partition firstly maily used if partition size >2TB, after use parted
# to rm partition, still can show in fdisk -l even it does not exist in fact.
gpart destroy -F da1 >& /dev/null
gpart create -s GPT da1 >> ~/summary.log 2>&1
gpart add -t freebsd-ufs -a 1M da1 >> ~/summary.log 2>&1
if [ $? -gt 0 ]; then
    LogMsg "Failed to create partition"
    echo "Creating partition: Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 10
fi
LogMsg "Partition created"
sleep 5

#
# Format the partition
#

LogMsg "Start testing filesystem: $fileSystems"
newfs -U /dev/da1p1 >> ~/summary.log 2>&1
if [ $? -gt 0 ]; then
    LogMsg "Failed to format partition with $fileSystems"
    echo "Formating partition: Failed with $fileSystems" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 10
fi
LogMsg "Successfully formated partition with $fileSystems"

#
# Mount partition
#
if [ ! -e "/mnt" ]; then
    mkdir /mnt
    if [ $? -gt 0 ]; then
        LogMsg "Failed to create mount point"
        echo "Creating mount point: Failed" >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 10
    fi
    LogMsg "Mount point /mnt created"
fi

mount /dev/da1p1 /mnt >> ~/summary.log 2>&1
if [ $? -gt 0 ]; then
    LogMsg "Failed to mount partition"
    echo "Mounting partition: Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 10
fi
LogMsg "Partition mount successful"

#
# Read/Write mount point
#
dos2unix STOR_VHDXResize_ReadWrite.sh
chmod +x STOR_VHDXResize_ReadWrite.sh
./STOR_VHDXResize_ReadWrite.sh


umount /mnt
if [ $? -gt 0 ]; then
    LogMsg "Failed to unmount partition"
    echo "Unmounting partition: Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 10
fi
LogMsg "Unmount partition successful"

gpart delete -i 1 da1 >> ~/summary.log 2>&1
if [ $? -gt 0 ]; then
    LogMsg "Failed to delete partition"
    echo "Deleting partition: Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 10
fi

UpdateTestState $ICA_TESTCOMPLETED

exit 0;
