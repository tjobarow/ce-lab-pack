ISO_NAME = win-files.iso
PVE_HOST = root@proxmox.kewar.org
PACKER_FILE = windows-2022.pkr.hcl

all: build

$(ISO_NAME): autounattend.xml scripts/*
	@echo "📦 Building $(ISO_NAME)..."
	hdiutil makehybrid -o $(ISO_NAME) autounattend.xml scripts/ -iso -joliet

upload: $(ISO_NAME)
	@echo "🚀 Uploading $(ISO_NAME) to Proxmox..."
	scp $(ISO_NAME) $(PVE_HOST):/var/lib/vz/template/iso/

build: upload
	@echo "⚙️ Running packer build..."
	packer init $(PACKER_FILE)
	packer validate $(PACKER_FILE)
	packer build $(PACKER_FILE)

clean:
	rm -f $(ISO_NAME)

