#!/bin/bash
set -euo pipefail

PLR_PATH={USER_HOME}/printer_data/gcodes/plr
VARIABLES={USER_HOME}/printer_data/config/variables.cfg
GENERATOR={PLR_DIR}/plr_generate.py

mkdir -p "$PLR_PATH"
filepath=$(sed -n "s/.*filepath *= *'\([^']*\)'.*/\1/p" "$VARIABLES")
last_file=$(sed -n "s/.*last_file *= *'\([^']*\)'.*/\1/p" "$VARIABLES")

if [ -z "$filepath" ] || [ -z "$last_file" ]; then
  echo "PLR generation failed: filepath or last_file is empty" >&2
  exit 1
fi

echo "$filepath"
echo "$last_file"
echo "plr=$last_file"

python3 "$GENERATOR" "$1" "$filepath" "$PLR_PATH/$last_file"
