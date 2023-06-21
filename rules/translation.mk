TRANSLATIONSOURCES := $(addprefix $(BUILDDIR)/deepl/,$(call pattern_list,$(SOURCES),.docx))

$(TRANSLATIONSOURCES): $(BUILDDIR)/deepl/%.docx: %.docx
	$(DEEPL) document --from en --to tr $^ $(@D)

%-tr.md: $(BUILDDIR)/deepl/%.docx
	$(PANDOC) \
		$(PANDOCARGS) \
		$(PANDOCFILTERS) \
		$^ -o $@
