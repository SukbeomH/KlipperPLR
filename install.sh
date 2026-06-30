#!/bin/bash

REAL_USER="$USER"
OWNER=""

# Get the path & user from env
if [ -n "$SUDO_USER" ]; then
    echo "shell script execute by with sudo :  user is $SUDO_USER"
    if [ "$SUDO_USER" = "runner" ]; then
        # Définir USER_HOME spécifiquement pour 'runner' et définir OWNER à 'pi'
        USER_HOME="/home/pi"
        OWNER="pi"
    else
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        OWNER="$SUDO_USER"
    fi
else
    USER_HOME=$(getent passwd "$USER" | cut -d: -f6)
    OWNER="$USER"
    echo "shell script execute without sudo : user is $USER"
fi

echo "Real user: $REAL_USER"
echo "User's home directory: $USER_HOME"
echo "Owner for chown: $OWNER"

# Define the Klipper directory using USER_HOME instead of HOME
KLIPPER_DIR="$USER_HOME/klipper"
echo "Klipper directory: $KLIPPER_DIR"

# Define the project directory
PROJECT_DIR="$PWD"
echo "Project directory: $PROJECT_DIR"

# Create the variables.cfg file in the printer_data directory, if it doesn't exist
if [ ! -f $USER_HOME/printer_data/config/variables.cfg ]; then
  touch $USER_HOME/printer_data/config/variables.cfg && echo "variables.cfg created successfully." || echo "Error creating variables.cfg."
fi

# Copy the project files to the Klipper directory
cp -f $PROJECT_DIR/plr.cfg $USER_HOME/printer_data/config/ && echo "plr.cfg copied successfully." || echo "Error copying plr.cfg."
# Auto replace path
sed -i -E "s|\{USER_HOME\}|$USER_HOME|i" $USER_HOME/printer_data/config/plr.cfg
sed -i -E "s|\{PLR_DIR\}|$USER_HOME/printer_data/plr|i" $USER_HOME/printer_data/config/plr.cfg

cp -f $PROJECT_DIR/gcode_shell_command.py $KLIPPER_DIR/klippy/extras/ && echo "gcode_shell_command.py copied successfully." || echo "Error copying gcode_shell_command.py."

# Use rsync to copy, overwriting existing files and create the folder if it does not exist
rsync $PROJECT_DIR/plr.sh $USER_HOME/printer_data/plr/ && echo "plr.sh copied successfully." || echo "Error copying plr.sh."
rsync $PROJECT_DIR/plr_generate.py $USER_HOME/printer_data/plr/ && echo "plr_generate.py copied successfully." || echo "Error copying plr_generate.py."
rsync $PROJECT_DIR/clear_plr.sh $USER_HOME/printer_data/plr/ && echo "clear_plr.sh copied successfully." || echo "Error copying clear_plr.sh."
# Auto replace path
sed -i -E "s|\{USER_HOME\}|$USER_HOME|i" $USER_HOME/printer_data/plr/plr.sh
sed -i -E "s|\{PLR_DIR\}|$USER_HOME/printer_data/plr|i" $USER_HOME/printer_data/plr/plr.sh
sed -i -E "s|\{USER_HOME\}|$USER_HOME|i" $USER_HOME/printer_data/plr/clear_plr.sh
# Make plr.sh & clear_plr.sh executable
chmod +x $USER_HOME/printer_data/plr/plr.sh && echo "plr.sh made executable." || echo "Error making plr.sh executable."
chmod +x $USER_HOME/printer_data/plr/plr_generate.py && echo "plr_generate.py made executable." || echo "Error making plr_generate.py executable."
chmod +x $USER_HOME/printer_data/plr/clear_plr.sh && echo "clear_plr.sh made executable." || echo "Error making clear_plr.sh executable."

# Check if printer.cfg exists, create it if it doesn't
if [ ! -f $USER_HOME/printer_data/config/printer.cfg ]; then
    touch $USER_HOME/printer_data/config/printer.cfg && echo "printer.cfg created successfully." || echo "Error creating printer.cfg."
fi

# Check if the file exists
if [ ! -f $USER_HOME/printer_data/config/printer.cfg ]; then
  echo "Error: $USER_HOME/printer_data/config/printer.cfg does not exist."
