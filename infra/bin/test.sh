while [ $# -gt 0 ]; do
  case "$1" in
    -v|--release-version)
      release_version="$2"
      shift 2
      ;;
    -p|--project)
      target_project="$2"
      shift 2
      ;;
    -d|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1"
      exit 1
      ;;
  esac
done

projects=("rabbit" "hare" "tortoise" "lion")

for project_name in "${projects[@]}"; do
  if [[ -n "$target_project" && "$target_project" != "$project_name" ]]; then
    echo "project given $target_project but not matching"
    continue
  fi
  echo "going ahead for $project_name"
done

slack_branches=${projects[@]}
pr_url=$(gh pr view --json url | jq -r \".url\")
echo "export SLACK_MRKDWN_BODY=\"The following projects are built and packed : $(echo $slack_branches), and are ready to be released. Review and merge the created PR : $(echo $pr_url) to finish the staging flow.\"" >> $BASH_ENV
