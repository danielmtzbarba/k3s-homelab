# danielmtz-website-dev-tls

This directory is the private development website app.

The dev app is intentionally not exposed on the public internet.

Current private access model:

- namespace: `danielmtz-website-dev`
- deployment: `danielmtz-website-dev`
- service: `danielmtz-website-dev`
- no public ingress
- Tailscale access through the server MagicDNS name on a dedicated NodePort

Current access target:

- `http://k3s-server-1:30080`

Why this shape:

- MagicDNS names Tailscale devices, not Kubernetes applications
- with the current cluster, the clean private path is to expose the dev app on the server node over the tailnet
- a true per-app MagicDNS hostname would require an extra Tailscale component such as Serve or the Tailscale Kubernetes operator
