# If called using the CaSILE CLI the init rules will be sourced before any
# project specific ones, then everything will be sourced in order. If people do
# a manual include to rules they may or may not know to source the
# initialization rules first. This is to warn them.
ifeq ($(CASILEDIR),)
$(error Please initialize CaSILE by sourcing casile.mk first, then include your project rules, then source this rules.mk file)
endif

PUBLISHERDIR ?= $(CASILEDIR)

# Set the language if not otherwise set
LANGUAGE ?= en

# Localization functions (source is a key => val file _and_ its inverse)
-include $(CASILEDIR)/rules/$(LANGUAGE).mk $(CASILEDIR)/rules/$(LANGUAGE)-reversed.mk

# Empty recipes for anything we _don't_ want to bother rebuilding:
$(MAKEFILE_LIST):;

export PATH := $(CASILEDIR)/scripts:$(PATH):$(shell $(_ENV) $(PYTHON) -c "import site; print(site.getsitepackages()[0]+'/scripts')")
export HOSTNAME := $(shell $(_ENV) $(HOSTNAMEBIN))
export PROJECT := $(PROJECT)

MARKDOWNSOURCES := $(patsubst ./%,%,$(call find,*.md))
LUASOURCES := $(patsubst ./%,%,$(call find,*.lua))
MAKESOURCES := $(patsubst ./%,%,$(call find,[Mm]akefile*))
YAMLSOURCES := $(patsubst ./%,%,$(call find,*.yml))

# Find stuff that could be built based on what has matching YAML and a MD components
SOURCES_DEF := $(filter $(basename $(notdir $(MARKDOWNSOURCES))),$(basename $(notdir $(YAMLSOURCES))))
SOURCES ?= $(SOURCES_DEF)
TARGETS ?= $(SOURCES)

ISBNS := $(and $(YAMLSOURCES),$(shell $(_ENV) $(YQ) -M -e -r '.identifier[]? | select(.scheme == "ISBN-13").text' $(YAMLSOURCES)))

# List of targets that don't have content but should be rendered anyway
MOCKUPSOURCES ?=
MOCKUPBASE ?= $(firstword $(SOURCES))
MOCKUPFACTOR ?= 1

# List of figures that need building prior to content
FIGURES ?=

# Default output formats and parameters (often overridden)
FORMATS ?= pdfs epub mobi odt docx mdbook zola $(and $(ISBNS),play) app html
BLEED ?= 3
TRIM ?= 10
NOBLEED ?= 0
NOTRIM ?= 0
PAPERWEIGHT ?= 60
STAPLECOUNT ?= 2
COILSPACING ?= 12
COILWIDTH ?= 8
COILCOLOR ?= rgb<.7,.7,.7>
COVERGRAVITY ?= Center
SCENELIGHT ?= rgb<1,1,1>
SCENEX ?= $(call scale,2400)
SCENEY ?= $(call scale,3200)

# Because sometimes the same base content can be post processed multiple ways
EDITS ?= $(_withverses) $(_withoutfootnotes) $(_withoutlinks)

# Build mode flags
DRAFT ?= false # Take shortcuts, scale things down, be quick about it
LAZY ?= false # Pretend to do things we didn't
HIGHLIGHT_DIFF ?= false # Show differences to parent branch in build
STATSMONTHS ?= 1 # How far back to look for commits when building stats
DEBUG ?= false # Use SILE debug flags, set -x, and the like (previously also set in casile.mk)
DEBUGTAGS ?= casile $(PROJECT) # Specific debug flags to set
COVERS ?= true # Build covers?
MOCKUPS ?= true # Render mock-up books in project
SCALE ?= 8 # Reduction factor for draft builds
HIDPI_DEF := $(call scale,600) # Default DPI for generated press resources
HIDPI ?= $(HIDPI_DEF)
LODPI_DEF := $(call scale,300) # Default DPI for generated consumer resources
LODPI ?= $(LODPI_DEF)
SORTORDER ?= meta # Sort series by: none, alphabetical, date, meta, manual

# Set default output format(s)
LAYOUTS ?= a4-$(_print)

# Sometimes the same content, edits and target papersize and bindings might be presented in more than one variant
EDITIONS ?=

