#!/bin/bash
# Check if argument is provided
if [[ -z "${1:-}" ]]; then
  echo "Error: Path to Packer template not provided as first argument" >&2
  exit 1
fi

# Make sure the file exists
if [[ ! -e "${1:-}" ]]; then
  echo "Error: Template not found at $1" >&2
  exit 1
fi

TEMPLATE_PATH=$1

echo "Starting Packer build process against template $1"
if packer validate \
    -var-file=secrets.pkrvars.hcl \
    -var-file=vm_config.pkrvars.hcl \
    -var-file=proxmox.pkrvars.hcl \
    $TEMPLATE_PATH; then
    echo "Packer validation succeeded"
else
    echo "Packer validation failed" >&2
    exit 1
fi

if packer build \
    -var-file=secrets.pkrvars.hcl \
    -var-file=vm_config.pkrvars.hcl \
    -var-file=proxmox.pkrvars.hcl \
    $TEMPLATE_PATH; then
    echo "Packer proxmox succeeded"
else
    echo "Packer validation failed" >&2
    exit 1
fi