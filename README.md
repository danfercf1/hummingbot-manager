# Hummingbot Container Manager

A bash script to manage multiple Hummingbot trading bot instances running in separate Docker containers.

## Features

- 🐳 Manage multiple Hummingbot instances from one interface
- 📜 List all running Hummingbot containers
- ➕ Create new instances with isolated configurations
- 🔌 Attach to any running instance
- ⏹ Stop running instances
- 📁 Automatic directory management for each instance

## Prerequisites

- Docker installed and running
- Docker Compose (optional, for reference)
- Bash shell

## Installation

1. Save the script to a file:

   ```bash
   curl -o hummingbot-manager.sh https://raw.githubusercontent.com/danfercf1/hummingbot-manager/refs/heads/main/manager.sh
