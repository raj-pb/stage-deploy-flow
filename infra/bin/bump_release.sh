#!/bin/bash
set -e

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/}

Gets the latest release for a project

Options:
    -h          display this help and exit
    -p          project name
    -t          type of bump: major, minor, patch
EOF
}

if ! command -v bump2version &> /dev/null
then
    echo "bump2version could not be found"
    echo "pip3 install -U bump2version"
    exit
fi

latest_release() {
  echo "Latest release for $1"
}

while getopts "h?p:t:" opt; do
  case "$opt" in
    h|\?)
      show_help
      exit 0
      ;;
    p)
      project_name="$OPTARG"
      ;;
    t)
      bump_type="$OPTARG"
      ;;
  esac
done

if [ -z "$project_name" ]; then
  echo 'Missing -p' >&2
  exit 1
fi

echo "Getting latest release for: $project_name"

versions=$(git branch -r --list "origin/$project_name/*")
printf "Found versions:\n%s\n\n" "$versions"

latest_release_tag=$(git branch -r --list "origin/$project_name/*" | sed "s/release[-/]/release-/" | sed -nE '/release-[0-9]+.[0-9]+.[0-9]+/p' | sort -Vr | head -1 | cut -d '/' -f3)
latest_version=$(echo $latest_release_tag | cut -d '-' -f2)
echo "Found latest version: $latest_version"

echo "Bumping Version"
echo "$latest_version" > VERSION

# Bump the version to actually get the version.
bump2version --current-version $latest_version $bump_type VERSION --no-configured-files --verbose --allow-dirty
new_version=$(cat VERSION)

echo "$latest_version -> $new_version"

git checkout -b "$project_name/release/$new_version"
git add VERSION
git commit -m "Bump version $latest_version -> $new_version"

echo "Version incremented, push your branch to git to continue."
