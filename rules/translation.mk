deepl/%.md: $(BUILDDIR)/deepl/%.docx
	mkdir -p $(@D)
	$(PANDOC) \
		$(PANDOCARGS) \
		$(PANDOCFILTERS) \
		$^ -o $@

targetlang = $(notdir $(abspath $(dir $1)))
deepldeps = $(call pattern_list,$(shell $(_ENV) list_related_files.zsh srcid $(basename $(notdir $1))),.docx -manifest.yml)

$(BUILDDIR)/deepl/%.docx: $$(call deepldeps,$$@)
	$(YQ) -r '.lang' $(filter %-manifest.yml,$^) | read srclang
	$(DEEPL) document --from "$${srclang}" --to "$(call targetlang,$@)" $< $(@D)
	mv $(@D)/$< $@ ||:
