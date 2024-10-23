#!/bin/bash

sudo mkdir /mnt/HOME
echo '/dev/disk/by-uuid/4CC27C52C27C41EE /mnt/HOME auto nosuid,nodev,nofail,x-gvfs-show 0 0' | sudo tee -a /etc/fstab
