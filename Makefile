XML_FILE ?= delete.xml

DOCNAME_FULL := $(shell xmllint --xpath "string(//rfc/@docName)" $(XML_FILE) 2>/dev/null)
DOCNAME_BASE := $(shell echo $(DOCNAME_FULL) | sed -E 's/-[0-9]+$$//')
VERSION := $(shell echo $(DOCNAME_FULL) | sed -E 's/.*-([0-9]{2})$$/\1/')
VERSION_NOZERO := $(shell echo "$(VERSION)" | sed -e 's/^0*//')
NEXT_VERSION :=  $(shell printf "%02d" "$$(($(VERSION_NOZERO) + 1))")

NEW_FILE := draft/$(DOCNAME_FULL)
PBASE := published/$(DOCNAME_FULL)
LBSE := draft/$(DOCNAME_BASE)-latest

MAIN_BRANCH ?= main

BRANCH_EXISTS := $(shell git rev-parse --verify $(MAIN_BRANCH) 2>/dev/null)

ifeq ($(DOCNAME_FULL),)
DOC_OUT := $(shell xmllint --xpath "string(//rfc/@docName)" $(XML_FILE) 2>&1)
$(error Failed to extract docName from $(XML_FILE) using xmllint. $(DOC_OUT))
endif

all: $(NEW_FILE).xml $(NEW_FILE).txt $(NEW_FILE).html

lint:
	@xmllint --format $(NEW_FILE).xml

rfcdiff:
	@rfcdiff --body --diff $(OLD_FILE).txt $(NEW_FILE).txt

.PHONY: all lint rfcdiff

$(NEW_FILE).html: $(XML_FILE)
	xml2rfc --cache /tmp --html $(NEW_FILE).xml
	cp $@ $(LBSE).html

$(NEW_FILE).txt: $(XML_FILE)
	xml2rfc --cache /tmp --text $(NEW_FILE).xml
	cp $@ $(LBSE).txt

$(NEW_FILE).xml: $(XML_FILE)
	mkdir -p draft
	cp $(XML_FILE) $@
	cp $@ $(LBSE).xml

.PHONY: git-clean-check
git-clean-check:
	@echo Checking for git clean status
	@STATUS="$$(git status -s)"; [[ -z "$$STATUS" ]] || echo "$$STATUS"

.PHONY: main-branch-check
main-branch-check:
ifeq ($(BRANCH_EXISTS),)
	$(error Branch '$(MAIN_BRANCH)' does not exist. Exiting.)
endif

.PHONY: publish
publish: main-branch-check git-clean-check $(NEW_FILE).xml $(NEW_FILE).html $(NEW_FILE).txt
	@mkdir -p published
	git tag -m "publish $(NEW_FILE)" bp-$(DOCNAME_FULL)
	cp $(NEW_FILE).xml $(NEW_FILE).html $(NEW_FILE).txt published/
	git add $(PBASE).xml $(PBASE).txt $(PBASE).html
	git commit -m "publish $(PBASE)"
	git tag -m "published $(NEW_FILE)" published-$(DOCNAME_FULL)
	sed -i -e 's/\(docName=\".*-\)\([0-9][0-9]\)/\1$(NEXT_VERSION)/' $(XML_FILE)
	git commit -m "new version -$(NEXT_VERSION)" $(XML_FILE)

debug:
	@echo "DOCNAME_FULL = [$(DOCNAME_FULL)]"
	@echo "DOCNAME_BASE = [$(DOCNAME_BASE)]"
	@echo "VERSION = [$(VERSION)]"
	@echo "NEW_FILE = [$(NEW_FILE)]"
