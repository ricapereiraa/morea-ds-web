# Traefik ACME notes

Traefik stores Let's Encrypt certificates in the file `./traefik/letsencrypt/acme.json`.

Before starting the stack, create the folder and the file and set restrictive permissions (Linux/macOS):

```bash
mkdir -p traefik/letsencrypt
touch traefik/letsencrypt/acme.json
chmod 600 traefik/letsencrypt/acme.json
```

On Docker Desktop for Windows, permissions are handled by the host and you may need to create the file manually.
