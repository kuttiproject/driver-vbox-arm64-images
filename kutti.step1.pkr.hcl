packer {
    required_plugins {
        virtualbox = {
          version = "~> 1"
          source  = "github.com/hashicorp/virtualbox"
        }
    }
}

variable "iso-url" {
  # Location of the base debian netinst iso
  type    = string
  default = "./iso/debian-12.10.0-arm64-netinst.iso"
}

variable "iso-checksum" {
  # Checksum of the base debian netinst iso
  type    = string
  default = "sha256:94d3460a0ea9b43f538af7edfe1c882d5b6ecd1837f3f560379b148d36f59d19"
}

source "virtualbox-iso" "kutti-base" {
  # Before using this script, you need to obtain a debian
  # netinst ISO, and put it in a folder called "iso".
  # The iso name and its checksum should be updated here.
  # The last build used debian 10.6.0.
  iso_url      = "${var.iso-url}"
  iso_checksum = "${var.iso-checksum}"

  # Create a VM with 
  #  - 2 cpu cores
  #  - 2 GiB RAM
  #  - 100 GiB hard disk
  cpus      = "2"
  memory    = "2048"
  disk_size = "102400"

  # Optimize for 64-bit arm64 Debian Linux
  guest_os_type = "Debian12_Arm64"
  
  # Needs vmsvga adapter
  gfx_controller = "vmsvga"
  gfx_vram_size  = "128"

  # HDD and iso interfaces need to be virtio
  hard_drive_interface = "virtio"
  iso_interface = "virtio"

  # Guest additions will be built in the next step
  guest_additions_mode = "disable"

  # HTTP serve the preseed file
  http_directory = "buildhttp"

  # Ensure that MAC addresses are stripped at export
  export_opts = [
    "--manifest",
    "--options", "nomacs"
  ]
  format = "ova"

  # Set up a boot command for the Debian Netinst CD.
  # This assumes boot into GRUB, where it chooses
  # `A` for Advanced options, then `A` for Automated
  # setup, then waits a while before typing the url
  # for the preseed file and pressing enter. 
  # Also see the commented preseed file to see what 
  # exactly gets installed and configured.
  boot_wait = "15s"
  boot_command = [
    "<wait>",
    "a<wait>a",
    "<wait><wait><wait><wait><wait><wait><wait><wait><wait><wait><wait><wait>",
    "<wait><wait><wait><wait><wait><wait><wait><wait><wait><wait><wait><wait>",
    "http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed_bookworm.cfg <wait>",
    "<enter><wait>"
  ]

  # Below is the boot command used in non-EFI systems.
  # There, it presses Escape to get to a boot command
  # line, where it can type the install command.
  # Important aspects are:
  #   - DEBIAN_FRONTEND and priority ensure no chatter
  #   - fb ensures no framebuffer, which we don't need
  #   - auto specifies a preseeded installation
  #   - url specifies the location of the preseed file
  #   - domain and hostname must be specified here,
  #     because an automatic installation sets up the
  #     network first, and needs these parameters to 
  #     be set in the boot command.
  # boot_command = [
  #   "<esc><wait>",
  #   "install <wait>",
  #   "DEBIAN_FRONTEND=noninteractive <wait>",
  #   "priority=critical <wait>",
  #   "fb=false <wait>",
  #   "auto=true <wait>",
  #   "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed_buster.cfg <wait>",
  #   "domain=kuttiproject.org <wait>",
  #   "hostname=kutti <wait>",
  #   "<enter><wait>"
  # ]

  # Although this step needs no ssh, these settings must be
  # specified.
  ssh_username = "kuttiadmin"
  ssh_password = "Pass@word1"
  ssh_timeout  = "20m"

  shutdown_command = "sudo poweroff"

  # VirtualBox 7 requires this additional setting for accessing
  # the preseed file over http.
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--nat-localhostreachable1", "on"],
    [ "modifyvm", "{{.Name}}", "--usbxhci", "on" ],
  ]

  # The output file should be called kutti-base.ova
  vm_name = "kutti-base"
}

build {
  sources = [
    "sources.virtualbox-iso.kutti-base"
  ]
}