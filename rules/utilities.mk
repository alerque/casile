NONDISTGOALS = $(filter-out %dist $(DISTDIR)/.% _gha _glc %.env,$(MAKECMDGOALS))

.PHONY: clean
clean:
	rm -rf "$(BUILDDIR)" "$(DISTDIR)" $(call extantfiles,$(DISTFILES))
	# $(GIT) clean -xf $(foreach CONFIG,$(PROJECTCONFIGS),-e $(CONFIG))

.PHONY: dist
dist: $(DISTDIR).zip $(DISTDIR).tar.gz

.PHONY: install-dist
install-dist: $(NONDISTGOALS) | $(DISTDIR)
install-dist: $$(or $$(call extantfiles,$$(DISTFILES)),fail)
	set -o extendedglob
	export VERSION_CONTROL=none
	local files=($(addsuffix ($(hash)qN),$(DISTFILES)))
	$(XARGS) -r $(INSTALL) -m0644 -t "$(DISTDIR)" <<< $${$${(u)files}}
	local dirs=($(addsuffix ($(hash)qN),$(DISTDIRS)))
	$(XARGS) -r -I {} cp -a {} "$(DISTDIR)" <<< $${(F)$${(u)dirs}}

.PHONY: debug
debug:
	echo "ALLLAYOUTS = $(ALLLAYOUTS)"
	echo "ALLTAGS = $(ALLTAGS)"
	echo "BINDINGS = $(BINDINGS)"
	echo "BOUNDLAYOUTS = $(BOUNDLAYOUTS)"
	echo "BRANCH = $(BRANCH)"
	echo "CASILEDIR = $(CASILEDIR)"
	echo "CICONFIG = $(CICONFIG)"
	echo "CITEMPLATE = $(CITEMPLATE)"
	echo "DEBUG = $(DEBUG)"
	echo "DEBUGTAGS = $(DEBUGTAGS)"
	echo "DISTDIR = $(DISTDIR)"
	echo "DISTFILES = $(DISTFILES)"
	echo "DOCUMENTCLASS = $(DOCUMENTCLASS)"
	echo "DOCUMENTOPTIONS = $(DOCUMENTOPTIONS)"
	echo "DRAFT = $(DRAFT)"
	echo "EDITIONS = $(EDITIONS)"
	echo "EDITS = $(EDITS)"
	echo "FAKELAYOUTS = $(FAKELAYOUTS)"
	echo "FAKEPAPERSIZES = $(FAKEPAPERSIZES)"
	echo "FIGURES = $(FIGURES)"
	echo "FONTDIRS = $(FONTDIRS)"
	echo "FORMATS = $(FORMATS)"
	echo "GOALLAYOUTS = $(GOALLAYOUTS)"
	echo "HIGHLIGHT_DIFF = $(HIGHLIGHT_DIFF)"
	echo "ISBNS = $(ISBNS)"
	echo "LANGUAGE = $(LANGUAGE)"
	echo "LAYOUTS = $(LAYOUTS)"
	echo "LUAINCLUDES = $(LUAINCLUDES)"
	echo "LUALIBS = $(LUALIBS)"
	echo "LUASOURCES = $(LUASOURCES)"
	echo "M4MACROS = $(M4MACROS)"
	echo "MAKECMDGOALS = $(MAKECMDGOALS)"
	echo "MAKEFILE_LIST = $(MAKEFILE_LIST)"
	echo "MAKESOURCES = $(MAKESOURCES)"
	echo "MARKDOWNSOURCES = $(MARKDOWNSOURCES)"
	echo "METADATA = $(METADATA)"
	echo "MOCKUPBASE = $(MOCKUPBASE)"
	echo "MOCKUPFACTOR = $(MOCKUPFACTOR)"
	echo "MOCKUPSOURCES = $(MOCKUPSOURCES)"
	echo "PANDOCARGS = $(PANDOCARGS)"
	echo "PAPERSIZES = $(PAPERSIZES)"
	echo "PARENT = $(PARENT)"
	echo "PLAYSOURCES = $(PLAYSOURCES)"
	echo "PROJECT = $(PROJECT)"
	echo "PROJECTCONFIGS = $(PROJECTCONFIGS)"
	echo "PROJECTDIR = $(PROJECTDIR)"
	echo "PROJECTLUA = $(PROJECTLUA)"
	echo "PROJECTVERSION = $(PROJECTVERSION)"
	echo "PUBLISHERDIR = $(PUBLISHERDIR)"
	echo "PUBLISHERLOGO = $(PUBLISHERLOGO)"
	echo "REALLAYOUTS = $(REALLAYOUTS)"
	echo "REALPAPERSIZES = $(REALPAPERSIZES)"
	echo "RENDERED = $(RENDERED)"
	echo "SERIESSCENES = $(SERIESSCENES)"
	echo "SILE = $(SILE)"
	echo "SILEFLAGS = $(SILEFLAGS)"
	echo "SILEPATH = $(SILEPATH)"
	echo "SOURCES = $(SOURCES)"
	echo "TAG = $(TAG)"
	echo "TARGETS = $(TARGETS)"
	echo "UNBOUNDLAYOUTS = $(UNBOUNDLAYOUTS)"
	echo "YAMLSOURCES = $(YAMLSOURCES)"
	echo "urlinfo = $(call urlinfo,$(PROJECT))"
	echo "versioninfo = $(call versioninfo,$(PROJECT))"

