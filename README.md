# <img src="https://raw.githubusercontent.com/SpamTagger/debian-bootc-core/refs/heads/main/debian-bootc-core.svg" alt="debian-bootc-core Logo" style="height:2em; vertical-align:middle;">debian-bootc-core

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/debian-bootc-core)](https://artifacthub.io/packages/search?repo=debian-bootc-core)

## 🐧 What is debian-bootc-core 🐧

This project builds a BootC-compatible OCI container image from the latest official `<version>-slim` Debian image, then installs and configures the minimum necessary to get BootC on top.

## ✨ Features ✨

* Builds for the current Stable and Testing release (default: `DEBIAN_VER=stable just build`)
* Builds raw disk from local image (`just generate-bootable-image`) or official image (`just bootable-image-from-ghcr`)
* GitHub actions to automatically build and upload to GHCR (`just login-to-ghcr; just push-to-registry`)
* Simple Incus launch (`just launch-incus`)
* Remains as minimal as possible, however this still grows the ~80MB slim image to ~1.5GB

## 🤔 Why Does This Exist 🤔

BootC provides a retatively new and exciting way to build a predicatable, secure OS images with atomic updates and rollbacks. So far, most of that work has been done in the Fedora/CentOS world. The SpamTagger organization is reviving the MailCleaner project which has always been a Debian-based project.

We are maintaining the tools to build this generic image as a minimal container to base our appliance images on. Splitting it to a seperate project allows for reusability, and a easier segregation of issues to make it easier to diagnose potential problems in the future.

## 🧭 Getting Started 🧭

The `debian-bootc-core` images provided by this repo are not intended to be used directly. This is for a few reasons:

* There is no `root` password set, meaning that it would require significant knowledge to mount the image and create a password.
* There is almost nothing pre-installed. It does not provide any sandbox userspace utilities which are typically used to make immutable images functional (ie. `flatpak`, `snapd`, or `homebrew`).
* No additional firmware is provided except those provided by the kernel, so it will not support most hardware.

The purpose of this image is to consume it as a starting point for another BootC image, so that you don't need to worry about duplicating effort to get BootC working with Debian.
