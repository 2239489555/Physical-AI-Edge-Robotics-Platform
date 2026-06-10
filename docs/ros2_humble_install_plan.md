# ROS 2 Humble Minimal Install Plan

Status: planned

Purpose: install only the ROS 2 Humble dependencies needed for P0-003 on the company-owned Jetson server.

Official reference:

- ROS 2 Humble Ubuntu deb install docs: <https://docs.ros.org/en/humble/Installation/Ubuntu-Install-Debs.html>
- Docker Engine Ubuntu apt repository docs, used only to identify malformed Docker source syntax during apt troubleshooting: <https://docs.docker.com/engine/install/ubuntu/>

## Baseline Decision

The Jetson baseline shows:

- Ubuntu 22.04.5 LTS.
- arm64.
- L4T R36.4.3.
- CUDA 12.6.
- TensorRT 10.3.
- ROS 2 missing or command failed.
- colcon missing or command failed.

Decision: install ROS 2 Humble minimal runtime and development tools after apt simulation passes.

## Scope

Install:

- `ros-humble-ros-base`
- `ros-dev-tools`
- `ros-humble-demo-nodes-cpp`
- `ros-humble-demo-nodes-py`

Do not install:

- ROS 2 Jazzy.
- ROS desktop/full desktop packages.
- Ubuntu 24.04 packages.
- Isaac ROS.
- TensorRT or CUDA changes.
- Global Python packages through pip.
- systemd services.

Do not modify `.bashrc` in this phase. Source ROS manually in each shell.

## Preflight Commands

Run from the repository root on Jetson:

```bash
git pull origin main
bash scripts/setup_runtime_dirs.sh
git status --short --ignored
```

Check whether a ROS source already exists:

```bash
grep -R "packages.ros.org/ros2" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
dpkg-query --show ros2-apt-source 2>/dev/null || true
```

## Add ROS 2 Apt Source If Missing

If no ROS 2 apt source is present, follow the current official ROS 2 apt source package flow:

```bash
sudo apt update
sudo apt install -y curl
mkdir -p runtime/cache/ros2-apt-source
export ROS_APT_SOURCE_VERSION="$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F '"tag_name"' | awk -F'"' '{print $4}')"
curl -L -o "runtime/cache/ros2-apt-source/ros2-apt-source.deb" "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo "$VERSION_CODENAME")_all.deb"
sudo dpkg -i runtime/cache/ros2-apt-source/ros2-apt-source.deb
```

## Simulate Install Before Changing Packages

```bash
sudo apt update
sudo apt install -s ros-humble-ros-base ros-dev-tools ros-humble-demo-nodes-cpp ros-humble-demo-nodes-py | tee runtime/artifacts/preflight/ros2_humble_install_simulation.txt
bash scripts/summarize_apt_simulation.sh runtime/artifacts/preflight/ros2_humble_install_simulation.txt | tee runtime/artifacts/preflight/ros2_humble_install_simulation_summary.txt
```

Stop and ask for review if the simulation proposes removing NVIDIA, CUDA, JetPack, L4T, Docker, or core OS packages. Upgrades to shared system libraries such as `libssl3` or `libsqlite3-0` are not automatic blockers, but they must be visible in the simulation summary before the real install.

## If Apt Is Locked Or Package Lists Are Stale

If `sudo apt update` fails with a lock like:

```text
Could not get lock /var/lib/apt/lists/lock. It is held by process <pid> (apt-get)
```

do not remove the lock file. First inspect and wait:

```bash
ps -fp <pid>
sudo fuser -v /var/lib/apt/lists/lock /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock || true
systemctl is-active apt-daily.service apt-daily-upgrade.service || true
systemctl is-active apt-daily.timer apt-daily-upgrade.timer || true
```

If the process is a normal apt job, wait for it to finish, then run:

```bash
sudo apt update
```

If `apt install` later returns `404 Not Found` for Ubuntu packages, treat it as stale package lists. Do not continue installing with stale indexes. Re-run:

```bash
sudo apt update
```

If `sudo apt update` fetches ROS packages but exits with Docker repository errors like these:

```text
The repository 'https://download.docker.com/linux/ubuntu $(. Release' does not have a Release file.
The repository 'https://download.docker.com/linux/ubuntu /etc/os-release Release' does not have a Release file.
The repository 'https://download.docker.com/linux/ubuntu "${UBUNTU_CODENAME:-$VERSION_CODENAME}") Release' does not have a Release file.
```

then the root cause is a malformed Docker apt source. A shell expression from Docker's repository setup instructions was written literally into an apt source file instead of being evaluated to `jammy`.

Do not install ROS packages until `sudo apt update` exits cleanly. First inspect and record the affected source files:

```bash
mkdir -p runtime/artifacts/preflight
sudo grep -RInE 'download\.docker\.com/linux/ubuntu|\$\(|UBUNTU_CODENAME|VERSION_CODENAME' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | tee runtime/artifacts/preflight/docker_apt_sources_before_fix.txt
```

If the malformed entry is a deb822 source file with `Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")`, back it up and set the suite explicitly to `jammy`:

If another valid Docker source already exists, for example `/etc/apt/sources.list.d/docker.list` already contains `https://download.docker.com/linux/ubuntu jammy stable`, prefer disabling the malformed duplicate deb822 source instead of creating two active Docker sources:

