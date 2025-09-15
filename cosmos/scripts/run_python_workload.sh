#!/bin/bash

# === CONFIGURATION ==="
PROJECT_DIR="/tmp/ycsb/ycsb-azurecosmos-binding-0.18.0-SNAPSHOT"
VENV_DIR="$PROJECT_DIR/venv"
PYTHON_SCRIPT="$PROJECT_DIR/CosmosClient.py"
REQUIREMENTS_FILE="$PROJECT_DIR/requirements.txt"
LOG_FILE="/home/${ADMIN_USER_NAME}/python_cosmos.log"

# === FUNCTIONS ===
create_venv_if_needed() {
  sudo apt install python3.13-venv --yes
  if [ ! -d "$VENV_DIR" ]; then
    echo "📦 Virtual environment not found. Creating at $VENV_DIR..."
    sudo python3.13 -m venv "$VENV_DIR"
    if [ $? -ne 0 ]; then
      echo "❌ Failed to create virtual environment."
      exit 1
    fi
    echo "✅ Virtual environment created."
  else
    echo "✅ Virtual environment already exists."
  fi
}

install_requirements() {
  sudo apt-get install python3-pip --yes
  if [ -f "$REQUIREMENTS_FILE" ]; then
    echo "📚 Installing dependencies from $REQUIREMENTS_FILE..."
    source "$VENV_DIR/bin/activate"
    sudo $(which pip3.13) install --upgrade pip
    sudo $(which pip3.13) install -r "$REQUIREMENTS_FILE"
    if [ $? -ne 0 ]; then
      echo "❌ Failed to install requirements."
      exit 1
    fi
    echo "✅ Dependencies installed."
  else
    echo "⚠️  No requirements.txt found at $REQUIREMENTS_FILE. Skipping dependency installation."
  fi
}

launch_script() {
  if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "❌ Python script not found at $PYTHON_SCRIPT"
    exit 1
  fi

  echo "🚀 Launching $PYTHON_SCRIPT in background using venv..."

  source "$VENV_DIR/bin/activate"
  echo "$(which python3.13) -u $PYTHON_SCRIPT --endpoint $COSMOS_URI --database "ycsb" --container "usertable" --key $COSMOS_KEY --workload_type $workload_type --read_document_count $read_document_count --ops $YCSB_OPERATION_COUNT --concurrency $THREAD_COUNT --target_ops_per_sec $TARGET_OPERATIONS_PER_SECOND --use_envoy $USE_ENVOY --proxy_host $PROXY_DNS_NAME"

  # do not pass --use_envoy and --proxy_host if not using envoy
  if [ "$USE_ENVOY" != "true" ] && [ "$USE_ENVOY" != "True" ]; then
    echo "🚀 Launching $PYTHON_SCRIPT without --use_envoy and --proxy_host..."
    sudo $(which python3.13) "$PYTHON_SCRIPT" --endpoint $COSMOS_URI --database "ycsb" --container "usertable" --key $COSMOS_KEY --workload_type $workload_type --read_document_count $read_document_count --ops $YCSB_OPERATION_COUNT --concurrency $THREAD_COUNT --target_ops_per_sec $TARGET_OPERATIONS_PER_SECOND > "$LOG_FILE" 2>&1
  else
    echo "🚀 Launching $PYTHON_SCRIPT with --use_envoy and --proxy_host..."
    sudo $(which python3.13) "$PYTHON_SCRIPT" --endpoint $COSMOS_URI --database "ycsb" --container "usertable" --key $COSMOS_KEY --workload_type $workload_type --read_document_count $read_document_count --ops $YCSB_OPERATION_COUNT --concurrency $THREAD_COUNT --target_ops_per_sec $TARGET_OPERATIONS_PER_SECOND --use_envoy $USE_ENVOY --proxy_host $PROXY_DNS_NAME > "$LOG_FILE" 2>&1
  fi
  echo "✅ Script launched. Logging to $LOG_FILE"
}

install_py3_13() {
  sudo add-apt-repository ppa:deadsnakes/ppa --yes
  sudo apt install python3.13 --yes
  if [ $? -ne 0 ]; then
    echo "❌ Failed to install Python 3.13."
    exit 1
  fi
  echo "✅ Python 3.13 installed."
}

# === EXECUTION ===
#set -x
install_py3_13
create_venv_if_needed
install_requirements
launch_script
#set +x