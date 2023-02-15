#!/bin/bash

show_help() {
  echo "Usage: $0 [-v|--release-version <version>]"
  echo "  -v, --release-version <version>   version being released in semver format"
  echo "  -r, --rollback <version>          rollback the version [WARNING: cannot be undone]"
  echo "  -h, --help                        show this help message and exit"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -v|--release-version)
      release_version="$2"
      shift 2
      ;;
    -r|--rollback)
      branches="$(git branch | sed 's/^..//' | grep "/release/$2")";
      for branch in $branches; do echo "$branch" && git push origin --delete "$branch" && git branch -D "$branch"; done
      tags="$(git tag -l | grep "$2")"
      for tag in $tags; do echo "$tag" && git push origin --delete "$tag" && git tag -d "$tag"; done
      exit 0
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
current_branch=$(git rev-parse --abbrev-ref HEAD)


# Update the version for a particular project, commit and push to a new branch
branch_and_commit() {
  project_dir=$1
  project_name=$(yq eval '.PROJECT_NAME' "$project_dir/manifest.yaml")
  project_branch=$(git branch -r | grep "$project_name/release/" | sed 's/^..//' | sort -V | tail -n1)

  # make project dir as the working directory
  pushd "$project_dir" > /dev/null || exit
  if ! git diff --quiet origin/develop "$project_branch" -- "$project_dir"; then
    git stash
    new_branch="$project_name/release/$release_version"
    new_tag="tags/$project_name/release/$release_version-rc.1"
    git checkout -b "$new_branch" origin/develop
    echo "$release_version" > VERSION
    git add VERSION
    git commit -m "[Version bump] $project_branch -> $new_branch"
    git tag "$new_tag"
    git push -u origin "$new_tag" "$new_branch"
    git checkout "$current_branch"
    git stash pop
  fi
  popd > /dev/null || exit
}

# Check if there are git diff for each project, and bump the version if there is
find "$root_dir" -type d -mindepth 1 -maxdepth 5 | while read -r project_dir; do
  if [ -f "$project_dir/manifest.yaml" ]; then
    branch_and_commit "$project_dir"
  fi
done
