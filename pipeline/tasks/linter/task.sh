#!/bin/sh

set -e

yarn
./go "linter-${TARGET}"
