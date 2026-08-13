BINARY_NAME := network-tools-tests-ext

BUILD_DIR := bin

.PHONY: all
all: build

.PHONY: build
build:
	@echo "Building $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	cd cmd && go build -o ../$(BUILD_DIR)/$(BINARY_NAME) .

.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