fi

# Check if the string is already present in the file
if grep -Fxq '[include plr.cfg]' $USER_HOME/printer_data/config/printer.cfg; then
    echo "The string [include plr.cfg] is already present in the file."
else
    # Create a temporary file
    temp_file=$(mktemp)

    # Add the line [include plr.cfg] at the beginning of the file
    echo "[include plr.cfg]" > "$temp_file"
    cat $USER_HOME/printer_data/config/printer.cfg >> "$temp_file"

    # Replace the original file with the temporary file
    mv "$temp_file" $USER_HOME/printer_data/config/printer.cfg

    # Check if the string was added successfully
    if grep -q '[include plr.cfg]' $USER_HOME/printer_data/config/printer.cfg; then
        echo "The string [include plr.cfg] was successfully added."
    else
        echo "Error: the string [include plr.cfg] was not added."
    fi
fi

# Check if the variables.cfg file exists
if [ ! -f $USER_HOME/printer_data/config/variables.cfg ]; then
  echo "The file $USER_HOME/printer_data/config/variables.cfg does not exist. Creating..."
  # Attempt to create the variables.cfg file
  touch $USER_HOME/printer_data/config/variables.cfg

  # Check if the file was created successfully
  if [ -f $USER_HOME/printer_data/config/variables.cfg ]; then
    echo "The file $USER_HOME/printer_data/config/variables.cfg was created successfully."
  else
    echo "Error: Creating the file $USER_HOME/printer_data/config/variables.cfg failed."
  fi
else
  echo "The file $USER_HOME/printer_data/config/variables.cfg already exists."
fi

# Check if the moonraker.conf file exists
if [ ! -f $USER_HOME/printer_data/config/moonraker.conf ]; then
    echo "The file moonraker.conf does not exist, creating the file..."
    touch $USER_HOME/printer_data/config/moonraker.conf
fi

# Check if the string [include update_plr.cfg] is already present in the file
if grep -Fxq "[include update_plr.cfg]" $USER_HOME/printer_data/config/moonraker.conf; then
    echo "The string [include update_plr.cfg] is already present in the file moonraker.conf."
else
    echo "Adding the string [include update_plr.cfg] to the file moonraker.conf..."
    # Create a temporary file
    temp_file=$(mktemp)

    # Add the line [include update_plr.cfg] at the beginning of the file
    echo "[include update_plr.cfg]" > "$temp_file"
    cat $USER_HOME/printer_data/config/moonraker.conf >> "$temp_file"

    # Replace the original file with the temporary file
    mv "$temp_file" $USER_HOME/printer_data/config/moonraker.conf
fi

# Check if the update_plr.cfg file exists
if [ -f $USER_HOME/printer_data/config/update_plr.cfg ]; then
    echo "The file update_plr.cfg already exists, deleting the file..."
    rm $USER_HOME/printer_data/config/update_plr.cfg
fi

# Create a new update_plr.cfg file with cat EOF
echo "Creating a new update_plr.cfg file with cat EOF..."
cat > $USER_HOME/printer_data/config/update_plr.cfg << EOF
# plr-klipper update_manager entry
[update_manager KlipperPLR]
type: git_repo
path: ~/KlipperPLR
origin: https://github.com/SukbeomH/KlipperPLR.git
primary_branch: main
install_script: install.sh
is_system_service: False

EOF

echo "Check if the script is executed using sudo..."
if [ -n "$SUDO_USER" ]; then
    echo "The script is executed using sudo."
    # La variable SUDO_USER est définie, donc le script est exécuté avec sudo
    REAL_USER="$SUDO_USER"
    echo "Utilisateur réel (SUDO_USER) : $REAL_USER"
    
    echo "Personal path of real users (USER_HOME) : $USER_HOME"

    echo "Execute the chown command of $USER_HOME/printer_data/config/ with $OWNER:$OWNER"
    chown -R "$OWNER":"$OWNER" "$USER_HOME/printer_data/config/"
    echo "Execute the chown command."
else
    echo "This script is not executed using sudo."
fi

# Print a message to the user
echo "Installation complete"

#end of script
