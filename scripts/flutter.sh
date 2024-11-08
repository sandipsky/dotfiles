#!/bin/bash

# Set Android version
ANDROID_VERSION=34

# Add environment variables to .bashrc and .zshrc for persistence
echo "export ANDROID_SDK_ROOT=~/AndroidSDK" >> ~/.bashrc
echo "export PATH=\$PATH:~/AndroidSDK/cmdline-tools/latest/bin:~/AndroidSDK/emulator" >> ~/.bashrc

echo "export ANDROID_SDK_ROOT=~/AndroidSDK" >> ~/.zshrc
echo "export PATH=\$PATH:~/AndroidSDK/cmdline-tools/latest/bin:~/AndroidSDK/emulator" >> ~/.zshrc

# Download the latest command line tools
curl -o "~/Downloads/commandlinetools.zip" https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip  

# Create the SDK directory if it doesn't exist
mkdir -p ~/AndroidSDK/cmdline-tools/latest

# Unzip the downloaded file into the SDK directory
unzip "~/Downloads/commandlinetools.zip" -d "~/AndroidSDK/cmdline-tools/latest"

# Accept licenses
yes | ~/AndroidSDK/cmdline-tools/latest/bin/sdkmanager --licenses

# Install necessary packages
~/AndroidSDK/cmdline-tools/latest/bin/sdkmanager "system-images;android-${ANDROID_VERSION};google_apis_playstore;x86"
~/AndroidSDK/cmdline-tools/latest/bin/sdkmanager platform-tools emulator
~/AndroidSDK/cmdline-tools/latest/bin/sdkmanager "platforms;android-${ANDROID_VERSION}"
~/AndroidSDK/cmdline-tools/latest/bin/sdkmanager "build-tools;${ANDROID_VERSION}.0.0"

# Create an AVD with the specified Android version
~/AndroidSDK/cmdline-tools/latest/bin/avdmanager create avd --name "android${ANDROID_VERSION}" --package "system-images;android-${ANDROID_VERSION};google_apis;x86_64"

# Download and install Flutter
curl -o "~/Downloads/flutter_linux.tar.xz" https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.10.5-stable.tar.xz
mkdir -p ~/flutter
tar xf "~/Downloads/flutter_linux.tar.xz" -C ~/

# Add Flutter to the PATH in .bashrc and .zshrc
echo "export PATH=\$PATH:~/flutter/flutter/bin" >> ~/.bashrc
echo "export PATH=\$PATH:~/flutter/flutter/bin" >> ~/.zshrc

# Load the new PATH for the current session
export PATH=$PATH:~/flutter/flutter/bin

# Set up Flutter to use the Android SDK and accept licenses
flutter config --android-sdk ~/AndroidSDK
flutter doctor --android-licenses