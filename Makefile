# ImplicitCAD Makefile. Build and test Implicitcad.

## This is the makefile if you are running cabal-install 1.24 or later.

## Locations of binaries used when running tests, or generating the images to go along with our README.md.
# The location of stl2ps, from stltools, available from https://github.com/rsmith-nl/stltools/tree/develop
stl2ps=/disk4/faikvm.com/stltools/stltools/stl2ps.py
# The location of convert, from imagemagick
convert=convert
# The location of GHC, used to compile .hs examples.
GHC=ghc
GHCVERSION=$(shell ${GHC} --version | sed "s/.*version //")
ARCHITECTURE=$(shell arch | sed "s/i[3-6]86/i386/" )
# new-style location root. must NOT have trailing slash
BUILDROOT=dist-newstyle/build/${ARCHITECTURE}-linux/ghc-${GHCVERSION}/implicit-0.2.1
EXEBUILDROOT=${BUILDROOT}/x/
TESTBUILDROOT=${BUILDROOT}/t/
BENCHBUILDROOT=${BUILDROOT}/b/

exebin = ${EXEBUILDROOT}/$(1)/build/$(1)/$(1)
exedir = ${EXEBUILDROOT}/$(1)

# The location of the created extopenscad binary, for running shell based test cases.
EXTOPENSCAD=extopenscad
EXTOPENSCADBIN=$(call exebin,${EXTOPENSCAD})
EXTOPENSCADDIR=$(call exedir,${EXTOPENSCAD})
# The location of the implicitsnap binary, which listens for requests via http. The backend of the website.
IMPLICITSNAP=implicitsnap
IMPLICITSNAPBIN=$(call exebin,${IMPLICITSNAP})
IMPLICITSNAPDIR=$(call exedir,${IMPLICITSNAP})
# The location of the benchmark binary, for benchmarking some implicitcad internals.
BENCHMARK=Benchmark
BENCHMARKBIN=$(call exebin,${BENCHMARK})
BENCHMARKDIR=$(call exedir,${BENCHMARK})
# The location of the documentation generator. for documenting (some of) the extopenscad language.
DOCGEN=docgen
DOCGENBIN=$(call exebin,${DOCGEN})
DOCGENDIR=$(call exedir,${DOCGEN})
# The location of the parser benchmark binary, specifically for benchmarking implicitcad's parser.
PARSERBENCH=${BENCHBUILDROOT}/parser-bench/build/parser-bench/parser-bench
PARSERBENCHDIR=${BENCHBUILDROOT}/parser-bench
# The location of the created test binary, for running haskell test cases.
TESTSUITE=${TESTBUILDROOT}/test-implicit/build/test-implicit/test-implicit
TESTSUITEDIR=${TESTBUILDROOT}/test-implicit
# The location of it's source.
TESTFILES=$(shell find tests/ -name '*.hs')

## Options used when calling ImplicitCAD. for testing, and for image generation.
# Enable multiple CPU usage.
# Use the parallel garbage collector.
# spit out some performance statistics.
RTSOPTS=+RTS -N -qg -t
# The resolution to generate objects at. FIXME: what does this mean in human terms? 
RESOPTS=-r 50

SCADOPTS?=-q

# Uncomment for profiling support. Note that you will need to recompile all of the libraries, as well.
#PROFILING= --enable-profiling

## FIXME: escape this right
# Uncomment for valgrind on the examples.
#VALGRIND=valgrind --tool=cachegrind --cachegrind-out-file=$$each.cachegrind.`date +%s`

LIBFILES=$(shell find Graphics -name '*.hs')
LIBTARGET=${BUILDROOT}/build/Graphics/Implicit.o

EXECTARGETS=$(EXTOPENSCADBIN) $(IMPLICITSNAPBIN) $(BENCHMARKBIN) $(TESTSUITE) $(PARSERBENCH) $(DOCGENBIN)
EXECBUILDDIRS=$(EXTOPENSCADDIR) $(IMPLICITSNAPDIR) $(BENCHMARKDIR) $(DOCGENDIR)
TARGETS=$(EXECTARGETS) $(LIBTARGET)

# Mark the below fake targets as unreal, so make will not get choked up if a file with one of these names is created.
.PHONY: build install clean distclean nukeclean docs dist examples tests

# Empty out the default suffix list, to make debugging output cleaner.
.SUFFIXES:

# Allow for us to (ab)use $$* in dependencies of rules.
.SECONDEXPANSION:

