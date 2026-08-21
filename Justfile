# vim: set ts=4 sw=4 expandtab :
set shell:= ["bash", "-c"]
set dotenv-load := true

# Version codenames, to be kept up to date with upstream
stable := "trixie"
stable_num := "13"
testing := "forky"
testing_num := "14"

just := just_executable()
podman := require('podman')

image_repo := env("BUILD_IMAGE_REPO", "ghcr.io")
image_org := env("BUILD_IMAGE_ORG", "spamtagger")
image_name := env("BUILD_IMAGE_NAME", "debian-bootc-core")
# Default to current Stable release
debian_ver := env("DEBIAN_VER", "stable")

base_dir := env("BUILD_BASE_DIR", ".")
filesystem := env("BUILD_FILESYSTEM", "ext4")
selinux := path_exists('/sys/fs/selinux')

build_arch := env("BUILD_ARCH", "")
datestamp := env("DATESTAMP", "")

default:
    just --list --unsorted

containerfile $image_name=image_name:
    #!/usr/bin/env bash

    # Transform Kernel arch to Debian arch names
    ARCH="{{ build_arch }}"
    if [[ -z "$ARCH" ]]; then
        [[ "$ARCH" == "aarch64" ]] && ARCH=arm64
        [[ "$ARCH" == "armv7l" ]] && ARCH=armhf
        [[ "$ARCH" == "x86_64" ]] && ARCH=amd64
        [[ "$ARCH" == "ppc64le" ]] && ARCH=ppc64el
    fi

    # Standardize releases to codenames
    DEBIAN_VER={{ debian_ver }}
    [[ "{{ debian_ver }}" == "stable" ]] && DEBIAN_VER="{{ stable }}"
    [[ "{{ debian_ver }}" == "testing" ]] && DEBIAN_VER="{{ testing }}"

    # Preprocess Containerfile.in with codename and arch variables
    flags=(
        "-DDEBIAN_VER_SUB=$DEBIAN_VER"
        "-DARCH_SUB=$ARCH"
    )

    # Compile Bootc for Trixie only
    {{ require('cpp') }} -E -traditional -P Containerfile.in ${flags[@]} > Containerfile


gen-date:
    #!/usr/bin/env bash

    DATE="$(date +%Y%m%d)"

    LIST_TAGS="$(mktemp)"
    while [[ ! -s "$LIST_TAGS" ]]; do
       skopeo list-tags docker://ghcr.io/spamtagger/debian-bootc-core > "$LIST_TAGS"
    done

    if [[ $(cat "$LIST_TAGS" | jq "any(.Tags[]; contains(\"$DEBIAN_VER.$DATE\"))") == "true" ]]; then
       POINT="1"
       while $(cat "$LIST_TAGS" | jq -e "any(.Tags[]; contains(\"$DEBIAN_VER.$DATE.$POINT\"))")
       do
           (( POINT++ ))
       done
    fi
    if [[ -n "${POINT:-}" ]]; then
        DATE="$DATE.$POINT"
    fi
    echo $DATE