```bash
BAD_DOCKER_SOURCE="/etc/apt/sources.list.d/docker.sources"
test -f "$BAD_DOCKER_SOURCE"
mkdir -p runtime/artifacts/preflight/apt-source-backups
sudo cp -a "$BAD_DOCKER_SOURCE" "runtime/artifacts/preflight/apt-source-backups/$(basename "$BAD_DOCKER_SOURCE").$(date -u +%Y%m%dT%H%M%SZ)"
if sudo grep -q '^Enabled:' "$BAD_DOCKER_SOURCE"; then
  sudo sed -i -E 's/^Enabled:.*/Enabled: no/' "$BAD_DOCKER_SOURCE"
else
  sudo sed -i '1i Enabled: no' "$BAD_DOCKER_SOURCE"
fi
```

If no other valid Docker source exists, back up the deb822 source and set its suite explicitly to `jammy`:

```bash
BAD_DOCKER_SOURCE="$(sudo grep -RIlE '^Suites: .*(\$\(|UBUNTU_CODENAME|VERSION_CODENAME)' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | head -n 1)"
test -n "$BAD_DOCKER_SOURCE"
mkdir -p runtime/artifacts/preflight/apt-source-backups
sudo cp -a "$BAD_DOCKER_SOURCE" "runtime/artifacts/preflight/apt-source-backups/$(basename "$BAD_DOCKER_SOURCE").$(date -u +%Y%m%dT%H%M%SZ)"
sudo sed -i -E '/^Suites: .*(\$\(|UBUNTU_CODENAME|VERSION_CODENAME)/s/.*/Suites: jammy/' "$BAD_DOCKER_SOURCE"
```

If the malformed entry is an old one-line `.list` entry, comment out only the malformed Docker line:

```bash
BAD_DOCKER_SOURCE="$(sudo grep -RIlE '^deb .*download\.docker\.com/linux/ubuntu .*(\$\(|UBUNTU_CODENAME|VERSION_CODENAME)' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | head -n 1)"
test -n "$BAD_DOCKER_SOURCE"
mkdir -p runtime/artifacts/preflight/apt-source-backups
sudo cp -a "$BAD_DOCKER_SOURCE" "runtime/artifacts/preflight/apt-source-backups/$(basename "$BAD_DOCKER_SOURCE").$(date -u +%Y%m%dT%H%M%SZ)"
sudo sed -i -E '/^deb .*download\.docker\.com\/linux\/ubuntu .*(\$\(|UBUNTU_CODENAME|VERSION_CODENAME)/s/^/# disabled malformed docker source: /' "$BAD_DOCKER_SOURCE"
```

Then refresh apt and verify ROS package candidates:

```bash
sudo apt update | tee runtime/artifacts/preflight/apt_update_after_docker_source_fix.txt
apt-cache policy ros-humble-ros-base ros-dev-tools ros-humble-demo-nodes-cpp ros-humble-demo-nodes-py | tee runtime/artifacts/preflight/ros2_policy_after_apt_fix.txt
```

If `ros-humble-*` packages are still not found after installing `ros2-apt-source`, it usually means apt has not refreshed the newly added ROS source yet. Run:

```bash
sudo apt update
apt-cache policy ros-humble-ros-base ros-dev-tools ros-humble-demo-nodes-cpp ros-humble-demo-nodes-py
```

Only continue to simulation after the policy command shows ROS packages are available.

## Install

Only after simulation looks safe:

```bash
sudo apt install -y ros-humble-ros-base ros-dev-tools ros-humble-demo-nodes-cpp ros-humble-demo-nodes-py | tee runtime/artifacts/preflight/ros2_humble_install.txt
```

## Verify

Open a fresh shell or source ROS manually:

```bash
source /opt/ros/humble/setup.bash
ros2 --help
colcon --version
ros2 pkg list | grep '^demo_nodes_cpp$'
```

In terminal 1:

```bash
source /opt/ros/humble/setup.bash
ros2 run demo_nodes_cpp talker
```

In terminal 2:

```bash
source /opt/ros/humble/setup.bash
ros2 run demo_nodes_cpp listener
```

In terminal 3:

```bash
source /opt/ros/humble/setup.bash
ros2 topic list
ros2 topic echo /chatter --once
ros2 topic hz /chatter
mkdir -p runtime/bags/baseline
ros2 bag record /chatter -o runtime/bags/baseline/chatter_smoke
```

Stop recording with `Ctrl+C`, then replay:

```bash
source /opt/ros/humble/setup.bash
ros2 bag play runtime/bags/baseline/chatter_smoke
```

## Expected Evidence

- `ros2 --help` works.
- `colcon --version` works.
- talker/listener communicate.
- `/chatter` appears in `ros2 topic list`.
- `ros2 topic echo /chatter --once` prints one message.
- `ros2 topic hz /chatter` reports a frequency.
- rosbag records under `runtime/bags/`.
- `runtime/` remains ignored by git.

## After Verification

Paste a short sanitized result back into the thread:

```text
ROS apt source existed before install? yes/no
Install simulation removed packages? no/yes + summary
Installed packages command completed? yes/no
ros2 --help works? yes/no
colcon --version works? yes/no
demo_nodes_cpp talker/listener works? yes/no
rosbag record/play works? yes/no
Any errors:
```
