#!/bin/bash
# Wrapper script to run commands in the WAN2.2 conda environment

# Initialize conda
if [ -f "/root/miniconda3/etc/profile.d/conda.sh" ]; then
    source "/root/miniconda3/etc/profile.d/conda.sh"
else
    export PATH="/root/miniconda3/bin:$PATH"
fi

# Activate the environment
conda activate wan22_lora

# Execute the command passed as arguments
exec "$@"