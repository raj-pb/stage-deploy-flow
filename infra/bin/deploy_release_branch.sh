#!/bin/bash
set -e

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/}

Creates a docker release from a given branch. Pushes the container to ECR when finished.

The current branch must be named <project>/release-x.y.z, e.g.
  api/release-0.0.1
  metrics_api/release-4.1.0

Options:
    -h          display this help and exit
EOF
}


while getopts "h?" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    esac
done

# Verify branch doesn't have any outstanding files or commits.
if [[ $(git diff --stat) != '' ]]; then
  output=$(git diff --stat)
  echo "$output"
  echo "---------------------------------------------------------------"
  echo "[x] git branch is dirty"
  echo "    Releases can only be created from clean branches, exiting."
  exit 1
else
  echo "[✓] git branch is clean"
fi

# Verify branch follows naming convention
current_branch=$(git rev-parse --abbrev-ref HEAD)

file_directory="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
python3 "$file_directory"/release_candidate_tags.py -b "$current_branch"
new_tag=$(git describe --abbrev=0 --tags | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [[ "$new_tag" =~ ^tags\/([a-z_]+)\/release[-\/]([[:digit:]]+.[[:digit:]]+.[[:digit:]]+-[a-z_]*.[[:digit:]]+)? ]]
then
  build_tag=$(echo "$current_branch" | cut -d'/' -f2)
  tag_project=${BASH_REMATCH[1]}
  version=${BASH_REMATCH[2]}  # overwrite
  if [ "tag_project" = "$project_name" ]
  then
    echo "[✓] Project tag matches expected project."
  else
    echo "[x] Project directory does not match."
    echo "    > expected: $project_name"
    echo "    > got:      $tag_project"
  fi
else
  echo "[x] Latest tag not found:"
  echo "    expected:       tags/<project>/release/x.y.z-rc.u"
  echo "    latest tag:     $new_tag"
fi

if [[ "$current_branch" =~ ^([a-z_]+)/release[-\/]([[:digit:]]+.[[:digit:]]+.[[:digit:]]+[a-z]*) ]]
then
  build_tag=$(echo "$current_branch" | cut -d'/' -f2)
  project_name=${BASH_REMATCH[1]}
  version=${BASH_REMATCH[2]}

  echo "[✓] Detected Branch: $current_branch"
  echo "    > project name:  $project_name"
  echo "    > build tag:     $build_tag"
  echo "    > version        $version"
else
  echo "[x] Invalid branch name, must be in the format:"
  echo "    expected:       <project>/release-x.y.z"
  echo "    current branch: $current_branch"
  exit 1
fi

# Verify project name
current_project_name=$(yq eval ".PROJECT_NAME" "./manifest.yaml")
if [ ! "$current_project_name" ]
then
  echo "[x] Could not find project name $project_name in manifest, exiting."
  exit 1
fi

if [ "$current_project_name" = "$project_name" ]
then
  echo "[✓] Project directory matches expected path."
else
  echo "[x] Project directory does not match."
  echo "    > expected: $project_name"
  echo "    > got:      $current_project_name"
  exit 1
fi
echo "Building Release..."

# RELEASE_VERSION=$version make $project_name-deploy
