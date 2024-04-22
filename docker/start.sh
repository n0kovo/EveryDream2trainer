#!/bin/bash
cat /welcome.txt
export PYTHONUNBUFFERED=1

# Function to set up environment for OpenPAI
setup_openpai_environment() {
    echo -e "\nFound PAI_JOB_NAME: $PAI_JOB_NAME - configuring environment for OpenPAI."
    export IN_PAI=true
    
    # Dynamically get the ports for Jupyter and Tensorboard
    export JUPYTER_PORT=$PAI_CONTAINER_HOST_jupyter_lab_http_PORT_LIST
    export TENSORBOARD_PORT=$PAI_CONTAINER_HOST_tensorboard_http_PORT_LIST

    # Check if SSH is configured in PAI (TODO: Is this the right condition?)
    [[ -n "$PAI_CONTAINER_SSH_PORT" ]] && export PAI_SSH=true
}

# Check if running in PAI and set up the environment
if [[ -v PAI_JOB_NAME ]]; then
    setup_openpai_environment
fi

if [[ ! -f "v1-inference-v.yaml" ]]; then
    python /workspace/EveryDream2trainer/utils/get_yamls.py
fi

mkdir -p EveryDream2trainer/logs EveryDream2trainer/input

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
if [[ -v JUPYTER_PASSWD ]]; then
    export jupyter_passwd=$JUPYTER_PASSWD
    export jupyter_passwd_hash=`python3 -c "import os;from IPython.lib.security import passwd; print(passwd(passphrase=os.environ['jupyter_passwd'], algorithm='sha1'))"`
    jupyter nbextension enable --py widgetsnbextension
    jupyter labextension disable "@jupyterlab/apputils-extension:announcements"
    jupyter lab --allow-root --no-browser --port=${JUPYTER_PORT:-8888} --ip='*' \
        --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
        --NotebookApp.password=$jupyter_passwd_hash --ServerApp.allow_origin='*' \
        --ServerApp.preferred_dir=/workspace/EveryDream2trainer
else
    echo "Container Started"
    sleep infinity
fi
