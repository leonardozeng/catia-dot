# build vfs_catia_dot inside samba source tree

PWD := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
VERSION := $(shell apt-cache policy samba | grep -Po '(?<=: )[^()]+' | head -1 )
SAMBADIR := samba-$(shell echo '$(VERSION)' | grep -Po '(?<=:).+(?=-)' )
DEB_BUILD_ARCH := $(shell dpkg-architecture -qDEB_BUILD_ARCH )
DEB_HOST_MULTIARCH := $(shell dpkg-architecture -qDEB_HOST_MULTIARCH )

all: help

help:
	@echo ""
	@echo "Usage:"
	@echo "  make clean   - cleanup"
	@echo "  make patch   - create vfs_catia_dot.patch"
	@echo "  make source  - download source, apply patches"
	@echo "  make build   - compile binaries"
	@echo "  make rebuild - recompile binaries"
	@echo "  make package - build package using checkinstall"
	@echo ""
	@echo "  Samba version: $(VERSION), $(DEB_BUILD_ARCH)"
	@echo ""

clean:
	rm -rf "$(PWD)/build_dir"
	( cd "$(PWD)" && rm -f vfs_catia_dot.patch vfs-catia-dot_*.deb )

patch:
	( cd "$(PWD)" && git diff `git rev-list --max-parents=0 HEAD` -- vfs_catia.c > "$(PWD)/vfs_catia_dot.patch" )

source: patch
	[ -d "$(PWD)/build_dir" ] || mkdir -m 0755 "$(PWD)/build_dir"
	( cd "$(PWD)/build_dir" && apt-get source samba=$(VERSION) )
	patch -N "$(PWD)/build_dir/$(SAMBADIR)/source3/modules/vfs_catia.c" -i "$(PWD)/vfs_catia_dot.patch" || true
	patch -N "$(PWD)/build_dir/$(SAMBADIR)/debian/rules" -i "$(PWD)/rules.patch" || true

build: source
	( cd "$(PWD)/build_dir/$(SAMBADIR)" && fakeroot ./debian/rules build )

rebuild: source
	( cd "$(PWD)/build_dir/$(SAMBADIR)" && fakeroot ./debian/rules clean ; fakeroot debian/rules build )

package: build
	( cd "$(PWD)" && \
		VER_A=$$(echo '$(VERSION)' | perl -pe 's/^([\d\:]+)\.(\d+)\..*$$/$$1.".".($$2+0).".0"/e') && \
		VER_B=$$(echo '$(VERSION)' | perl -pe 's/^([\d\:]+)\.(\d+)\..*$$/$$1.".".($$2+1).".0"/e') && \
		fakeroot checkinstall -D -y \
			--install=no --fstrans=yes --nodoc --backup=no \
			--requires="samba-libs \(\>= $${VER_A}\), samba-libs \(\<\< $${VER_B}\)" \
			--pkgname=vfs-catia-dot --pkgversion=$(VERSION) --pkgarch=$(DEB_BUILD_ARCH) --pkggroup=net )

install:
	strip "$(PWD)/build_dir/$(SAMBADIR)/bin/default/source3/modules/libvfs_module_catia.so"
	install -d -m 0755 "/usr/lib/$(DEB_HOST_MULTIARCH)/samba/vfs"
	install -m 0644 "$(PWD)/build_dir/$(SAMBADIR)/bin/default/source3/modules/libvfs_module_catia.so" \
		"/usr/lib/$(DEB_HOST_MULTIARCH)/samba/vfs/catia_dot.so"
