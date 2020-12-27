SHELL := /bin/bash

REMOTES := $(shell git remote)
ADDONS := $(shell y2j < .addons.yml | jq -r '.addons | keys[]' | sort | uniq)

CHECKOUT := $(addprefix checkout-, $(ADDONS))
FETCH := $(addprefix fetch-, $(ADDONS))
DOCKER := $(addprefix docker-, $(ADDONS))
UPDATE := $(addprefix update-, $(ADDONS))
DOCS := $(addprefix docs-, $(ADDONS))
CLEAN := $(addprefix clean-, $(ADDONS))

define colorecho
echo -en "\033[$1;3$2m"; echo -n $3; echo -e "\033[0m"
endef

update: $(UPDATE)
$(UPDATE):
	$(MAKE) fetch-$(subst update-,,$@) checkout-$(subst update-,,$@) docs-$(subst update-,,$@) render commit clean-$(subst update-,,$@) || exit 0

commit:
	@if git status --porcelain | grep "^?? " >/dev/null; then \
		echo ; \
		$(call colorecho,1,5, Error: There are unstaged files in the repository); \
		echo -e "\nWhen you have fixed the underlying issues run '$(MAKE) $@'\n"; \
		git status; \
		exit 1;\
	fi
	@if git status --porcelain | grep -v "^[MARCD] " >/dev/null; then \
		echo ; \
		$(call colorecho,1,5, Error: Not all files are stages for committing); \
		echo -e "\nWhen you have fixed the underlying issues run '$(MAKE) $@'\n"; \
		git status; \
		exit 1;\
	fi
	@if [ -f ".git/STAGED_COMMIT_MSG" ]; then \
		git commit -e -F .git/STAGED_COMMIT_MSG; \
		rm -f .git/STAGED_COMMIT_MSG; \
	else \
		git commit; \
	fi;

fetch: $(FETCH)
$(FETCH):
	@KEY=$(subst fetch-,,$@); \
	REMOTES=$(git remote | paste -d: -s); \
	if [[ ":$$REMOTES:" != *":$$KEY:"* ]]; then \
		git remote add $$KEY https://github.com/$$(y2j < .addons.yml | jq -r ".addons.$$KEY.repository").git; \
	fi; \
	git fetch $$KEY;

docker: $(DOCKER)
$(DOCKER):
	@KEY=$(subst docker-,,$@); \
	TARGET=$$(y2j < .addons.yml | jq -r ".addons.$$KEY.target"); \
	REMOTE=$$(git branch -ra | egrep "remotes/$$KEY/" | sed "s@\s*remotes/@@"); \
	CONFIG=$$(git show $$REMOTE:$$TARGET/config.json | jq); \
	IMAGE=$$(echo $$CONFIG | jq -r ".image"); \
	VERSION=$$(echo $$CONFIG | jq -r .version); \
	for arch in $$(echo $$CONFIG | jq -r .arch[]); do \
		IMAGE_ARCH=$$(echo $$IMAGE | sed "s/{arch}/$$arch/"); \
		echo -n "Checking for $$IMAGE_ARCH:$$VERSION on docker hub ..."; \
		IMAGES=$$(curl --silent -f -lSL \
		https://hub.docker.com/v2/repositories/$$IMAGE_ARCH/tags/$$VERSION 2>/dev/null \
		| jq '.images | length'); \
		if [[ "$$IMAGES" -eq "0" ]]; then \
			$(call colorecho,1,5, not found); \
			FAILED=failed; \
		else \
			$(call colorecho,1,2, found); \
		fi; \
		sleep .1; \
	done; \
	if [ -n "$$FAILED" ]; then \
		$(call colorecho,1,5, Error: Some or all dockerimages are missing on docker hub); \
		exit 1; \
	fi;

checkout: $(CHECKOUT)
$(CHECKOUT):
	@KEY=$(subst checkout-,,$@); \
	TARGET=$$(y2j < .addons.yml | jq -r ".addons.$$KEY.target"); \
	REMOTE=$$(git branch -ra | egrep "remotes/$$KEY/" | sed "s@\s*remotes/@@"); \
	if [ \! -d $$KEY ]; then \
		mkdir $$KEY; \
		MESSAGE=":heart_eyes_cat: Added $$KEY"; \
	else \
		CURRENT=$$(jq -r .version < $$KEY/config.json); \
		NEXT=$$(git show $$REMOTE:$$TARGET/config.json | jq -r .version); \
		if vcomp $$CURRENT $$NEXT ; then \
			MESSAGE=":kissing_cat: Updated $$KEY from $$CURRENT to"; \
		else \
			$(call colorecho,1,5, Error: Version conflict on $$KEY "$$CURRENT < $$NEXT"); \
			exit 1; \
		fi; \
	fi; \
	git archive $$REMOTE $$TARGET | tar --strip-components=1 -xvC $$KEY; \
	echo "$$MESSAGE $$(jq -r .version < $$TARGET/config.json)" >> .git/STAGED_COMMIT_MSG; \
	git add -A $$KEY; 

docs: $(DOCS)
$(DOCS):
	@KEY=$(subst docs-,,$@); \
	for tmpl in $$(find $$KEY/ -type f -name '*.j2'); do \
		NAME=$$( echo $$(basename $$tmpl) | sed 's/^\.//;s/\.j2$$//'); \
		DIR=$$(dirname $$tmpl); \
		j2tr $$tmpl $$KEY/config.json > $$DIR/$$NAME || exit 1; \
		git add $$DIR/$$NAME; \
		git rm -f $$tmpl; \
	done;

render:
	@for tmpl in $$(find . -type f -name '*.j2'); do \
		NAME=$$( echo $$(basename $$tmpl) | sed 's/^\.//;s/\.j2$$//'); \
		DIR=$$(dirname $$tmpl); \
		set -x; \
		QUERY="[inputs | {(input_filename | gsub(\"/config.json$$\";\"\")): .}] | add | {addons: .}"; \
		jq -n "$$QUERY" */config.json | j2tr $$tmpl > $$DIR/$$NAME; \
		git add $$DIR/$$NAME; \
	done;

clean: $(CLEAN)
$(CLEAN):
	git remote remove $(subst clean-,,$@)

.PHONY: checkout $(CHECKOUT) clean $(CLEAN) commit docker $(DOCKER) docs $(DOCS) fetch $(FETCH) render update $(UPDATE)