# Special dependency to force rebuilds of up to date targets
.PHONY: force
force:;

.PHONY: fail

.PHONY: _gha
_gha:
	echo "::set-output name=DISTDIR::$(DISTDIR)"
	echo "::set-output name=PROJECT::$(PROJECT)"
	echo "::set-output name=VERSION::$(call versioninfo,$(PROJECT))"

.PHONY: _glc
_glc: $(CI_JOB_NAME_SLUG).env

$(CI_JOB_NAME_SLUG).env: $(NONDISTGOALS)
	$(ZSH) << 'EOF' # inception to break out of CaSILE’s make shell wrapper
	export PS4=; set -x ; exec 2> $@ # black magic to output sourcable content
	DISTDIR="$(DISTDIR)"
	PROJECT="$(PROJECT)"
	VERSION="$(call versioninfo,$(PROJECT))"
	EOF

.PHONY: list
list:
	$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2> /dev/null |
		$(AWK) -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' |
		$(SORT) |
		$(EGREP) -v -e '^[^[:alnum:]]' -e '^$@$$' |
		$(XARGS)

.PHONY: upgrade_toolkits
upgrade_toolkits: upgrade_casile

.PHONY: upgrade_repository
upgrade_repository: upgrade_toolkits .gitattributes

.PHONY: upgrade_casile
upgrade_casile:
	$(call munge,$(LUASOURCES),$(SED) -f $(CASILEDIR)/upgrade-lua.sed,Replace old Lua variables and functions with new namespaces)
	$(call munge,$(MAKESOURCES),$(SED) -f $(CASILEDIR)/upgrade-make.sed,Replace old Makefile variables and functions with new namespaces)
	$(call munge,$(YAMLSOURCES),$(SED) -f $(CASILEDIR)/upgrade-yaml.sed,Replace old YAML key names and data formats)
	export SKIPM4=false
	$(call munge,$(MARKDOWNSOURCES),$(SED) -f $(CASILEDIR)/upgrade-markdown.sed,Replace obsolete Markdown syntax)

# Reset file timestamps to git history to avoid unnecessary builds
.PHONY: time_warp
time_warp:
	$(call time_warp,$(PROJECTDIR))

.PHONY: normalize_lua
normalize_lua: $(LUASOURCES)
	$(call munge,$^,$(SED) -e 's/function */function /g',Normalize Lua coding style)

