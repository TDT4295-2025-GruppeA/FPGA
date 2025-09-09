#!/bin/bash
set -e

# Colors for printing
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
GRAY="\033[0;90m"
NO_COLOR="\033[0m"

# Seperator line between tests
SEPARATOR="----------------------------------------------------------------"

# The source folder relative to the testbench build folder
SRC_FOLDER="../src"
# File containing all source files relative to the testbench build folder
TB_FILES="../tb-files.txt"
# The build folder for the testbenches
BUILD_TB="build_tb"

# Create and enter test build folder to not pollute the main directory
mkdir -p ${BUILD_TB}
cd ${BUILD_TB}

# Load in all source files
SRCS=$(cat ${TB_FILES})
# Remove everything after a '#' (comments)
SRCS=$(echo -e "${SRCS}" | sed 's/#.*//')
# Remove empty lines
SRCS=$(echo "${SRCS}" | sed '/^\s*$/d')
# Prepend the source folder path
SRCS=$(echo "${SRCS}" | sed "s|^|${SRC_FOLDER}/|" )

# Filter out testbench files from sources
TBS=$(echo -e ${SRCS} | grep -E "_tb\.sv$")

# Compile all sources into the work library
# Xsim creates a new folder in the current directory
echo -e "${BLUE}[INFO]${NO_COLOR} Compiling sources..."

echo -e "${GRAY}"
xvlog -sv $SRCS
echo -e "${NO_COLOR}"

# Couters to keep track of passed/failed tests
pass_count=0
fail_count=0

# Elaborate and simulate each testbench
for tb in $TBS; do
    # Get the testbench name without extension
    tb_name=$(basename "$tb" .sv)
    sim_name="${tb_name}_sim"

    # Elaborate
    echo -e "${SEPARATOR}"
    echo -e "${BLUE}[INFO]${NO_COLOR} Elaborating $tb_name..."

    echo -e "${GRAY}"
    xelab -svlog "$tb" -s "$sim_name"
    echo -e "${NO_COLOR}"

    if [ $? -ne 0 ]; then
        echo -e "${RED}[FAIL]${NO_COLOR} $tb_name (elaboration failed)"
        fail_count=$((fail_count + 1))
        continue
    fi

    # Simulate
    echo -e "${BLUE}[INFO]${NO_COLOR} Running $tb_name..."

    echo -e "${GRAY}"
    TB_OUTPUT="$(xsim "$sim_name" --runall | tee /dev/tty)"
    echo -e "${NO_COLOR}"


    if echo $TB_OUTPUT | grep -q "Error:"; then
        echo -e "${RED}[FAIL]${NO_COLOR} $tb_name (simulation errors)"
        fail_count=$((fail_count + 1))
    else
        echo -e "${GREEN}[PASS]${NO_COLOR} $tb_name"
        pass_count=$((pass_count + 1))
    fi

done

# Print summary
if [ $fail_count -eq 0 ]; then
    SUMMARY_PREFIX="${GREEN}[ALL PASSED]${NO_COLOR}"
elif [ $pass_count -eq 0 ]; then
    SUMMARY_PREFIX="${RED}[ALL FAILED]${NO_COLOR}"
else
    SUMMARY_PREFIX="${YELLOW}[SOME FAILED]${NO_COLOR}"
fi

echo -e "${SEPARATOR}"
echo -e "${SUMMARY_PREFIX} Passed: $pass_count | Failed: $fail_count | Total: $((pass_count+fail_count))"

# Exit with error code if any test failed
if [ $fail_count -ne 0 ]; then
    exit 1
fi