gen-tags:
    #!/usr/bin/env bash

    # Transform Kernel arch to Debian arch names
    ARCH="{{ build_arch }}"
    if [[ -z "$ARCH" ]]; then
        [[ "$ARCH" == "aarch64" ]] && ARCH=arm64
        [[ "$ARCH" == "armv7l" ]] && ARCH=armhf
        [[ "$ARCH" == "x86_64" ]] && ARCH=amd64
        [[ "$ARCH" == "ppc64le" ]] && ARCH=ppc64el
    fi

    # Tag with codename and release
    SUFFIX=''
    [[ "{{ build_arch }}" == "" ]] || SUFFIX="-${ARCH}"

    DEBIAN_VER="{{ debian_ver }}"

    SHA_SHORT="$(git rev-parse --short HEAD)"
    DATESTAMP="{{ datestamp }}"
    if [[ -z $DATESTAMP ]]; then
        DATESTAMP=$(just gen-date)
    fi

    VER_NUM={{ stable_num }}
    [[ "$DEBIAN_VER" == "stable" ]] && DEBIAN_VER={{ stable }}
    [[ "$DEBIAN_VER" == "testing" ]] && DEBIAN_VER={{ testing }} && VER_NUM={{ testing_num }}

    TAGS=()
    TAGS+=("${DEBIAN_VER}${SUFFIX}")
    TAGS+=("${DEBIAN_VER}-${SHA_SHORT}${SUFFIX}")
    TAGS+=("${DEBIAN_VER}.${DATESTAMP}${SUFFIX}")
    TAGS+=("${VER_NUM}${SUFFIX}")
    TAGS+=("${VER_NUM}-${SHA_SHORT}${SUFFIX}")
    TAGS+=("${VER_NUM}.${DATESTAMP}${SUFFIX}")
    if [[ "$DEBIAN_VER" == "stable" ]]; then
        TAGS+=("{{ stable }}${SUFFIX}")
        TAGS+=("{{ stable }}-${SHA_SHORT}${SUFFIX}")
        TAGS+=("{{ stable }}.${DATESTAMP}${SUFFIX}")
    fi
    if [[ "$DEBIAN_VER" == "{{ stable }}" ]]; then
        TAGS+=("stable${SUFFIX}")
        TAGS+=("stable-${SHA_SHORT}${SUFFIX}")
        TAGS+=("stable.${DATESTAMP}${SUFFIX}")
    fi
    if [[ "$DEBIAN_VER" == "testing" ]]; then
        TAGS+=("{{ testing }}${SUFFIX}")
        TAGS+=("{{ testing }}-${SHA_SHORT}${SUFFIX}")
        TAGS+=("{{ testing }}.${DATESTAMP}${SUFFIX}")
    fi
    if [[ "$DEBIAN_VER" == "{{ testing }}" ]]; then
        TAGS+=("testing${SUFFIX}")
        TAGS+=("testing-${SHA_SHORT}${SUFFIX}")
        TAGS+=("testing.${DATESTAMP}${SUFFIX}")
    fi
    printf '%s\n' "${TAGS[@]}"

alias build := build-container
build-container $image_name=image_name:
    #!/usr/bin/env bash
    just containerfile

    # OSTree Labels
    VER_NUM={{ stable_num }}
    DEBIAN_VER={{ debian_ver }}
    [[ "$DEBIAN_VER" == "stable" ]] && DEBIAN_VER={{ stable }}
    [[ "$DEBIAN_VER" == "testing" ]] && DEBIAN_VER={{ testing }} && VER_NUM={{ testing_num }}

    # Transform Kernel arch to Debian arch names
    ARCH="{{ build_arch }}"
    if [[ -z "$ARCH" ]]; then
        [[ "$ARCH" == "aarch64" ]] && ARCH=arm64
        [[ "$ARCH" == "armv7l" ]] && ARCH=armhf
        [[ "$ARCH" == "x86_64" ]] && ARCH=amd64
        [[ "$ARCH" == "ppc64le" ]] && ARCH=ppc64el
    fi

    # Tag with codename and release
    SUFFIX=''
    [[ "{{ build_arch }}" == "" ]] && SUFFIX="-${ARCH}"

    LABELS=(
        "--label" "containers.bootc=1"
        "--label" "io.artifacthub.package.deprecated=false"
        "--label" "io.artifacthub.package.keywords=bootc,debian"
        "--label" "io.artifacthub.package.logo-url=https://avatars.githubusercontent.com/u/205223896?s=200&v=4"
        "--label" "io.artifacthub.package.maintainers=[{\"name\": \"JohnMertz\", \"email\": \"git@john.me.tz\"}]"
        "--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/{{ image_org }}/{{ image_name }}/main/README.md"
        "--label" "org.opencontainers.image.created=$(date -u +%Y\-%m\-%d\T%H\:%M\:%S\Z)"
        "--label" "org.opencontainers.image.description=$image_description"
        "--label" "org.opencontainers.image.license=GPLv3"
        "--label" "org.opencontainers.image.source=https://raw.githubusercontent.com/{{ image_org }}/{{ image_name }}/main/Containerfile.in"
        "--label" "org.opencontainers.image.title={{ image_name }}"
        "--label" "org.opencontainers.image.url=https://github.com/{{ image_org }}/{{ image_name }}"
        "--label" "org.opencontainers.image.vendor={{ image_org }}"
        "--label" "org.opencontainers.image.version=${VER_NUM}"
        "--label" "org.opencontainers.image.description=Debian Bootc compatible base image"
        "--label" "io.artifacthub.package.deprecated=false"
        "--label" "io.artifacthub.package.prerelease=true"
    )

    TAGS=()

    while IFS= read -r t; do
        TAGS+=("--tag" "localhost/$image_name:$t")
    done < <(just gen-tags)

    sudo {{ podman }} build \
        "${LABELS[@]}" \
        "${TAGS[@]}" \
        "${BUILD_ARGS[@]}" \
        --format oci \
        --env=ARCH_SUB=$ARCH \
        --env=DEBIAN_VER_SUB=${DEBIAN_VER} \
        -t "{{ image_name }}:${DEBIAN_VER}" \
        .

    rm Containerfile

