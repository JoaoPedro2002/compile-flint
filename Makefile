##########################################################
#  Make file that statically compiles the dependencies.  #
##########################################################
# The sources are downloaded, than unpacked and compiled #
##########################################################


# Dirs
CURR_DIR=$(shell pwd)
OUTPUT_DIR := ${CURR_DIR}/output
SO_OUTPUT_DIR := ${OUTPUT_DIR}/shared
WASM_OUTPUT_DIR := ${OUTPUT_DIR}/wasm

BUILD_DIR := ${CURR_DIR}/build
__dummy := $(shell mkdir -p ${BUILD_DIR} ${SO_OUTPUT_DIR} ${WASM_OUTPUT_DIR})

# Libraries
FLINT_VERSION=3.1.2
FLINT=flint-${FLINT_VERSION}
FLINT_SOURCE=https://flintlib.org/${FLINT}.tar.gz

GMP_VERSION=6.3.0
GMP=gmp-${GMP_VERSION}
GMP_SOURCE=https://gmplib.org/download/gmp/${GMP}.tar.gz

MPFR_VERSION=4.2.1
MPFR=mpfr-${MPFR_VERSION}
MPFR_SOURCE=https://www.mpfr.org/mpfr-current/${MPFR}.tar.gz

# Compile flags
GMP_FLAGS= --enable-shared
MPFR_FLAGS = ${GMP_FLAGS} --with-gmp=${SO_OUTPUT_DIR}
FLINT_FLAGS= ${GMP_FLAGS} --with-gmp=${SO_OUTPUT_DIR} --with-mprf=${SO_OUTPUT_DIR}

# Map to link a library to its source
${MPFR} := MPFR
${FLINT} := FLINT
${GMP} := GMP

COMPILE_MAKE = make -j $(shell expr $(shell nproc) + 1)

EMCONFIGURE := emconfigure ./configure --build i686-pc-linux-gnu --disable-assembly --host=none --prefix=${WASM_OUTPUT_DIR} CFLAGS="-O3 -Wall"
EMMAKE := emmake make -j $(shell expr $(shell nproc) + 1) && emmake make install

.PHONY: all clean libflint libgmp libmpfr

all: ${WASM_OUTPUT_DIR}/libflint.a ${SO_OUTPUT_DIR}/libflint.so

${WASM_OUTPUT_DIR}/libgmp.a: ${BUILD_DIR}/${GMP}/
	cd ${BUILD_DIR}/${GMP}/ && CC_FOR_BUILD=gcc ${EMCONFIGURE} && ${EMMAKE}

${WASM_OUTPUT_DIR}/libmpfr.a: ${WASM_OUTPUT_DIR}/libgmp.a ${BUILD_DIR}/${MPFR}/
	cd ${BUILD_DIR}/${MPFR}/ && CC_FOR_BUILD=gcc ABI=long ${EMCONFIGURE} --with-gmp=${WASM_OUTPUT_DIR} && ${EMMAKE}

${WASM_OUTPUT_DIR}/libflint.a: ${WASM_OUTPUT_DIR}/libmpfr.a ${BUILD_DIR}/${FLINT}/
	cd ${BUILD_DIR}/${FLINT}/ && ${EMCONFIGURE} --with-gmp=${WASM_OUTPUT_DIR} --with-mpfr=${WASM_OUTPUT_DIR} && ${EMMAKE}

${SO_OUTPUT_DIR}/%.so: %
	mv $$(find ${BUILD_DIR} -name $(notdir $@)) $@
	# Update file timestamp to avoid recompilation
	touch $@

libflint: ${BUILD_DIR}/${FLINT}/ ${SO_OUTPUT_DIR}/libmpfr.so
	cd $< && ./configure ${FLINT_FLAGS} && ${COMPILE_MAKE}

libmpfr: ${BUILD_DIR}/${MPFR}/ ${SO_OUTPUT_DIR}/libgmp.so
	cd $< && ./configure ${MPFR_FLAGS} && ${COMPILE_MAKE}

libgmp: ${BUILD_DIR}/${GMP}/
	cd $< && ./configure ${GMP_FLAGS} && ${COMPILE_MAKE}

${BUILD_DIR}/%/: %.tar.gz
	tar -xzf $< -C ${BUILD_DIR}

%.tar.gz:
	wget -q $($($*)_SOURCE) -O $@

clean:
	rm -rf ${BUILD_DIR} ${OUTPUT_DIR}
