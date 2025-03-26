# Define variables
PACKAGE_NAME = froggle-certs
DEB_DIR = src/$(PACKAGE_NAME)
BUILD_DIR = build
DEB_FILE = $(BUILD_DIR)/$(PACKAGE_NAME).deb
DISTRIBUTION = bookworm
DIST_ROOT = dists/$(DISTRIBUTION)

# Default target
.PHONY: all build preprepo sign clean

all: build preprepo sign clean

# Build the .deb package (only if source changed)
$(DEB_FILE): $(DEB_DIR)/*
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	dpkg-deb --build $(DEB_DIR) $(DEB_FILE)

build: $(DEB_FILE)

# Add the package to the repository
preprepo:
	reprepro remove $(DISTRIBUTION) $(PACKAGE_NAME)
	reprepro -V \
		--section utils \
		--component main \
		--priority optional \
		includedeb $(DISTRIBUTION) $(DEB_FILE)

# Sign the Release file
sign:
	gpg --default-key 8A2F51D138155F46 \
		--output $(DIST_ROOT)/InRelease \
		--clearsign $(DIST_ROOT)/Release

deploy:
	rsync -ravP --delete $(DIST_ROOT) $(STORAGE_ROOT)
# Clean up
clean:
	rm -rf $(BUILD_DIR)
