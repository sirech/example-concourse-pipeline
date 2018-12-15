#!/bin/sh

set -e

npm i
./go "test-${TARGET}"
