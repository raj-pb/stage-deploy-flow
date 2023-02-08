#!/bin/bash
set -e

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/}

Deploys an image to ecs

Options:
    -h          display this help and exit
    -t          deploy this docker tag
EOF
}


while getopts "h?te" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    t)
      docker_tag=$OPTARG
      ;;
    e)
      env=$OPTARG
      ;;
    esac
done


ecs_cluster_name=$(yq eval ".ECS_CLUSTER_NAME" "./manifest.yaml")
ecs_service_name=$(yq eval ".ECS_SERVICE_NAME" "./manifest.yaml")

exec "ecs deploy $ecs_cluster_name-$env $ecs_service_name-$env --image main $docker_tag --timeout -1"
