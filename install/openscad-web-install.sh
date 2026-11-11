#!/usr/bin/env bash
# OpenSCAD Web (openscad-playground) - LXC install script
# License: MIT
# Source: https://github.com/openscad/openscad-playground

# shellcheck disable=SC1090
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

SRC=/opt/openscad-playground
WEB=/var/www/openscad
VERFILE=/opt/openscad-web_version.txt
PATCH_BASE="https://raw.githubusercontent.com/Bacon8tor/OpenScadWeb/main/patches"

msg_info "Installing Dependencies"
$STD apt-get install -y git curl ca-certificates gnupg make zip unzip nginx
msg_ok "Installed Dependencies"

if declare -F setup_nodejs >/dev/null; then
  NODE_VERSION="22" setup_nodejs
else
  msg_info "Installing Node.js 22"
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
  $STD apt-get update
  $STD apt-get install -y nodejs
  msg_ok "Installed Node.js $(node -v)"
fi

msg_info "Cloning openscad-playground"
$STD git clone --depth 1 https://github.com/openscad/openscad-playground "$SRC"
msg_ok "Cloned openscad-playground"

msg_info "Building openscad-playground (downloads OpenSCAD WASM + libraries, takes several minutes)"
cd "$SRC" || exit
# Serve from the web root instead of the upstream author's GitHub Pages path.
sed -i 's#"homepage": *"[^"]*"#"homepage": "/"#' package.json
# Turn on the "Upload file(s)" menu item (disabled upstream)
curl -fsSL "${PATCH_BASE}/enable-upload.mjs" -o /opt/openscad-web-enable-upload.mjs
$STD node /opt/openscad-web-enable-upload.mjs "$SRC"
$STD npm ci
$STD npm run build:libs
$STD npm run build
mkdir -p "$(dirname "$WEB")"
rm -rf "$WEB"
# -L: public/openscad.{js,wasm} are symlinks into the build tree; copy the real files.
cp -rL dist "$WEB"
echo "$(git rev-parse HEAD)-p1" >"$VERFILE"  # -p1 must match PATCH_REV in ct/openscad-web.sh
$STD npm cache clean --force
msg_ok "Built openscad-playground ($(cut -c1-7 "$VERFILE"))"

msg_info "Configuring nginx"
cat <<'EOF' >/etc/nginx/sites-available/openscad
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root /var/www/openscad;
    index index.html;

    gzip on;
    gzip_comp_level 6;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/javascript application/json application/wasm image/svg+xml;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Never cache the entry page so updates show up right away
    location = /index.html {
        add_header Cache-Control "no-cache";
    }

    # Big static assets: cache for a day (filenames aren't content-hashed upstream)
    location ~* \.(wasm|zip|js|css|ttf|woff2?|png|svg|ico)$ {
        add_header Cache-Control "public, max-age=86400";
        try_files $uri =404;
    }
}
EOF
# Browsers need application/wasm for streaming compilation; add it if this nginx lacks it
if ! grep -q 'application/wasm' /etc/nginx/mime.types; then
  sed -i 's#^types {#types {\n    application/wasm                                 wasm;#' /etc/nginx/mime.types
fi
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/openscad /etc/nginx/sites-enabled/openscad
$STD nginx -t
systemctl enable -q --now nginx
systemctl reload nginx
msg_ok "Configured nginx"

motd_ssh
customize
cleanup_lxc
