#!/bin/bash

function show_help {
  echo "Usage: $0 [-h] [--dry-run]"
  echo "  -h, --help          show this help message and exit"
  echo "  --dry-run           perform a dry run, don't merge any branches"
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

find "$root_dir" -type d -mindepth 1 -maxdepth 5 | while read -r project_dir; do
  if [ -f "$project_dir/manifest.yaml" ]; then
    project_name=$(yq eval '.PROJECT_NAME' "$project_dir/manifest.yaml")
    project_branch=$(git branch -r | grep "$project_name/release/" | sed 's/^..//' | sort -V | tail -n1)

    # Check if the last released branch is ahead of develop
    commits_ahead=$(git rev-list --count "develop..$project_branch")
    if [[ $commits_ahead -eq 0 ]]; then
      echo "$project_name: No changes in the current release."
      continue
    fi

    # Merge the branch into develop
    if [[ -z "$DRY_RUN" ]]; then
      git checkout develop && git pull
      git merge --no-ff "$project_branch"
      git push
      echo "$project_name: $project_branch merged to develop."
    else
      echo "Dry run: found $project_branch to be merged."
    fi
  fi
done