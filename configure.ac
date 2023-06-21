AC_PREREQ([2.69])
AC_INIT([casile], [m4_esyscmd(build-aux/git-version-gen .tarball-version)], [caleb@alerque.com])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIR([build-aux])
AM_INIT_AUTOMAKE([foreign tar-pax dist-xz dist-zip no-dist-gzip color-tests subdir-objects])
AM_SILENT_RULES([yes])

# Build time deps
AC_PROG_AWK
AC_PROG_GREP
AC_PROG_INSTALL
AC_PROG_SED
AX_PROGVAR([cargo])
AX_PROGVAR([cmp])
AX_PROGVAR([stat])
AX_PROGVAR([rustc])
AX_PROGVAR([xargs])

AC_ARG_ENABLE([dependency-checks],
              AS_HELP_STRING([--disable-dependency-checks],
                             [Disable dependency checks]))
AM_CONDITIONAL([DEPENDENCY_CHECKS], [test "x$enable_dependency_checks" != "xno"])

AC_ARG_ENABLE([developer],
              AS_HELP_STRING([--enable-developer],
                             [Check for and enable tooling required only for developers]))
AM_CONDITIONAL([DEVELOPER], [test "x$enable_developer" = "xyes"])

# Add --enable-debug flag to change Rust build mode
AC_ARG_ENABLE(debug,
            AS_HELP_STRING([--enable-debug],[Build Rust code with debugging information [default=no]]),
            [debug_release=$enableval],
            [debug_release=no])

AC_MSG_CHECKING(whether to build Rust code with debugging information)
if test "x$debug_release" = "xyes" ; then
    AC_MSG_RESULT(yes)
    RUST_TARGET_SUBDIR=debug
else
    AC_MSG_RESULT(no)
    RUST_TARGET_SUBDIR=release
fi
AM_CONDITIONAL([DEBUG_RELEASE], [test "x$debug_release" = "xyes"])

AC_ARG_WITH([bash-completion-dir],
    AS_HELP_STRING([--with-bash-completion-dir[=PATH]],
        [Install the bash auto-completion script in this directory. @<:@default=yes@:>@]),
    [],
    [with_bash_completion_dir=yes])
if test "x$with_bash_completion_dir" = "xyes"; then
    PKG_CHECK_MODULES([BASH_COMPLETION], [bash-completion >= 2.0],
                      [BASH_COMPLETION_DIR="`pkg-config --define-variable=datadir=$datadir --variable=completionsdir bash-completion`"],
        [BASH_COMPLETION_DIR="$datadir/bash-completion/completions"])
else
    BASH_COMPLETION_DIR="$with_bash_completion_dir"
fi
AC_SUBST([BASH_COMPLETION_DIR])
AM_CONDITIONAL([ENABLE_BASH_COMPLETION],[test "x$with_bash_completion_dir" != "xno"])

AC_ARG_WITH([fish-completion-dir],
    AS_HELP_STRING([--with-fish-completion-dir[=PATH]],
        [Install the fish auto-completion script in this directory. @<:@default=yes@:>@]),
    [],
    [with_fish_completion_dir=yes])
if test "x$with_fish_completion_dir" = "xyes"; then
    PKG_CHECK_MODULES([FISH_COMPLETION], [fish >= 3.0],
                      [FISH_COMPLETION_DIR="`pkg-config --define-variable=datadir=$datadir --variable=completionsdir fish`"],
        [FISH_COMPLETION_DIR="$datadir/fish/vendor_completions.d"])
else
    FISH_COMPLETION_DIR="$with_fish_completion_dir"
fi
AC_SUBST([FISH_COMPLETION_DIR])
AM_CONDITIONAL([ENABLE_FISH_COMPLETION],[test "x$with_fish_completion_dir" != "xno"])

AC_ARG_WITH([zsh-completion-dir],
    AS_HELP_STRING([--with-zsh-completion-dir[=PATH]],
        [Install the zsh auto-completion script in this directory. @<:@default=yes@:>@]),
    [],
    [with_zsh_completion_dir=yes])
if test "x$with_zsh_completion_dir" = "xyes"; then
    ZSH_COMPLETION_DIR="$datadir/zsh/site-functions"
else
    ZSH_COMPLETION_DIR="$with_zsh_completion_dir"
fi
AC_SUBST([ZSH_COMPLETION_DIR])
AM_CONDITIONAL([ENABLE_ZSH_COMPLETION],[test "x$with_zsh_completion_dir" != "xno"])

AC_SUBST([RUST_TARGET_SUBDIR])

