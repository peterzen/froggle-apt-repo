# Define variables
PACKAGE_NAME = froggle-certs
DEB_DIR = src/$(PACKAGE_NAME)
DEB_FILE = incoming/$(PACKAGE_NAME).deb
DISTRIBUTION = bookworm

# Default target
all: build

# Build the .deb package
build:
	dpkg-deb --build $(DEB_DIR) $(DEB_FILE)

# Add the package to the repository using reprepro
preprepo:
	reprepro -V \
		--section utils \
		--component main \
		--priority 0 \
		includedeb $(DISTRIBUTION) $(DEB_FILE)

all: build preprepo

# Clean up (optional)
clean:
	rm -rf $(DEB_FILE)
