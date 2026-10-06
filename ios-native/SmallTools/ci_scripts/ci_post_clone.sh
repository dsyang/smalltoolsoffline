#!/bin/sh
# Xcode Cloud runs this after cloning the repo, before resolving packages and building.
# Regenerates SmallTools.xcodeproj from project.yml so the build always matches the spec.
set -e

brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH/ios-native/SmallTools"
xcodegen generate
