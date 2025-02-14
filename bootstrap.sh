#!/bin/bash

#:  @hide_from_man_page
#:  * `vendor-install-ruby` [<target>]
#:
#:  Install Portable Ruby.

onoe() {
  # Check whether stderr is a tty.
  if [[ -n "${HOMEBREW_COLOR}" || (-t 2 && -z "${HOMEBREW_NO_COLOR}") ]]
  then
    echo -ne "\\033[4;31mError\\033[0m: " >&2 # highlight Error with underline and red color
  else
    echo -n "Error: " >&2
  fi
  if [[ $# -eq 0 ]]
  then
    cat >&2
  else
    echo "$*" >&2
  fi
}

odie() {
  onoe "$@"
  exit 1
}

safe_cd() {
  cd "$@" >/dev/null || odie "Failed to cd to """$"*""!"
}

ohai() {
  # Check whether stdout is a tty.
  if [[ -n "${HOMEBREW_COLOR}" || (-t 1 && -z "${HOMEBREW_NO_COLOR}") ]]
  then
    echo -e "\\033[34m==>\\033[0m \\033[1m$*\\033[0m" # blue arrow and bold text
  else
    echo "==> $*"
  fi
}

brew() {
  # This variable is set by bin/brew
  # shellcheck disable=SC2154
  "${HOMEBREW_BREW_FILE}" "$@"
}

if [[ -z "${HOMEBREW_PREFIX}" ]]
then
  odie "HOMEBREW_PREFIX is not set."
fi

HOMEBREW_BREW_FILE="${HOMEBREW_PREFIX}/bin/brew"
HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
HOMEBREW_LIBRARY="${HOMEBREW_REPOSITORY}/Library"

HOMEBREW_PROCESSOR="$(uname -m)"
HOMEBREW_PHYSICAL_PROCESSOR="${HOMEBREW_PROCESSOR}"
HOMEBREW_SYSTEM="$(uname -s)"
# Doesn't need a default case because we don't support other OSs
# shellcheck disable=SC2249
case "${HOMEBREW_SYSTEM}" in
  Linux) HOMEBREW_LINUX="1" ;;
esac
if [[ -z "${HOMEBREW_LINUX}" ]]
then
  odie "This is only supported on Linux."
fi

if [[ -z "${HOMEBREW_CURL}" ]]
then
  # This is set by the user environment.
  # shellcheck disable=SC2154
  HOMEBREW_BREWED_CURL_PATH="${HOMEBREW_PREFIX}/opt/curl/bin/curl"
  if [[ -n "${HOMEBREW_FORCE_BREWED_CURL}" && -x "${HOMEBREW_BREWED_CURL_PATH}" ]] &&
     "${HOMEBREW_BREWED_CURL_PATH}" --version &>/dev/null
  then
    HOMEBREW_CURL="${HOMEBREW_BREWED_CURL_PATH}"
  elif [[ -n "${HOMEBREW_CURL_PATH}" ]]
  then
    HOMEBREW_CURL="${HOMEBREW_CURL_PATH}"
  else
    HOMEBREW_CURL="curl"
  fi
fi

HOMEBREW_LINUX_MINIMUM_GLIBC_VERSION="2.13"
if [[ "${HOMEBREW_PROCESSOR}" == "aarch64" ]]
then
  HOMEBREW_LINUX_MINIMUM_GLIBC_VERSION="2.17"
fi

HOMEBREW_CACHE="${HOMEBREW_CACHE-${XDG_CACHE_HOME-${HOME}/.cache}/Homebrew}"

if [[ -z "${HOMEBREW_GITHUB_PACKAGES_AUTH}" ]]
then
  if [[ -n "${HOMEBREW_DOCKER_REGISTRY_TOKEN}" ]]
  then
    HOMEBREW_GITHUB_PACKAGES_AUTH="Bearer ${HOMEBREW_DOCKER_REGISTRY_TOKEN}"
  elif [[ -n "${HOMEBREW_DOCKER_REGISTRY_BASIC_AUTH_TOKEN}" ]]
  then
    HOMEBREW_GITHUB_PACKAGES_AUTH="Basic ${HOMEBREW_DOCKER_REGISTRY_BASIC_AUTH_TOKEN}"
  else
    HOMEBREW_GITHUB_PACKAGES_AUTH="Bearer QQ=="
  fi
fi

# HOMEBREW_ARTIFACT_DOMAIN, HOMEBREW_ARTIFACT_DOMAIN_NO_FALLBACK, HOMEBREW_BOTTLE_DOMAIN, HOMEBREW_CACHE,
# HOMEBREW_CURLRC, HOMEBREW_DEVELOPER, HOMEBREW_DEBUG, HOMEBREW_VERBOSE are from the user environment
# HOMEBREW_PORTABLE_RUBY_VERSION is set by utils/ruby.sh
# HOMEBREW_LIBRARY, HOMEBREW_PREFIX are set by bin/brew
# HOMEBREW_CURL, HOMEBREW_GITHUB_PACKAGES_AUTH, HOMEBREW_LINUX, HOMEBREW_LINUX_MINIMUM_GLIBC_VERSION, HOMEBREW_MACOS,
# HOMEBREW_PHYSICAL_PROCESSOR, HOMEBREW_PROCESSOR, HOMEBREW_USER_AGENT_CURL are set by brew.sh
# shellcheck disable=SC2154
source "${HOMEBREW_LIBRARY}/Homebrew/utils/lock.sh"
source "${HOMEBREW_LIBRARY}/Homebrew/utils/ruby.sh"

VENDOR_DIR="${HOMEBREW_LIBRARY}/Homebrew/vendor"

# Built from https://github.com/ZhongRuoyu/homebrew-portable-ruby-aarch64-linux.
set_ruby_variables() {
  # Handle the case where /usr/local/bin/brew is run under arm64.
  # It's a x86_64 installation there (we refuse to install arm64 binaries) so
  # use a x86_64 Portable Ruby.
  if [[ -n "${HOMEBREW_MACOS}" && "${VENDOR_PHYSICAL_PROCESSOR}" == "arm64" && "${HOMEBREW_PREFIX}" == "/usr/local" ]]
  then
    ruby_PROCESSOR="x86_64"
    ruby_OS="darwin"
  else
    ruby_PROCESSOR="${VENDOR_PHYSICAL_PROCESSOR}"
    if [[ -n "${HOMEBREW_MACOS}" ]]
    then
      ruby_OS="darwin"
    elif [[ -n "${HOMEBREW_LINUX}" ]]
    then
      ruby_OS="linux"
    fi
  fi

  case "${ruby_OS}" in
    linux)
      case "${ruby_PROCESSOR}" in
        x86_64)
          ruby_TAG="x86_64_linux"
          ruby_SHA="97237694d0ddd0da07b4333b1755e5e0377354e89a5f5573b3db0590107db696"
          ;;
        aarch64)
          ruby_TAG="aarch64_linux"
          ruby_SHA="bb74f066d10b7a7420c908ec880d3539fbdba222f300127daafcfa650ba71886"
          ;;
        *) ;;
      esac
      ;;
    *) ;;
  esac

  # Dynamic variables can't be detected by shellcheck
  # shellcheck disable=SC2034
  if [[ -n "${ruby_TAG}" && -n "${ruby_SHA}" ]]
  then
    ruby_FILENAME="portable-ruby-${HOMEBREW_PORTABLE_RUBY_VERSION}.${ruby_TAG}.bottle.tar.gz"
    ruby_URLs=()
    if [[ -n "${HOMEBREW_ARTIFACT_DOMAIN}" ]]
    then
      ruby_URLs+=("${HOMEBREW_ARTIFACT_DOMAIN}/v2/zhongruoyu/zhongruoyu-portable-ruby-aarch64-linux/portable-ruby/blobs/sha256:${ruby_SHA}")
      if [[ -n "${HOMEBREW_ARTIFACT_DOMAIN_NO_FALLBACK}" ]]
      then
        ruby_URL="${ruby_URLs[0]}"
        return
      fi
    fi
    if [[ -n "${HOMEBREW_BOTTLE_DOMAIN}" ]]
    then
      ruby_URLs+=("${HOMEBREW_BOTTLE_DOMAIN}/bottles-portable-ruby-aarch64-linux/${ruby_FILENAME}")
    fi
    ruby_URLs+=(
      "https://ghcr.io/v2/zhongruoyu/zhongruoyu-portable-ruby-aarch64-linux/portable-ruby/blobs/sha256:${ruby_SHA}"
      "https://github.com/ZhongRuoyu/homebrew-portable-ruby-aarch64-linux/releases/download/${HOMEBREW_PORTABLE_RUBY_VERSION}/${ruby_FILENAME}"
    )
    ruby_URL="${ruby_URLs[0]}"
  fi
}