# So we don't have to iterate through this as much
EDITIONEDITSOURCES := $(SOURCES)
EDITIONEDITSOURCES += $(and $(EDITIONS),$(call pattern_list,$(SOURCES),$(EDITIONS),#))
EDITIONEDITSOURCES += $(and $(EDITS),$(call pattern_list,$(SOURCES),$(EDITS),# ))
EDITIONEDITSOURCES += $(and $(EDITIONS),$(EDITS),$(call pattern_list,$(SOURCES),$(EDITIONS),$(EDITS),#))
EDITIONEDITSOURCES := $(subst #,,$(EDITIONEDITSOURCES))

# Categorize supported outputs
PAPERSIZES := $(call localize,$(subst layouts/,,$(notdir $(basename $(wildcard $(CASILEDIR)/layouts/*.lua)))))
BINDINGS = $(call localize,print paperback hardcover coil stapled)
DISPLAYS := $(_app) $(_screen)
PLACARDS := $(_square) $(_wide) $(_banner) epub

FAKEPAPERSIZES := $(DISPLAYS) $(PLACARDS)
REALPAPERSIZES := $(filter-out $(FAKEPAPERSIZES),$(PAPERSIZES))
FAKELAYOUTS := $(call pattern_list,$(PLACARDS),-$(_print))
REALLAYOUTS := $(call pattern_list,$(REALPAPERSIZES),$(foreach BINDING,$(BINDINGS),-$(BINDING))) $(call pattern_list,$(DISPLAYS),-$(_print))
ALLLAYOUTS := $(REALLAYOUTS) $(FAKELAYOUTS)
UNBOUNDLAYOUTS := $(call pattern_list,$(PAPERSIZES),-$(_print))
BOUNDLAYOUTS := $(filter-out $(UNBOUNDLAYOUTS),$(ALLLAYOUTS))

# Add any specifically targeted output layouts
GOALLAYOUTS := $(sort $(filter-out -,$(foreach GOAL,$(MAKECMDGOALS),$(call parse_layout,$(GOAL)))))
LAYOUTS += $(GOALLAYOUTS)

ifneq ($(filter ci %.promotionals %.zola %.epub %.play %.app,$(MAKECMDGOALS)),)
LAYOUTS += $(call pattern_list,$(PLACARDS),-$(_print))
endif

RENDERINGS := $(_3d)-$(_front) $(_3d)-$(_back) $(_3d)-$(_pile)
RENDERED_DEF := $(filter $(call pattern_list,$(REALPAPERSIZES),-%),$(filter-out %-$(_print),$(LAYOUTS)))
RENDERED ?= $(RENDERED_DEF)
RENDERED += $(GOALLAYOUTS)

# Over-ride entr arguments, defaults to just clear
# Add -r to kill and restart jobs on activity
# And -p to wait for activity on first invocation
ENTRFLAGS := -c -r
CI ?=

# POV-Ray’s progress status output doesn't play nice with Gitlab’s CI logging or debug output
ifneq ($(CI),)
POVFLAGS += -V
endif
ifeq ($(DEBUG),true)
POVFLAGS += -V
endif

# Tweak POV worker threads to match CASILE job limits, tweak rendering order
POVFLAGS += +BS128 +RP5 +WT$(CASILE_JOBS)
POVTEXTURESCALE ?= $(call scale,15,100)%

# List of extra m4 macro files to apply to every source
M4MACROS ?=
PROJECTMACRO := $(wildcard $(PROJECT).m4)

# List of extra YAML meta data files to splice into each book
METADATA ?=
PROJECTYAML_DEF := $(wildcard $(PROJECT).yml)
PROJECTYAML ?= $(PROJECTYAML_DEF)

# Extra Lua files to include before processing documents
LUAINCLUDES += $(BUILDDIR)/casile.lua
PROJECTLUA := $(wildcard $(PROJECT).lua)

# Extra libraries to include (later ones can override earlier ones)
LUALIBS +=

# Add a place where project local fonts can live
FONTDIRS += $(patsubst ./%,%,$(CASILEDIR)/fonts $(wildcard $(PROJECTDIR:./=.)/.fonts)))

FCCONFIG := $(BUILDDIR)/fontconfig.conf
# BUILDDIR would otherwise get created by other rules anyway, but we're dodging race conditions
export FONTCONFIG_FILE := $(shell $(_ENV) test -d "$(BUILDDIR)" || $(MKDIR_P) "$(BUILDDIR)" && cd "$(BUILDDIR)" && pwd)/fontconfig.conf

# ImageMagick security policy steps on Ghostscript's toes when running under
# setpriv (which we do in Docker), so just keep it all local.
export MAGICK_TEMPORARY_PATH := $(shell $(_ENV) test -d "$(BUILDDIR)" || $(MKDIR_P) "$(BUILDDIR)" && cd "$(BUILDDIR)" && pwd)

# For the benefit of scritps and other contexts outside of this Makefile scope...
export CASILE_BUILDDIR := $(realpath $(BUILDDIR))

# Extensible list of files for git to ignore
IGNORES += $(PROJECTCONFIGS)
IGNORES += $(BUILDDIR)
IGNORES += $(DISTFILES) $(DISTDIRS)

# Tell SILE to look here for stuff before its internal stuff, but still keep anything the user set before run
SILEPATH ?= $(and $(SILE_PATH),$(subst ;,$( ),$(SILE_PATH)))
SILEPATH += $(BUILDDIR)
ifneq ($(PUBLISHERDIR),$(CASILEDIR))
PUBLISHERDIRABS := $(realpath $(patsubst ./%,%,$(PUBLISHERDIR)))
SILEPATH += $(PUBLISHERDIRABS)
export PATH := $(PUBLISHERDIRABS)/scripts:$(PATH)
endif
SILEPATH += $(CASILEDIR)

# Extra arguments to pass to Pandoc
PANDOCARGS ?= --wrap=preserve --markdown-headings=atx --top-level-division=chapter
PANDOCARGS += --reference-location=section
PANDOCFILTERS ?=
PANDOCFILTERARGS ?= --from markdown-space_in_atx_header+ascii_identifiers+four_space_rule --to markdown-smart-four_space_rule

# For when perl one-liners need Unicode compatibility
PERLARGS ?= -Mutf8 -CS

# Extra arguments for Image Magick
MAGICKARGS ?= -define profile:skip="*"

# Set default document class
DOCUMENTCLASS ?= cabook

DOCUMENTOPTIONS += binding=$(call unlocalize,$(or $(call parse_binding,$@),$(firstword $(BINDINGS))))
DOCUMENTOPTIONS += layout=$(call unlocalize,$(or $(call parse_papersize,$@),$(firstword $(PAPERSIZES))))
DOCUMENTOPTIONS += $(and $(call parse_editions,$@),edition=$(call unlocalize,$(call parse_editions,$@)))
DOCUMENTOPTIONS += $(and $(call parse_edits,$@),edit=$(call unlocalize,$(call parse_edits,$@)))

# Default template for setting up Gitlab CI runners
CITEMPLATE ?= $(CASILEDIR)/travis.yml
CICONFIG ?= .travis.yml

# Default templates for zola publishes
ZOLA_TEMPLATE_SERIES ?= $(CASILEDIR)/zola_series.html
ZOLA_TEMPLATE_BOOK ?= $(CASILEDIR)/zola_book.html
ZOLA_STYLE ?= $(CASILEDIR)/zola_style.sass

# List of files that persist across make clean
PROJECTCONFIGS :=

# For watch targets, treat extra parameters as things to pass to the next make
ifeq (watch,$(firstword $(MAKECMDGOALS)))
WATCHARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(WATCHARGS):;@:)
endif

ifeq ($(DEBUG),true)
SILEFLAGS += -t
.SHELLFLAGS += -x
endif

# Pass debug tags on to SILE
ifdef DEBUGTAGS
SILEFLAGS += -d $(subst $( ),$(,),$(strip $(DEBUGTAGS)))
endif

# Combad undefined variable warnings for things sometimes set externally
CI_COMMIT_REF_NAME ?=
GITHUB_HEAD_REF ?=
GITHUB_REF ?=
CI_COMMIT_TAG ?=
CI_MERGE_REQUEST_SOURCE_BRANCH_NAME ?=
GITHUB_BASE_REF ?=
CI_JOB_NAME_SLUG ?=

# Most CI runners need help getting the branch name because of sparse checkouts
BRANCH := $(subst refs/heads/,,$(or $(CI_COMMIT_REF_NAME),$(GITHUB_HEAD_REF),$(GITHUB_REF),$(shell $(_ENV) $(GIT) rev-parse --abbrev-ref HEAD)))
TAG := $(or $(CI_COMMIT_TAG),$(shell $(_ENV) $(GIT) describe --tags --exact-match 2>/dev/null))
ALLTAGS := $(strip $(CI_COMMIT_TAG) $(shell $(_ENV) $(GIT) tag --points-at HEAD | $(XARGS) echo))
PARENT := $(shell $(_ENV) $(GIT) merge-base $(or $(CI_MERGE_REQUEST_SOURCE_BRANCH_NAME),$(GITHUB_BASE_REF),master) $(BRANCH) 2>/dev/null)
HEAD ?=

# Add mock-ups to sources
ifeq ($(strip $(MOCKUPS)),true)
SOURCES += $(MOCKUPSOURCES)
endif

# Probe for available sources relevant to each target once
$(foreach SOURCE,$(SOURCES),$(eval TARGETMACROS_$(SOURCE) := $(wildcard $(SOURCE).lua)))
$(foreach SOURCE,$(SOURCES),$(eval TARGETYAMLS_$(SOURCE) := $(wildcard $(SOURCE).yml)))
$(foreach SOURCE,$(SOURCES),$(eval TARGETLUAS_$(SOURCE) := $(wildcard $(SOURCE).lua)))

# Create list of all possible final outputs for possible distribution
DISTFILES ?=
DISTDIRS ?=
DISTDIR ?= $(PROJECT)-$(call versioninfo,$(PROJECT))

include $(CASILEDIR)/rules/translation.mk
include $(CASILEDIR)/rules/utilities.mk

.PHONY: all
all: $(FORMATS)

define format_template =
.PHONY: $(1)
$(1): $(call pattern_list,$(2),.$(1))
ifneq ($(1),zola)
$(1): $(and $(EDITS),$(call pattern_list,$(2),$(EDITS),.$(1)))
endif
endef

$(foreach FORMAT,$(FORMATS),$(eval $(call format_template,$(FORMAT),$(TARGETS))))

VIRTUALPDFS := $(call pattern_list,$(SOURCES),.pdfs)
VIRTUALEDITPDFS := $(and $(EDITS),$(call pattern_list,$(SOURCES),$(EDITS),.pdfs))
.PHONY: $(VIRTUALPDFS) $(VIRTUALEDITPDFS)
$(VIRTUALPDFS) $(VIRTUALEDITPDFS): %.pdfs: $(call pattern_list,$$*,$(LAYOUTS),.pdf)
$(VIRTUALPDFS): %.pdfs: $(and $(EDITIONS),$(call pattern_list,$$*,$(EDITIONS),$(LAYOUTS),.pdf))
$(VIRTUALEDITPDFS): %.pdfs: $$(and $(EDITIONS),$(EDITS),$$(call pattern_list,$$(call parse_bookid,$$*),$(EDITIONS),$(EDITS),$(LAYOUTS),.pdf))

# Setup target dependencies to mimic stages of a CI pipeline
ifeq ($(MAKECMDGOALS),ci)
CI ?= 1
.PHONY: pdfs
pdfs: debug
renderings promotionals: pdfs
endif

.PHONY: ci
ci: debug pdfs renderings promotionals

.PHONY: renderings
renderings: $(call pattern_list,$(TARGETS),.renderings)

VIRTUALRENDERINGS := $(call pattern_list,$(SOURCES),.renderings)
VIRTUALEDITRENDERINGS := $(and $(EDITS),$(call pattern_list,$(SOURCES),$(EDITS),.renderings))
.PHONY: $(VIRTUALRENDERINGS) $(VIRTUALEDITRENDERINGS)
$(VIRTUALRENDERINGS) $(VIRTUALEDITRENDERINGS): %.renderings: $(call pattern_list,$$*,$(RENDERED),$(RENDERINGS),.jpg)
$(VIRTUALRENDERINGS): %.renderings: $(and $(EDITIONS),$(call pattern_list,$$*,$(EDITIONS),$(RENDERED),$(RENDERINGS),.jpg))
$(VIRTUALEDITRENDERINGS): %.renderings: $$(and $(EDITIONS),$(EDITS),$$(call pattern_list,$$(call parse_bookid,$$*),$(EDITIONS),$(EDITS),$(RENDERED),$(RENDERINGS),.jpg))

.PHONY: promotionals
promotionals: $(call pattern_list,$(TARGETS),.promotionals)

VIRTUALPROMOTIONALS := $(call pattern_list,$(SOURCES),.promotionals)
.PHONY: $(VIRTUALPROMOTIONALS)
$(VIRTUALPROMOTIONALS): %.promotionals: $(call pattern_list,$$*,$(PLACARDS),-$(_poster).jpg) $$*-icon.png

# If a series, add some extra dependencies to convenience builds
ifneq ($(words $(TARGETS)),1)
promotionals: series_promotionals
renderings: series_renderings
endif

.PHONY: series_promotionals
series_promotionals: $(PROJECT)-epub-$(_poster)-$(_montage).jpg $(PROJECT)-$(_square)-$(_poster)-$(_montage).jpg

.PHONY: series_renderings
series_renderings: $(call pattern_list,$(PROJECT),$(RENDERED),-$(_3d)-$(_montage).jpg)

$(PROJECT)-%-$(_poster)-$(_montage).png: $$(call pattern_list,$(SOURCES),%,-$(_poster).png) $(firstword $(SOURCES))-%-$(_print)-$(_geometry).sh
	$(sourcegeometry)
	$(MAGICK) montage \
		$(MAGICKARGS) \
		$(filter %.png,$^) \
		-geometry $${pagewpm}x$${pagehpm}+0+0 \
		$@

.PHONY: $(SOURCES)

REALSOURCES := $(filter-out $(MOCKUPSOURCES),$(SOURCES))
$(REALSOURCES): $(foreach FORMAT,$(FORMATS),$$@.$(FORMAT))
$(MOCKUPSOURCES): $(foreach FORMAT,$(filter pdfs,$(FORMATS)),$$@.$(FORMAT))

.PHONY: figures
figures: $(FIGURES)

PROJECTCONFIGS += .editorconfig
.editorconfig: $(CASILEDIR)/editorconfig
	$(call skip_if_tracked,$@)
	cp $< $@

PROJECTCONFIGS += .gitignore
.gitignore: $(lastword $(MAKEFILE_LIST))
	$(call skip_if_tracked,$@)
	echo '$(IGNORES)' |
		$(SED) -e 's/ /\n/g' > $@

.gitattributes: $(lastword $(MAKEFILE_LIST))
	$(GIT) diff-index --quiet --cached HEAD || exit 1 # die if anything already staged
	$(GIT) diff-files --quiet -- $@ || exit 1 # die if this file has uncommitted changes
	for ft in md yml; do
		line="*.$${ft} linguist-detectabale=true"
		$(GREP) -qxF "$${line}" $@ || echo $${line} >> $@
		$(GIT) add -- $@
	done
	$(GIT) diff-index --quiet --cached HEAD || $(GIT) commit -m "[auto] Configure linguist file types for statistics"

$(CICONFIG): $(CITEMPLATE)
	$(GIT) diff-index --quiet --cached HEAD || exit 1 # die if anything already staged
	$(GIT) diff-files --quiet -- $@ || exit 1 # die if this file has uncommitted changes
	cat $< | \
		$(call ci_setup) | \
		$(SPONGE) $@
	$(GIT) add -- $@
	$(GIT) diff-index --quiet --cached HEAD || $(GIT) commit -m "[auto] Rebuild CI config file"

# Pass or fail target showing whether the CI config is up to date
.PHONY: $(CICONFIG)_current
$(CICONFIG)_current: $(CICONFIG)
	$(GIT) update-index --refresh --ignore-submodules ||:
	$(GIT) diff-files --quiet -- $<

$(BUILDDIR) $(DISTDIR):
	$(MKDIR_P) "$@"

$(DISTDIR).tar.bz2 $(DISTDIR).tar.gz $(DISTDIR).tar.xz $(DISTDIR).zip $(DISTDIR).tar.zst: install-dist
	bsdtar -acf "$@" "$(DISTDIR)"

# Some layouts have matching extra resources to build such as covers
ifneq ($(strip $(COVERS)),false)
$(VIRTUALPDFS) $(VIRTUALEDITPDFS): %.pdfs: $$(call pattern_list,$$*,$(filter %-$(_paperback),$(LAYOUTS)),$(_binding),.pdf)
$(VIRTUALPDFS) $(VIRTUALEDITPDFS): %.pdfs: $$(call pattern_list,$$*,$(filter %-$(_hardcover),$(LAYOUTS)),$(_case) $(_jacket),.pdf)
$(VIRTUALPDFS) $(VIRTUALEDITPDFS): %.pdfs: $$(call pattern_list,$$*,$(filter %-$(_coil),$(LAYOUTS)),$(_cover),.pdf)
$(VIRTUALPDFS) $(VIRTUALEDITPDFS): %.pdfs: $$(call pattern_list,$$*,$(filter %-$(_stapled),$(LAYOUTS)),$(_binding),.pdf)
endif

# Some layouts have matching resources that need to be built first and included
coverpreq = $(and $(filter true,$(COVERS)),$(filter $(_print),$(call parse_binding,$1)),$(filter-out $(DISPLAYS) $(PLACARDS),$(call parse_papersize,$1)),$(BUILDDIR)/$(basename $1)-$(_cover).pdf)

# Order is important here, these are included in reverse order so early supersedes late
onpaperlibs = $(TARGETLUAS_$(call parse_bookid,$1)) $(PROJECTLUA) $(LUALIBS)

MOCKUPPDFS := $(call pattern_list,$(MOCKUPSOURCES),$(REALLAYOUTS),.pdf)
$(MOCKUPPDFS): %.pdf: $$(call mockupbase,$$@)
	$(PDFTK) A=$(filter %.pdf,$^) cat $(foreach P,$(shell $(_ENV) seq 1 $(call pagecount,$@)),A2-2) output $@

FULLPDFS := $(call pattern_list,$(REALSOURCES),$(REALLAYOUTS),.pdf)
FULLPDFS += $(and $(EDITIONS),$(call pattern_list,$(REALSOURCES),$(EDITIONS),$(REALLAYOUTS),.pdf))
FULLPDFS += $(and $(EDITS),$(call pattern_list,$(REALSOURCES),$(EDITS),$(REALLAYOUTS),.pdf))
FULLPDFS += $(and $(EDITIONS),$(EDITS),$(call pattern_list,$(REALSOURCES),$(EDITIONS),$(EDITS),$(REALLAYOUTS),.pdf))
$(FULLPDFS): .EXTRA_PREREQS = $(LUAINCLUDES)
$(FULLPDFS): %.pdf: $(BUILDDIR)/%.sil $$(call coverpreq,$$@) $$(call onpaperlibs,$$@) $(FCCONFIG)
	$(call skip_if_lazy,$@)
	$(HIGHLIGHT_DIFF) && $(SED) -e 's/\\\././g;s/\\\*/*/g' -i $< ||:
	export SILE_PATH="$(subst $( ),;,$(SILEPATH))"
	# If in draft mode don't rebuild for TOC and do output debug info, otherwise
	# account for TOC $(_issue): https://github.com/simoncozens/sile/issues/230
	runsile="$(SILE) $(SILEFLAGS) $< -o $@"
	if $(DRAFT); then
		$${(z)runsile}
	else
		export pg0=$(call pagecount,$@)
		$${(z)runsile}
		# Note this page count can't be in Make because of expansion order
		export pg1=$$($(PDFINFO) $@ | $(AWK) '$$1 == "Pages:" {print $$2}' || echo 0)
		[[ $${pg0} -ne $${pg1} ]] && $${(z)runsile} ||:
		export pg2=$$($(PDFINFO) $@ | $(AWK) '$$1 == "Pages:" {print $$2}' || echo 0)
		[[ $${pg1} -ne $${pg2} ]] && $${(z)runsile} ||:
	fi
	# If we have a special cover page for this format, swap it out for the half title page
	coverfile=$(filter %-$(_cover).pdf,$^)
	if $(COVERS) && [[ -f $${coverfile} ]]; then
		$(PDFTK) $@ dump_data_utf8 output $(BUILDDIR)/$*.dat
		$(PDFTK) C=$${coverfile} B=$@ cat C1 B2-end output $*.tmp.pdf
		$(PDFTK) $*.tmp.pdf update_info_utf8 $(BUILDDIR)/$*.dat output $@
		rm $*.tmp.pdf
	fi

DISTFILES += $(FULLPDFS)

PANDOCTEMPLATE ?= $(CASILEDIR)/template.sil

FULLSILS := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(SOURCES),$(REALLAYOUTS),.sil))
FULLSILS += $(and $(EDITIONS),$(addprefix $(BUILDDIR)/,$(call pattern_list,$(SOURCES),$(EDITIONS),$(REALLAYOUTS),.sil)))
FULLSILS += $(and $(EDITS),$(addprefix $(BUILDDIR)/,$(call pattern_list,$(SOURCES),$(EDITS),$(REALLAYOUTS),.sil)))
FULLSILS += $(and $(EDITIONS),$(EDITS),$(addprefix $(BUILDDIR)/,$(call pattern_list,$(SOURCES),$(EDITIONS),$(EDITS),$(REALLAYOUTS),.sil)))
$(FULLSILS): private PANDOCFILTERS += --filter=$(CASILEDIR)/pandoc-filters/svg2pdf.py
$(FULLSILS): private THISEDIT = $(call parse_edits,$@)
$(FULLSILS): private PROCESSEDSOURCE = $(addprefix $(BUILDDIR)/,$(call pattern_list,$(call parse_bookid,$@),$(and $(THISEDIT),$(THISEDIT)-)$(_processed),.md))
$(FULLSILS): $(BUILDDIR)/%.sil: $$(PROCESSEDSOURCE)
$(FULLSILS): $(BUILDDIR)/%.sil: $$(call pattern_list,$$(call parse_bookid,$$@),-manifest.yml)
$(FULLSILS): $(BUILDDIR)/%.sil: $$(addprefix $(BUILDDIR)/,$$(call pattern_list,$$(call parse_bookid,$$@),-$(_verses)-$(_sorted).json -url.png))
$(FULLSILS): $(BUILDDIR)/%.sil: $(PANDOCTEMPLATE)
$(FULLSILS): $(BUILDDIR)/%.sil: | $$(call onpaperlibs,$$@)
$(FULLSILS): $(BUILDDIR)/%.sil:
	$(PANDOC) --standalone \
			$(PANDOCARGS) \
			$(PANDOCFILTERS) \
			-V documentclass="$(DOCUMENTCLASS)" \
			$(if $(DOCUMENTOPTIONS),-V classoptions="$(call join_with,$(,),$(DOCUMENTOPTIONS))",) \
			-V metadatafile="$(filter %-manifest.yml,$^)" \
			-V versesfile="$(filter %-$(_verses)-$(_sorted).json,$^)" \
			-V versioninfo="$(call versioninfo,$@)" \
			-V urlinfo="$(call urlinfo,$@)" \
			-V qrimg="./$(filter %-url.png,$^)" \
			$(foreach LUA,$(call reverse,$(filter %.lua,$|)), -V module=$(subst $(PUBLISHERDIR)/,,$(subst $(CASILEDIR)/,,$(basename $(LUA))))) \
			--template=$(filter %.sil,$^) \
			--from=markdown \
			--to=sile \
			$(filter %-manifest.yml,$^) =(< $< $(call pre_sile_markdown_hook)) |
		$(call sile_hook) > $@

# Send some environment data to a common Lua file to be pulled into all SILE runs
$(BUILDDIR)/casile.lua: | $(BUILDDIR)
	cat <<- EOF > $@
		CASILE = {}
		CASILE.project = "$(PROJECT)"
		CASILE.casiledir = "$(CASILEDIR)"
		CASILE.publisher = "casile"
		extendSilePath("$(PROJECTDIR)/lua_modules")
		return { _name = "casile", type = "casile" }
	EOF

$(FCCONFIG): FCDEFAULT ?= $(shell $(_ENV) env -u FONTCONFIG_FILE $(FCCONFLIST) | $(AWK) -F'[ :]' '/Default configuration file/ { print $$2 }')
$(FCCONFIG): | $(BUILDDIR)
	cat <<- EOF > $@
		<?xml version="1.0"?>
		<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
		<fontconfig>$(foreach DIR,$(FONTDIRS),
			<dir>$(shell $(_ENV) cd "$(shell $(_ENV) dirname $(DIR))" && pwd)</dir>)
			<include ignore_missing="no">$(FCDEFAULT)</include>
		</fontconfig>
	EOF

WITHVERSEFILTER := $(CASILEDIR)/pandoc-filters/withverses.lua
SOURCESWITHVERSES := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(SOURCES),$(_withverses),$(_processed),.md))
$(SOURCESWITHVERSES): private PANDOCFILTERS += --lua-filter=$(WITHVERSEFILTER)
$(SOURCESWITHVERSES): private PANDOCFILTERS += -M versedatafile="$(filter %-$(_verses)-$(_text).yml,$^)"
$(SOURCESWITHVERSES): $(BUILDDIR)/$$(call parse_bookid,$$@)-$(_verses)-$(_text).yml $(WITHVERSEFILTER)

SOURCESWITHOUTFOOTNOTES := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(SOURCES),$(_withoutfootnotes),$(_processed),.md))
$(SOURCESWITHOUTFOOTNOTES): private PANDOCFILTERS += --lua-filter=$(CASILEDIR)/pandoc-filters/withoutfootnotes.lua
$(SOURCESWITHOUTFOOTNOTES): private PANDOCFILTERS += --lua-filter=$(CASILEDIR)/pandoc-filters/withoutlinks.lua

SOURCESWITHOUTLINKS := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(SOURCES),$(_withoutlinks),$(_processed),.md))
$(SOURCESWITHOUTLINKS): private PANDOCFILTERS += --lua-filter=$(CASILEDIR)/pandoc-filters/withoutlinks.lua

SOURCESWITHEDITS := $(SOURCESWITHVERSES) $(SOURCESWITHOUTFOOTNOTES) $(SOURCESWITHOUTLINKS)
$(SOURCESWITHEDITS): $$(call strip_edits,$$@)
	$(PANDOC) \
		$(PANDOCARGS) $(PANDOCFILTERS) $(PANDOCFILTERARGS) \
		$(filter %.md,$^) -o $@

# Configure SILE arguments to include common Lua libraries
SILEFLAGS += $(call use_luas,$(LUAINCLUDES))

preprocess_macros = $(CASILEDIR)/casile.m4 $(M4MACROS) $(PROJECTMACRO) $(TARGETMACROS_$1)

$(BUILDDIR)/%-$(_processed).md: %.md $$(wildcard $(PROJECT)*.md $$*-$(_chapters)/*.md) $$(call preprocess_macros,$$*) | $(BUILDDIR) figures
	if $(HIGHLIGHT_DIFF) && $(if $(PARENT),true,false); then
		export FILTERS="$(filter %.m4,$^)"
		branch2criticmark.zsh $(PARENT) $<
	else
		$(M4) $(filter %.m4,$^) $<
	fi |
		renumber_footnotes.pl |
		$(and $(HEAD),head -n$(HEAD) |) \
		$(call link_verses) |
		$(PERL) $(PERLARGS) -pne "s/(?<=[\)\}])'/’/g" | # Work around Pandoc bug, see https://github.com/jgm/pandoc/issues/5385
		$(call criticToSile) |
		$(PANDOC) \
			$(PANDOCARGS) $(PANDOCFILTERS) $(PANDOCFILTERARGS) |
		$(call markdown_hook) > $@

%-$(_booklet).pdf: $(BUILDDIR)/%-$(_spineless).pdf
	$(PDFBOOK2) --short-edge --paper="{$(call pageh,$<)pt,$$(($(call pagew,$<)*2))pt}" -- $<
	mv $*-book.pdf $@

DISTFILES += *-$(_booklet).pdf

$(BUILDDIR)/%-2end.pdf: %.pdf | $(BUILDDIR)
	$(PDFTK) $< cat 2-end output $@

%-2up.pdf: $(BUILDDIR)/%-$(_cropped)-2end.pdf
	$(PDFJAM) --nup 2x1 --noautoscale true --paper a4paper --landscape --outfile $@ -- $<

DISTFILES += *-2up.pdf

$(BUILDDIR)/%-topbottom.pdf: $(BUILDDIR)/%-set1.pdf $(BUILDDIR)/%-set2.pdf
	$(PDFTK) A=$(word 1,$^) B=$(word 2,$^) shuffle A B output $@

%-a4proof.pdf: $(BUILDDIR)/%-topbottom.pdf
	$(PDFJAM) --nup 1x2 --noautoscale true --paper a4paper --outfile $@ -- $<

DISTFILES += *-a4proof.pdf

$(BUILDDIR)/%-cropleft.pdf: %.pdf | $$(geometryfile) $(BUILDDIR)
	$(sourcegeometry)
	t=$$(echo "$${trimpt} * 100" | $(BC))
	s=$$(echo "$${spinept} * 100 / 4" | $(BC))
	w=$$(echo "$(call pagew,$<) * 100 - $${t} + $${s}" | $(BC))
	h=$$(echo "$(call pageh,$<) * 100" | $(BC))
	$(PODOFOBOX) $< $@ media 0 0 $${w} $${h}

$(BUILDDIR)/%-cropright.pdf: %.pdf | $$(geometryfile) $(BUILDDIR)
	$(sourcegeometry)
	t=$$(echo "$${trimpt} * 100" | $(BC))
	s=$$(echo "$${spinept} * 100 / 4" | $(BC))
	w=$$(echo "$(call pagew,$<) * 100 - $$t + $$s" | $(BC))
	h=$$(echo "$(call pageh,$<) * 100" | $(BC))
	$(PODOFOBOX) $< $@ media $$(($$t-$$s)) 0 $$w $$h

$(BUILDDIR)/%-$(_spineless).pdf: $(BUILDDIR)/%-$(_odd)-cropright.pdf $(BUILDDIR)/%-$(_even)-cropleft.pdf
	$(PDFTK) A=$(word 1,$^) B=$(word 2,$^) shuffle A B output $@

%-$(_cropped).pdf: %.pdf | $$(geometryfile) $(BUILDDIR)
	$(sourcegeometry)
	t=$$(echo "$${trimpt} * 100" | $(BC))
	w=$$(echo "$(call pagew,$<) * 100 - $${t} * 2" | $(BC))
	h=$$(echo "$(call pageh,$<) * 100 - $${t} * 2" | $(BC))
	$(PODOFOBOX) $< $@ media $${t} $${t} $${w} $${h}

DISTFILES += *-$(_cropped).pdf

$(BUILDDIR)/%-set1.pdf: %.pdf | $(BUILDDIR)
	$(PDFTK) $< cat 1-$$(($(call pagecount,$<)/2)) output $@

$(BUILDDIR)/%-set2.pdf: %.pdf | $(BUILDDIR)
	$(PDFTK) $< cat $$(($(call pagecount,$<)/2+1))-end output $@

$(BUILDDIR)/%-$(_even).pdf: %.pdf | $(BUILDDIR)
	$(PDFTK) $< cat even output $@

$(BUILDDIR)/%-$(_odd).pdf: %.pdf | $(BUILDDIR)
	$(PDFTK) $< cat odd output $@

$(BUILDDIR)/%.toc: %.pdf | $(BUILDDIR) ;

$(BUILDDIR)/%.tov: %.pdf | $(BUILDDIR) ;

VIRTUALAPPS := $(call pattern_list,$(SOURCES),.app)
.PHONY: $(VIRTUALAPPS)
$(VIRTUALAPPS): %.app: %-$(_app).info %.promotionals

%-$(_app).pdf: %-$(_app)-$(_print).pdf
	cp $< $@

DISTFILES += *-$(_app).pdf

%-$(_app).info: $(BUILDDIR)/%-$(_app)-$(_print).toc %-$(_app)-$(_print).pdf %-manifest.yml
	toc2breaks.lua $* $(filter %-$(_app)-$(_print).toc,$^) $(filter %-manifest.yml,$^) $@ |
		while read range out; do
			$(PDFTK) $(filter %-$(_app)-$(_print).pdf,$^) cat $$range output $$out
		done

DISTFILES += *-$(_app).info

$(_issue).info:
	for source in $(SOURCES); do
		echo -e "# $$source\n"
		if test -d $${source}-bolumler; then
			$(FIND) $${source}-bolumler -name '*.md' -print |
				$(SORT) -n |
				while read chapter; do
					number=$${chapter%-*}; number=$${number#*/}
					$(SED) -ne "/^# /{s/ {.*}$$//;s!^# *\(.*\)! - [ ] $$number — [\1]($$chapter)!g;p}" $$chapter
				done
		elif $(GREP) -q '^# ' $$source.md; then
			$(SED) -ne "/^# /{s/^# *\(.*\)/ - [ ] [\1]($${source}.md)/g;p}" $$source.md
		else
			echo -e " - [ ] [$${source}]($${source}.md)"
		fi
		echo
	done > $@

DISTFILES += $(_issue).info

COVERBACKGROUNDS := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(EDITIONEDITSOURCES),$(UNBOUNDLAYOUTS),-$(_cover)-$(_background).png))
git_background = $(shell $(_ENV) $(GIT) ls-files -- $(call strip_layout,$1) 2> /dev/null)
$(COVERBACKGROUNDS): $(BUILDDIR)/%-$(_cover)-$(_background).png: $$(call git_background,$$@) $$(geometryfile)
	$(sourcegeometry)
	$(if $(filter %.png,$(call git_background,$@)),true,false) && $(MAGICK) \
		$(MAGICKARGS) \
		$(filter %.png,$^) \
		-gravity $(COVERGRAVITY) \
		-extent  "%[fx:w/h>=$${pageaspect}?h*$${pageaspect}:w]x" \
		-extent "x%[fx:w/h<=$${pageaspect}?w/$${pageaspect}:h]" \
		-resize $${pagewpx}x$${pagehpx} \
		$(call magick_background_filter) \
		$@ ||:
	$(if $(filter %.png,$(call git_background,$@)),false,true) && $(MAGICK) \
		$(MAGICKARGS) \
		-size $${pagewpx}x$${pagehpx}^ $(call magick_background_cover) \
		$@ ||:

# Requires fake geometry file with no binding spec because binding not part of pattern
$(BUILDDIR)/%-$(_poster).png: $(BUILDDIR)/%-$(_print)-$(_cover).png $$(geometryfile)
	$(sourcegeometry)
	$(MAGICK) \
		$(MAGICKARGS) \
		$< \
		-resize $${pagewpp}x$${pagehpp}^ \
		$(and $(filter epub,$(call parse_papersize,$@)),-resize 1000x1600^) \
		$@

COVERIMAGES := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(EDITIONEDITSOURCES),$(UNBOUNDLAYOUTS),-$(_cover).png))
$(COVERIMAGES): $(BUILDDIR)/%-$(_cover).png: $(BUILDDIR)/%-$(_cover)-$(_background).png $(BUILDDIR)/%-$(_cover)-$(_fragment).png $$(geometryfile)
	$(sourcegeometry)
	$(MAGICK) \
		$(MAGICKARGS) \
		$< \
		-compose SrcOver \
		\( -background none \
			-gravity Center \
			-size $${pagewpx}x$${pagehpx} \
			xc: \
			$(call magick_cover) \
		\) -composite \
		\( \
			-gravity Center \
			$(filter %-$(_cover)-$(_fragment).png,$^) \
		\) -compose SrcOver -composite \
		-gravity Center \
		-size '%[fx:u.w]x%[fx:u.h]' \
		$@

