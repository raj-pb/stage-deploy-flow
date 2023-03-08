#!/bin/bash


function show_help {
cat << EOF
Usage: $0 [-p|--project <project_name>] [-h] [--dry-run]

Handles the end of the staging deployment cycle, merges the latest commits in staging branch to the "develop" branch.
Updates the VERSION file, for all the changed projects in this release, to the released version.

All the staging branches will be of form <project>/release/x.y.z. The project would have a pending release
if the VERSION in develop branch is less than that of the latest staging branch, e.g.
  [git:develop] >> cat experiment_api/VERSION
                >> 4.1.0
  then, api/release/4.2.0 would be the staging branch that is pending release.

For all the projects with a pending release, the following would be done:
  - Merge all the staging branches to an auxiliary "prerelease"
  - Create a tag from the release candidates for the staging branch, e.g.:
       >> git tag -n1  gives-> tags/api/release/4.2.0-rc.15
       * [new tag]         tags/api/release/4.2.0
  - Mark the latest release tag for release & generate release notes
All the pending releases in stage are thus merged. This marks the end of the stage deployment flow.

<Scheduled ~2 weeks after the stage deployment starts>

Options:
  -p, --project <project_name>    run for a single target project
  -h, --help                      show this help message and exit
  --dry-run                       perform a dry run, don't merge any branches
EOF
}


# Parse command-line arguments
for arg in "$@"; do
  case $arg in
    -p|--project)
      target_project="$2"
      shift
      ;;
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
  # failure would give empty notes
  notes=python3 "$file_dir"/release_notes.py -e "$current_branch" -s "$prev_branch" -d "$project_dir" 2>/dev/null
  echo "$notes"
}

declare -a release_branches
declare -a project_dirs

while read -r project_dir; do
  if [ -f "$project_dir/manifest.yaml" ]; then
    project_name=$(yq eval '.PROJECT_NAME' "$project_dir/manifest.yaml")
    project_branch=$(git branch -r | grep "$project_name/release/" | sed 's/^..//' | sort -V | tail -n1)

    if [[ -n "$target_project" && "$target_project" != "$project_name" ]]; then
      # target given that doesn't match with given project
      continue
    fi

    # Check if the last released branch is ahead of develop
    commits_ahead=$(git rev-list --count "develop..$project_branch")
    if [[ $commits_ahead -eq 0 ]]; then
      echo "$project_name: No changes in the current release."
      continue
    fi

    # Mark the branch for release
    if [[ -z "$DRY_RUN" ]]; then
      release_branches+=("$project_branch")
      project_dirs+=("$project_dir")
    else
      echo "$project_name (dry run): found $project_branch to be merged."
    fi
  fi
done < <(find "$root_dir" -type d -mindepth 1 -maxdepth 5)


release_count=${#release_branches[@]}
if [ $release_count -eq 0 ]; then
  echo "No release"
  exit 0
fi


echo "Found $release_count number of releases."

prerelease_branch="prerelease"
# check if the prerelease branch exists
any_branch=${release_branches[0]}
any_version=$(echo "$any_branch" | awk -F "/" '{print $NF}')
if git rev-parse --verify "$prerelease_branch" > /dev/null 2>&1; then
  # if exists, rebase onto any_branch
  git checkout "$prerelease_branch"
  git rebase --onto "$any_branch" HEAD~ "$prerelease_branch" -f
else
  # else create one with the same base as any
  git checkout -b "$prerelease_branch" "$any_branch"
fi

# ensure no merge conflicts between all the branches
for ((i=0; i<release_count; i++)); do
  project_branch="${release_branches[$i]}"
  project_name=$(yq eval '.PROJECT_NAME' "${project_dirs[$i]}/manifest.yaml")

  echo "Merging $project_name: $project_branch..."
  if ! git merge --no-ff --no-commit "$project_branch"; then
    echo "Release aborted because of conflicts. Merge conflicts before continuing"
    echo "[Recommended] Ignore auxiliary branch "$prerelease_branch", update $project_branch and retry."
    git status
    git merge --abort
    exit 1
  fi

  # Continue with the merge if clean and commit the changes
  git commit -m "[release: $any_version] $project_name merge to "$prerelease_branch""
done


git push -u origin "$prerelease_branch"
# create a new PR
gh pr create --title "New Release : $any_version" --base develop --head "$prerelease_branch"
echo "All $release_count release branches merged to auxiliary branch "$prerelease_branch"."
echo "Merge \`"$prerelease_branch"\` to \`develop\` to finish the stage flow."
sleep 10   # avoid git timeout-by-rate-limiting


echo "Creating release tags..."
for ((i=0; i<release_count; i++)); do
  project_branch="${release_branches[$i]}"
  project_dir="${project_dirs[$i]}"
  project_name=$(yq eval '.PROJECT_NAME' "$project_dir/manifest.yaml")
  project_version=$(echo "$project_branch" | awk -F "/" '{print $NF}')

  git checkout $project_branch
  new_tag="tags/$project_name/release/$project_version"
  echo "Creating a new release tag $new_tag..."
  echo "Code frozen hereafter for $project_name in the current release."
  git tag "$new_tag"
  git push -u origin "$new_tag" -q
  sleep 10   # avoid git timeout-by-rate-limiting

  # Create the release & notes using gh
  echo "Generating release_notes..."
  notes=$(release_notes "$project_dir" "$project_name" "$project_branch")
  gh release create "$new_tag" --title "Release version $project_version" --notes "$notes"
  echo "$project_name: $project_version done."
done
