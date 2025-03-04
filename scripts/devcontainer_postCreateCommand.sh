#!/usr/bin/env bash
# Devcontainer postCreateCommand.
# Install dependencies for running this project in GitHub Codespaces.

set -eux

# For git version tagging:
go install github.com/maykonlsf/semver-cli/cmd/semver@latest