# Gitlab projects need a sub 200kb icon image
%-icon.png: $(BUILDDIR)/%-$(_square)-$(_poster).png
	$(MAGICK) \
		$(MAGICKARGS) \
		$< \
		-define png:extent=200kb \
		-resize 196x196 \
		-quality 9 \
		$@

DISTFILES += *-icon.png

COVERPDFS := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(EDITIONEDITSOURCES),$(UNBOUNDLAYOUTS),-$(_cover).pdf))
$(COVERPDFS): $(BUILDDIR)/%-$(_cover).pdf: $(BUILDDIR)/%-$(_cover).png $(BUILDDIR)/%-$(_cover)-$(_text).pdf $(FCCONFIG)
	$(COVERS) || exit 0
	text=$$(mktemp kapakXXXXXX.pdf)
	bg=$$(mktemp kapakXXXXXX.pdf)
	trap 'rm -rf $$text $$bg' EXIT SIGHUP SIGTERM
	$(MAGICK) \
		$(MAGICKARGS) \
		$< \
		-density $(LODPI) \
		-compress jpeg \
		-quality 50 \
		+repage \
		$$bg
	$(PDFTK) $(filter %.pdf,$^) cat 1 output $$text
	$(PDFTK) $$text background $$bg output $@

BINDINGFRAGMENTS := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(EDITIONEDITSOURCES),$(BOUNDLAYOUTS),-$(_binding)-$(_text).pdf))
$(BINDINGFRAGMENTS): .EXTRA_PREREQS = $(LUAINCLUDES)
$(BINDINGFRAGMENTS): $(BUILDDIR)/%-$(_binding)-$(_text).pdf: $(CASILEDIR)/binding.xml $$(call parse_bookid,$$@)-manifest.yml
$(BINDINGFRAGMENTS): $(BUILDDIR)/%-$(_binding)-$(_text).pdf: $(PROJECTLUA) $$(TARGETLUAS_$$(call parse_bookid,$$@))
$(BINDINGFRAGMENTS): $(BUILDDIR)/%-$(_binding)-$(_text).pdf: $$(subst $(BUILDDIR)/,,$$(subst -$(_binding)-$(_text),,$$@))
$(BINDINGFRAGMENTS): $(BUILDDIR)/%-$(_binding)-$(_text).pdf: $(FCCONFIG)
$(BINDINGFRAGMENTS): $(BUILDDIR)/%-$(_binding)-$(_text).pdf: | $(LUALIBS) $(BUILDDIR)
$(BINDINGFRAGMENTS): $(BUILDDIR)/%-$(_binding)-$(_text).pdf:
	cat <<- EOF > $(BUILDDIR)/$*.lua
		CASILE.versioninfo = "$(call versioninfo,$@)"
		local metadatafile = "$(filter %-manifest.yml,$^)"
		CASILE.metadata = require("readmeta").load(metadatafile)
		CASILE.layout = "$(or $(__$(call parse_papersize,$@)),$(call parse_papersize,$@))"
		CASILE.language = "$(LANGUAGE)"
		CASILE.spine = "$(call spinemm,$(filter %.pdf,$^))mm"
		return { _name = "$*", type = "casile" }
	EOF
	export SILE_PATH="$(subst $( ),;,$(SILEPATH))"
	$(SILE) $(SILEFLAGS) $(call use_luas,$^ $| $*.lua) --use packages.dumpframes\[outfile=$(basename $@).tof\] $< -o $@

