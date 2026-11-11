// Enables the "Upload file(s)" menu item in openscad-playground, which ships disabled upstream.
// Usage: node enable-upload.mjs /opt/openscad-playground
//
// Uploaded .scad files become editable sources; other files (STL, SVG, DXF, PNG, ...)
// are stored as data: URLs so they can be used with import("name.stl") / surface().
// Everything lands at the project root (/<filename>), next to /playground.scad.
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.argv[2] ?? '.';
const file = join(root, 'src/components/EditorPanel.tsx');
const src = readFileSync(file, 'utf8');

if (src.includes('openscad-web-upload')) {
  console.log('enable-upload: already patched');
  process.exit(0);
}

const disabled = /label:\s*"Upload file\(s\)",\s*icon:\s*'pi pi-upload',\s*disabled:\s*true,/;
if (!disabled.test(src)) {
  // Upstream changed (maybe it implemented upload itself). Don't break the build.
  console.warn('enable-upload: upload menu item not found in expected form; skipping patch');
  process.exit(0);
}

const replacement = `label: "Upload file(s)",
            icon: 'pi pi-upload',
            // openscad-web-upload: added by OpenScadWeb's Proxmox helper script
            command: () => {
              const input = document.createElement('input');
              input.type = 'file';
              input.multiple = true;
              input.accept = '.scad,.stl,.obj,.off,.amf,.3mf,.svg,.dxf,.png,.dat,.csv,.json,.txt';
              input.onchange = async () => {
                const files = Array.from(input.files ?? []);
                if (files.length === 0) return;
                const read = (f: File) => new Promise<{path: string, content?: string, url?: string}>((resolve, reject) => {
                  const reader = new FileReader();
                  const path = '/' + f.name;
                  reader.onerror = () => reject(reader.error);
                  if (f.name.toLowerCase().endsWith('.scad')) {
                    reader.onload = () => resolve({path, content: reader.result as string});
                    reader.readAsText(f);
                  } else {
                    reader.onload = () => resolve({path, url: reader.result as string});
                    reader.readAsDataURL(f);
                  }
                });
                try {
                  const added = await Promise.all(files.map(read));
                  const paths = new Set(added.map(a => a.path));
                  model.mutate(s => {
                    s.params.sources = [...s.params.sources.filter(src => !paths.has(src.path)), ...added];
                  });
                  const scad = added.find(a => a.path.endsWith('.scad'));
                  if (scad && scad.path !== model.state.params.activePath) {
                    model.openFile(scad.path);
                  } else if (scad) {
                    model.source = scad.content ?? '';
                  }
                } catch (e) {
                  console.error('Upload failed:', e);
                  window.alert('Upload failed: ' + e);
                }
              };
              input.click();
            },`;

writeFileSync(file, src.replace(disabled, replacement));
console.log('enable-upload: patched ' + file);
