#!/usr/bin/env bash

cp /usr/share/docker-internal/.gitlint.yaml $1
cd $1
git-lint --last-commit
git-lint --last-commit > lint_output