FRONTFRAGMENTS := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(EDITIONEDITSOURCES),$(BOUNDLAYOUTS),-$(_binding)-$(_fragment)-$(_front).png))
$(FRONTFRAGMENTS): $(BUILDDIR)/%-$(_fragment)-$(_front).png: $(BUILDDIR)/%-$(_text).pdf | $$(geometryfile)
	$(sourcegeometry)
	$(MAGICK) \
		$(MAGICKARGS) \
		-density $(HIDPI) \
		"$<[0]" \
		-colorspace sRGB \
		-gravity East \
		-crop $${pagewpx}x+0+0 +repage \
		$(call magick_fragment_front) +repage \
		-compose Copy -layers Flatten +repage \
		$@

BACKFRAGMENTS := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(EDITIONEDITSOURCES),$(BOUNDLAYOUTS),-$(_binding)-$(_fragment)-$(_back).png))
$(BACKFRAGMENTS): $(BUILDDIR)/%-$(_fragment)-$(_back).png: $(BUILDDIR)/%-$(_text).pdf | $$(geometryfile)
	$(sourcegeometry)
	$(MAGICK) \
		$(MAGICKARGS) \
		-density $(HIDPI) \
		"$<[0]" \
		-colorspace sRGB \
		-gravity West \
		-crop $${pagewpx}x+0+0 +repage \
		$(call magick_fragment_back) +repage \
		-compose Copy -layers Flatten +repage \
		$@

