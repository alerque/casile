set ignore-comments := true
set shell := ["zsh", "+o", "nomatch", "-ecu"]
set unstable := true
set script-interpreter := ["zsh", "+o", "nomatch", "-eu"]

_default:
    @just --list --unsorted

nuke-n-pave:
    git clean -dxff -e .husky -e .fonts -e .sources -e node_modules -e target -e completions
    ./bootstrap.sh

dev-conf: nuke-n-pave
    ./configure --enable-developer-mode --enable-debug
    make

rel-conf: nuke-n-pave
    ./configure --enable-developer-mode
    make

perfect:
    make check lint

restyle:
    git ls-files '*.lua' '*.lua.in' '*.rockspec.in' .busted .luacov .luacheckrc build-aux/config.ld | xargs stylua --respect-ignores
    git ls-files '*.rs' '*.rs.in' | xargs rustfmt --edition 2021 --config skip_children=true
    git ls-files '*.py' '*.py.in' | xargs ruff check --fix
    git ls-files '*.py' '*.py.in' | xargs ruff format
    git ls-files '*.toml' | xargs taplo format

[doc('Block execution if Git working tree isn’t pristine.')]
[private]
pristine:
    # Ensure there are no changes in staging
    git diff-index --quiet --cached HEAD || exit 1
    # Ensure there are no changes in the working tree
    git diff-files --quiet || exit 1

[doc('Block execution if we don’t have access to private keys.')]
[private]
keys:
    gpg -a --sign > /dev/null <<< "test"

cut-release type: pristine
    make release RELTYPE={{ type }}

release semver: pristine
    git describe HEAD --tags | grep -Fx 'v{{ semver }}'
    git push --atomic upstream master v{{ semver }}
    git push --atomic origin master v{{ semver }}

post-release semver: keys
    gh release download --clobber v{{ semver }}
    ls casile-{{ semver }}.{zip,tar.zst} casile-vendored-crates-{{ semver }}.tar.zst | xargs -n1 gpg -a --detach-sign
    gh release upload v{{ semver }} sile*-{{ semver }}.asc
