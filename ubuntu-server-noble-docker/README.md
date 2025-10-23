# Instructions for Ubuntu-Server-Noble (24.04) Packer Proxmox Template
This template will create and install a Ubuntu Server 24.04 (Noble) LTS template into your proxmox environment. It installs many popular/common packages through apt, as well as installs docker.

## Set up Packer and template environment
### Run packer init against template file
The ubuntu template includes the packer ```proxmox-iso``` requirement. 

```json
packer {
  required_plugins {
    proxmox-iso = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}
```
To install this plugin, run ```packer init ubuntu-server-noble.pkr.hcl```. This will download and install the Proxmox plugin.

To view the installed plugin information, run ```packer plugins installed```.

To install this plugin, you 
### Install xorriso for cdrom emulation
Run the following to install xorriso, which is needed to emulate a cdrom, and pass the VM cloud-init files.
```bash
apt-get install xorriso -y
```
### Install whois
Install the ```whois``` package, which will be used to hash your labadmin password later.
```bash
apt-get install whois
```
### Generate an SSH key pair to be copied to template
Use ssh-keygen to generate an SSH key pair which Packer will use to SSH to the server.
```bash
ssh-keygen -t ecdsa -f ./files/id_labadmin_ecdsa -N "" -C "packer ecdsa key"
```
### Install whois and use mkpasswd to hash your password
Use mkpassword to hash the password which will be used for the ```labadmin``` user, and copy the hash into ```\cloud-init\user-data```.
```bash
mkpassword --method=SHA-512 'mypasswordhere'
```
### Update contents of user-data cloud-init file with password hash, and add generated SSH public key.
Open ```\cloud-init\user-data``` and update the ```passwd``` and ```ssh_authorized_keys``` attributes of the labadmin user configuration like below.
```yaml
  user-data:
    package_upgrade: false
    timezone: America/New_York
    users:
      - name: labadmin
        groups: [adm, sudo]
        lock-passwd: false
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        # SHA512 hashed password - used mkpadsswd --method=SHA-512 'passwordhere' to generate
        passwd: <<add pass word hash here>>
        ssh_authorized_keys:
          - <<add SSH public key previously generated>>
```
### Update Proxmox variables in proxmox.pkrvars.hcl
Update the contents of proxmox.pkrvars.hcl to include your Proxmox API URL, api token id, and Proxmox node name.
```bash
proxmox_api_url="https://<Proxmox IP or URL>:8006/api2/json"  # Your Proxmox IP Address
proxmox_api_token_id="<<token id>>"
proxmox_node="<<PVE node name>>"
```
### Copy example.secrets.pkrvars.hcl to secrets.pkrvars.hcl and update it's contents
First, copy the example.secrets.pkrvars.hcl to a new file named secrets.pkrvars.hcl. Then, update the file with your Proxmox API Token Secret, the SSH username to use (recommended to leave as labadmin unless you want to change the username elsewhere as well), and give it the relative path (from the directory the packer template resides in) to the SSH private key you generated earlier.
```bash
proxmox_api_token_secret="api_secret"
ssh_username="labadmin"
ssh_priv_key_path="files/id_labadmin_ecdsa.priv"
```
### Update the contents of vm.pkrvars.hcl with VM template specific information
Update the contents of vm.pkrvars.hcl to tweak the VM settings, such as VLAN tagging on network interfaces, iso and disk storage targets, etc.
```bash
vm_id=2000
iso_storage_pool="hdd_storage_4tb"
iso_file="iso/ubuntu-24.04.3-live-server-amd64.iso"
iso_checksum="sha256:C3514BF0056180D09376462A7A1B4F213C1D6E8EA67FAE5C25099C6FD3D8274B"
disk_storage="nvme_flash_2tb"
network_interface_bridge="vmbr1"
network_vlan_id="202"
```

## Building VM template
Run the build.sh script, passing it the packer template file. The build.sh script will run ```packer validate``` first, and exit if any error occurs. If the template validates successfully, it starts the build process.

```bash
./build.sh ./ubuntu-server-noble.pkr.hcl
```
