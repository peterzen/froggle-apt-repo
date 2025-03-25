# Define variables
PACKAGE_NAME = froggle-certs
DEB_DIR = src/$(PACKAGE_NAME)
BUILD_DIR = build
DEB_FILE = $(BUILD_DIR)/$(PACKAGE_NAME).deb
DISTRIBUTION = bookworm
DIST_ROOT = dists/$(DISTRIBUTION)

# Default target
all: build

# Build the .deb package
build:
	rm -rf $(BUILD_DIR)
	mkdir $(BUILD_DIR)
	dpkg-deb --build $(DEB_DIR) $(DEB_FILE)

# Add the package to the repository using reprepro
preprepo:
	reprepro -V \
		--section utils \
		--component main \
		--priority 0 \
		includedeb $(DISTRIBUTION) $(DEB_FILE)

sign:
	gpg --default-key 8A2F51D138155F46 \
	--output $(DIST_ROOT)/InRelease \
	--clearsign $(DIST_ROOT)/Release

all: build preprepo sign clean

# Clean up (optional)
clean:
	rm -rf $(DEB_FILE) 
