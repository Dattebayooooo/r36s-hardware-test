PROGRAM_NAME := r36s-hardware-test
DEPLOY_PATH ?= /userdata/roms/native
IP ?= 192.168.0.110
USN ?= ark
PWD ?= ark


# ==============================
# ⏱️ Log Helpers
# ==============================
define log_step
	@echo "👉 $(1)"
	@sleep 1
endef

define log_success
	@echo "✅ $(1)"
endef

define log_error
	@echo "❌ $(1)"
endef

# ==============================
# 🛑 Command Runner
# ==============================
define run_cmd
	@bash -c 'set -e; \
	echo "▶ Running: $(1)"; \
	$(1) || { echo "❌ Failed: $(1)"; exit 1; }'
endef


all: clean docker deploy

# ==============================
# 🧹 Clean
# ==============================
clean:
	$(call log_step,🧹 Cleaning up binaries...)
	$(call run_cmd,rm -f "$(PROGRAM_NAME).exec" "bin/$(PROGRAM_NAME).exec")
	$(call log_success,Cleanup complete!)


docker:
	#docker run -d --name arkos-sdk -c 1024 -it --volume=/home/vitaly/GolandProjects/:/work/ --workdir=/work/ arkos-sdk
	docker exec arkos-sdk /bin/bash -c 'cd ${PROGRAM_NAME} && make build'

build:
	go build -o bin/${PROGRAM_NAME}.exec ${PROGRAM_NAME}/src/

# ==============================
# 🍎 macOS Setup
# ==============================
mac-setup:
	$(call log_step,🍎 Installing SDL dependencies via Homebrew...)
	$(call run_cmd,brew install sdl2 sdl2_image)
	$(call log_step,⚙️ Setting environment variables...)
	@echo 'export CGO_CFLAGS="-I/opt/homebrew/include"' >> ~/.zshrc
	@echo 'export CGO_LDFLAGS="-L/opt/homebrew/lib"' >> ~/.zshrc
	@echo 'export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig"' >> ~/.zshrc
	$(call log_success,Setup complete! Run: source ~/.zshrc)

# ==============================
# 🍎 macOS Build
# ==============================
mac-build:
	$(call log_step,🍎 Building $(PROGRAM_NAME) natively on macOS...)
	$(call run_cmd,export CGO_CFLAGS="-I/opt/homebrew/include" && \
	export CGO_LDFLAGS="-L/opt/homebrew/lib" && \
	export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig" && \
	go build -v -o $(PROGRAM_NAME) ./src)
	$(call log_success,macOS build successful! Binary: $(PROGRAM_NAME))

# ==============================
# 🐧 Linux Setup & Build
# ==============================
linux-setup:
	$(call log_step,🐧 Installing SDL dependencies via apt...)
	$(call run_cmd,sudo apt-get update && sudo apt-get install -y libsdl2-dev libsdl2-image-dev build-essential)
	$(call log_success,Setup complete!)

linux-build:
	$(call log_step,🐧 Building $(PROGRAM_NAME) natively on Linux...)
	$(call run_cmd,go build -v -o $(PROGRAM_NAME) ./src)
	$(call log_success,Linux build successful! Binary: $(PROGRAM_NAME))

# ==============================
# 🚀 Deploy to Device
# ==============================
deploy:
	@if [ -z "$(IP)" ] || [ -z "$(USN)" ] || [ -z "$(PWD)" ]; then \
		echo "❌ Missing required variables. Usage:"; \
		echo "make deploy IP=<ip> USN=<username> PWD=<password>"; \
		exit 1; \
	fi

	$(call log_step,🚀 Deploying $(PROGRAM_NAME) to $(USN)@$(IP)...)

	$(call run_cmd,ssh -p $(PWD) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $(USN)@$(IP) "/etc/init.d/S31emulationstation stop")

	$(call run_cmd,ssh -p $(PWD) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $(USN)@$(IP) "rm -f $(DEPLOY_PATH)/$(PROGRAM_NAME).exec")

	$(call run_cmd,ssh -p $(PWD) scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null bin/$(PROGRAM_NAME).exec $(USN)@$(IP):$(DEPLOY_PATH))

	$(call run_cmd,ssh -p $(PWD) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $(USN)@$(IP) "chmod +x $(DEPLOY_PATH)/$(PROGRAM_NAME).exec")

	$(call run_cmd,ssh -p $(PWD) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $(USN)@$(IP) "pkill -f $(PROGRAM_NAME).exec || true")

	$(call run_cmd,ssh -p $(PWD) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $(USN)@$(IP) "sh -c 'cd /tmp; $(DEPLOY_PATH)/$(PROGRAM_NAME).exec'" &)

	$(call log_success,Deployment complete!)

# ==============================
# 📖 Help
# ==============================
help:
	@echo "📖 Available commands:"
	@echo "  make mac-setup     🍎 Install SDL + setup env (one-time)"
	@echo "  make mac-build     🍎 Build natively on macOS"
	@echo "  make linux-setup   🐧 Install SDL dependencies on Linux (one-time)"
	@echo "  make linux-build   🐧 Build natively on Linux"
	@echo "  make deploy        🚀 Deploy binary to device"
	@echo "  make clean         🧹 Remove generated binaries"
	@echo "  make help          📖 Show this help message"

