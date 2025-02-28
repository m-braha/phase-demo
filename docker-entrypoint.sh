#!/bin/sh -e

if [ -z "$PHASE_APP" ] || [ -z "$PHASE_ENVIRONMENT" ] || [ -z "$PHASE_SERVICE_TOKEN" ]; then
    echo "Warning: Phase configuration incomplete (PHASE_APP, PHASE_ENVIRONMENT, PHASE_SERVICE_TOKEN)"
    echo "Skipping Phase secrets. Set env vars directly: docker run -e KEY1=value1 -e KEY2=value2 ..."
else

    # shellcheck disable=SC2046
    export $(phase secrets export --app="$PHASE_APP" --env="$PHASE_ENVIRONMENT" --path="${PHASE_ENV_PATH:-env}" | xargs)
    # Pull secrets from Phase and export them
    phase run --app="$PHASE_APP" --env="$PHASE_ENVIRONMENT" "$@"
fi

# Execute the main container command
exec "$@"
