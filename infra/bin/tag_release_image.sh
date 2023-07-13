
# Retag the last build image in ECR with a new tag
# Images should be in stage, and are ready to be copied into prod

if [ ! -f "./manifest.yaml" ]; then
    echo "The './manifest.yaml' file does not exist."
    echo "Check if the directory $(pwd) is a project."
    exit 1
fi

docker_image_name=$(yq eval ".DOCKER_IMAGE_NAME" "./manifest.yaml")
release_version=$(< "./VERSION")

echo "Checking for release tag: $release_version"

# Retrieve the image details of the last pushed image
latest_tags=$(aws ecr describe-images --repository-name "$docker_image_name" \
    --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageTags')

echo "$latest_tags are altest tags"
if [[ $latest_tags =~ (^|\W)"$release_version"($|\W) ]]; then
    required_tag="${BASH_REMATCH[0]}"
fi

if [ -n "$required_tag" ]; then
    echo "Latest build tags in stage $latest_tags don't include the needed version $release_version."
    exit 1
fi

echo "$required_tag"
echo "release-$release_version"
#IMAGE_TAG=$required_tag NEW_TAG=release-$release_version make docker-image-retag
