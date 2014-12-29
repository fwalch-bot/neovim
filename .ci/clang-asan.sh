. "$CI_SCRIPTS/common.sh"

sudo pip install cpp-coveralls

if [ "$TRAVIS_OS_NAME" = "linux" ]; then
	clang_version=3.4.2
	clang_suffix=x86_64-unknown-ubuntu12.04.xz
elif [ "$TRAVIS_OS_NAME" = "osx" ]; then
	clang_version=3.5.0
	clang_suffix=macosx-apple-darwin.tar.xz
else
	echo "Unknown OS '$TRAVIS_OS_NAME'."
	exit 1
fi

if [ ! -d /usr/local/clang-$clang_version ]; then
	echo "Downloading clang $clang_version..."
	sudo mkdir /usr/local/clang-$clang_version
	wget -q -O - http://llvm.org/releases/$clang_version/clang+llvm-$clang_version-$clang_suffix \
		| sudo tar xJf - --strip-components=1 -C /usr/local/clang-$clang_version
fi

export CC=/usr/local/clang-$clang_version/bin/clang
symbolizer=/usr/local/clang-$clang_version/bin/llvm-symbolizer

setup_deps x64

export ASAN_SYMBOLIZER_PATH=$symbolizer
export ASAN_OPTIONS="detect_leaks=1:log_path=$tmpdir/asan"
export TSAN_OPTIONS="external_symbolizer_path=$symbolizer:log_path=$tmpdir/tsan"

export UBSAN_OPTIONS="log_path=$tmpdir/ubsan" # not sure if this works

CMAKE_EXTRA_FLAGS="-DTRAVIS_CI_BUILD=ON \
	-DUSE_GCOV=ON \
	-DBUSTED_OUTPUT_TYPE=plainTerminal"

# Build and output version info.
$MAKE_CMD CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DSANITIZE=ON" nvim
build/bin/nvim --version
#
## Run functional tests.
#if ! $MAKE_CMD test; then
#	asan_check "$tmpdir"
#	exit 1
#fi
#asan_check "$tmpdir"
#
## Run legacy tests.
#if ! $MAKE_CMD oldtest; then
#	reset
#	asan_check "$tmpdir"
#	exit 1
#fi
#asan_check "$tmpdir"

# Install neovim and plugins; run Vader tests.
sudo -E $MAKE_CMD install

mkdir -p ~/.nvim/autoload ~/.nvim/bundle
wget -q -O ~/.nvim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
echo 'execute pathogen#infect()' > ~/.nvimrc

add_plugin() {
	git clone --recursive git://github.com/$1/$2 ~/.nvim/bundle/$2
	git -C ~/.nvim/bundle/$2 reset --hard $3
}

remove_plugin() {
	rm -rf ~/.nvim/bundle/$1
}

run_tests() {
	echo "Running Vader tests for $1."
	cd ~/.nvim/bundle/$1
	nvim "+Vader! test*/*.vader"
	asan_check "$tmpdir"
	cd $TRAVIS_BUILD_DIR
}

test_plugin() {
	add_plugin $1 $2 $3
	run_tests $2
	remove_plugin $2
}

## Plugins with failed tests:
# junegunn vim-pseudocl 4417db3eb095350594cd6a3e91ec8b78312ef06b
# junegunn vim-oblique 37a24e58e133561bba0dca8b36d6ef172193571c
#   Dependencies: vim-pseudocl 4417db3eb095350594cd6a3e91ec8b78312ef06b
# junegunn limelight.vim 53887b58391d3b814db0d4c1817e277e35978725
#   Dependencies: seoul256.vim 65a04448c293741c7221ead98849912ec0ab0bb0
# justinmk vim-sneak 4cc476fbf0ed3ef3f08c9a9de417576e4788d06f
#   Dependencies: tpope vim-repeat 5eba0f19c87402643eb8a7e7d20d9d5338fd6d71
# junegunn vim-easy-align 2.9.6
# junegunn vader.vim 4d100399fe3ebddbb4738fc5b409d36686c6382c
# junegunn fzf d38f7a5eb5348859786ff96b96a35eade0e2b0e5
# edkolev erlang-motions.vim e2eca9762b2071437ee7cb15aa774b569c9bbf43

# simplenote.vim requires Python
sudo pip install neovim

add_plugin junegunn vader.vim 4d100399fe3ebddbb4738fc5b409d36686c6382c

test_plugin junegunn vim-after-object ee6e008506434597b89f0e20cf29e236755736f5
test_plugin bruno- vim-alt-mappings 6a719284f7cbad4f0105cb8b2f587114c1189834
test_plugin Wolfy87 vim-enmasse 1.1.1
test_plugin mrtazz simplenote.vim v0.9.1
test_plugin junegunn seoul256.vim 65a04448c293741c7221ead98849912ec0ab0bb0

# Upload code coverage to coveralls.io.
coveralls --encoding iso-8859-1 || echo 'coveralls upload failed.'
