PROGRAM_NAME := r36s-hardware-test
DEPLOY_PATH := /userdata/roms/native
IP := 192.168.0.107
USN := root
PWD := linux

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

deploy:
	sshpass -p ${PWD} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${USN}@${IP} "/etc/init.d/S31emulationstation stop"
	sshpass -p ${PWD} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${USN}@${IP} "rm ${DEPLOY_PATH}/${PROGRAM_NAME}.exec -f"
	sshpass -p ${PWD} scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null bin/${PROGRAM_NAME}.exec ${USN}@${IP}:${DEPLOY_PATH}
	sshpass -p ${PWD} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${USN}@${IP} "chmod 777 ${DEPLOY_PATH}/${PROGRAM_NAME}.exec"
	sshpass -p ${PWD} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${USN}@${IP} "pkill -f ${PROGRAM_NAME}.exec"
	sshpass -p ${PWD} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${USN}@${IP} "sh -c 'cd /tmp; ${DEPLOY_PATH}/${PROGRAM_NAME}.exec'" &


