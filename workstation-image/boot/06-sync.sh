#!/bin/bash
set -e

# 06-sync.sh: Sync boot scripts and sway config from git repo on every boot
# Runs as root but executes git/cp operations as the user to preserve ownership
# Exits gracefully if repo is missing or git pull fails (non-fatal)

REPO_DIR="/home/user/dev/git/cloud-workstations"
USER_HOME="/home/user"
LOG_DIR="${USER_HOME}/logs"
LOG_FILE="${LOG_DIR}/sync.log"
BOOT_SRC="${REPO_DIR}/workstation-image/boot"
BOOT_DST="${USER_HOME}/boot"
SWAY_SRC="${REPO_DIR}/workstation-image/configs/sway/config"
SWAY_DST="${USER_HOME}/.config/home-manager/sway-config"

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

{
  echo "=== Boot sync started at $(date) ==="

  # Check if repo directory exists
  if [[ ! -d "${REPO_DIR}" ]]; then
    echo "WARNING: Repo directory not found at ${REPO_DIR}. Skipping sync."
    echo "=== Boot sync completed (repo missing) at $(date) ==="
    exit 0
  fi

  # Git pull with error tolerance
  echo "Pulling latest repo changes from ${REPO_DIR}..."
  if runuser -u user -- git -C "${REPO_DIR}" pull --ff-only 2>&1; then
    echo "✓ Git pull succeeded"
  else
    PULL_EXIT=$?
    echo "⚠ Git pull failed with exit code ${PULL_EXIT} (skipping sync, continuing boot)"
    echo "=== Boot sync completed (git pull failed) at $(date) ==="
    exit 0
  fi

  # Verify boot source directory exists
  if [[ ! -d "${BOOT_SRC}" ]]; then
    echo "ERROR: Boot scripts source directory not found at ${BOOT_SRC}"
    echo "=== Boot sync completed (source missing) at $(date) ==="
    exit 0
  fi

  # Copy all boot scripts
  echo "Syncing boot scripts from ${BOOT_SRC}..."
  for script in "${BOOT_SRC}"/*.sh; do
    script_name=$(basename "${script}")
    dest="${BOOT_DST}/${script_name}"
    if runuser -u user -- cp "${script}" "${dest}"; then
      echo "  ✓ Copied ${script_name}"
    else
      echo "  ✗ Failed to copy ${script_name} (continuing)"
    fi
  done

  # Copy sway config
  echo "Syncing sway config from ${SWAY_SRC}..."
  if [[ -f "${SWAY_SRC}" ]]; then
    if runuser -u user -- cp "${SWAY_SRC}" "${SWAY_DST}"; then
      echo "  ✓ Copied sway config"
    else
      echo "  ✗ Failed to copy sway config (continuing)"
    fi
  else
    echo "  ⚠ Sway config source not found at ${SWAY_SRC} (skipping)"
  fi

  echo "=== Boot sync completed successfully at $(date) ==="
} >> "${LOG_FILE}" 2>&1

exit 0
