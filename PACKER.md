# Packer Build Instructions

The images for this repository can be built using HashiCorp [Packer](https://www.packer.io/).

The build is done in two steps. The first step builds a base operating system image. The
second step can be run multiple times to generate images for different versions of Kubernetes.

## Build Prerequisites

1. Oracle VirtualBox, version 6.0 or above. The `VBoxManage` tool must be on the path.
2. HashiCorp Packer, version 1.7.2 or above. NOTE: 1.8.0 has a problem with OVA files.
3. A Debian netinst ISO image. This has to be downloaded into a folder called ISO in this directory, and its name and checksum updated in the `kutti.step1.pkr.hcl` file.

## Build Instructions

1. Create a folder called "iso" in the current directory.
2. Download a Debian netinst ISO file into this directory.
3. Obtain the path and SHA256 checksum of this file.
4. Run `packer build -var iso-url=PATH iso-checksum=CHECKSUM kutti.step1.pkr.hcl` to generate an OVA for a bare OS image.
5. Run `packer build -var "kube-version=DESIREDVERSION" kutti.step2.pkr.hcl`. Here, DESIREDVERSION is the kubernetes version, as it is published in the google debian repository for Kubernetes.

## Details

### Step 1

The first step is the script `kutti.step1.pkr.hcl`, which builds an OVA file from a Debian netinst CD ISO image. It uses a preseed file to configure the installation. Some important settings are as follows:

* US keyboard layout and language is US
* Locale and timezone are India
* The root password is "Pass@word1"
* A user called "kuttiadmin" is created with the password "Pass@word1"
* The entire hard disk is made into a single data partition, _no swap_.
* `sudo` and `openssh` are installed.
* The kuttiadmin user is given sudo rights without a password.

### Step 2

The second step is the script `kutti.step.pkr.hcl`. This starts from a VM created from the output of the previous step, and does the following:

* Builds VirtualBox Guest Additions
* Configures GRUB for:
  * zero wait at boot
  * use of fixed network interface names like eth0
* Adds a user called `user1` with sudo access.
* Adds driver interface scripts to the image
* Installs and configures `containerd` from the Docker debian repositories
* Installs kubernetes. The version is controlled by a variable called KUBE_VERSION
* Uninstalls unneeded software installed during the build process
* Writes a huge file filled with zeroes to fill the virtual HDD, and deletes it
* Compacts the virtual hard disk
* Adds an icon
* Exports to the final OVA.

## Makefile

The steps described above can also be performed via a supplied makefile and GNU make.
`make step1` and `make step2` can be used.

## Publishing a release

Collect the .ova files for the supported versions, and create a `driver-vbox-images.json` file describing them. Then publish a GitHub release, and upload the `driver-vbox-images.json` file and the .ova files to it. Details can be found in [RELEASE.md](RELEASE.md).
