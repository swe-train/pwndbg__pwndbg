#!/bin/bash

set -o errexit

help_and_exit() {
    echo "Usage: ./lint.sh [-f|--fix]"
    echo "  -f,  --fix         fix issues if possible"
    exit 1
}

if [[ $# -gt 1 ]]; then
    help_and_exit
fi

FIX=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -f | --format)
            FIX=1
            shift
            ;;
        *)
            help_and_exit
            ;;
    esac
done

# Use Python virtual env for all programs used here
if [[ -z "${PWNDBG_VENV_PATH}" ]]; then
    PWNDBG_VENV_PATH="./.venv"
fi

source "${PWNDBG_VENV_PATH}/bin/activate"

set -o xtrace

LINT_FILES="pwndbg tests *.py"
LINT_TOOLS="isort black ruff vermin mypy"

if ! type ${LINT_TOOLS} &> /dev/null; then
    PIP_CMD="pip install -Ur dev-requirements.txt"
    echo "Missing one of the following tools: ${LINT_TOOLS}"
    echo "Running '${PIP_CMD}'"

    $PIP_CMD
fi

call_shfmt() {
    local FLAGS=$1
    if [ -x "$(command -v shfmt)" ]; then
        local SHFMT_FILES=$(find . -name "*.sh" -not -path "./.venv/*")
        # Indents are four spaces, binary ops can start a line, indent switch cases,
        # and allow spaces following a redirect
        shfmt ${FLAGS} -i 4 -bn -ci -sr -d ${SHFMT_FILES}
    else
        echo "shfmt not installed, skipping"
    fi
}

if [[ $FIX == 1 ]]; then
    isort ${LINT_FILES}
    black ${LINT_FILES}
    ruff check --fix --output-format=full ${LINT_FILES}
    call_shfmt -w
else
    isort --check-only --diff ${LINT_FILES}
    black --check --diff ${LINT_FILES}
    ruff check --output-format=full ${LINT_FILES}
    call_shfmt
fi

# Checking minimum python version
vermin -vvv --no-tips -t=3.8- --violations ./pwndbg/

mypy pwndbg
