#!/bin/bash
# Immortal Vibes — deploy to Cloudflare Pages
# Usage: bash deploy.sh

set -e
echo "Building..."
cd web && npm run build
echo "Deploying..."
CLOUDFLARE_ACCOUNT_ID=e033027ade765b35fd428536f7c989af wrangler pages deploy .svelte-kit/cloudflare --project-name immortalvibes --commit-dirty=true
echo "Done! https://immortalvibes.pages.dev"