check_linux_glibc_version() {
  if [[ -z "${HOMEBREW_LINUX}" || -z "${HOMEBREW_LINUX_MINIMUM_GLIBC_VERSION}" ]]
  then
    return 0
  fi

  if [[ "${VENDOR_PROCESSOR}" == "aarch64" ]]
  then
    HOMEBREW_LINUX_MINIMUM_GLIBC_VERSION="2.17"
  fi

  local glibc_version
  local glibc_version_major
  local glibc_version_minor

  local minimum_required_major="${HOMEBREW_LINUX_MINIMUM_GLIBC_VERSION%.*}"
  local minimum_required_minor="${HOMEBREW_LINUX_MINIMUM_GLIBC_VERSION#*.}"

  if [[ "$(/usr/bin/ldd --version)" =~ \ [0-9]\.[0-9]+ ]]
  then
    glibc_version="${BASH_REMATCH[0]// /}"
    glibc_version_major="${glibc_version%.*}"
    glibc_version_minor="${glibc_version#*.}"
    if ((glibc_version_major < minimum_required_major || glibc_version_minor < minimum_required_minor))
    then
      odie "Vendored tools require system Glibc ${HOMEBREW_LINUX_MINIMUM_GLIBC_VERSION} or later (yours is ${glibc_version})."
    fi
  else
    odie "Failed to detect system Glibc version."
  fi
}

