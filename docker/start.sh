#!/bin/bash
cat /welcome.txt
export PYTHONUNBUFFERED=1

# Function to set up environment for OpenPAI
setup_openpai_environment() {
    echo -e "\nFound PAI_JOB_NAME: $PAI_JOB_NAME - configuring environment for OpenPAI."
    export IN_PAI=true
    
    # Dynamically get the ports for Jupyter and Tensorboard
    local jupyter_port_var="PAI_PORT_LIST_${PAI_CURRENT_TASK_ROLE_NAME}_${PAI_CURRENT_TASK_ROLE_CURRENT_TASK_INDEX}_jupyter_lab_http"
    local tensorboard_port_var="PAI_PORT_LIST_${PAI_CURRENT_TASK_ROLE_NAME}_${PAI_CURRENT_TASK_ROLE_CURRENT_TASK_INDEX}_tensorboard_http"
    export JUPYTER_PORT=${!jupyter_port_var}
    export TENSORBOARD_PORT=${!tensorboard_port_var}

    # Check if SSH is configured in PAI (TODO: Is this the right condition?)
    [[ -n "$PAI_CONTAINER_SSH_PORT" ]] && export PAI_SSH=true
}

# Check if running in PAI and set up the environment
if [[ -v PAI_JOB_NAME ]]; then
    setup_openpai_environment
fi

if [[ ! -f "v2-inference-v.yaml" ]]; then
    python /workspace/EveryDream2trainer/utils/get_yamls.py
fi

mkdir -p logs input

# Configure SSH if a public key is provided and not running in PAI SSH
if [[ -v PUBLIC_KEY && ! -d "${HOME}/.ssh" && ! -v PAI_SSH ]]; then
    mkdir -p $HOME/.ssh
    echo "${PUBLIC_KEY}" > $HOME/.ssh/authorized_keys
    chmod -R 700 $HOME/.ssh
    service ssh start
fi  

# Start Tensorboard
tensorboard --logdir /workspace/EveryDream2trainer/logs --host 0.0.0.0 --port=${TENSORBOARD_PORT:-6006} &

# Conditionally start JupyterLab
if [[ -v JUPYTER_PASSWORD ]]; then
    jupyter nbextension enable --py widgetsnbextension
    jupyter labextension disable "@jupyterlab/apputils-extension:announcements"
    jupyter lab --allow-root --no-browser --port=${JUPYTER_PORT:-8888} --ip='*' \
        --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
        --ServerApp.token=$JUPYTER_PASSWORD --ServerApp.allow_origin='*' \
        --ServerApp.preferred_dir=/workspace/EveryDream2trainer
else
    echo "Container Started"
    sleep infinity
fi
