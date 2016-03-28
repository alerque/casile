BASE := $(shell cd "$(shell dirname $(lastword $(MAKEFILE_LIST)))/../" && pwd)
TOOLS := $(shell cd "$(shell dirname $(lastword $(MAKEFILE_LIST)))/" && pwd)
PROJECT != basename $(BASE)
OUTPUT = ${HOME}/ownCloud/viachristus/$(PROJECT)
SHELL = bash
OWNCLOUD = https://owncloud.alerque.com/remote.php/webdav/viachristus/$(PROJECT)
SOURCES := $(wildcard *.md)
TARGETS := ${SOURCES:.md=}
FORMATS ?= pdf epub mobi
LAYOUTS ?= a4 a5trim octavo halfletter cep
PRINTS ?=
#PRINTS ?= kesme kesme-ciftyonlu
DRAFT ?= false
STATS_MONTHS ?= 2
BRANCH = $(shell git rev-parse --abbrev-ref HEAD)

ifneq ($(BRANCH),master)
OUTPUT = ${HOME}/ownCloud/viachristus/$(PROJECT)/$(BRANCH)
OWNCLOUD = https://owncloud.alerque.com/remote.php/webdav/viachristus/$(PROJECT)/$(BRANCH)
endif

export TEXMFHOME := $(TOOLS)/texmf
export PATH := $(TOOLS)/bin:$(PATH)

.ONESHELL:
.SECONDEXPANSION:
.PHONY: all ci clean init sync_pre sync_post $(TARGETS)
.SECONDARY:
.PRECIOUS: %.pdf %.sil

all: $(TARGETS)

ci: init clean sync_pre all sync_post stats

clean:
	git clean -xf

$(TARGETS): $(foreach FORMAT,$(FORMATS),$$@.$(FORMAT))

init:
	mkdir -p $(OUTPUT)

define sync_owncloud
	-pgrep -u $(USER) -x owncloud || \
		owncloudcmd -n -s $(OUTPUT) $(OWNCLOUD) 2>/dev/null
endef

sync_pre:
	$(call sync_owncloud)
	-rsync -ctv \
		$(foreach FORMAT,$(FORMATS),$(OUTPUT)/*.$(FORMAT)) $(BASE)/

sync_post:
	-rsync -ctv \
		$(foreach FORMAT,$(FORMATS),*.$(FORMAT)) $(OUTPUT)/
	$(call sync_owncloud)

%.pdf: $(foreach LAYOUT,$(LAYOUTS),$$*-$(LAYOUT).pdf) $(foreach LAYOUT,$(LAYOUTS),$(foreach PRINT,$(PRINTS),$$*-$(LAYOUT)-$(PRINT).pdf)) ;

%.pdf: %.sil $(TOOLS)/viachristus.lua
	@$(shell test -f "$<" || echo exit 0)
	# Once for TOC, again for real page numbers, again again for final
	if $(DRAFT); then \
		sile $< -o $@ ;\
	else \
		sile $< -o $@ && sile $< -o $@ && sile $< -o $@ ;\
	fi

%-kesme.pdf: %.pdf
	@if [ ! "" = "$(findstring octavo,$@)$(findstring halfletter,$@)" ]; then\
		export PAPER_OPTS="paperwidth=210mm,paperheight=297mm" ;\
	elif [ ! "" = "$(findstring a5trim,$@)" ]; then\
		export PAPER_OPTS="paperheight=210mm,paperwidth=148.5mm,layoutheight=195mm,layoutwidth=135mm,layouthoffset=7.5mm,layoutvoffset=6.75mm" ;\
	elif [ ! "" = "$(findstring cep,$@)" ]; then\
		export PAPER_OPTS="paperheight=210mm,paperwidth=148.5mm,layoutheight=170mm,layoutwidth=115mm,layouthoffset=16.5mm,layoutvoffset=20mm" ;\
	else \
		exit 0 ;\
	fi
	-xelatex -jobname=$(basename $@) -interaction=batchmode \
		"\documentclass{scrbook}\usepackage[$$PAPER_OPTS,showcrop]{geometry}\usepackage{pdfpages}\begin{document}\includepdf[pages=-,noautoscale,fitpaper=false]{$<}\end{document}"

%-ciftyonlu.pdf: %.pdf
	-pdfbook --short-edge --suffix ciftyonlu --noautoscale true -- $<

define build_sile
	pandoc --standalone \
		-V documentclass="book" \
		-V papersize="$4" \
		-V script=$(TOOLS)/layout-$3 \
		$(shell test -f "$(basename $1).lua" && echo "-V script=$(basename $1)") \
		-V script=$(TOOLS)/viachristus \
		--template=$(TOOLS)/template.sil \
		$(shell test -f "$(basename $1).yml" && echo "$(basename $1).yml") \
		$1 -o $2-$3.sil
endef

%-a4.sil: %.md %.yml $(TOOLS)/template.sil $$(wildcard $$*.lua) $(TOOLS)/layout-a4.lua
	$(call build_sile,$<,$*,$(patsubst $*-%.sil,%,$@),a4)

%-a5trim.sil: %.md %.yml $(TOOLS)/template.sil $$(wildcard $$*.lua) $(TOOLS)/layout-a5trim.lua
	$(call build_sile,$<,$*,$(patsubst $*-%.sil,%,$@),133mm x 195mm)

%-octavo.sil: %.md %.yml $(TOOLS)/template.sil $$(wildcard $$*.lua) $(TOOLS)/layout-octavo.lua
	$(call build_sile,$<,$*,$(patsubst $*-%.sil,%,$@),432pt x 648pt)

%-halfletter.sil: %.md %.yml $(TOOLS)/template.sil $$(wildcard $$*.lua) $(TOOLS)/layout-halfletter.lua
	$(call build_sile,$<,$*,$(patsubst $*-%.sil,%,$@),halfletter)

%-cep.sil: %.md %.yml $(TOOLS)/template.sil $$(wildcard $$*.lua) $(TOOLS)/layout-cep.lua
	$(call build_sile,$<,$*,$(patsubst $*-%.sil,%,$@),115mm x 170mm)

%.epub %.odt %.docx: %.md %.yml
	pandoc $(basename $<).yml $< -o $@

%.mobi: %.epub
	-kindlegen $<

stats: $(foreach SOURCE,$(SOURCES),$(SOURCE)-stats)

%-stats:
	@$(TOOLS)/stats.zsh $(@:-stats=) $(STATS_MONTHS)
