#!/bin/bash

sudo touch /etc/polkit-1/rules.d/49-nopasswd_global.rules
sudo bash -c "cat >> /etc/polkit-1/rules.d/49-nopasswd_global.rules" << EOF
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF




