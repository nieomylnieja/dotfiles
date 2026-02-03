#!/usr/bin/env bash
# Nord color scheme for ble.sh
# https://www.nordtheme.com/
# https://github.com/nordtheme/nord

# Nord Palette
# Polar Night
nord0='#2e3440' # Background
nord1='#3b4252' # Lighter background
nord2='#434c5e' # Selection background
nord3='#4c566a' # Comments, invisibles
# Snow Storm
nord4='#d8dee9' # Dark foreground
nord5='#e5e9f0' # Foreground
nord6='#eceff4' # Light foreground
# Frost
nord7='#8fbcbb'  # Cyan
nord8='#88c0d0'  # Bright cyan
nord9='#81a1c1'  # Blue
nord10='#5e81ac' # Bright blue
# Aurora
nord11='#bf616a' # Red
nord12='#d08770' # Orange
nord13='#ebcb8b' # Yellow
nord14='#a3be8c' # Green
nord15='#b48ead' # Purple

# Error states
ble-face argument_error="bg=$nord11,fg=$nord0"
ble-face argument_option="fg=$nord7,italic"

# Auto-complete
ble-face auto_complete="fg=$nord3,italic"

# Commands
ble-face command_alias="fg=$nord8"
ble-face command_builtin="fg=$nord12"
ble-face command_directory="fg=$nord10"
ble-face command_file="fg=$nord8"
ble-face command_function="fg=$nord8"
ble-face command_keyword="fg=$nord15"

# Disabled
ble-face disabled="fg=$nord1"

# Filenames
ble-face filename_directory="fg=$nord10"
ble-face filename_directory_sticky="fg=$nord0,bg=$nord14"
ble-face filename_executable="fg=$nord14,bold"
ble-face filename_orphan="fg=$nord8,bold"
ble-face filename_setgid="fg=$nord0,bg=$nord13,underline"
ble-face filename_setuid="fg=$nord0,bg=$nord12,underline"

# UI
ble-face overwrite_mode="fg=$nord0,bg=$nord8"

# Region/Selection
ble-face region="bg=$nord2"
ble-face region_insert="bg=$nord2"
ble-face region_match="fg=$nord0,bg=$nord13"
ble-face region_target="fg=$nord0,bg=$nord15"

# Syntax highlighting
ble-face syntax_brace="fg=$nord3"
ble-face syntax_command="fg=$nord8"
ble-face syntax_comment="fg=$nord3,italic"
ble-face syntax_delimiter="fg=$nord3"
ble-face syntax_document="fg=$nord4,bold"
ble-face syntax_document_begin="fg=$nord4,bold"
ble-face syntax_error="bg=$nord11,fg=$nord0"
ble-face syntax_escape="fg=$nord13"
ble-face syntax_expr="fg=$nord15"
ble-face syntax_function_name="fg=$nord9"
ble-face syntax_glob="fg=$nord12"
ble-face syntax_history_expansion="fg=$nord9,italic"
ble-face syntax_param_expansion="fg=$nord11"
ble-face syntax_quotation="fg=$nord14"
ble-face syntax_tilde="fg=$nord15"
ble-face syntax_varname="fg=$nord4"

# Variable names
ble-face varname_array="fg=$nord12"
ble-face varname_empty="fg=$nord12"
ble-face varname_export="fg=$nord12"
ble-face varname_expr="fg=$nord12"
ble-face varname_hash="fg=$nord12"
ble-face varname_number="fg=$nord4"
ble-face varname_readonly="fg=$nord12"
ble-face varname_transform="fg=$nord12"
ble-face varname_unset="bg=$nord11,fg=$nord0"

# Visual bell
ble-face vbell_erase="bg=$nord2"
