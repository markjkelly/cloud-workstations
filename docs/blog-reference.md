# Blog Reference: Running Antigravity on a Browser Tab

Source: https://medium.com/google-cloud/running-antigravity-on-a-browser-tab-6298bb7e47c4

## Step 1: Clone the Assets Repo

```bash
git clone https://github.com/GoogleCloudPlatform/cloud-workstations-custom-image-examples.git
cd cloud-workstations-custom-image-examples/examples/images/gnome/noVnc/
```

Use the `/assets` folder from here.

## Step 2: Dockerfile

```dockerfile
# syntax=docker/dockerfile:1
FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base as novnc-builder

ARG NOVNC_BRANCH=v1.5.0
ARG WEBSOCKIFY_BRANCH=v0.12.0

WORKDIR /out

RUN git clone --quiet --depth 1 --branch $NOVNC_BRANCH https://github.com/novnc/noVNC.git && \
  cd noVNC/utils && \
  git clone  --quiet --depth 1 --branch $WEBSOCKIFY_BRANCH https://github.com/novnc/websockify.git

#######################################################
# End NoVNC Builder Container
#######################################################

# Main container build
FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base

# Use ARG to avoid apt-get warnings
ARG DEBIAN_FRONTEND=noninteractive

# Install and configure systemd.
RUN apt-get update && apt-get install -y \
  systemd && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* &&\
  ln -s /dev/null /etc/systemd/system/apache2.service && \
  ln -s /dev/null /etc/systemd/system/getty@tty1.service && \
  ln -s /dev/null /etc/systemd/system/ldconfig.service && \
  /sbin/ldconfig -Xv && \
  ln -s /dev/null /etc/systemd/system/systemd-modules-load.service && \
  ln -s /dev/null /etc/systemd/system/ssh.socket && \
  ln -s /dev/null /etc/systemd/system/ssh.service && \
  echo "d /run/sshd 0755 root root" > /usr/lib/tmpfiles.d/sshd.conf && \
  echo -e "x /run/docker.socket - - - - -\nx /var/run/docker.socket - - - - -" > /usr/lib/tmpfiles.d/docker.conf

# Install GNOME
RUN apt-get update && apt-get install -y \
    gnome-software \
    gnome-software-common \
    gnome-software-plugin-snap \
    libappstream-glib8 \
    libgd3 \
    colord \
    gnome-control-center \
    gvfs-backends \
    hplip \
    libgphoto2-6 \
    libsane1 \
    sane-utils \
    ubuntu-desktop-minimal && \
  apt-get remove -y gnome-initial-setup && \
  apt-get remove -y --purge cloud-init && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  chmod -x /usr/lib/ubuntu-release-upgrader/check-new-release-gtk

# Install Antigravity
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | tee /etc/apt/sources.list.d/antigravity.list > /dev/null && \
    apt-get update && \
    apt-get install -y antigravity

# Install Google Chrome
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list > /dev/null && \
    apt-get update && \
    apt-get install -y google-chrome-stable

# Divert the original Chrome executable to a new location and create a wrapper script.
# This ensures the fix persists even when the Chrome package is updated.
RUN dpkg-divert --add --rename --divert /usr/bin/google-chrome-stable.real /usr/bin/google-chrome-stable && \
    echo '#!/bin/bash' > /usr/bin/google-chrome-stable && \
    echo 'exec /usr/bin/google-chrome-stable.real --no-sandbox --no-zygote --disable-gpu --disable-dev-shm-usage "$@"' >> /usr/bin/google-chrome-stable && \
    chmod +x /usr/bin/google-chrome-stable


# Install TigerVNC and noVNC
COPY --from=novnc-builder /out/noVNC /opt/noVNC
RUN apt-get update && apt-get install -y \
    dbus-x11 \
    tigervnc-common \
    tigervnc-scraping-server \
    tigervnc-standalone-server \
    tigervnc-xorg-extension \
    python3-numpy  && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# Merge assets into the container.
COPY assets/opt /opt
COPY assets/. /

# Run TigerVNC and noVNC as services.
RUN ln -s /etc/systemd/system/tigervnc.service /etc/systemd/system/multi-user.target.wants/ && \
  ln -s /etc/systemd/system/novnc.service /etc/systemd/system/multi-user.target.wants/ && \
  systemctl enable tigervnc && \
  systemctl enable novnc

# This is implicit when extending workstations predefined images, however we are
# including it in the sample to explicitly call-out we are overriding the
# default entrypoint when merging assets.
ENTRYPOINT ["/google/scripts/entrypoint.sh"]
```

## Step 3: Build and Push

```bash
# Create Artifact Registry repository
gcloud artifacts repositories create cloud-workstations-images \
  --repository-format=docker \
  --location=REGION \
  --project=PROJECT_ID

# Configure Docker auth
gcloud auth configure-docker REGION-docker.pkg.dev

# Build, tag, and push
docker build -t REGION-docker.pkg.dev/PROJECT_ID/cloud-workstations-images/antigravity-workstation:latest .
docker push REGION-docker.pkg.dev/PROJECT_ID/cloud-workstations-images/antigravity-workstation:latest
```

## Step 4: Create Cluster and Configuration

- Create via GCP Console or gcloud
- Choose region close to local computer
- Blog author used e2-standard-16 (our spec: g2-standard-16 with NVIDIA L4 GPU)
- Select the custom image from Artifact Registry

## Step 5: Connect

1. Create a workstation from the configuration
2. Start and Launch the workstation
3. First launch shows error — need to set VNC password
4. Get SSH connection command from UI, paste into Cloud Shell
5. Run `vncpasswd` (max 8 characters)
6. Relaunch workstation tab, enter VNC password
7. If error persists: `sudo systemctl restart tigervnc.service`

## Troubleshooting

For crashes (shared memory too small):
```bash
/usr/share/antigravity/antigravity --no-sandbox --disable-gpu --disable-dev-shm-usage
```

## Key Differences from Blog (Our Spec Additions)

- **Machine type:** Blog uses e2-standard-16; we use g2-standard-16 (NVIDIA L4 GPU)
- **Persistent disk:** 500GB pd-ssd with HOME mount (not in blog)
- **Nix package manager:** Install on persistent disk (not in blog)
- **GPU drivers:** NVIDIA L4 drivers + CUDA (not in blog)
- **Repository name:** Blog uses `cloud-workstations-images`; our spec uses `workstation-images`
