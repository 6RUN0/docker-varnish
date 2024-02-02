#!/usr/bin/env bash

set -Eeuox pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

distrs=( "$@" )

if [ ${#distrs[@]} -eq 0 ]; then
	GLOBIGNORE=".*:latest/"
	distrs=( */ )
fi

distrs=( "${distrs[@]%/}" )

for distr in "${distrs[@]}"; do
	for suite in $distr/*; do
		suite=${suite##*/}
		cp *.sh "$distr/$suite/"
		rm "$distr/$suite/update.sh"
		sed -r \
			-e 's/%%DISTR%%/'"$distr"'/' \
			-e 's/%%SUITE%%/'"$suite"'/' \
			"Dockerfile.template" > "$distr/$suite/Dockerfile"
	done
done
