# Utility variables for later, http://blog.jgc.org/2007/06/escaping-comma-and-space-in-gnu-make.html
, := ,
space := $() $()
$(space) := $() $()
lparen := (
rparen := )

# Utility functions for simplifying per-project makefiles
depend_font = fc-match "$1" family | $(GREP) -qx "$1"
require_pubdir = $(and $(filter-out true,$(DRAFT)),$(or $(strip $(PUBDIR)),$(error Required PUBDIR not set)))

# Assorted utility functions for juggling information about books
mockupbase = $(if $(filter $(MOCKUPSOURCES),$(call parse_bookid,$1)),$(subst $(call parse_bookid,$1),$(MOCKUPBASE),$1),$1)
pagecount = $(shell $(PDFINFO) $(call mockupbase,$1) | $(AWK) '$$1 == "Pages:" {printf "%.0f", $$2 * $(MOCKUPFACTOR)}' || echo 0)
pagew = $(shell $(PDFINFO) $(call mockupbase,$1) | $(AWK) '$$1$$2 == "Pagesize:" {print $$3}' || echo 0)
pageh = $(shell $(PDFINFO) $(call mockupbase,$1) | $(AWK) '$$1$$2 == "Pagesize:" {print $$5}' || echo 0)
spinemm = $(shell echo "$(call pagecount,$1) * $(PAPERWEIGHT) / 1000 + 1 " | $(BC))
mmtopx = $(shell echo "$1 * $(HIDPI) * 0.0393701 / 1" | $(BC))
mmtopm = $(shell echo "$1 * 96 * .0393701 / 1" | $(BC))
mmtopt = $(shell echo "$1 * 2.83465 / 1" | $(BC))
width = $(shell $(IDENTIFY) -density $(HIDPI) -format "%[fx:w]" $1)
height = $(shell $(IDENTIFY) -density $(HIDPI) -format "%[fx:h]" $1)
parse_layout = $(foreach WORD,$1,$(call parse_papersize,$(WORD))-$(call parse_binding,$(WORD)))
strip_layout = $(filter-out $1,$(foreach PAPERORBINDING,$(PAPERSIZES) $(BINDINGS),$(subst -$(PAPERORBINDING),,$1)))
parse_papersize = $(or $(filter $(PAPERSIZES),$(subst -, ,$(basename $1))),)
strip_papersize = $(filter-out $1,$(foreach PAPERSIZE,$(PAPERSIZES),$(subst -$(PAPERSIZE),,$1)))
parse_binding = $(or $(filter $(BINDINGS),$(subst -, ,$(basename $1))),)
strip_binding = $(filter-out $1,$(foreach BINDING,$(BINDINGS),$(subst -$(BINDING),,$1)))
parse_edits = $(foreach WORD,$1,$(subst $(space),-,$(or $(filter $(EDITS),$(subst -, ,$(basename $(WORD)))),)))
strip_edits = $(foreach WORD,$1,$(filter-out $(WORD),$(foreach EDIT,$(EDITS),$(subst -$(EDIT),,$(WORD)))))
parse_bookid = $(firstword $(subst -, ,$(basename $1)))
series_sort = $(shell PROJECT=$(PROJECT) SORTORDER=$(SORTORDER) series_sort.lua $1)
metainfo = $(shell $(YQ) -r '$1' < $(PROJECTYAML))
isbntouid = $(call cachevar,$1,uuid,$(basename $(notdir $(shell $(GREP) -l $1 $(YAMLSOURCES)))))
isbnmask = $(call cachevar,$1,mask,$(shell $(PYTHON) -c "import isbnlib; print(isbnlib.mask('$1'))"))
ebookisbn = $(call cachevar,$1,ebook,$(or $(shell $(YQ) -r '.identifier[]? | select(.key == "ebook"    ).text' $1.yml),$(call printisbn,$1)))
printisbn = $(call cachevar,$1,print,$(shell $(YQ) -r '.identifier[]? | select(.key == "paperback").text' $1.yml))
ebooktoprint = $(call cachevar,$1,ep,$(call printisbn,$(call isbntouid,$1)))
povtomagick = $(subst 1,255,$(subst >,$(rparen),$(subst <,$(lparen),$(1))))

# Utility to modify recursive variables, see http://stackoverflow.com/a/36863261/313192
prepend = $(eval $(1) = $(2)$(value $(1)))
append = $(eval $(1) = $(value $(1))$(2))

