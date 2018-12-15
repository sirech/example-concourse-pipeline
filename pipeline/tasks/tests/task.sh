#!/bin/sh

set -e

yarn
./go "test-${TARGET}"