# Disable make's default builtin rules, to make debugging output cleaner.
MAKEFLAGS += --no-builtin-rules

# Build implicitcad binaries.
build: $(TARGETS)

# Install implicitcad.
install: build
	cabal install

# Cleanup from using the rules in this file.
clean:
	rm -f Examples/*.stl
	rm -f Examples/*.svg
	rm -f Examples/*.ps
	rm -f Examples/*.png
	rm -f Examples/example[0-9][0-9]
	rm -f Examples/*.hi
	rm -f Examples/*.o
	rm -f Examples/example*.cachegrind.*
	rm -f tests/*.stl
	rm -rf docs/parser.md
	rm -f $(TARGETS)
	rm -rf ${EXECBUILDDIRS} ${PARSERBENCHDIR} ${TESTSUITEDIR}
	rm -f ${BUILDROOT}/build/libHS*
	rm -f ${BUILDROOT}/cache/registration

# Clean up before making a release.
distclean: clean Setup
	./Setup clean
	rm -f Setup Setup.hi Setup.o
	rm -rf dist-newstyle
	rm -f `find ./ -name "*~"`
	rm -f `find ./ -name "\#*\#"`

# Destroy the current user's cabal/ghc environment.
nukeclean: distclean
	rm -rf ~/.cabal/ ~/.ghc/

# Generate documentation.
docs: $(DOCGEN)
	./Setup haddock
	$(DOCGEN) > docs/escad.md

# Upload to hackage?
dist: $(TARGETS)
	./Setup sdist

# Generate examples.
examples: $(EXTOPENSCADBIN)
	cd Examples && for each in `find ./ -name '*scad' -type f | sort`; do { echo $$each ; ../$(EXTOPENSCADBIN) $(SCADOPTS) $$each $(RTSOPTS); } done
	cd Examples && for each in `find ./ -name '*.hs' -type f | sort`; do { filename=$(basename "$$each"); filename="$${filename%.*}"; cd ..; $(GHC) Examples/$$filename.hs -o Examples/$$filename; cd Examples; echo $$filename; $$filename +RTS -t ; } done

# Generate images from the examples, so we can upload the images to our website.
images: examples
	cd Examples && for each in `find ./ -name '*.stl' -type f | sort`; do { filename=$(basename "$$each"); filename="$${filename%.*}"; if [ -e $$filename.transform ] ; then echo ${stl2ps} $$each $$filename.ps `cat $$filename.transform`; else ${stl2ps} $$each $$filename.ps; fi; ${convert} $$filename.ps $$filename.png; } done

# Hspec parser tests.
tests: $(TESTSUITE) $(TESTFILES)
#	cd tests && for each in `find ./ -name '*scad' -type f | sort`; do { ../$(EXTOPENSCADBIN) $$each ${RESOPTS} ${RTSOPTS}; } done
	$(TESTSUITE)

# The ImplicitCAD library.
$(LIBTARGET): $(LIBFILES)
	cabal new-build implicit

# The parser test suite, since it's source is stored in a different location than the other binaries we build:
${TESTBUILDROOT}/test-implicit/build/test-implicit/test-implicit: $(TESTFILES) Setup ${BUILDROOT}/setup-config $(LIBTARGET) $(LIBFILES)
	cabal new-build test-implicit

# Build a binary target with cabal.
${EXEBUILDROOT}/%: programs/$$(word 1,$$(subst /, ,%)).hs Setup ${BUILDROOT}/setup-config $(LIBTARGET) $(LIBFILES)
	cabal new-build $(word 1,$(subst /, ,$*))
	touch $@

# Build a benchmark target with cabal.
${BENCHBUILDROOT}/%: programs/$$(word 1,$$(subst /, ,%)).hs Setup ${BUILDROOT}/setup-config $(LIBTARGET) $(LIBFILES)
	cabal new-build $(word 1,$(subst /, ,$*))

# Prepare to build.
${BUILDROOT}/setup-config: implicit.cabal
	cabal new-update
	cabal new-install --only-dependencies --upgrade-dependencies $(PROFILING)
	cabal new-configure --enable-tests --enable-benchmarks $(PROFILING)

# The setup command, used to perform administrative tasks (haddock, upload to hackage, clean, etc...).
Setup: Setup.*hs ${BUILDROOT}/setup-config $(LIBTARGET)
	$(GHC) -O2 -Wall --make Setup -package Cabal
	touch $@