reverse = $(if $(wordlist 2,2,$(1)),$(call reverse,$(wordlist 2,$(words $(1)),$(1))) $(firstword $(1)),$(1))

uniq = $(if $1,$(firstword $1) $(call uniq,$(filter-out $(firstword $1),$1)))

cachevar = $(or $($(1)_$(2)_cache),$(eval $(1)_$(2)_cache := $3),$($(1)_$(2)_cache))

# Making lists of possible targets is tedious syntax, but just using pattern
# rules means the targets are not extendible. By dynamically generating names by
# iterating over all possible combinations of an arbitrary sequence of lists
# we get a lot more flexibility and keeps the lists easy to write.
pattern_list = $(call uniq,$(and $(or $(and $5,$4,$3,$2,$1),$(and $(4),$(3),$(2),$(1)),$(and $(3),$(2),$(1)),$(and $(2),$(1))),$(if $(and $(1),$(2)),,$(foreach A,$(1),$(A)))$(if $(and $(2),$(3)),,$(foreach A,$(1),$(foreach B,$(2),$(A)$(B))))$(if $(and $(3),$(4)),,$(foreach A,$(1),$(foreach B,$(2),$(foreach C,$(3),$(A)-$(B)$(C)))))$(if $(and $(4),$(5)),,$(foreach A,$(1),$(foreach B,$(2),$(foreach C,$(3),$(foreach D,$(4),$(A)-$(B)-$(C)$(D))))))))
join_with = $(subst $(space),$1,$(strip $2))

# String i18n l10n functions
localize = $(foreach WORD,$1,$(or $(_$(WORD)),$(WORD)))
unlocalize = $(foreach WORD,$1,$(or $(__$(WORD)),$(WORD)))

# Geometry file dependency functions
newgeometry = $(shell $(GREP) -sq hidpi=$(HIDPI) $1 || echo force)
newcommits = $(shell test $$($(GIT) log -n1 --format=%ct)0 -gt $$(stat -c %Y $@ 2>/dev/null)0 && echo force)
geometrybase = $(and $(filter-out $(FAKEPAPERSIZES),$(call parse_papersize,$1)),$(filter-out $(UNBOUNDLAYOUTS),$(call parse_layout,$1)),$*.pdf) $(_geometry)-$(call parse_papersize,$1).pdf
geometryfile = $(call parse_bookid,$@)-$(call parse_papersize,$@)-$(or $(call parse_binding,$@),$(_print))-$(_geometry).sh
sourcegeometry = source $(filter %-$(_geometry).sh,$^ $|)
dump = $(warning DUMP: $1)

define ci_setup ?=
	cat -
endef

define addtopub ?=
	$(DRAFT) && rm -f $(PUBDIR)/$@ || ln -f $@ $(PUBDIR)/$@
endef

# If building in draft mode, scale resolutions down for quick builds
define scale ?=
$(strip $(shell $(DRAFT) && echo $(if $2,$2,"($1 + $(SCALE) - 1) / $(SCALE)" | $(BC)) || echo $1))
endef

define time_warp ?=
	cd $1
	$(GIT) update-index --refresh --ignore-submodules ||:
	$(GIT) diff-index --quiet --cached HEAD
	$(GIT) ls-files |
		while read file; do
			ts=$$($(GIT) log -n1 --pretty=format:%cI -- $$file)
			$(GIT) diff-files --quiet -- $$file || continue
			touch -d "$$ts" -- $$file
		done
endef

define versioninfo ?=
$(shell
	echo -en "$(call parse_bookid,$1)@$(subst $(call parse_bookid,$1)/,,$(or $(TAG),$(BRANCH)))-"
	if [[ -n "$(TAG)" ]]; then
		$(GIT) describe --always --dirty=* | cut -d/ -f2 | xargs echo -en
	elif [[ "$(BRANCH)" == master ]]; then
		$(GIT) describe --always --tags --dirty=* | cut -d/ -f2 | xargs echo -en
	else
		$(GIT) rev-list --boundary $(PARENT)..HEAD | $(GREP) -v - | wc -l | xargs -iX echo -en "X-"
		$(DIFF) && echo -en "$$($(GIT) rev-parse --short $(PARENT))→"
		$(GIT) describe --always --dirty=* | cut -d/ -f2 | xargs echo -en
	fi)
endef

