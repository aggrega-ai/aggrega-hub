#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# run-with-git-token.sh — runs a command with a token that git sends to
# github.com, without writing the token anywhere on disk.
#
#   GIT_TOKEN=<token> run-with-git-token.sh <command> [argument...]
#
# The token is read from the environment variable GIT_TOKEN, never from an
# argument. The command runs with git's configuration extended, through the
# GIT_CONFIG_COUNT, GIT_CONFIG_KEY_0 and GIT_CONFIG_VALUE_0 environment
# variables, by an authorization header for https://github.com/. Nothing is
# written to .git/config or to any other file, the header is masked in the
# workflow's log, and the script never prints it. git 2.31 or later reads
# configuration from those variables; an older git is refused before the command
# runs.
#
# A job's checkout does not keep the token it was given, so the steps that push
# call this script and no other step finds the token on disk.
#
# This file is a deliberate copy of the same mechanism in aggrega-cli's release
# workflow, which runs it inline, because each repository's CI runs from its own
# checkout alone. A change to one is made to the other in the same change.

set -euo pipefail
# The header must never reach the log, so tracing stays off even when the caller
# turned it on.
set +x

if [ "$#" -eq 0 ]; then
  echo "run-with-git-token: no command given" >&2
  exit 2
fi
if [ -z "${GIT_TOKEN:-}" ]; then
  echo "run-with-git-token: GIT_TOKEN is empty" >&2
  exit 2
fi

probe="$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=runwithgittoken.probe GIT_CONFIG_VALUE_0=read git config --get runwithgittoken.probe || true)"
if [ "$probe" != read ]; then
  echo "run-with-git-token: $(git --version) does not read configuration from GIT_CONFIG_COUNT, which is how the token reaches git without being written to disk; git 2.31 or later does" >&2
  exit 1
fi

auth="$(printf 'x-access-token:%s' "$GIT_TOKEN" | base64 -w0)"
echo "::add-mask::$auth"
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.https://github.com/.extraheader"
export GIT_CONFIG_VALUE_0="AUTHORIZATION: basic $auth"
unset GIT_TOKEN
exec "$@"
