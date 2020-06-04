#!/bin/bash -e
cd "$( dirname "${BASH_SOURCE[0]}" )"
clojure -m uberdeps.uberjar --deps-file ../server/deps.edn --target ../target/rhombeus.jar
