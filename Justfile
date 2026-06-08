set dotenv-load := true

image_name := env("BUILD_IMAGE_NAME", "debian-bootc-core")
image_repo := env("BUILD_IMAGE_REPO", "ghcr.io/spamtagger")
image_tag := env("BUILD_IMAGE_TAG", "latest")
base_dir := env("BUILD_BASE_DIR", ".")
debian_ver := env("DEBIAN_VER", "trixie")
stable := "trixie"
testing := "forky"
filesystem := env("BUILD_FILESYSTEM", "ext4")
selinux := path_exists('/sys/fs/selinux')

default:
    just --list --unsorted

containerfile $image_name=image_name:
    #!/usr/bin/env bash
    ARCH=$(arch)
    [[ "$ARCH" == "aarch64" ]] && ARCH=arm64
    [[ "$ARCH" == "armv7l" ]] && ARCH=armhf
    [[ "$ARCH" == "x86_64" ]] && ARCH=amd64
    [[ "$ARCH" == "ppc64le" ]] && ARCH=ppc64el
    flags=(
        "-DDEBIAN_VER_SUB={{ debian_ver }}"
        "-DARCH_SUB=$ARCH"
    )

    {{ require('cpp') }} -E -traditional -P Containerfile.in ${flags[@]} > Containerfile

alias build := build-container
build-container $image_name=image_name:
    #!/usr/bin/env bash
    just containerfile

    DATE="$(date +%Y%m%d)"
    TAG={{ debian_ver }}
    TAGS=()
    TAGS+=("--tag" "localhost/$image_name:$TAG")
    [[ "{{ debian_ver }}" == "{{ stable }}" ]] && TAG="stable" && TAGS+=("--tag" "localhost/$image_name:latest") && TAGS+=("--tag" "localhost/$image_name:stable")
    [[ "{{ debian_ver }}" == "{{ testing }}" ]] && TAG="testing" && TAGS+=("--tag" "localhost/$image_name:testing")
    SHA_SHORT="$(git rev-parse --short HEAD)"
    TAGS+=("--tag" "localhost/$image_name:$SHA_SHORT")
    TAGS+=("--tag" "localhost/$image_name:$DATE")

    # OSTree Labels
    IMAGE_VERSION="{{ debian_ver }}.$DATE"
    LABELS=(
        "--label" "containers.bootc=1"
        "--label" "io.artifacthub.package.deprecated=false"
        "--label" "io.artifacthub.package.keywords=bootc,debian"
        "--label" "io.artifacthub.package.logo-url=https://avatars.githubusercontent.com/u/205223896?s=200&v=4"
        "--label" "io.artifacthub.package.maintainers=[{\"name\": \"JohnMertz\", \"email\": \"git@john.me.tz\"}]"
        "--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/$image_registry/$image_org/$image_repo/main/README.md"
        "--label" "org.opencontainers.image.created=$(date -u +%Y\-%m\-%d\T%H\:%M\:%S\Z)"
        "--label" "org.opencontainers.image.description=$image_description"
        "--label" "org.opencontainers.image.license=GPLv3"
        "--label" "org.opencontainers.image.source=https://raw.githubusercontent.com/$image_org/$image_repo/refs/heads/main/Containerfile.in"
        "--label" "org.opencontainers.image.title={{ debian_ver }}"
        "--label" "org.opencontainers.image.url=https://github.com/$image_org/$image_repo"
        "--label" "org.opencontainers.image.vendor=$image_org"
        "--label" "org.opencontainers.image.version=${IMAGE_VERSION}"
        "--label" "org.opencontainers.image.description=Debian Bootc compatible base image"
        "--label" "io.artifacthub.package.deprecated=false"
        "--label" "io.artifacthub.package.prerelease=true"
    )

    sudo podman build \
        --format oci \
        --env=DEBIAN_VER_SUB="{{ debian_ver }}" \
        -t "{{ image_name }}:${TAG}" \
        .
    rm Containerfile

run-container $image_name=image_name:
    sudo podman run --rm -it "{{ image_name }}:{{ image_tag }}" bash

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /etc/containers:/etc/containers{{ if selinux == 'true' { ':Z' } else { '' } }} \
        -v /var/lib/containers:/var/lib/containers{{ if selinux == 'true' { ':Z' } else { '' } }} \
        {{ if selinux == 'true' { '-v /sys/fs/selinux:/sys/fs/selinux' } else { '' } }} \
        {{ if selinux == 'true' { '--security-opt label=type:unconfined_t' } else { '' } }} \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{ base_dir }}:/data" \
        "{{ image_name }}:{{ image_tag }}" bootc {{ ARGS }}

ghcrbootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /etc/containers:/etc/containers{{ if selinux == 'true' { ':Z' } else { '' } }} \
        -v /var/lib/containers:/var/lib/containers{{ if selinux == 'true' { ':Z' } else { '' } }} \
        {{ if selinux == 'true' { '-v /sys/fs/selinux:/sys/fs/selinux' } else { '' } }} \
        {{ if selinux == 'true' { '--security-opt label=type:unconfined_t' } else { '' } }} \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{ base_dir }}:/data" \
        "{{ image_repo}}/{{ image_name }}:{{ image_tag }}" bootc {{ ARGS }}

# accelerate bootc image building with /tmp
setup-bootc-accelerator:
    echo "BUILD_BASE_DIR=/tmp" > .env

generate-bootable-image $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    image_filename={{ image_name }}.img
    if [ ! -e "{{ base_dir }}/${image_filename}" ] ; then
        fallocate -l 20G "{{ base_dir }}/${image_filename}"
    fi
    just bootc install to-disk \
            --composefs-backend \
            --via-loopback /data/${image_filename} \
            --filesystem "{{ filesystem }}" \
            --target-imgref {{ image_repo }}/{{ image_name }}:{{ image_tag }} \
            --wipe \
            --bootloader systemd

bootable-image-from-ghcr $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    image_filename={{ image_name }}.img
    if [ ! -e "{{ base_dir }}/${image_filename}" ] ; then
        fallocate -l 20G "{{ base_dir }}/${image_filename}"
    fi
    just ghcrbootc install to-disk \
            --composefs-backend \
            --via-loopback /data/${image_filename} \
            --filesystem "{{ filesystem }}" \
            --source-imgref docker://{{ image_repo }}/{{ image_name }}:{{ image_tag }} \
            --target-imgref {{ image_repo }}/{{ image_name }}:{{ image_tag }} \
            --wipe \
            --bootloader systemd \
            --karg "debug" \
            --karg "systemd.log_level=debug" \
            --karg "systemd.journald.forward_to_console=1"

# Login to GHCR
[group('CI')]
@login-to-ghcr:
    sudo podman login ghcr.io -u "$GITHUB_ACTOR" -p "$GHCR_TOKEN"

# Push Images to Registry
[group('CI')]
push-to-registry $destination="ghcr.io/spamtagger/debian-bootc-core" $transport="docker://":
    #!/usr/bin/bash

    if [[ ! -z $COSIGN_PRIVATE_KEY ]]; then
        echo "$COSIGN_PRIVATE_KEY" > /tmp/cosign.key
    elif [[ -e cosign.key ]]; then
        cp cosign.key /tmp/cosign.key
    fi
    echo "privateKeyFile: /tmp/cosign.key" > "/tmp/sigstore-params.yaml"
    echo "privateKeyPassphraseFile: /dev/null" >> "/tmp/sigstore-params.yaml"

    TAG={{ debian_ver }}
    [[ "{{ debian_ver }}" == "{{ stable }}" ]] && TAG="stable"
    [[ "{{ debian_ver }}" == "{{ testing }}" ]] && TAG="testing"

    for i in {1..5}; do
        sudo podman push localhost/debian-bootc-core:$TAG $transport$destination:$TAG && break || sleep $((5 * i));
        if [[ $i -eq '5' ]]; then
            exit 1
        fi
    done
    DIGEST=$(skopeo inspect $transport$destination:$TAG | jq -r .Digest)
    COSIGN_EXPERIMENTAL=1 COSIGN_LOG_LEVEL=debug REGISTRY_AUTH_FILE=/run/containers/0/auth.json sudo cosign sign -y --key /tmp/cosign.key --registry-username $GITHUB_ACTOR --registry-password $GHCR_TOKEN $destination@$DIGEST
    {{ if env('COSIGN_PRIVATE_KEY', '') != '' { 'rm /tmp/cosign.key' } else { '' } }}

launch-incus:
    #!/usr/bin/env bash
    image_file={{ base_dir }}/{{ image_name }}.img

    if [ ! -f "$image_file" ]; then
        echo "No image file found, generate-bootable-image first"
        exit 1
    fi

    abs_image_file=$(realpath "$image_file")

    instance_name="{{ image_name }}"
    echo "Creating instance $instance_name from image file $abs_image_file"
    incus init "$instance_name" --empty --vm
    incus config device override "$instance_name" root size=50GiB
    incus config set "$instance_name" limits.cpu=4 limits.memory=8GiB
    incus config set "$instance_name" security.secureboot=false
    incus config device add "$instance_name" vtpm tpm
    incus config device add "$instance_name" install disk source="$abs_image_file" boot.priority=90
    incus start "$instance_name"


    echo "$instance_name is Starting..."

    incus console --type=vga "$instance_name"

rm-incus:
    #!/usr/bin/env bash
    instance_name="{{ image_name }}"
    echo "Stopping and removing instance $instance_name"
    incus rm --force "$instance_name" || true
