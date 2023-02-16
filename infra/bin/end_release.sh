#!/bin/bash

function show_help {
cat << EOF
Usage: $0 [-h] [--dry-run]

Handles the end of the staging deployment cycle, merges the latest commits in staging branch to the "develop" branch.
Updates the VERSION file, for all the changed projects in this release, to the released version.

All the staging branches will be of form <project>/release/x.y.z. The project would have a pending release
if the VERSION in develop branch is less than that of the latest staging branch, e.g.
  [git:develop] >> cat experiment_api/VERSION
                >> 4.1.0
  then, api/release/4.2.0 would be the staging branch that is pending release.

For all the projects with a pending release, the following would be done:
  - Merge all the staging branches to "develop"
  - Create a tag from the release candidates for the staging branch, e.g.:
       >> git tag -n1  gives-> tags/api/release/4.2.0-rc.15
       * [new tag]         tags/api/release/4.2.0
  - Mark the latest release tag for release & generate release notes
All the pending releases in stage are thus merged. This marks the end of the stage deployment flow.

<Scheduled ~2 weeks after the stage deployment starts>

Options:
  -h, --help          show this help message and exit
  --dry-run           perform a dry run, don't merge any branches
EOF
}

# Parse command-line arguments
for arg in "$@"; do
  case $arg in
    -h|--help)
      show_help
      exit 0
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    *)
      echo "Unknown argument: $arg"
      show_help
      exit 1
      ;;
  esac
done

root_dir=$(git rev-parse --show-toplevel)
file_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

release_notes() {
  local project_dir=$1
  local project_name=$2
  local current_branch=$3
  # the previous release; which will be the same as current branch for the very first branch
  local prev_branch
  prev_branch=$(git branch -r | grep "$project_name/release/" | sed 's/^..//' | sort -V | tail -n2 | head -n1)
  local notes
  # errors would give empty notes
  notes=python3 "$file_dir"/release_notes.py -e "$current_branch" -s "$prev_branch" -d "$project_dir" 2>/dev/null
  echo "$notes"
}

find "$root_dir" -type d -mindepth 1 -maxdepth 5 | while read -r project_dir; do
  if [ -f "$project_dir/manifest.yaml" ]; then
    project_name=$(yq eval '.PROJECT_NAME' "$project_dir/manifest.yaml")
    project_branch=$(git branch -r | grep "$project_name/release/" | sed 's/^..//' | sort -V | tail -n1)
    project_version=$(echo "$project_branch" | awk -F "/" '{print $NF}')

    # Check if the last released branch is ahead of develop
    commits_ahead=$(git rev-list --count "develop..$project_branch")
    if [[ $commits_ahead -eq 0 ]]; then
      echo "$project_name: No changes in the current release."
      continue
    fi

    # Merge the branch into develop
    if [[ -z "$DRY_RUN" ]]; then
      echo "$project_name: $project_branch being merged..."
      git checkout develop -q && git pull -q
      if ! git merge --no-ff --no-commit "$project_branch"; then
        echo "Release aborted. Merge conflicts and retry:"
        git status
        git merge --abort
        exit 1
      fi

      # Continue with the merge if clean and commit the changes
      git commit -m "[release] $project_name:$project_version merge to develop"
      new_tag="tags/$project_name/release/$project_version"
      echo "Creating a new tag $new_tag..."
      git tag "$new_tag"
      git push -u origin develop "$new_tag" -q

      # Create the release & notes using gh
      echo "Generating release_notes..."
      notes=$(release_notes "$project_dir" "$project_name" "$project_branch")
      gh release create "$new_tag" --title "Release version $project_version" --notes "$notes"
      echo "$project_name: $project_version merged to develop."
    else
      echo "$project_name (dry run): found $project_branch to be merged."
    fi
  fi
done