SPINEFRAGMENTS := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(EDITIONEDITSOURCES),$(BOUNDLAYOUTS),-$(_binding)-$(_fragment)-$(_spine).png))
$(SPINEFRAGMENTS): $(BUILDDIR)/%-$(_fragment)-$(_spine).png: $(BUILDDIR)/%-$(_text).pdf | $$(geometryfile)
	$(sourcegeometry)
	$(MAGICK) \
		$(MAGICKARGS) \
		-density $(HIDPI) \
		"$<[0]" \
		-colorspace sRGB \
		-gravity Center \
		-crop $${spinepx}x+0+0 +repage \
		$(call magick_fragment_spine) \
		-compose Copy -layers Flatten +repage \
		$@

COVERFRAGMENTS := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(EDITIONEDITSOURCES),$(UNBOUNDLAYOUTS),-$(_cover)-$(_text).pdf))
$(COVERFRAGMENTS): .EXTRA_PREREQS = $(LUAINCLUDES)
$(COVERFRAGMENTS): $(BUILDDIR)/%-$(_text).pdf: $(CASILEDIR)/cover.xml $$(call parse_bookid,$$@)-manifest.yml
$(COVERFRAGMENTS): $(BUILDDIR)/%-$(_text).pdf: $(PROJECTLUA) $$(TARGETLUAS_$$(call parse_bookid,$$@))
$(COVERFRAGMENTS): $(BUILDDIR)/%-$(_text).pdf: $(FCCONFIG)
$(COVERFRAGMENTS): $(BUILDDIR)/%-$(_text).pdf: | $(LUALIBS) $(BUILDDIR)
$(COVERFRAGMENTS): $(BUILDDIR)/%-$(_text).pdf:
	cat <<- EOF > $(BUILDDIR)/$*.lua
		CASILE.versioninfo = "$(call versioninfo,$@)"
		local metadatafile = "$(filter %-manifest.yml,$^)"
		CASILE.metadata = require("readmeta").load(metadatafile)
		CASILE.layout = "$(or $(__$(call parse_papersize,$@)),$(call parse_papersize,$@))"
		CASILE.language = "$(LANGUAGE)"
		return { _name = "casile", type = "casile" }
	EOF
	export SILE_PATH="$(subst $( ),;,$(SILEPATH))"
	$(SILE) $(SILEFLAGS) $(call use_luas,$^ $| $*.lua) $< -o $@

