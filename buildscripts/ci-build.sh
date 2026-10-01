#!/bin/sh
set -v
set -e

# Unencrypt our provisioning profiles, certificates, and private key
# 
# Encrypt the profiles, certs, and key using the following example command where 
# "secret-key" is the key stored in the Github Secrets variable ENCRYPTION_SECRET
#
# openssl aes-256-cbc -k "secret-key" -in buildscripts/profile/DashNews.provisionprofile -out buildscripts/profile/DashNews.provisionprofile.enc -a
#
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in buildscripts/profile/DashNews.provisionprofile.enc -d -a -out buildscripts/profile/DashNews.provisionprofile
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in buildscripts/profile/DashNewsiOS.mobileprovision.enc -d -a -out buildscripts/profile/DashNewsiOS.mobileprovision
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in buildscripts/certs/mac-dist.cer.enc -d -a -out buildscripts/certs/mac-dist.cer
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in buildscripts/certs/ios-dist.cer.enc -d -a -out buildscripts/certs/ios-dist.cer
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in buildscripts/certs/mac-dist.p12.enc -d -a -out buildscripts/certs/mac-dist.p12

# Put the certificates and private key in the Keychain, set ACL permissions, and make default
security create-keychain -p github-actions github-build.keychain
security import buildscripts/certs/apple.cer -k ~/Library/Keychains/github-build.keychain -A
security import buildscripts/certs/mac-dist.cer -k ~/Library/Keychains/github-build.keychain -A
security import buildscripts/certs/ios-dist.cer -k ~/Library/Keychains/github-build.keychain -A
security import buildscripts/certs/mac-dist.p12 -k ~/Library/Keychains/github-build.keychain -P $KEY_SECRET -A
security set-key-partition-list -S apple-tool:,apple: -s -k github-actions github-build.keychain
security default-keychain -s github-build.keychain

# Copy the provisioning profile
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
cp buildscripts/profile/DashNews.provisionprofile ~/Library/MobileDevice/Provisioning\ Profiles/
cp buildscripts/profile/DashNewsiOS.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

# Delete the decrypted files
rm -f buildscripts/profile/DashNews.provisionprofile
rm -f buildscripts/profile/DashNewsiOS.mobileprovision
rm -f buildscripts/certs/mac-dist.cer
rm -f buildscripts/certs/ios-dist.cer
rm -f buildscripts/certs/mac-dist.p12

# Do the build
xcodebuild -scheme $SCHEME build -destination "$DESTINATION" -showBuildTimingSummary -allowProvisioningUpdates

# Delete the keychain and the provisioning profile
security delete-keychain github-build.keychain
rm -f ~/Library/MobileDevice/Provisioning\ Profiles/DashNews.provisionprofile
rm -f ~/Library/MobileDevice/Provisioning\ Profiles/DashNewsiOS.mobileprovision
