#!/bin/sh
set -e
export RUN_ALL_TESTS=1

#opts=( --parallel )
opts=( )


echo "* Testing without sanitizer"
swift test "${opts[@]}" "${@}"

for sanitizer in address thread undefined; do
    echo "* Testing with '${sanitizer}' sanitizer"
    swift test --sanitize "${sanitizer}" "${opts[@]}" "${@}"
done