.PHONY: normalize_markdown
normalize_markdown: $(MARKDOWNSOURCES)
	$(call munge,$(filter %.md,$^),msword_escapes.pl,Fixup bad MS word typing habits that Pandoc tries to preserve)
	$(call munge,$(filter %.md,$^),lazy_quotes.pl,Replace lazy double single quotes with real doubles)
	$(call munge,$(filter %.md,$^),figure_dash.pl,Convert hyphens between numbers to figure dashes)
	$(call munge,$(filter %.md,$^),italic_reorder.pl,Fixup italics around names and parethesised translations)
	#(call munge,$(filter %.md,$^),apostrophize_names.pl,Use apostrophes when adding suffixes to proper names)
	$(call munge,$(filter %.md,$^),$(PANDOC) $(PANDOCARGS) $(PANDOCFILTERS) $(subst -smart,+smart,$(PANDOCFILTERARGS)) $(cleanupcriticmarkfrompandoc),Normalize and tidy Markdown syntax using Pandoc)
	$(call munge,$(filter %.md,$^),reorder_punctuation.pl,Cleanup punctuation mark order such as footnote markers)

normalize_markdown: normalize_markdown_$(LANGUAGE)

.PHONY: normalize_markdown_en
normalize_markdown_en: $(filter en/%,$(MARKDOWNSOURCES)) ;

.PHONY: normalize_markdown_tr
normalize_markdown_tr: $(filter tr/%,$(MARKDOWNSOURCES))
	$(call munge,$(filter %.md,$^),ordinal_spaces.pl,Use narrow non-breaking spaces after ordinal numbers)

.PHONY: normalize_references
normalize_references: $(MARKDOWNSOURCES)
	$(call munge,$^,normalize_references.js,Normalize verse references using BCV parser)

.PHONY: normalize
normalize: normalize_lua normalize_markdown normalize_references

split_chapters:
	$(if $(MARKDOWNSOURCES),,exit 0)
	$(foreach SOURCE,$(MARKDOWNSOURCES),$(call split_chapters,$(SOURCE)))

.PHONY: normalize_files
normalize_files: private PANDOCFILTERS = --lua-filter=$(CASILEDIR)/pandoc-filters/titlecase_titles.lua
normalize_files: private PANDOCFILTERS = --lua-filter=$(CASILEDIR)/pandoc-filters/chapterid.lua
normalize_files:
	$(GIT) diff-index --quiet --cached HEAD || exit 1 # die if anything already staged
	$(if $(MARKDOWNSOURCES),,exit 0)
	echo $(MARKDOWNSOURCES) |
		$(PERL) -pne 's/ /\n/g' |
		$(PCREGREP) "$(PROJECTDIR)/($(subst $(space),|,$(strip $(SOURCES))))-.*/" |
		while read src; do
			$(GIT) diff-files --quiet -- $${src} || exit 1 # die if this file has uncommitted changes
			basename $${src} | $(PERL) -pne 's/-.*$$//' | read chapno
			dirname $${src} | read dir
			$(SED) -n '/^#/{s/ı/i/g;p}' $${src} |
				$(PANDOC) $(PANDOCARGS) $(PANDOCFILTERS) $(PANDOCFILTERARGS) | read identifier
				target="$${dir}/$${chapno}-$${identifier}.md"
				[[ $${src} == $${target} ]] || $(GIT) mv "$${src}" "$${target}"
		done
	$(GIT) diff-index --quiet --cached HEAD || $(GIT) commit -m "[auto] Normalize filenames based on chapter ids"

watch:
	$(GIT) ls-files --recurse-submodules |
		$(ENTR) $(ENTRFLAGS) make DRAFT=true LAZY=true $(WATCHARGS)

diff:
	$(GIT) diff --color=always --ignore-submodules --no-ext-diff
	$(GIT) submodule foreach $(GIT) diff --color=always --no-ext-diff
