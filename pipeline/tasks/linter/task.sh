#!/bin/sh

set -e

npm i
./go "linter-${TARGET}"
