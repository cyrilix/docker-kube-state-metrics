#! /bin/bash

IMG_NAME=cyrilix/kube-state-metrics
VERSION=1.8.0
MAJOR_VERSION=1.8
export DOCKER_CLI_EXPERIMENTAL=enabled
export DOCKER_USERNAME=cyrilix

set -e

init_qemu() {
    echo "#############"
    echo "# Init qemu #"
    echo "#############"

    local qemu_url='https://github.com/multiarch/qemu-user-static/releases/download/v2.9.1-1'

    docker run --rm --privileged multiarch/qemu-user-static:register --reset

    for target_arch in aarch64 arm x86_64; do
        wget "${qemu_url}/x86_64_qemu-${target_arch}-static.tar.gz";
        tar -xvf "x86_64_qemu-${target_arch}-static.tar.gz";
    done
}

fetch_sources() {
    local project_name=kube-state-metrics

    if [[ ! -d  ${project_name} ]] ;
    then
        git clone https://github.com/kubernetes/${project_name}.git
    fi
    cd ${project_name}
    git reset --hard
    git checkout v${VERSION}
}

build_and_push_images() {
    make REGISTRY=cyrilix all-container
    for arch in "amd64" "arm" "arm64";
    do
        docker tag "${IMG_NAME}-${arch}:v${VERSION}" "${IMG_NAME}:${arch}-latest"
        docker tag "${IMG_NAME}-${arch}:v${VERSION}" "${IMG_NAME}:${arch}-${VERSION}"
        docker tag "${IMG_NAME}-${arch}:v${VERSION}" "${IMG_NAME}:${arch}-${MAJOR_VERSION}"

        docker push "${IMG_NAME}:${arch}-latest"
        docker push "${IMG_NAME}:${arch}-${VERSION}"
        docker push "${IMG_NAME}:${arch}-${MAJOR_VERSION}"
    done
}


build_manifests() {
    docker -D manifest create "${IMG_NAME}:${VERSION}" "${IMG_NAME}:amd64-${VERSION}" "${IMG_NAME}:arm-${VERSION}" "${IMG_NAME}:arm64-${VERSION}"
    docker -D manifest annotate "${IMG_NAME}:${VERSION}" "${IMG_NAME}:arm-${VERSION}" --os=linux --arch=arm --variant=v6
    docker -D manifest annotate "${IMG_NAME}:${VERSION}" "${IMG_NAME}:arm64-${VERSION}" --os=linux --arch=arm64 --variant=v8
    docker -D manifest push "${IMG_NAME}:${VERSION}"

    docker -D manifest create "${IMG_NAME}:latest" "${IMG_NAME}:amd64-latest" "${IMG_NAME}:arm-latest" "${IMG_NAME}:arm64-latest"
    docker -D manifest annotate "${IMG_NAME}:latest" "${IMG_NAME}:arm-latest" --os=linux --arch=arm --variant=v6
    docker -D manifest annotate "${IMG_NAME}:latest" "${IMG_NAME}:arm64-latest" --os=linux --arch=arm64 --variant=v8
    docker -D manifest push "${IMG_NAME}:latest"

    docker -D manifest create "${IMG_NAME}:${MAJOR_VERSION}" "${IMG_NAME}:amd64-${MAJOR_VERSION}" "${IMG_NAME}:arm-${MAJOR_VERSION}" "${IMG_NAME}:arm64-${MAJOR_VERSION}"
    docker -D manifest annotate "${IMG_NAME}:${MAJOR_VERSION}" "${IMG_NAME}:arm-${MAJOR_VERSION}" --os=linux --arch=arm --variant=v6
    docker -D manifest annotate "${IMG_NAME}:${MAJOR_VERSION}" "${IMG_NAME}:arm64-${MAJOR_VERSION}" --os=linux --arch=arm64 --variant=v8
    docker -D manifest push "${IMG_NAME}:${MAJOR_VERSION}"
}

fetch_sources
init_qemu

echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

build_and_push_images

build_manifests