FRONTFRAGMENTIMAGES := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(EDITIONEDITSOURCES),$(UNBOUNDLAYOUTS),-$(_cover)-$(_fragment).png))
$(FRONTFRAGMENTIMAGES): $(BUILDDIR)/%-$(_fragment).png: $(BUILDDIR)/%-$(_text).pdf
	$(MAGICK) \
		$(MAGICKARGS) \
		-density $(HIDPI) \
		"$<[0]" \
		-colorspace sRGB \
		$(call magick_fragment_cover) \
		-compose Copy -layers Flatten +repage \
		$@

PUBLISHEREMBLUM ?= $(PUBLISHERDIR)/emblum.svg
$(BUILDDIR)/publisher_emblum.svg: $(PUBLISHEREMBLUM) | $(BUILDDIR)
	$(call skip_if_tracked,$@)
	cp $< $@

$(BUILDDIR)/publisher_emblum-grey.svg: $(PUBLISHEREMBLUM) | $(BUILDDIR)
	$(call skip_if_tracked,$@)
	cp $< $@

PUBLISHERLOGO ?= $(PUBLISHERDIR)/logo.svg
$(BUILDDIR)/publisher_logo.svg: $(PUBLISHERLOGO) | $(BUILDDIR)
	$(call skip_if_tracked,$@)
	cp $< $@

$(BUILDDIR)/publisher_logo-grey.svg: $(PUBLISHERLOGO) | $(BUILDDIR)
	$(call skip_if_tracked,$@)
	cp $< $@

BINDINGIMAGES := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(EDITIONEDITSOURCES),$(BOUNDLAYOUTS),-$(_binding).png))
$(BINDINGIMAGES): $(BUILDDIR)/%-$(_binding).png: $$(addsuffix .png,$$(addprefix $$(basename $$@)-$(_fragment)-,$(_front) $(_back) $(_spine)))
$(BINDINGIMAGES): $(BUILDDIR)/%-$(_binding).png: $(BUILDDIR)/$$(call parse_bookid,$$@)-$(_barcode).png
$(BINDINGIMAGES): $(BUILDDIR)/%-$(_binding).png: $(BUILDDIR)/publisher_emblum.svg $(BUILDDIR)/publisher_emblum-grey.svg $(BUILDDIR)/publisher_logo.svg $(BUILDDIR)/publisher_logo-grey.svg
$(BINDINGIMAGES): $(BUILDDIR)/%-$(_binding).png: $$(geometryfile)
$(BINDINGIMAGES): $(BUILDDIR)/%-$(_binding).png:
	$(sourcegeometry)
	$(MAGICK) \
		$(MAGICKARGS) \
		-size $${imgwpx}x$${imghpx} -density $(HIDPI) \
		$(or $(and $(call git_background,$*-$(_cover)-$(_background).png),$(call git_background,$*-$(_cover)-$(_background).png) -resize $${imgwpx}x$${imghpx}!),$(call magick_background_binding)) \
		$(call magick_border) \
		\( -gravity East -size $${pagewpx}x$${pagehpx} -background none xc: $(call magick_front) -splice $${bleedpx}x \) -compose SrcOver -composite \
		\( -gravity West -size $${pagewpx}x$${pagehpx} -background none xc: $(call magick_back) -splice $${bleedpx}x \) -compose SrcOver -composite \
		\( -gravity Center -size $${spinepx}x$${pagehpx} -background none xc: $(call magick_spine) \) -compose SrcOver -composite \
		\( -gravity East $(filter %-$(_front).png,$^) -splice $${bleedpx}x -write mpr:text-front \) -compose SrcOver -composite \
		\( -gravity West $(filter %-$(_back).png,$^) -splice $${bleedpx}x -write mpr:text-front \) -compose SrcOver -composite \
		\( -gravity Center $(filter %-$(_spine).png,$^) -write mpr:text-front \) -compose SrcOver -composite \
		$(call magick_emblum,$(BUILDDIR)/publisher_emblum.svg) \
		$(call magick_barcode,$(filter %-$(_barcode).png,$^)) \
		$(call magick_logo,$(BUILDDIR)/publisher_logo.svg) \
		-gravity Center -size '%[fx:u.w]x%[fx:u.h]' \
		$(call magick_binding) \
		$@

$(BUILDDIR)/%-printcolor.png: $(BUILDDIR)/%.png
	$(MAGICK) \
		$(MAGICKARGS) \
		$< $(call magick_printcolor) \
		$@

$(BUILDDIR)/%-$(_binding).svg: $(CASILEDIR)/binding.svg $$(basename $$@)-printcolor.png $$(geometryfile)
	$(sourcegeometry)
	ver="$(subst @,\\@,$(call versioninfo,$@))"
	$(PERL) $(PERLARGS) -pne "
			s#IMG#$(subst $(BUILDDIR)/,,$(filter %.png,$^))#g;
			s#VER#$${ver}#g;
			s#CANVASX#$${bindingwmm}mm#g;
			s#CANVASY#$${pagehmm}mm#g;
			s#IMW#$${imgwpm}#g;
			s#IMH#$${imghpm}#g;
			s#WWW#$${bindingwpm}#g;
			s#HHH#$${pagehpm}#g;
			s#BLEED#$${bleedpm}#g;
			s#TRIM#$${trimpm}#g;
			s#CROP#$${trimmm}mm#g;
			s#CW#$${pagewpm}#g;
			s#SW#$${spinepm}#g;
		" $< > $@

