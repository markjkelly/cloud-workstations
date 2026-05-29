#!/bin/bash
set -e

# 09-sync.sh: Sync boot scripts and sway config from git repo on every boot
# Runs at order 9 (after 07-apps and 08-workspaces) so the user exists.
# Updates take effect on the next reboot.
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

  # Git pull with error tolerance — run as root with HOME set so git uses user config
  # No su/runuser needed; chown fixes ownership after copy
  echo "Pulling latest repo changes from ${REPO_DIR}..."
  git config --global --add safe.directory "${REPO_DIR}" 2>/dev/null || true
  if HOME="${USER_HOME}" GIT_SSH_COMMAND="ssh -i ${USER_HOME}/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${USER_HOME}/.ssh/known_hosts" git -C "${REPO_DIR}" pull --ff-only 2>&1; then
    echo "✓ Git pull succeeded"
    # Restore ownership of any root-owned files created by pull
    chown -R 1000:1000 "${REPO_DIR}" 2>/dev/null || true
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

  # Copy all boot scripts and restore ownership
  echo "Syncing boot scripts from ${BOOT_SRC}..."
  for script in "${BOOT_SRC}"/*.sh; do
    script_name=$(basename "${script}")
    dest="${BOOT_DST}/${script_name}"
    if cp "${script}" "${dest}" && chown 1000:1000 "${dest}"; then
      echo "  ✓ Copied ${script_name}"
    else
      echo "  ✗ Failed to copy ${script_name} (continuing)"
    fi
  done

  # Copy sway config and restore ownership
  echo "Syncing sway config from ${SWAY_SRC}..."
  if [[ -f "${SWAY_SRC}" ]]; then
    if cp "${SWAY_SRC}" "${SWAY_DST}" && chown 1000:1000 "${SWAY_DST}"; then
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
