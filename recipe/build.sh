#! /usr/bin/bash
set -eux

chmod +x configure

# ThePEG uses std::mem_fun and friends, removed in C++17. libc++ keeps them
# behind these macros; libstdc++ still ships them, so Linux is unaffected.
# It also uses std::insert_iterator without <iterator>, which libc++ does
# not pull in through other headers.
if [[ "$(uname)" == "Darwin" ]]; then
  export CXXFLAGS="${CXXFLAGS} -D_LIBCPP_ENABLE_CXX17_REMOVED_BINDERS -D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION -include iterator"
  # ThePEG's plugin libraries take ThePEG's own symbols from the process that
  # loads them, which Linux allows by default and macOS only when asked.
  export LDFLAGS="${LDFLAGS} -Wl,-undefined,dynamic_lookup"
fi

NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu)

./configure \
  --prefix="${PREFIX}" \
  --with-gsl="${PREFIX}" \
  --with-lhapdf="${PREFIX}" \
  --with-fastjet="${PREFIX}" \
  --with-zlib="${PREFIX}"

make -j"${NPROC}"
make install

# conda-build flags fastjet's lib/libfastjetcontribfragile.so.0 as
# "deleted" during this install -- root-caused to a pre-existing
# fastjet-feedstock bug: it's a dangling symlink shipped by fastjet's
# own build.sh (-> libfastjetcontribfragile.so, a file that was never
# actually installed), already non-functional before this build ever
# touched it. Harmless here; the real fix belongs in fastjet-feedstock.
#
# .la files are dead weight in a conda env (dynamic linking doesn't
# need them) and are a known source of this exact class of
# cross-package libtool interference -- strip ThePEG's own, matching
# the upstream herwig-bootstrap script's own deletelibtool() step.
find "${PREFIX}/lib" "${PREFIX}/lib64" -maxdepth 1 -name '*.la' -delete 2>/dev/null || true