%-$(_binding).pdf: $(BUILDDIR)/%-$(_binding).svg $(FCCONFIG) $$(geometryfile)
	$(sourcegeometry)
	env HOME=$(BUILDDIR) \
		$(and $(CASILE_SINGLEXVFBJOB),$(FLOCK) $(BUILDDIR)/lock-xvfb) \
		$(XVFBRUN) -d $(INKSCAPE) $< \
		--batch-process \
		--export-dpi=$${hidpi} \
		--export-area-page \
		--export-margin=$${trimmm} \
		-o $@

DISTFILES += *-$(_binding).pdf

# Dial down trim/bleed for non-full-bleed output so we can use the same math
UNBOUNDGEOMETRIES := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(EDITIONEDITSOURCES),$(UNBOUNDLAYOUTS),-$(_geometry).sh))
$(UNBOUNDGEOMETRIES): private BLEED = $(NOBLEED)
$(UNBOUNDGEOMETRIES): private TRIM = $(NOTRIM)

# Some output formats don't have PDF content, but we still need to calculate the
# page geometry, so generate a single page PDF to measure with no binding scenario
EMPTYGEOMETRIES := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(_geometry),$(PAPERSIZES),.pdf))
$(EMPTYGEOMETRIES): .EXTRA_PREREQS = $(LUAINCLUDES)
$(EMPTYGEOMETRIES): $(BUILDDIR)/$(_geometry)-%.pdf: $(CASILEDIR)/geometry.xml | $(BUILDDIR)
	cat <<- EOF > $(BUILDDIR)/$*.lua
		CASILE.versioninfo = "$(call versioninfo,$@)"
		CASILE.layout = "$(or $(__$(call parse_papersize,$@)),$(call parse_papersize,$@))"
		CASILE.language = "$(LANGUAGE)"
		return { _name = "$*", type = "casile" }
	EOF
	export SILE_PATH="$(subst $( ),;,$(SILEPATH))"
	$(SILE) $(SILEFLAGS) $(call use_luas,$^ $| $*.lua) --use packages.dumpframes\[outfile=$(basename $@).tof\] $< -o $@

# Hard coded list instead of plain pattern because make is stupid: http://stackoverflow.com/q/41694704/313192
GEOMETRIES := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(EDITIONEDITSOURCES),$(ALLLAYOUTS),-$(_geometry).sh))
$(GEOMETRIES): $(BUILDDIR)/%-$(_geometry).sh: $$(call geometrybase,$$@) $$(call newgeometry,$$@)
	$(ZSH) << 'EOF' # inception to break out of CaSILE’s make shell wrapper
	export PS4=; set -x ; exec 2> $@ # black magic to output the finished math
	hidpi=$(HIDPI)
	lodpi=$(HIDPI)
	bleedmm=$(BLEED)
	bleedpx=$(call mmtopx,$(BLEED))
	bleedpm=$(call mmtopm,$(BLEED))
	bleedpt=$(call mmtopt,$(BLEED))
	trimmm=$(TRIM)
	trimpx=$(call mmtopx,$(TRIM))
	trimpm=$(call mmtopm,$(TRIM))
	trimpt=$(call mmtopt,$(TRIM))
	$(shell $(_ENV) $(MAGICK) identify -density $(HIDPI) -format '
			pagewmm=%[fx:round(w/$(HIDPI)*25.399986)]
			pagewpx=%[fx:w]
			pagewpm=%[fx:round(w/$(HIDPI)*90)]
			pagewpt=%[fx:round(w/$(HIDPI)*72)]
			pagewpp=%[fx:round(w/$(HIDPI)*$(LODPI))]
			pagehmm=%[fx:round(h/$(HIDPI)*25.399986)]
			pagehpx=%[fx:h]
			pagehpm=%[fx:round(h/$(HIDPI)*90)]
			pagehpt=%[fx:round(h/$(HIDPI)*72)]
			pagehpp=%[fx:round(h/$(HIDPI)*$(LODPI))]
			pageaspect=%[fx:w/h]
		' "$(filter $(BUILDDIR)/$(_geometry)-%.pdf,$^)[0]" || echo false)
	pminpx=$$(($$pagewpx<$$pagehpx?$$pagewpx:$$pagehpx))
	pmaxpx=$$(($$pagewpx>$$pagehpx?$$pagewpx:$$pagehpx))
	pagecount=$(call pagecount,$(filter %.pdf,$<))
	spinemm=$(call spinemm,$(filter %.pdf,$<))
	spinepx=$(call mmtopx,$(call spinemm,$(filter %.pdf,$<)))
	spinepm=$(call mmtopm,$(call spinemm,$(filter %.pdf,$<)))
	spinept=$(call mmtopt,$(call spinemm,$(filter %.pdf,$<)))
	fbwmm=$$(($$pagewmm+$$bleedmm))
	fbwpx=$$(($$pagewpx+$$bleedpx))
	fbwpm=$$(($$pagewpm+$$bleedpm))
	fbwpt=$$(($$pagewpt+$$bleedpt))
	ftwmm=$$(($$pagewmm+$$trimmm*2))
	ftwpx=$$(($$pagewpx+$$trimpx*2))
	ftwpm=$$(($$pagewpm+$$trimpm*2))
	ftwpt=$$(($$pagewpt+$$trimpt*2))
	fthmm=$$(($$pagehmm+$$trimmm*2))
	fthpx=$$(($$pagehpx+$$trimpx*2))
	fthpm=$$(($$pagehpm+$$trimpm*2))
	fthpt=$$(($$pagehpt+$$trimpt*2))
	bindingwmm=$$(($$pagewmm+$$spinemm+$$pagewmm))
	bindingwpx=$$(($$pagewpx+$$spinepx+$$pagewpx))
	bindingwpm=$$(($$pagewpm+$$spinepm+$$pagewpm))
	bindingwpt=$$(($$pagewpt+$$spinept+$$pagewpt))
	imgwmm=$$(($$bindingwmm+$$bleedmm*2))
	imgwpx=$$(($$bindingwpx+$$bleedpx*2))
	imgwpm=$$(($$bindingwpm+$$bleedpm*2))
	imgwpt=$$(($$bindingwpt+$$bleedpt*2))
	imghmm=$$(($$pagehmm+$$bleedmm*2))
	imghpx=$$(($$pagehpx+$$bleedpx*2))
	imghpm=$$(($$pagehpm+$$bleedpm*2))
	imghpt=$$(($$pagehpt+$$bleedpt*2))
	widelayout=$$(($${pagewpx} > $${pagehpx}))
	$(call geometry_extras)
	EOF

$(BUILDDIR)/%-$(_binding)-$(_front).png: $(BUILDDIR)/%-$(_binding).png $$(geometryfile)
	$(sourcegeometry)
	$(MAGICK) \
		$(MAGICKARGS) \
		$< \
		-gravity East \
		-crop $${pagewpx}x$${pagehpx}+$${bleedpx}+0! \
		$@

$(BUILDDIR)/%-$(_binding)-$(_back).png: $(BUILDDIR)/%-$(_binding).png $$(geometryfile)
	$(sourcegeometry)
	$(MAGICK) \
		$(MAGICKARGS) \
		$< \
		-gravity West \
		-crop $${pagewpx}x$${pagehpx}+$${bleedpx}+0! \
		$@

$(BUILDDIR)/%-$(_binding)-$(_spine).png: $(BUILDDIR)/%-$(_binding).png $$(geometryfile)
	$(sourcegeometry)
	$(MAGICK) \
		$(MAGICKARGS) \
		$< \
		-gravity Center \
		-crop $${spinepx}x$${pagehpx}+0+0! \
		$@

DISTFILES += *.png
DISTFILES += *.jpg

# POV-Ray rendered scene rules
include $(CASILEDIR)/rules/renderings.mk

# EPUB, MOBI, and PLAY ebook rules
include $(CASILEDIR)/rules/ebooks.mk

# MDBOOK rules
include $(CASILEDIR)/rules/mdbook.mk

# ZOLA static site rules
include $(CASILEDIR)/rules/zola.mk

ODTS := $(call pattern_list,$(SOURCES),.odt)
ODTS += $(and $(EDITS),$(call pattern_list,$(SOURCES),$(EDITS),.odt))
$(ODTS): %.odt: $(BUILDDIR)/%-$(_processed).md $$(call parse_bookid,$$*)-manifest.yml
	$(PANDOC) \
		$(PANDOCARGS) \
		$(PANDOCFILTERS) \
		$(filter %-manifest.yml,$^) \
		$(filter %-$(_processed).md,$^) -o $@

DISTFILES += $(ODTS)

DOCXS := $(call pattern_list,$(SOURCES),.docx)
DOCXS += $(and $(EDITS),$(call pattern_list,$(SOURCES),$(EDITS),.docx))
$(DOCXS): %.docx: $(BUILDDIR)/%-$(_processed).md $$(call parse_bookid,$$*)-manifest.yml
	$(PANDOC) \
		$(PANDOCARGS) \
		$(PANDOCFILTERS) \
		$(filter %-manifest.yml,$^) \
		$(filter %-$(_processed).md,$^) -o $@

DISTFILES += $(DOCXS)

HTMLS := $(call pattern_list,$(SOURCES),.html)
HTMLS += $(and $(EDITS),$(call pattern_list,$(SOURCES),$(EDITS),.html))
$(HTMLS): PANDOCARGS += --standalone --reference-location=document
$(HTMLS): %.html: $(BUILDDIR)/%-$(_processed).md $$(call parse_bookid,$$*)-manifest.yml
	$(PANDOC) \
		$(PANDOCARGS) \
		$(PANDOCFILTERS) \
		$(filter %-manifest.yml,$^) \
		$(filter %-$(_processed).md,$^) -o $@

DISTFILES += $(HTMLS)

VIRTUALSCREENS := $(call pattern_list,$(SOURCES),.$(_screen))

.PHONY: $(VIRTUALSCREENS)
$(VIRTUALSCREENS): %.$(_screen): %-$(_screen).pdf %-manifest.yml

MANIFESTS := $(call pattern_list,$(SOURCES),-manifest.yml)
$(MANIFESTS): %-manifest.yml: $(CASILEDIR)/casile.yml $(METADATA) $(PROJECTYAML) $$(TARGETYAMLS_$$*)
	# $(YQ) -M -e -s -y 'reduce .[] as $$item({}; . + $$item)' $(filter %.yml,$^) |
	$(PERL) -MYAML::Merge::Simple=merge_files \
			-MYAML -E 'say Dump merge_files(@ARGV)' \
			$(filter %.yml,$^) \
			<(echo 'layouts: [$(subst $( ),$(,),$(strip $(LAYOUTS)))]') \
			<(echo 'versioninfo: "$(call versioninfo,$@)"') \
			<(echo 'urlinfo: "$(call urlinfo,$@)"') |
		$(SED) -e 's/~$$/nil/g;/^--- |/d;$$a...' \
			-e '/text: [[:digit:]]\{10,13\}/{p;s/^\([[:space:]]*\)text: \([[:digit:]]\+\)$$/$(subst /,\/,$(PYTHON)) -c "import isbnlib; print(\\"\1mask: \\" + isbnlib.mask(\\"\2\\"))"/e}' \
			-e '/\(own\|next\)cloudshare: [^"]/s/: \(.*\)$$/: "\1"/' > $@

DISTFILES += $(MANIFESTS)

$(BUILDDIR)/%-manifest.json: %-manifest.yml | $(BUILDDIR)
	$(YQ) . $< > $@

BIOHTMLS := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(SOURCES),-bio.html))
$(BIOHTMLS): $(BUILDDIR)/%-bio.html: %-manifest.yml
	$(YQ) -r '.creator[0].about' $(filter %-manifest.yml,$^) |
		$(PANDOC) -f markdown -t html | head -c -1 > $@