AM_COND_IF([DEPENDENCY_CHECKS], [

    # Run time deps
    AC_PROG_EGREP
    AC_PROG_MKDIR_P
    AX_PROGVAR([bc])
    AX_PROGVAR([diff])
    AX_PROGVAR([cut])
    AX_PROGVAR([curl])
    AX_PROGVAR([entr])
    AX_PROGVAR([epubcheck])
    AX_PROGVAR([fcconflist], [fc-conflist])
    AX_PROGVAR([find])
    AX_PROGVAR([flock])
    AX_PROGVAR([git])
    AX_PROGVAR([gitwarptime], [git-warp-time])
    AX_PROGVAR([gs])
    AX_PROGVAR([hostnamebin], [hostname])
    AX_PROGVAR([inkscape])
    AX_PROGVAR([jq])
    AX_PROGVAR([kindlegen])
    AX_PROGVAR([m4])
    AX_PROGVAR([magick])
    AX_PROGVAR([mdbook])
    AX_PROGVAR([node])
    AX_PROGVAR([pandoc])
    AX_PROGVAR([pcregrep])
    AX_PROGVAR([pdfbook2])
    AX_PROGVAR([pdfinfo])
    AX_PROGVAR([pdfjam])
    AX_PROGVAR([pdftk])
    AX_PROGVAR([pgrep])
    AX_PROGVAR([pwait])
    AX_PROGVAR([podofobox])
    AX_PROGVAR([povray])
    AX_PROGVAR([sassc])
    AX_PROGVAR([sile])
    AX_PROGVAR([sort])
    AX_PROGVAR([sponge])
    AX_PROGVAR([sqlite3])
    AX_PROGVAR([truncate])
    AX_PROGVAR([wc])
    AX_PROGVAR([xcf2png])
    AX_PROGVAR([xvfbrun], [xvfb-run])
    AX_PROGVAR([yarn])
    AX_PROGVAR([yq])
    AX_PROGVAR([zint])
    AX_PROGVAR([zola])
    AX_PROGVAR([zsh])

    AC_MSG_CHECKING(whether pandoc has SILE Writer)
    AS_IF([$PANDOC --list-output-formats | $GREP -qx sile],[
        AC_MSG_RESULT(yes)
    ],[
        AC_MSG_FAILURE([pandoc must have sile writer support])
    ])

    AX_PROG_LUA(5.1, [], [], AC_MSG_ERROR([lua interpreter is required]))
    AX_LUAROCKS_ROCK(yaml)

    AC_PATH_PROG([PERL], [perl])
    AX_PROG_PERL_VERSION([5], [], AC_MSG_ERROR([perl interpreter is required]))
    AX_PERL_MODULE_VERSION([YAML 1.30], [], AC_MSG_ERROR(Need Perl YAML module))
    AX_PERL_MODULE_VERSION([YAML::Merge::Simple 0.01], [], AC_MSG_ERROR(Need Perl YAML::Merge::Simple module))

    AM_PATH_PYTHON([3.6])
    AX_PYTHON_MODULE(ruamel, true)
    AX_PYTHON_MODULE(isbnlib, true)
    AX_PYTHON_MODULE(pandocfilters, true)

    AX_FONT(Hack)
    AX_FONT(TeX Gyre Heros)
    AX_FONT(Libertinus Serif)
    AX_FONT(Libertinus Serif Display)
    AX_FONT(Libertinus Sans)

    # Developer tooling deps
    AM_COND_IF([DEVELOPER], [
        AX_PROGVAR([black])
        AX_PROGVAR([checkmake])
        AX_PROGVAR([docker])
        AX_PROGVAR([luacheck])
        AX_PROGVAR([ruff])
        AX_PROGVAR([rustfmt])
        AX_PROGVAR([tr])
    ])
])

TRANSFORMED_PACKAGE_NAME="$(printf "$PACKAGE_NAME" | $SED -e "${program_transform_name//\$\$/\$}")"
AC_SUBST([TRANSFORMED_PACKAGE_NAME])

AC_CONFIG_FILES([Makefile])
AC_CONFIG_FILES([rules/casile.mk])
AC_CONFIG_FILES([make-shell.zsh], [chmod +x make-shell.zsh])

AC_DEFUN([AX_SCRIPT], [AC_CONFIG_FILES([scripts/$1], [chmod +x scripts/$1])])

# cd scripts; git ls-files '*.in' | sed -e 's/\.in$//'
AX_SCRIPT([branch2criticmark.zsh])
AX_SCRIPT([casile-entry.zsh])
AX_SCRIPT([cover_title.py])
AX_SCRIPT([diff2marked.zsh])
AX_SCRIPT([extract_references.js])
AX_SCRIPT([figure_dash.pl])
AX_SCRIPT([isbn_format.py])
AX_SCRIPT([italic_reorder.pl])
AX_SCRIPT([lazy_quotes.pl])
AX_SCRIPT([link_verses.js])
AX_SCRIPT([list_related_files.zsh])
AX_SCRIPT([loadchapters.zsh])
AX_SCRIPT([msword_escapes.pl])
AX_SCRIPT([normalize_references.js])
AX_SCRIPT([ordinal_spaces.pl])
AX_SCRIPT([renumber_footnotes.pl])
AX_SCRIPT([reorder_punctuation.pl])
AX_SCRIPT([series_sort.lua])
AX_SCRIPT([smart_quotes.pl])
AX_SCRIPT([split_chapters.zsh])
AX_SCRIPT([split_mdbook_src.zsh])
AX_SCRIPT([stats.zsh])
AX_SCRIPT([toc2breaks.lua])
AX_SCRIPT([unicode_symbols.pl])
AX_SCRIPT([worklog.zsh])

AC_ARG_PROGRAM

AC_OUTPUT
