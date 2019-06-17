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

  local A_EXEC="$ALPTRAUM_EXEC"
  [ -n "$A_EXEC" ] || case "$1" in
    gcu:* )
      [ -n "$GCU_REPO_AUTH" ] || GCU_REPO_AUTH='@@guess'
      A_EXEC="$1"; shift;;
  esac

  local GCU_PATH=
  sprout_maybe_clone_gcu || return $?

  if [ -n "$ALPTRAUM_CWD" ]; then
    mkdir --parents -- "$ALPTRAUM_CWD"
    cd -- "$ALPTRAUM_CWD" || return $?
  fi

  sprout_maybe_clone_custom_git_repo || return $?

  case "$A_EXEC" in
    gcu:* )
      [ -d "$GCU_PATH" ] || return 4$(
        echo "E: GCU_PATH is not a directory: '$GCU_PATH'" >&2)
      A_EXEC="$GCU_PATH/with_gcu_rc.sh ${A_EXEC#*:}"
      ;;
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
    openssh-client    # for git+ssh://… repos
    procps            # for custom format "ps"
    sed
    tar
    unzip
    util-linux
    wget
    zip
    '"$ALPTRAUM_EXTRA_PKG" | sed -nre '
    s~\s*#.*$~~
    s~^\s+([a-z])~\1~p
    ' | sort -u) || return $?
  echo

  echo 'Install command aliases:'
  sprout_add_command_alias nodejs node || return $?
  echo
}


sprout_add_command_alias () {
  local WANT_CMD="$1"; shift
  local PROVIDER="$(which "$@" 2>/dev/null | grep -m 1 -Pe '^/')"
  if [ -x "$PROVIDER" ]; then
    ln -vsT -- "$PROVIDER" /usr/bin/"$WANT_CMD" || return $?
  else
    # Message alignment reference: ln -s would print
    # ___"'/usr/bin/$WANT_CMD' -> '…'"
    echo "# skip    $WANT_CMD: found none of [$*]"
  fi
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
  local AUTH="$GCU_REPO_AUTH"
  # ^-- may be configured via $ALP_RC; GCU will later read it from git config

  case "$AUTH" in
    '' ) return 0;;
    @@guess ) sprout_guess_gcu_repo_auth || return $?;;
  esac

  local REPO_NAME='GitLabCIUtilities'
  flowers "Install $REPO_NAME:"
  GCU_PATH="/usr/share/instaffo-util/$REPO_NAME"
  local GCU_UPDATER="$GCU_PATH/force_update_self.sh"
  [ -x "$GCU_UPDATER" ] || git clone "https://${AUTH#\
    }@gitlab.com/Instaffo/Scraping/$REPO_NAME.git" "$GCU_PATH" || return $?
  [ -d ./"$REPO_NAME" ] || ln --symbolic --target-directory=. \
    -- "$GCU_PATH" || return $?
  "$GCU_UPDATER" "$GCU_REPO_BRANCH" || return $?
  echo
}


sprout_guess_gcu_repo_auth () {
  local PW_FN='instaffo_gitlab_ci_utilities_auth.txt'
  AUTH="$(grep -vFe '#' -- \
    ".git/$PW_FN" \
    "$HOME/.config/git/$PW_FN" \
    "$HOME/.$PW_FN" \
    2>/dev/null | grep -Fe : -m 1)"
  [ -n "$AUTH" ] && return 0

  echo "E: failed to guess GCU repo auth" >&2
  return 3
}








[ "$1" = --lib ] && return 0; sprout "$@"; exit $?
