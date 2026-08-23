# syntax=docker/dockerfile:1
#
# Build-time network configuration for restricted / non-global-internet
# environments (corporate proxy, internal npm mirror, TLS-intercepting
# proxy with a private root CA):
#
#   --build-arg HTTP_PROXY=http://proxy.internal:3128
#   --build-arg HTTPS_PROXY=http://proxy.internal:3128
#   --build-arg NO_PROXY=localhost,127.0.0.1,.internal
#   --build-arg NPM_REGISTRY=https://npm-mirror.internal/
#
# Drop any corporate root CA .crt files into certs/ before building; they
# get installed into the system + Node trust store automatically.
#
# The Docusaurus "AI cookbook" content sync (bin/sync-ai-cookbook.js) needs
# to reach github.com and is skipped entirely here in favor of
# bin/ensure-ai-cookbook.js (writes a local placeholder, no network calls),
# so the image build never depends on public internet access beyond
# fetching npm/apt packages.

########## Build stage ##########
FROM node:24-bookworm-slim AS build
WORKDIR /app

ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG NPM_REGISTRY=https://registry.npmjs.org
ENV HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    NO_PROXY=${NO_PROXY} \
    http_proxy=${HTTP_PROXY} \
    https_proxy=${HTTPS_PROXY} \
    no_proxy=${NO_PROXY}

# git: local `git log` info for Docusaurus "last updated" metadata (no
# network calls made against it — the AI cookbook sync step is skipped).
# ca-certificates/fontconfig/fonts-noto-core: TLS trust store + real glyphs
# for rendering the Hebrew watermark text via sharp/librsvg.
RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      ca-certificates \
      fontconfig \
      fonts-noto-core \
    && rm -rf /var/lib/apt/lists/*

# Install any corporate root CA(s) dropped into certs/ (empty by default)
# into the system trust store, which Node also honors via NODE_EXTRA_CA_CERTS.
COPY certs/ /usr/local/share/ca-certificates/extra/
RUN update-ca-certificates
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

RUN corepack enable
RUN yarn config set registry "$NPM_REGISTRY"

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --network-timeout 600000

COPY . .

# Bake the watermark (tiger source image + Hebrew caption, 12% opacity)
# into static/img/watermark.png before the Docusaurus build picks it up.
RUN node watermark-src/generate-watermark.mjs

# Equivalent to `yarn build`, but using the offline-safe ensure step
# instead of the network-dependent `prebuild` cookbook sync.
RUN node ./bin/ensure-ai-cookbook.js \
    && node --max-old-space-size=7168 ./node_modules/@docusaurus/core/bin/docusaurus.mjs build \
    && node ./bin/check-font-preload-hash.js

########## Runtime stage ##########
# Non-root, unprivileged-port nginx image: no capabilities/root needed,
# works with a Kubernetes PodSecurityContext of runAsNonRoot + a read-only
# root filesystem (see k8s/deployment.yaml).
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime

COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8080/ >/dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
