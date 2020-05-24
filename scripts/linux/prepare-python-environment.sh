#!/usr/bin/env sh

VENV_PATH="env"
echo "Creating a new virtual environment in $VENV_PATH"
python3 -m venv "$VENV_PATH"

# shellcheck source=/dev/null
. "$VENV_PATH"/bin/activate

echo "Installing pip packages in the $VENV_PATH virtual environment..."
pip install -r requirements.txt

echo "To activate the $VENV_PATH virtual environment, source the $VENV_PATH/bin/activate script."
echo "To deactivate the $VENV_PATH virtual environment, execute the deactivate command."
