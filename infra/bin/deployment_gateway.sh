#!/bin/bash

show_help() {
  echo "Usage: $0 [-v|--release-version <version>]"
  echo "  -v, --release-version <version>   version being released in semver format"
  echo "  -h, --help                        show this help message and exit"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -v|--release-version)
      release_version="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

if [ -z "$release_version" ]; then
  echo "Error: missing required argument --release-version"
  show_help
  exit 1
fi

# Validate the release version is in semver format
if ! [[ "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Invalid release version, should be in semver format x.y.z"
  show_help
  exit 1
fi

# Validate the release version is the latest possible
latest_version=$(git branch -r | grep "/release/" | sort -V | tail -n 1 | awk -F "/" '{print $NF}')
if [ "$release_version" = "$(echo -e "$latest_version\n$release_version" | sort -V | head -n1)" ]; then
  echo "Error: Release version $release_version cannot be lesser than the last version $latest_version"
  exit 1
fi


root_dir=$(git rev-parse --show-toplevel)

find "$root_dir" -type d -mindepth 1 -maxdepth 10 | while read -r dir; do
  if [ -f "$dir/manifest.yaml" ]; then
    project_name=$(yq eval '.PROJECT_NAME' "$dir/manifest.yaml")
    latest_project_version=$(git branch -r | grep "$project_name/release/" | sort -V | tail -n1)
    echo $project_name
    echo $latest_project_version
  fi
done
