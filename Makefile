GOMOD ?= on
GO ?= GO111MODULE=$(GOMOD) go

#Don't enable mod=vendor when GOMOD is off or else go build/install will fail
GOMODFLAG ?=-mod=vendor
ifeq ($(GOMOD), off)
GOMODFLAG=
endif

GOFMT ?= gofmt
TERRAFORM ?= $(shell which terraform 2>/dev/null || which true 2>/dev/null)
GO_MD2MAN ?= go-md2man
LN = ln
RM = rm

GOBINPATH    := $(shell $(GO) env GOPATH)/bin
VERSION      := $(shell cat VERSION)
COMMIT       := $(shell git rev-parse --short HEAD 2>/dev/null)
BUILD_DATE   := $(shell date +%Y%m%d)
TAGS         := development
SKUBA_LDFLAGS = -ldflags "-X=github.com/SUSE/skuba/internal/app/skuba.Version=$(VERSION) \
                          -X=github.com/SUSE/skuba/internal/app/skuba.Commit=$(COMMIT) \
                          -X=github.com/SUSE/skuba/internal/app/skuba.BuildDate=$(BUILD_DATE)"

SKUBA_DIRS    = cmd pkg internal test

# go source files, ignore vendor directory
SKUBA_SRCS = $(shell find $(SKUBA_DIRS) -type f -name '*.go')

.PHONY: all
all: install

.PHONY: build
build:
	$(GO) build $(GOMODFLAG) $(SKUBA_LDFLAGS) -tags $(TAGS) ./cmd/...

MANPAGES_MD := $(wildcard docs/man/*.md)
MANPAGES    := $(MANPAGES_MD:%.md=%)

docs/man/%.1: docs/man/%.1.md
	$(GO_MD2MAN) -in $< -out $@

.PHONY: docs
docs: $(MANPAGES)

.PHONY: install
install:
	$(GO) install $(GOMODFLAG) $(SKUBA_LDFLAGS) -tags $(TAGS) ./cmd/...
	$(RM) -f $(GOBINPATH)/kubectl-caasp
	$(LN) -s $(GOBINPATH)/skuba $(GOBINPATH)/kubectl-caasp

.PHONY: clean
clean:
	$(GO) clean -i
	$(RM) -f ./skuba

.PHONY: distclean
distclean: clean
	$(GO) clean -i -cache -testcache -modcache

.PHONY: staging
staging:
	make TAGS=staging install

.PHONY: release
release:
	make TAGS=release install

.PHONY: lint
lint:
	$(GO) vet ./...
	test -z `$(GOFMT) -l $(SKUBA_SRCS)` || { $(GOFMT) -d $(SKUBA_SRCS) && false; }
	$(TERRAFORM) fmt -check=true -write=false -diff=true ci/infra
	find ci -type f -name "*.sh" | xargs bashate

.PHONY: suse-package
suse-package:
	ci/packaging/suse/rpmfiles_maker.sh $(VERSION)

.PHONY: suse-changelog
suse-changelog:
	ci/packaging/suse/changelog_maker.sh "$(CHANGES)"

# tests
.PHONY: test-e2e
test-e2e:
	./ci/tasks/e2e-tests.py

# this target are called from skuba dir mainly not from CI dir
# build ginkgo executables from vendor (used in CI)
.PHONY: build-ginkgo
build-ginkgo:
	$(GO) build -o ginkgo ./vendor/github.com/onsi/ginkgo/ginkgo

.PHONY: setup-ssh
setup-ssh:
	./ci/tasks/setup-ssh.py
