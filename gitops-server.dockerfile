# UI build
FROM node:24-bookworm@sha256:8de41dd3ced665c49a1d7a0801f146fc88cd58ce53350fac59e5bd59c9ee8950 AS ui
RUN apt-get update -y && apt-get install -y build-essential python3 g++
RUN npm install -g node-gyp
RUN mkdir -p /home/app && chown -R node:node /home/app
WORKDIR /home/app
USER node
COPY --chown=node:node package*.json /home/app/
COPY --chown=node:node yarn.lock /home/app/
COPY --chown=node:node Makefile /home/app/
COPY --chown=node:node tsconfig.json /home/app/
COPY --chown=node:node .parcelrc /home/app/
COPY --chown=node:node .npmrc /home/app/
COPY --chown=node:node .yarn /home/app/.yarn
COPY --chown=node:node .yarnrc.yml /home/app/
RUN make node_modules
COPY --chown=node:node ui /home/app/ui
RUN make ui

# Go build
FROM golang:1.24.3@sha256:86b4cff66e04d41821a17cea30c1031ed53e2635e2be99ae0b4a7d69336b5063 AS go-build

# Add known_hosts entries for GitHub and GitLab
RUN mkdir ~/.ssh
RUN ssh-keyscan github.com >> ~/.ssh/known_hosts
RUN ssh-keyscan gitlab.com >> ~/.ssh/known_hosts

COPY Makefile /app/
WORKDIR /app
RUN go env -w GOCACHE=/go-cache
RUN --mount=type=cache,target=/gomod-cache \
    go env -w GOMODCACHE=/gomod-cache
COPY go.* /app/
RUN go mod download
COPY core /app/core
COPY pkg /app/pkg
COPY cmd /app/cmd
COPY api /app/api

# These are ARGS are defined here to minimise cache misses
# (cf. https://docs.docker.com/engine/reference/builder/#impact-on-build-caching)
# Pass these flags so we don't have to copy .git/ for those commands to work
ARG GIT_COMMIT="_unset_"
ARG LDFLAGS="-X localbuild=true"

RUN --mount=type=cache,target=/gomod-cache --mount=type=cache,target=/go-cache \
    LDFLAGS=${LDFLAGS##-X localbuild=true} GIT_COMMIT=$GIT_COMMIT make gitops-server

#  Distroless
FROM gcr.io/distroless/base@sha256:27769871031f67460f1545a52dfacead6d18a9f197db77110cfc649ca2a91f44 AS runtime
COPY --from=ui /home/app/bin/dist/ /dist/
COPY --from=go-build /app/bin/gitops-server /gitops-server
COPY --from=go-build /root/.ssh/known_hosts /root/.ssh/known_hosts

ENTRYPOINT ["/gitops-server"]