run-container $image_name=image_name:
    sudo {{ podman }} run --rm -it "{{ image_name }}:{{ debian_ver }}" bash

bootc *ARGS:
    sudo {{ podman }} run \
        --rm --privileged --pid=host \
        -it \
        -v /etc/containers:/etc/containers{{ if selinux == 'true' { ':Z' } else { '' } }} \
        -v /var/lib/containers:/var/lib/containers{{ if selinux == 'true' { ':Z' } else { '' } }} \
        {{ if selinux == 'true' { '-v /sys/fs/selinux:/sys/fs/selinux' } else { '' } }} \
        {{ if selinux == 'true' { '--security-opt label=type:unconfined_t' } else { '' } }} \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{ base_dir }}:/data" \
        "{{ image_name }}:{{ debian_ver }}" bootc {{ ARGS }}

ghcrbootc *ARGS:
    sudo {{ podman }} run \
        --rm --privileged --pid=host \
        -it \
        -v /etc/containers:/etc/containers{{ if selinux == 'true' { ':Z' } else { '' } }} \
        -v /var/lib/containers:/var/lib/containers{{ if selinux == 'true' { ':Z' } else { '' } }} \
        {{ if selinux == 'true' { '-v /sys/fs/selinux:/sys/fs/selinux' } else { '' } }} \
        {{ if selinux == 'true' { '--security-opt label=type:unconfined_t' } else { '' } }} \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{ base_dir }}:/data" \
        "{{ image_repo}}/{{ image_org }}/{{ image_name }}:{{ debian_ver }}" bootc {{ ARGS }}

# accelerate bootc image building with /tmp
setup-bootc-accelerator:
    echo "BUILD_BASE_DIR=/tmp" > .env

generate-bootable-image $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    image_filename={{ image_name }}-{{ debian_ver }}.img
    if [ ! -e "{{ base_dir }}/${image_filename}" ] ; then
        fallocate -l 20G "{{ base_dir }}/${image_filename}"
    fi
    just bootc install to-disk \
        --composefs-backend \
        --via-loopback /data/${image_filename} \
        --filesystem "{{ filesystem }}" \
        --target-imgref {{ image_name }}:{{ debian_ver }} \
        --wipe \
        --bootloader systemd

bootable-image-from-ghcr $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    image_filename={{ image_name }}-{{ debian_ver }}.img
    if [ ! -e "{{ base_dir }}/${image_filename}" ] ; then
        fallocate -l 20G "{{ base_dir }}/${image_filename}"
    fi
    just ghcrbootc install to-disk \
        --composefs-backend \
        --via-loopback /data/${image_filename} \
        --filesystem "{{ filesystem }}" \
        --source-imgref docker://{{ image_repo }}/{{ image_org }}/{{ image_name }}:{{ debian_ver }} \
        --target-imgref {{ image_repo }}/{{ image_org }}/{{ image_name }}:{{ debian_ver }} \
        --wipe \
        --bootloader systemd \
        --karg "debug" \
        --karg "systemd.log_level=debug" \
        --karg "systemd.journald.forward_to_console=1"

# Login to GHCR
[group('CI')]
@login-to-ghcr:
    sudo {{ podman }} login ghcr.io -u "$GITHUB_ACTOR" -p "$GHCR_TOKEN"

# Push Images to Registry
[group('CI')]
push-to-registry $destination="ghcr.io/spamtagger/debian-bootc-core" $transport="docker://":
    #!/usr/bin/bash

    while IFS= read -r t; do
        for i in {1..5}; do
            sudo {{ podman }} push localhost/debian-bootc-core:$t $transport$destination:$t && break || sleep $((5 * i));
            if [[ $i -eq '5' ]]; then
                exit 1
            fi
        done
    done < <(just gen-tags $image_name)

launch-incus:
    #!/usr/bin/env bash
    image_file={{ base_dir }}/{{ image_name }}-{{ debian_ver }}.img

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
