#!/bin/bash
virsh --connect qemu:///system start win10; virt-viewer --connect qemu:///system win10