define find ?=
$(shell
	$(FIND) $(PROJECTDIR) \
			-maxdepth 2 \
			-name '$1' \
			$(foreach PATH,$(shell $(GIT) submodule | $(AWK) '{print $$2}'),-not -path '*/$(PATH)/*') |
			$(GREP) -f <($(GIT) ls-files | $(SED) -e 's/$$/$$/;s#^#./#') |
		xargs echo)
endef

define munge ?=
	: $${SKIPM4:=true}
	$(GIT) diff-index --quiet --cached HEAD || exit 1 # die if anything already staged
	for f in $1; do
		$${SKIPM4} && $(GREP) -q "esyscmd" $$f && continue # skip anything with m4 macros
		$(GIT) diff-files --quiet -- $$f || exit 1 # die if this file has uncommitted changes
		$2 < $$f | sponge $$f
		$(GIT) add -- $$f
	done
	$(GIT) diff-index --quiet --cached HEAD || $(GIT) commit -m "[auto] $3"
endef

define find_and_munge ?=
	$(warning Using obsolete combined find_and_munge command, please migrate to separate commands)
	$(GIT) diff-index --quiet --cached HEAD || exit 1 # die if anything already staged
	$(FIND) $(PROJECTDIR) -maxdepth 2 -name '$1' $(foreach PATH,$(shell $(GIT) submodule | $(AWK) '{print $$2}'),-not -path '*/$(PATH)/*') |
		$(GREP) -f <($(GIT) ls-files | $(SED) -e 's/$$/$$/;s#^#./#') |
		while read f; do
			$(GREP) -q "esyscmd.*loadchapters.zsh" $$f && continue # skip compilations that are mostly M4
			$(GIT) diff-files --quiet -- $$f || exit 1 # die if this file has uncommitted changes
			$2 < $$f | sponge $$f
			$(GIT) add -- $$f
		done
	$(GIT) diff-index --quiet --cached HEAD || $(GIT) commit -m "[auto] $3"
endef

define link_verses ?=
		link_verses.js
endef

define criticToSile ?=
	$(SED) -e 's#{==#\\criticHighlight{#g' -e 's#==}#}#g' \
		-e 's#{>>#\\criticComment{#g'   -e 's#<<}#}#g' \
		-e 's#{++#\\criticAdd{#g'       -e 's#++}#}#g' \
		-e 's#{--#\\criticDel{#g'       -e 's#--}#}#g'
endef

define markdown_hook ?=
	cat -
endef

define pre_sile_markdown_hook ?=
	cat -
endef

define sile_hook ?=
	cat -
endef

define skip_if_tracked ?=
	$(GIT) ls-files --error-unmatch -- $1 2>/dev/null && exit 0 ||:
endef

define skip_if_lazy ?=
	$(LAZY) && $(if $(filter $1,$(MAKECMDGOALS)),false,true) && test -f $1 && { touch $1; exit 0 } ||:
endef

define magick_cover ?=
		-fill none \
		-fuzz 5% \
		-draw 'color 1,1 replace' \
		+write mpr:text \
		\( mpr:text \
			-channel RGBA \
			-morphology "Dilate:%[fx:w/500]" Octagon \
			-channel RGB \
			-negate \
		\) -compose SrcOver -composite \
		\( mpr:text \
			-channel RGBA \
			-morphology "Dilate:%[fx:w/200]" Octagon \
			-resize 25% \
			-blur "0x%[fx:w/200]" \
			-resize 400% \
			-channel A \
			-level 0%,250% \
			-channel RGB \
			-negate \
		\) -compose SrcOver -composite \
		\( mpr:text \
		\) -compose SrcOver -composite
endef

define magick_background_cover ?=
	$(call magick_background)
endef

define magick_background_binding ?=
	$(call magick_background)
endef

define magick_background ?=
	xc:DarkGray
endef

define magick_background_filter ?=
	-normalize
endef

define magick_border ?=
	-fill none -strokewidth 1 \
	$(shell $(DRAFT) && echo -n '-stroke gray50' || echo -n '-stroke transparent') \
	-draw "rectangle $$bleedpx,$$bleedpx %[fx:w-$$bleedpx],%[fx:h-$$bleedpx]" \
	-draw "rectangle %[fx:$$bleedpx+$$pagewpx],$$bleedpx %[fx:w-$$bleedpx-$$pagewpx],%[fx:h-$$bleedpx]"
endef

