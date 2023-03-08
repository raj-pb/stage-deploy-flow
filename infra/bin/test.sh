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

papaya="ada"
echo "export SLACK_PLACEHOLDER=\"$(cat <<EOF
The following projects are built and packed : $(echo $papaya), and are ready to be released.
Review and merge the created PR to finish the staging flow.
EOF
)\"" >> $BASH_ENV
