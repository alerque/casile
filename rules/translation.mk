DEEPLSOURCES := $(addprefix $(BUILDDIR)/deepl/,$(call pattern_list,$(SOURCES),.docx))
DEEPLTRANSLATIONS := $(addprefix $(BUILDDIR)/deepl/,$(call pattern_list,$(SOURCES),.docx))

$(DEEPLTRANSLATIONS): $(BUILDDIR)/deepl/%.docx: %.docx
	$(DEEPL) document --from $(TRANSLATION_SOURCE_LANG) --to $(TRANSLATION_TARGET_LANG) $^ $(@D)
	mv $(@D)/$^ $@

%-deepl_tr.md: TRANSLATION_SOURCE_LANG := en
%-deepl_tr.md: TRANSLATION_TARGET_LANG := tr

%-deepl_tr.md: $(BUILDDIR)/deepl/%.docx
	$(PANDOC) \
		$(PANDOCARGS) \
		$(PANDOCFILTERS) \
		$^ -o $@
