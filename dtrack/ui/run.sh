#!/usr/bin/env bash

ACTION="$1"
BUILD_FLAG=$([[ "$2" == "--local" ]] && echo || echo "--build --pull=always")

if [[ "$ACTION" == "debug" ]]; then
  (cd $(pwd)/../.. && \
    docker compose -f docker-compose.yaml \
                   -f config/docker-compose.overrides/dev.yaml \
                   -f config/docker-compose.overrides/debug.yaml \
                   up -d ${BUILD_FLAG})
  export VITE_ENVIRONMENT=DEBUG
  export VITE_JWT_SECRET=Dummy5ecr3t4D3bug0n1yN0T4Pr0D123
  export VITE_PALETTE_PRIMARY=#5F6368
  export VITE_PALETTE_SECONDARY=#B0B3B8
elif [[ "$ACTION" == "dev" ]]; then
  docker compose up -d ${BUILD_FLAG}
fi

if [[ "$2" == "--local" ]]; then
  exec ./node_modules/.bin/vite
fi
