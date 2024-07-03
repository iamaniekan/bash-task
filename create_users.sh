#!/bin/bash

# Define log file and password file paths
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Function to log messages
log_message() {
    MESSAGE=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $MESSAGE" >> "$LOG_FILE"
}

# Ensure necessary files and permissions
setup_files() {
    touch "$LOG_FILE" "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    log_message "Script started"
}

# Check input file
check_input_file() {
    if [[ -z "$1" ]]; then
        log_message "No input file provided"
        exit 1
    fi
    
    INPUT_FILE="$1"
    
    if [[ ! -f "$INPUT_FILE" ]]; then
        log_message "Input file does not exist: $INPUT_FILE"
        exit 1
    fi
}

# Validate and sanitize input
sanitize_input() {
    INPUT="$1"
    echo "$INPUT" | sed 's/[^a-zA-Z0-9,;]//g'
}

# Create user and groups
create_user_and_groups() {
     USERNAME="$1"
     GROUPS="$2"
    
    # Check if user already exists
    if id "$USERNAME" &>/dev/null; then
        log_message "User $USERNAME already exists"
        return
    fi
    
    # Create user with home directory
    useradd -m -s /bin/bash "$USERNAME"

    if [[ $? -ne 0 ]]; then
        log_message "Failed to create user $USERNAME"
        return
    fi

    log_message "Created user $USERNAME"
    
    # Create personal group
    groupadd "$USERNAME"
    usermod -aG "$USERNAME" "$USERNAME"
    
    # Process additional groups
    IFS=',' read -ra GROUP_LIST <<< "$GROUPS"
    for group in "${GROUP_LIST[@]}"; do
        group=$(echo "$group" | xargs)
        if ! getent group "$group" &>/dev/null; then
            groupadd "$group"
        fi
        
        usermod -aG "$group" "$USERNAME"
    done
    
    generate_password "$USERNAME"
}

# Generate and set a random password
generate_password() {
    USERNAME="$1"
    PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 12)
    echo "$USERNAME:$PASSWORD" | chpasswd

    # Store password in a secure file
    echo "$USERNAME,$PASSWORD" >> "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    log_message "Password setup for $USERNAME is successful"
}

# Process each line of the input file
process_file() {
    while IFS= read -r line; do
        # Ignore empty lines
        [[ -z "$line" ]] && continue
        
        # Remove trailing whitespace
        line=$(sanitize_input "$line")
        
        # Extract username and groups
        USERNAME=$(echo "$line" | cut -d ';' -f 1)
        GROUPS=$(echo "$line" | cut -d ';' -f 2)

        # Create user and groups
        create_user_and_groups "$USERNAME" "$GROUPS" &
    done < "$INPUT_FILE"
    wait
}

# Main function to orchestrate the script
main() {
    setup_files
    check_input_file "$1"
    process_file
    log_message "Script ended"
}

main "$1"
