#!/bin/sh
# -*- coding: utf-8, tab-width: 2 -*-
#
# !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !!
#
#   This script's purpose is to ensure a sane shell environment.
#   Thus, initially we must assume a very dumb shell and almost no tools.
#
# !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !!

# Canot use "function" keyword because dash doesn't support that.

sprout () {
  local LANG=en_US.UTF-8  # make error messages search engine-friendly
  export LANG
  local LANGUAGE="$LANG"
  export LANGUAGE
  local ALP_RC='.gitlab-alptraum.rc'
  [ ! -f "$ALP_RC" ] || . ./"$ALP_RC" || return $?

  sprout_alpine_sanity || return $?

  local GCU_PATH=
  sprout_maybe_clone_gcu || return $?

  if [ -n "$ALPTRAUM_CWD" ]; then
    mkdir --parents -- "$ALPTRAUM_CWD"
    cd -- "$ALPTRAUM_CWD" || return $?
  fi

  sprout_maybe_clone_custom_git_repo || return $?

  local A_EXEC="$ALPTRAUM_EXEC"
  [ -n "$A_EXEC" ] || case "$1" in
    gcu:* ) A_EXEC="$1"; shift;;
  esac
  case "$A_EXEC" in
    gcu:* ) A_EXEC="$GCU_PATH/with_gcu_rc.sh ${A_EXEC#*:}";;
  esac

  local CU_MSG="Godspeed! $A_EXEC $*" CU_TRIM=
  for CU_TRIM in dumb shell is dumb; do CU_MSG="${CU_MSG% }"; done
  flowers "$CU_MSG"
  echo
  exec $A_EXEC "$@"
}


flowers () { echo "✿❀❁✿❀❁ $* ❁❀✿❁❀✿"; }


sprout_alpine_sanity () {
  local BUSY="$(which busybox 2>/dev/null)"
  if [ -x /bin/bash ]; then
    if [ /bin/bash -ef "$BUSY" ]; then
      echo "D: Found a busybox bash. That's fishy."
    else
      return 0
    fi
  fi

  [ -x /sbin/apk ] || return 4$(
    echo "E: $FUNCNAME: no sane bash, no apk => giving up." >&2)

  flowers "Sprout a sane shell environment:"
  apk update || return $?
  apk add $(echo '
    bash
    binutils
    coreutils
    findutils
    git
    grep
    moreutils
    sed
    openssh-client    # for git+ssh://… repos
    util-linux
    wget
    ' | sed -nre '
    s~\s*#.*$~~
    s~^\s+([a-z])~\1~p
    ') || return $?
  echo
}


sprout_maybe_clone_custom_git_repo () {
  local REPO="$ALPTRAUM_CLONE_REPO"
  [ -n "$REPO" ] || return 0
  flowers "Clone your git repo:"
  local INTO="${ALPTRAUM_CLONE_INTO:-.}"
  git clone "$REPO" "$INTO" || return $?
  cd -- "$INTO" || return $?
  echo
}


sprout_maybe_clone_gcu () {
  [ -n "$GCU_REPO_AUTH" ] || return 0
  # ^-- may be configured via $ALP_RC; GCU will later read it from git config
  local REPO_NAME='GitLabCIUtilities'
  flowers "Install $REPO_NAME:"
  GCU_PATH="/usr/share/instaffo-util/$REPO_NAME"
  export GCU_PATH
  local GCU_UPDATER="$GCU_PATH/force_update_self.sh"
  [ -x "$GCU_UPDATER" ] || git clone "https://${GCU_REPO_AUTH#\
    }@gitlab.com/Instaffo/Scraping/$REPO_NAME.git" "$GCU_PATH" || return $?
  [ -d ./"$REPO_NAME" ] || ln --symbolic --target-directory=. \
    -- "$GCU_PATH" || return $?
  "$GCU_UPDATER" "$GCU_REPO_BRANCH" || return $?
  echo
}








[ "$1" = --lib ] && return 0; sprout "$@"; exit $?