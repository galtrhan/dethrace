# Dethrace convenience Makefile
# Wraps CMake. There is no hand-written compile graph here.
#
# Usage:
#   make            # show help
#   make build      # configure (if needed) and compile
#   make install    # copy binary to PREFIX/bin (default: ~/.local/bin)
#   make uninstall  # remove installed binary

.DEFAULT_GOAL := help

# Build tree
BUILD_DIR   ?= build
BUILD_TYPE  ?= Debug
GENERATOR   ?= Ninja
JOBS        ?= $(shell nproc 2>/dev/null || echo 4)

# Install location (matches Carmageddon.desktop -> ~/.local/bin/dethrace)
PREFIX      ?= $(HOME)/.local
BINDIR      ?= $(PREFIX)/bin
BINARY_NAME ?= dethrace

BUILD_BIN   := $(BUILD_DIR)/$(BINARY_NAME)
INSTALL_BIN := $(BINDIR)/$(BINARY_NAME)

CMAKE_FLAGS ?= -DCMAKE_BUILD_TYPE=$(BUILD_TYPE)

.PHONY: help configure build rebuild clean distclean install uninstall run status

help:
	@echo "Dethrace build targets"
	@echo ""
	@echo "  make configure   Create/update $(BUILD_DIR)/ with CMake ($(GENERATOR))"
	@echo "  make build       Configure if needed, then compile"
	@echo "  make rebuild     Wipe $(BUILD_DIR)/, configure, compile"
	@echo "  make clean       Remove object files (keep CMake cache)"
	@echo "  make distclean   Delete $(BUILD_DIR)/ entirely"
	@echo "  make install     Install $(BINARY_NAME) to $(INSTALL_BIN)"
	@echo "  make uninstall   Remove $(INSTALL_BIN)"
	@echo "  make run         Run $(BUILD_BIN)"
	@echo "  make status      Show build and install paths"
	@echo ""
	@echo "Variables (override on the command line):"
	@echo "  BUILD_DIR=$(BUILD_DIR)  BUILD_TYPE=$(BUILD_TYPE)  GENERATOR=$(GENERATOR)"
	@echo "  PREFIX=$(PREFIX)  BINDIR=$(BINDIR)  JOBS=$(JOBS)"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make install"
	@echo "  make BUILD_TYPE=Release rebuild install"

configure: $(BUILD_DIR)/CMakeCache.txt

$(BUILD_DIR)/CMakeCache.txt:
	@mkdir -p $(BUILD_DIR)
	cmake -S . -B $(BUILD_DIR) -G "$(GENERATOR)" $(CMAKE_FLAGS)

build: $(BUILD_DIR)/CMakeCache.txt
	cmake --build $(BUILD_DIR) -j$(JOBS)

rebuild: distclean build

clean:
	@if [ -d $(BUILD_DIR) ]; then cmake --build $(BUILD_DIR) --target clean; else echo "No $(BUILD_DIR)/ yet."; fi

distclean:
	rm -rf $(BUILD_DIR)

install: build
	@mkdir -p "$(BINDIR)"
	install -m 755 "$(BUILD_BIN)" "$(INSTALL_BIN)"
	@echo "Installed $(INSTALL_BIN)"
	@echo "Desktop entry: ~/.local/share/applications/Carmageddon.desktop"

uninstall:
	@if [ -e "$(INSTALL_BIN)" ] || [ -L "$(INSTALL_BIN)" ]; then \
		rm -f "$(INSTALL_BIN)"; \
		echo "Removed $(INSTALL_BIN)"; \
	else \
		echo "Nothing to remove at $(INSTALL_BIN)"; \
	fi

run: build
	"$(BUILD_BIN)"

status:
	@echo "Source:      $(CURDIR)"
	@echo "Build dir:   $(CURDIR)/$(BUILD_DIR)"
	@echo "Build type:  $(BUILD_TYPE)"
	@echo "Generator:   $(GENERATOR)"
	@echo "Build bin:   $(BUILD_BIN)$$([ -x $(BUILD_BIN) ] && echo ' (exists)' || echo ' (missing)')"
	@echo "Install bin: $(INSTALL_BIN)$$([ -e $(INSTALL_BIN) ] && echo ' (exists)' || echo ' (missing)')"
	@echo "Desktop:     $(HOME)/.local/share/applications/Carmageddon.desktop"
	@if [ -e "$(INSTALL_BIN)" ]; then echo "Resolved:    $$(readlink -f "$(INSTALL_BIN)")"; fi
