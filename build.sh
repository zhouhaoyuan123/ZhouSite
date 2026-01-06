#!/bin/bash

# Create the dist directory if it doesn't exist
mkdir -p dist

# Remove existing content in dist
rm -rf dist/*

# List of files and directories to exclude
exclude=".config .git attached_assets .upm .replit build.sh README.md replit.md dist"

# Move all files and folders to the dist directory, excluding the specified ones
for item in *; do
  exclude_flag=false
  for exclude_item in $exclude; do
    if [ "$item" = "$exclude_item" ]; then
      exclude_flag=true
      break
    fi
  done

  if [ "$exclude_flag" = false ]; then
    cp -r "$item" dist/
  fi

# Add robots.txt (allow all)
echo "User-agent: * 
Allow: /" > dist/robots.txt

done