define magick_emblum ?=
	-gravity South \
	\( -background none \
		$1 \
		-resize "%[fx:min($$spinepx/100*(100-$$spinemm),$(call mmtopx,12))]"x \
		$(call magick_sembol_filter) \
		-splice "x%[fx:$(call mmtopx,5)+$$bleedpx]" \
	\) -compose SrcOver -composite
endef

define magick_sembol_filter ?=
endef

define magick_logo ?=
	-gravity SouthWest \
	\( -background none \
		$1 \
		$(call magick_logo_filter) \
		-resize $(call mmtopx,30)x \
		-splice "%[fx:$$bleedpx+$$pagewpx*15/100]x%[fx:$$bleedpx+$(call mmtopx,10)]" \
	\) -compose SrcOver -composite
endef

define magick_logo_filter ?=
endef

define magick_barcode ?=
	-gravity SouthEast \
	\( -background white \
		$1 \
		-resize $(call mmtopx,30)x \
		-bordercolor white \
		-border $(call mmtopx,2) \
		-background none \
		-splice "%[fx:$$bleedpx+$$pagewpx+$$spinepx+$$pagewpx*15/100]x%[fx:$$bleedpx+$(call mmtopx,10)]" \
	\) -compose SrcOver -composite
endef

define magick_crease ?=
	-stroke gray95 -strokewidth $(call mmtopx,0.5) \
	\( -size $${pagewpx}x$${pagehpx} -background none xc: -draw "line %[fx:$1$(call mmtopx,8)],0 %[fx:$1$(call mmtopx,8)],$${pagehpx}" -blur 0x$(call scale,$(call mmtopx,0.2)) -level "0x40%!" \) \
	-compose ModulusAdd -composite
endef

define magick_fray ?=
	\( +clone \
		-alpha Extract \
		-virtual-pixel black \
		-spread 2 \
		-blur 0x4 \
		-threshold 20% \
		-spread 2 \
		-blur 0x0.7 \
	\) -alpha Off -compose CopyAlpha -composite
endef

define magick_emulateprint ?=
	+level 0%,95%,1.6 \
	-modulate 100,75
endef

define magick_printcolor ?=
	-modulate 100,140 \
	+level 0%,110%,0.7
endef

define pagetopng ?=
	$(MAGICK) \
		$(MAGICKARGS) \
		-density $(HIDPI) \
		-background white \
		"$<[$$(($1-1))]" \
		-flatten \
		-colorspace RGB \
		-crop $${pagewpx}x$${pagehpx}+$${trimpx}+$${trimpx}! \
		$@
endef

define povray ?=
	headers=$$(mktemp povXXXXXX.inc)
	cat <<- EOF < $2 < $3 > $$headers
		#version 3.7;
		#declare SceneLight = $(SCENELIGHT);
		global_settings { assumed_gamma 1.0 }
	EOF
	while pgrep povray > /dev/null; do sleep 2.5; done
	$(POVRAY) $(POVFLAGS) -I$1 -HI$$headers -W$5 -H$6 -Q$(call scale,11,4) -O$4
	rm $$headers
endef

define pov_crop ?=
	\( +clone \
		-virtual-pixel Edge \
		-fuzz 1% \
		-trim \
		-set option:fuzzy_trim "%[fx:w]x%[fx:h]+%[fx:page.x]+%[fx:page.y]" \
		+delete \
	\) \
	-crop "%[fuzzy_trim]" +repage \
	-background transparent \
	-gravity Center \
	-extent  "%[fx:asp = (w/h <= 3/4 ? 3/4 : 4/3); w/h <= asp ? h*asp : w]x" \
	-extent "x%[fx:asp = (w/h <= 3/4 ? 3/4 : 4/3); w/h >= asp ? w/asp : h]" \
	-resize $1 -resize 50%
endef

define split_chapters ?=
	$(GIT) diff-index --quiet --cached HEAD || exit 1 # die if anything already staged
	$(GIT) diff-files --quiet -- $1 || exit 1 # die if this file has uncommitted changes
	$(GREP) -q 'esyscmd.*cat' $1 && exit 1 # skip if the source is aready a compilation
	split_chapters.zsh $1
	$(GIT) diff-index --quiet --cached HEAD || $(GIT) commit -m "[auto] Split $1 into one file per chapter"
endef

define magick_fragment_cover ?=
endef

define magick_fragment_front ?=
endef

define magick_fragment_back ?=
endef

define magick_fragment_spine ?=
endef

define magick_binding ?=
endef

define geometry_extras ?=
endef

# vim: ft=make
