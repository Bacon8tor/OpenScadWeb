#!/usr/bin/env bash
# OpenSCAD Web (openscad-playground) - Proxmox LXC helper script
# Built on the community-scripts framework (https://github.com/community-scripts)
# License: MIT
# Source: https://github.com/openscad/openscad-playground

# Where this repo's ct/ and install/ scripts are fetched from:
# the GitHub raw URL of this repo (override by exporting COMMUNITY_SCRIPTS_URL before running).
export COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/Bacon8tor/OpenScadWeb/main}"

_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
# shellcheck disable=SC1090
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")

APP="OpenSCAD-Web"
var_tags="${var_tags:-3d;cad}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-6}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  local SRC=/opt/openscad-playground
  local WEB=/var/www/openscad
  local VERFILE=/opt/openscad-web_version.txt

  if [[ ! -d "$SRC/.git" ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Checking for updates"
  cd "$SRC" || exit
  $STD git fetch --depth 1 origin main
  local LATEST CURRENT
  LATEST=$(git rev-parse FETCH_HEAD)
  CURRENT=$(cat "$VERFILE" 2>/dev/null || echo "none")
  msg_ok "Checked for updates"

  if [[ "$LATEST" == "$CURRENT" ]]; then
    msg_ok "${APP} is already up to date (${CURRENT:0:7})"
    exit
  fi

  msg_info "Updating OS packages"
  $STD apt-get update
  $STD apt-get -y upgrade
  msg_ok "Updated OS packages"

  msg_info "Updating ${APP} to ${LATEST:0:7} (this can take several minutes)"
  $STD git reset --hard "$LATEST"
  sed -i 's#"homepage": *"[^"]*"#"homepage": "/"#' package.json
  $STD npm ci
  $STD npm run build:libs
  $STD npm run build
  rm -rf "${WEB}.new"
  cp -rL dist "${WEB}.new"
  rm -rf "${WEB}.old"
  [[ -d "$WEB" ]] && mv "$WEB" "${WEB}.old"
  mv "${WEB}.new" "$WEB"
  rm -rf "${WEB}.old"
  echo "$LATEST" >"$VERFILE"
  $STD npm cache clean --force
  systemctl reload nginx
  msg_ok "Updated ${APP} to ${LATEST:0:7}"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}${CL}"
echo -e "${INFO}${YW} For remote access, add a Nginx Proxy Manager proxy host -> http://${IP}:80 (enable SSL + an Access List).${CL}"
