# Setting up a k3s 3 node cluster using multipass

## Prerequisites

This script was developed for MacOS development environments, but might translate to linux with some tweaks.

### multipass

```bash
brew install multipass
```

### kubectl

```bash
brew install kubectl
```

## Usage

To setup a lightweight k3s cluster via multipass, try the following:

```bash
git clone https://github.com/brozeph/multipass-with-k3s.git
cd multipass-with-k3s
bash k3s-setup.sh
```

### Cleaning up

There's a simple cleanup routine in the script to remove the VMs and tear down the cluster.

```bash
bash k3s-setup.sh --cleanup
```

### Customizing the settings

Within the `k3s-setup.sh` script, a few environment variables at the top of the script can be used to adjust the size of the VMs, etc.