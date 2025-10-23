#!/bin/bash

# Find all "pubspec.yaml" files starting from the current directory
find . -type f -name "pubspec.yaml" | while read -r file; do
  # Extract the directory of the "pubspec.yaml"
  dir=$(dirname "$file")
  
  # Output the directory being processed
  echo "Running dart pub get in: $dir"
  
  # Change to that directory and run `dart pub get`
  (cd "$dir" && dart pub get)
done