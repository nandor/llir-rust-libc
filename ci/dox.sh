#!/usr/bin/env sh

# Builds documentation for all target triples that we have a registered URL for
# in liblibc. This scrapes the list of triples to document from `src/lib.rs`
# which has a bunch of `html_root_url` directives we pick up.

set -ex

TARGET_DOC_DIR="target/doc"
README="README.md"
PLATFORM_SUPPORT="platform-support.md"

rm -rf "$TARGET_DOC_DIR"
mkdir -p "$TARGET_DOC_DIR"

if ! rustc --version | grep -E "nightly" ; then
    echo "Building the documentation requires a nightly Rust toolchain"
    exit 1
fi

rustup component add rust-src

# List all targets that do currently build successfully:
# shellcheck disable=SC1003
grep '[\d|\w|-]* \\' ci/build.sh > targets
sed -i.bak 's/ \\//g' targets
grep '^[_a-zA-Z0-9-]*$' targets | sort > tmp && mv tmp targets

# Create a markdown list of supported platforms in $PLATFORM_SUPPORT
rm $PLATFORM_SUPPORT || true

printf '### Platform-specific documentation\n' >> $PLATFORM_SUPPORT

while read -r target; do
    echo "documenting ${target}"

    case "${target}" in
        *apple*)
            # FIXME:
            # We can't build docs of apple targets from Linux yet.
            continue
            ;;
        *)
            ;;
    esac

    rustup target add "${target}" || true

    # Enable extra configuration flags:
    export RUSTDOCFLAGS="--cfg freebsd11"

    # If cargo doc fails, then try with unstable feature:
    if ! cargo doc --target "${target}" \
        --no-default-features --features const-extern-fn,extra_traits ; then
        cargo doc --target "${target}" \
        -Z build-std=core,alloc \
        --no-default-features --features const-extern-fn,extra_traits
    fi

    mkdir -p "${TARGET_DOC_DIR}/${target}"
    cp -r "target/${target}/doc" "${TARGET_DOC_DIR}/${target}"

    echo "* [${target}](${target}/doc/libc/index.html)" >> $PLATFORM_SUPPORT
done < targets

# Replace <div class="platform_support"></div> with the contents of $PLATFORM_SUPPORT
cp $README $TARGET_DOC_DIR
line=$(grep -n '<div class="platform_docs"></div>' $README | cut -d ":" -f 1)

{ head -n "$((line-1))" $README; cat $PLATFORM_SUPPORT; tail -n "+$((line+1))" $README; } > $TARGET_DOC_DIR/$README

cp $TARGET_DOC_DIR/$README $TARGET_DOC_DIR/index.md

RUSTDOCFLAGS="--enable-index-page --index-page=${TARGET_DOC_DIR}/index.md -Zunstable-options" cargo doc

# Tweak style
cp ci/rust.css $TARGET_DOC_DIR
sed -ie "8i <link rel=\"stylesheet\" type=\"text/css\" href=\"normalize.css\">" $TARGET_DOC_DIR/index.html
sed -ie "9i <link rel=\"stylesheet\" type=\"text/css\" href=\"rust.css\">" $TARGET_DOC_DIR/index.html

# Copy the licenses
cp LICENSE-* $TARGET_DOC_DIR/
