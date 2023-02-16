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
        # Continue with the merge and commit the changes
        git status
        git merge --abort
        exit 1
      fi
      git commit -m "[release] $project_name:$project_version merge to develop"
      new_tag="tags/$project_name/release/$project_version"
      git tag "$new_tag"
      git push -u origin develop "$new_tag"
      # Create the release notes using gh
      gh release create "$new_tag" --title "Release version $project_version" --notes "These are the release notes for version $VERSION"
      echo "$project_name: $project_version merged to develop."
    else
      echo "$project_name (dry run): found $project_branch to be merged."
    fi
  fi
done