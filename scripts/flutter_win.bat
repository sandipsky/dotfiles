@echo off

set ANDROID_VERSION=34
setx ANDROID_SDK_ROOT "%USERPROFILE%\AndroidSDK"
setx PATH "%PATH%;%USERPROFILE%\AndroidSDK\cmdline-tools\latest\bin;%USERPROFILE%\AndroidSDK\emulator"
curl -o "%USERPROFILE%\Downloads\commandlinetools.zip" https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip
mkdir "%USERPROFILE%\AndroidSDK\cmdline-tools\latest"
powershell -command "Expand-Archive -Path '%USERPROFILE%\Downloads\commandlinetools.zip' -DestinationPath '%USERPROFILE%\AndroidSDK\cmdline-tools\latest'"
%USERPROFILE%\AndroidSDK\cmdline-tools\latest\bin\sdkmanager.bat --licenses
%USERPROFILE%\AndroidSDK\cmdline-tools\latest\bin\sdkmanager.bat "system-images;android-%ANDROID_VERSION%;google_apis_playstore;x86"
%USERPROFILE%\AndroidSDK\cmdline-tools\latest\bin\sdkmanager.bat platform-tools emulator
%USERPROFILE%\AndroidSDK\cmdline-tools\latest\bin\sdkmanager.bat "platforms;android-%ANDROID_VERSION%"
%USERPROFILE%\AndroidSDK\cmdline-tools\latest\bin\sdkmanager.bat "build-tools;%ANDROID_VERSION%.0.0"
%USERPROFILE%\AndroidSDK\cmdline-tools\latest\bin\avdmanager.bat create avd --name "android%ANDROID_VERSION%" --package "system-images;android-%ANDROID_VERSION%;google_apis;x86_64"
curl -o "%USERPROFILE%\Downloads\flutter_windows.zip" https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.10.5-stable.zip
mkdir "%USERPROFILE%\flutter"
powershell -command "Expand-Archive -Path '%USERPROFILE%\Downloads\flutter_windows.zip' -DestinationPath '%USERPROFILE%\flutter'"
setx PATH "%PATH%;%USERPROFILE%\flutter\flutter\bin"
%USERPROFILE%\flutter\flutter\bin\flutter config --android-sdk %USERPROFILE%\AndroidSDK
%USERPROFILE%\flutter\flutter\bin\flutter doctor --android-licenses