fetch() {
  local -a curl_args
  local url
  local sha
  local first_try=1
  local vendor_locations
  local temporary_path

  curl_args=()

  # do not load .curlrc unless requested (must be the first argument)
  # HOMEBREW_CURLRC isn't misspelt here
  # shellcheck disable=SC2153
  if [[ -z "${HOMEBREW_CURLRC}" ]]
  then
    curl_args[${#curl_args[*]}]="-q"
  elif [[ "${HOMEBREW_CURLRC}" == /* ]]
  then
    curl_args+=("-q" "--config" "${HOMEBREW_CURLRC}")
  fi

  # Authorization is needed for GitHub Packages but harmless on GitHub Releases
  curl_args+=(
    --fail
    --remote-time
    --location
    --user-agent "${HOMEBREW_USER_AGENT_CURL}"
    --header "Authorization: ${HOMEBREW_GITHUB_PACKAGES_AUTH}"
  )

  if [[ -n "${HOMEBREW_QUIET}" ]]
  then
    curl_args[${#curl_args[*]}]="--silent"
  elif [[ -z "${HOMEBREW_VERBOSE}" ]]
  then
    curl_args[${#curl_args[*]}]="--progress-bar"
  fi

  temporary_path="${CACHED_LOCATION}.incomplete"

  mkdir -p "${HOMEBREW_CACHE}"
  [[ -n "${HOMEBREW_QUIET}" ]] || ohai "Downloading ${VENDOR_URL}" >&2
  if [[ -f "${CACHED_LOCATION}" ]]
  then
    [[ -n "${HOMEBREW_QUIET}" ]] || echo "Already downloaded: ${CACHED_LOCATION}" >&2
  else
    for url in "${VENDOR_URLs[@]}"
    do
      [[ -n "${HOMEBREW_QUIET}" || -n "${first_try}" ]] || ohai "Downloading ${url}" >&2
      first_try=''
      if [[ -f "${temporary_path}" ]]
      then
        # HOMEBREW_CURL is set by brew.sh (and isn't misspelt here)
        # shellcheck disable=SC2153
        "${HOMEBREW_CURL}" "${curl_args[@]}" -C - "${url}" -o "${temporary_path}"
        if [[ $? -eq 33 ]]
        then
          [[ -n "${HOMEBREW_QUIET}" ]] || echo "Trying a full download" >&2
          rm -f "${temporary_path}"
          "${HOMEBREW_CURL}" "${curl_args[@]}" "${url}" -o "${temporary_path}"
        fi
      else
        "${HOMEBREW_CURL}" "${curl_args[@]}" "${url}" -o "${temporary_path}"
      fi

      [[ -f "${temporary_path}" ]] && break
    done

    if [[ ! -f "${temporary_path}" ]]
    then
      vendor_locations="$(printf "  - %s\n" "${VENDOR_URLs[@]}")"
      odie <<EOS
Failed to download ${VENDOR_NAME} from the following locations:
${vendor_locations}

Do not file an issue on GitHub about this; you will need to figure out for
yourself what issue with your internet connection restricts your access to
GitHub (used for Homebrew updates and binary packages).
EOS
    fi

    trap '' SIGINT
    mv "${temporary_path}" "${CACHED_LOCATION}"
    trap - SIGINT
  fi

  if [[ -x "/usr/bin/shasum" ]]
  then
    sha="$(/usr/bin/shasum -a 256 "${CACHED_LOCATION}" | cut -d' ' -f1)"
  fi

  if [[ -z "${sha}" && -x "$(type -P sha256sum)" ]]
  then
    sha="$(sha256sum "${CACHED_LOCATION}" | cut -d' ' -f1)"
  fi

  if [[ -z "${sha}" ]]
  then
    if [[ -x "$(type -P ruby)" ]]
    then
      sha="$(
        ruby <<EOSCRIPT
require 'digest/sha2'
digest = Digest::SHA256.new
File.open('${CACHED_LOCATION}', 'rb') { |f| digest.update(f.read) }
puts digest.hexdigest
EOSCRIPT
      )"
    else
      odie "Cannot verify checksum ('shasum', 'sha256sum' and 'ruby' not found)!"
    fi
  fi

  if [[ -z "${sha}" ]]
  then
    odie "Could not get checksum ('shasum', 'sha256sum' and 'ruby' produced no output)!"
  fi

  if [[ "${sha}" != "${VENDOR_SHA}" ]]
  then
    odie <<EOS
Checksum mismatch.
Expected: ${VENDOR_SHA}
  Actual: ${sha}
 Archive: ${CACHED_LOCATION}
To retry an incomplete download, remove the file above.
EOS
  fi
}

install() {
  local tar_args

  if [[ -n "${HOMEBREW_VERBOSE}" ]]
  then
    tar_args="xvzf"
  else
    tar_args="xzf"
  fi

  mkdir -p "${VENDOR_DIR}/portable-${VENDOR_NAME}"
  safe_cd "${VENDOR_DIR}/portable-${VENDOR_NAME}"

  trap '' SIGINT

  if [[ -d "${VENDOR_VERSION}" ]]
  then
    mv "${VENDOR_VERSION}" "${VENDOR_VERSION}.reinstall"
  fi

  safe_cd "${VENDOR_DIR}"
  [[ -n "${HOMEBREW_QUIET}" ]] || ohai "Pouring ${VENDOR_FILENAME}" >&2
  tar "${tar_args}" "${CACHED_LOCATION}"

  if [[ "${VENDOR_PROCESSOR}" != "${HOMEBREW_PROCESSOR}" ]] ||
     [[ "${VENDOR_PHYSICAL_PROCESSOR}" != "${HOMEBREW_PHYSICAL_PROCESSOR}" ]]
  then
    return 0
  fi

  safe_cd "${VENDOR_DIR}/portable-${VENDOR_NAME}"

  if "./${VENDOR_VERSION}/bin/${VENDOR_NAME}" --version >/dev/null
  then
    ln -sfn "${VENDOR_VERSION}" current
    if [[ -d "${VENDOR_VERSION}.reinstall" ]]
    then
      rm -rf "${VENDOR_VERSION}.reinstall"
    fi
  else
    rm -rf "${VENDOR_VERSION}"
    if [[ -d "${VENDOR_VERSION}.reinstall" ]]
    then
      mv "${VENDOR_VERSION}.reinstall" "${VENDOR_VERSION}"
    fi
    odie "Failed to install ${VENDOR_NAME} ${VENDOR_VERSION}!"
  fi

  local brew_env="${HOMEBREW_PREFIX}/etc/homebrew/brew.env"
  if [[ "${VENDOR_PROCESSOR}" == "aarch64" ]] &&
     ! grep -qs '^HOMEBREW_FORCE_VENDOR_RUBY=' "${brew_env}" 2>/dev/null
  then
    mkdir -p "${HOMEBREW_PREFIX}/etc/homebrew"
    echo "HOMEBREW_FORCE_VENDOR_RUBY=1" >>"${brew_env}"
  fi
  trap - SIGINT
}

homebrew-vendor-install-ruby() {
  local option
  local url_var
  local sha_var

  unset VENDOR_PHYSICAL_PROCESSOR
  unset VENDOR_PROCESSOR

  for option in "$@"
  do
    case "${option}" in
      -\? | -h | --help | --usage)
        brew help vendor-install-ruby
        exit $?
        ;;
      --verbose) HOMEBREW_VERBOSE=1 ;;
      --quiet) HOMEBREW_QUIET=1 ;;
      --debug) HOMEBREW_DEBUG=1 ;;
      --*) ;;
      -*)
        [[ "${option}" == *v* ]] && HOMEBREW_VERBOSE=1
        [[ "${option}" == *q* ]] && HOMEBREW_QUIET=1
        [[ "${option}" == *d* ]] && HOMEBREW_DEBUG=1
        ;;
      *)
        if [[ -n "${HOMEBREW_DEVELOPER}" ]]
        then
          if [[ -n "${PROCESSOR_TARGET}" ]]
          then
            odie "This command does not take more than processor targets!"
          else
            VENDOR_PHYSICAL_PROCESSOR="${option}"
            VENDOR_PROCESSOR="${option}"
          fi
        else
          odie "This command does not take multiple processor targets!"
        fi
        ;;
    esac
  done

  VENDOR_NAME="ruby"
  [[ -n "${HOMEBREW_DEBUG}" ]] && set -x

  if [[ -z "${VENDOR_PHYSICAL_PROCESSOR}" ]]
  then
    VENDOR_PHYSICAL_PROCESSOR="${HOMEBREW_PHYSICAL_PROCESSOR}"
  fi

  if [[ -z "${VENDOR_PROCESSOR}" ]]
  then
    VENDOR_PROCESSOR="${HOMEBREW_PROCESSOR}"
  fi

  set_ruby_variables
  check_linux_glibc_version

  filename_var="${VENDOR_NAME}_FILENAME"
  sha_var="${VENDOR_NAME}_SHA"
  url_var="${VENDOR_NAME}_URL"
  VENDOR_FILENAME="${!filename_var}"
  VENDOR_SHA="${!sha_var}"
  VENDOR_URL="${!url_var}"
  VENDOR_VERSION="$(cat "${VENDOR_DIR}/portable-${VENDOR_NAME}-version")"

  if [[ -z "${VENDOR_URL}" || -z "${VENDOR_SHA}" ]]
  then
    odie "No Homebrew ${VENDOR_NAME} ${VENDOR_VERSION} available for ${HOMEBREW_PROCESSOR} processors!"
  fi

  # Expand the name to an array of variables
  # The array name must be "${VENDOR_NAME}_URLs"! Otherwise substitution errors will occur!
  # shellcheck disable=SC2086,SC2248
  read -r -a VENDOR_URLs <<<"$(eval "echo "\$\{${url_var}s[@]\}"")"

  CACHED_LOCATION="${HOMEBREW_CACHE}/${VENDOR_FILENAME}"

  lock "vendor-install ${VENDOR_NAME}"
  fetch
  install
}

homebrew-vendor-install-ruby "$@"
