# OpenSCAD Web: Proxmox helper script

This creates a Debian 12 LXC on Proxmox running [openscad-playground](https://github.com/openscad/openscad-playground), which is OpenSCAD compiled to WebAssembly and served by nginx. Open it from any browser. Rendering runs on the device you're using, so the container stays small.

The scripts use the [community-scripts](https://github.com/community-scripts) framework, so you get the same whiptail menus as the other community helper scripts.

## Install

Run this in the Proxmox host shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Bacon8tor/OpenScadWeb/main/ct/openscad-web.sh)"
```

The build downloads the OpenSCAD WASM build, fonts and libraries (BOSL2, MCAD and more), so it takes a few minutes. When it's finished, open `http://<container-ip>`.

Default resources are 2 vCPU, 2 GB RAM and a 6 GB disk. The build needs the RAM. Once it's done you can lower RAM to 512 MB.

## Access from anywhere with Nginx Proxy Manager

In NPM, add a **Proxy Host** with these settings:

| Field | Value |
|---|---|
| Domain | e.g. `openscad.example.com` |
| Scheme | `http` |
| Forward Hostname/IP | the LXC's IP |
| Forward Port | `80` |
| Block Common Exploits | on |
| SSL tab | Request a Let's Encrypt cert, Force SSL, HTTP/2 |
| Access List | **Strongly recommended.** The app itself has no login. |

## Update

Open the LXC console and run:

```bash
update
```

This rebuilds only when upstream has a new commit. If you lowered the RAM after install, raise it back to 2 GB first.

## Notes

- Projects are saved in each browser's local storage, so they don't sync between devices. Use the playground's download/share options to move designs around.
- Big renders use the CPU and RAM of the device you're viewing from.
- File layout:
  - Source and build tree: `/opt/openscad-playground`
  - Served files: `/var/www/openscad`
  - nginx site: `/etc/nginx/sites-available/openscad`
