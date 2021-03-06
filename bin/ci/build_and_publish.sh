#!/usr/bin/env bash
#
# build_and_publish.sh
#
# This script is used during CI to build and push images to DockerHub.
# This is run from the projects root directory, e.g. './bin/ci/build_and_publish.sh'
# so all paths should be relative to the repo root.
#
# The CI environment should provide the following environment variables:
#   IMAGE_NAME: The name of the Docker image (without tags)
#   CIRCLE_TAG: The name of the git tag
#
# All arguments passed to the script should be tags for the $IMAGE_NAME.
# If $CIRCLE_TAG exists, it will be parsed to generate the tags for all
# appropriate versions. For example:
#   CIRCLE_TAG  ->  IMAGE TAGS
#   1           ->  1
#   1.2         ->  1, 1.2
#   1.2.3       ->  1, 1.2, 1.2.3
#

echo "Building and Publishing Images"

#
# Get Tags
#
# In this section, we collect all of the tags that we will use for
# the image to be built and pushed.
#

declare -a tags

if [ "${CIRCLE_TAG}" ]; then
    echo "Found CIRCLE_TAG: ${CIRCLE_TAG}"

    # First, search for "-" in the tag. This would be the case for tags
    # with suffixes, e.g. "1-dev", "1.2.3-rc0". If a suffix is present,
    # then we will not generate additional image tags.
    suffix_count=$(awk -F- '{print NF-1}' <<< "${CIRCLE_TAG}")
    if [ ${suffix_count} -eq 0 ]; then
        IFS='.' read -r -a array <<< "${CIRCLE_TAG}"

        major="${array[0]}"
        minor="${array[1]}"
        micro="${array[2]}"

        if [ "${micro}" ]; then
            tags+=("${major}.${minor}.${micro}")
        fi
        if [ "${minor}" ]; then
            tags+=("${major}.${minor}")
        fi
        if [ "${major}" ]; then
            tags+=("${major}")
        fi
    fi

    if [ "${tags}" ]; then
        echo "Created image tags from CIRCLE_TAG: ${tags[@]}"
    else
        echo "No image tags created from CIRCLE_TAG"
    fi

    # Add the CIRCLE_TAG to the tags. In some cases, this may duplicate
    # a tag, but building with the same tag should just use the cache
    # and not cause any problems.
    tags+=("${CIRCLE_TAG}")
fi


# Now, add all of the tags provided via command line arguments
for arg in "$@"; do
    tags+=("$arg")
done

echo "All tags for ${IMAGE_NAME}: ${tags[@]}"


#
# Build
#
# Now, we build the image and tag it with the tags we collected above.
# How the image is built is up to the repo. It is recommended that a
# single image is built with a 'tmp' tag first, then the tags applied
# afterwards.
#
# Performing a single build will make it easier for images that take
# build-time arguments that may cause cache invalidation across all
# builds (e.g. if a build time is specified).
#

# Build the temp image first
docker build -f Dockerfile -t ${IMAGE_NAME}:tmp .

# Apply all of our tags to the image
for tag in "${tags[@]}"; do
    docker tag ${IMAGE_NAME}:tmp ${IMAGE_NAME}:${tag}
done


#
# Publish
#
# Now, we publish the images to DockerHub. Note that the 'tmp' image
# is not pushed - it is a local artifact for convenience only.
#
#

for tag in "${tags[@]}"; do
    docker push ${IMAGE_NAME}:${tag}
done