DESHTMLS := $(addprefix $(BUILDDIR)/,$(call pattern_list,$(SOURCES),-description.html))
$(DESHTMLS): $(BUILDDIR)/%-description.html: %-manifest.yml
	$(YQ) -r '.abstract' $(filter %-manifest.yml,$^) |
		$(PANDOC) -f markdown -t html | head -c -1 > $@

$(BUILDDIR)/%-url.png: $(BUILDDIR)/%-url.svg
	$(MAGICK) \
		$(MAGICKARGS) \
		$< \
		-bordercolor white -border 10x10 \
		-bordercolor black -border 4x4 \
		$@

$(BUILDDIR)/%-url.svg: | $(BUILDDIR)
	$(ZINT) \
			--direct \
			--filetype=svg \
			--scale=10 \
			--barcode=58 \
			--data="$(call urlinfo,$@)" \
		> $@

$(BUILDDIR)/%-$(_barcode).svg: %-manifest.yml | $(BUILDDIR)
	$(ZINT) --direct \
			--filetype=svg \
			--scale=5 \
			--barcode=69 \
			--height=30 \
			--data=$(shell $(_ENV) isbn_format.py $< paperback) |\
		$(SED) -e 's/Helvetica\( Regular\)\?/TeX Gyre Heros/g' \
		> $@

$(BUILDDIR)/%-$(_barcode).png: $(BUILDDIR)/%-$(_barcode).svg
	$(MAGICK) \
		$(MAGICKARGS) \
		$< \
		-bordercolor white -border 10 \
		-font Hack-Regular -pointsize 72 \
		label:" ISBN $(shell $(_ENV) isbn_format.py $*-manifest.yml paperback mask)" +swap -gravity Center -append \
		-bordercolor white -border 0x10 \
		-resize $(call scale,1200)x \
		$@
	if [[ $(shell $(_ENV) isbn_format.py $*-manifest.yml paperback) == 9786056644504 ]]; then
		$(MAGICK) \
			$(MAGICKARGS) \
			$@ \
			-stroke red \
			-strokewidth $(call scale,10) \
			-draw 'line 0,0,%[fx:w],%[fx:h]' \
			$@
	fi

STATSSOURCES := $(call pattern_list,$(SOURCES),-stats)

.PHONY: stats
stats: $(STATSSOURCES)

.PHONY: $(STATSSOURCES)
$(STATSSOURCES): %-stats:
	stats.zsh $* $(STATSMONTHS)

$(BUILDDIR)/repository-lastcommit.ts: $$(newcommits) | $(BUILDDIR)
	touch -d $$($(GIT) log -n1 --format=%cI) $@

$(BUILDDIR)/repository-worklog.sqlite: $(BUILDDIR)/repository-lastcommit.ts
	$(SQLITE3) $@ 'DROP TABLE IF EXISTS commits; CREATE TABLE commits (sha TEXT, author TEXT, date DATE, file TEXT, added INT, removed INT)'
	worklog.zsh | $(SQLITE3) -batch $@

WORKLOGFIELDS := sha AS 'Commit', date AS 'Date', file AS 'Filename', added AS 'Added', removed AS 'Removed'

$(BUILDDIR)/repository-worklog.md: $(BUILDDIR)/repository-worklog.sqlite force
	now="$$(LANG=en_US date +%c)"
	ver="$(call versioninfo,$(PROJECT))"
	export IFS='|'
	$(SQLITE3) $< "SELECT DISTINCT(author) FROM commits" |
		while read author; do
			$(SQLITE3) $< "SELECT DISTINCT strftime('%Y-%m', date) FROM commits WHERE author='$${author}'" |
				while read month; do
					$(SQLITE3) $< "SELECT SUM(added+ -removed) FROM commits WHERE author='$${author}' and strftime('%Y-%m', date)='$${month}'" | read netadded
					[[ $${netadded} -ge 1 ]] || continue
					echo "# Worklog for $${author}"
					echo "## $$(LANG=en_US date +'%B %Y' -d $${month}-01)"
					echo
					echo "Report Generated on $${now} from repository $${ver}."
					echo
					echo "### File Edits"
					echo
					echo "Net characters added: $${netadded}"
					echo
					echo '``` table'
					echo '---\nheader: True\n---'
					$(SQLITE3) --header -csv $< "SELECT $(WORKLOGFIELDS) FROM commits WHERE author='$${author}' AND strftime('%Y-%m', date)='$${month}'"
					echo '```'
					echo
				done
		done |
			$(PANDOC) $(PANDOCARGS) -F pantable -o $@

repository-worklog.pdf: $(BUILDDIR)/repository-worklog.md
	$(PANDOC) $(PANDOCARGS) \
		-t latex \
		--pdf-engine=xelatex \
		-V "mainfont:Libertinus Serif" \
		-V "geometry:landscape" \
		$< -o $@

$(BUILDDIR)/%-$(_verses).json: $(BUILDDIR)/%-$(_processed).md
	$(if $(HEAD),head -n$(HEAD),cat) $< |
		extract_references.js > $@

$(BUILDDIR)/%-$(_verses)-$(_sorted).json: $(BUILDDIR)/%-$(_verses).json
	$(JQ) -M -e 'unique_by(.osis) | sort_by(.seq)' $< > $@

$(BUILDDIR)/%-$(_verses)-$(_text).yml: $(BUILDDIR)/%-$(_verses)-$(_sorted).json
	$(JQ) -M -e -r 'map_values(.osis) | _nwise(100) | join(";")' $< |
		$(XARGS) -iX $(CURL) -s -L "https://sahneleme.incil.info/api/X" |
		# Because yq doesn't --slurp JSON, see https://github.com/kislyuk/yq/issues/56
		$(JQ) -s '[.]' |
		$(YQ) -M -e -y ".[0][] // [] | map_values(.scripture)" |
		$(GREP) -v '^---$$' |
		# Because lua-yaml has a bug parsing non quoted keys...
		$(SED) -e '/^[^ ]/s/^\([^:]\+\):/"\1":/' \
			> $@

POSTCASILEEVAL ?=
ifneq (,$(POSTCASILEEVAL))
$(eval $(POSTCASILEEVAL))
endif

POSTCASILEINCLUDE ?=
ifneq (,$(POSTCASILEINCLUDE))
-include $(POSTCASILEINCLUDE)
endif
