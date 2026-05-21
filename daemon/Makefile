# Build configuration
BINARY_NAME=search-daemon
LIB_NAME=libsearch.a
GO_CMD=go
BUILD_DIR=build

.PHONY: all build clean test lib

all: build lib

build:
	mkdir -p $(BUILD_DIR)
	$(GO_CMD) build -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/daemon

# Target for the Swift bridge (Static Library)
lib:
	mkdir -p $(BUILD_DIR)
	$(GO_CMD) build -buildmode=c-archive -o $(BUILD_DIR)/$(LIB_NAME) ./pkg/bridge

test:
	$(GO_CMD) test -v ./...

clean:
	rm -rf $(BUILD_DIR)
	rm -f search-daemon/pkg/bridge/*.h
