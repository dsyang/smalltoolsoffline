#!/bin/sh
# Xcode Cloud runs this after cloning the repo, before resolving packages and building.
# Regenerates SmallTools.xcodeproj from project.yml so the build always matches the spec.
set -e

brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH/ios-native/SmallTools"

# A workflow can set APP_VERSION (e.g. 0.9.0 for the Dev workflow) in its
# environment variables to ship under a different version than project.yml.
if [ -n "$APP_VERSION" ]; then
  echo "Overriding MARKETING_VERSION with $APP_VERSION"
  sed -i '' "s/MARKETING_VERSION: .*/MARKETING_VERSION: \"$APP_VERSION\"/" project.yml
fi

xcodegen generate
