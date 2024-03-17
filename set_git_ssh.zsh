#!/bin/zsh

# Set github email
# export GITHUB_U="<usernmae>"
# export GITHUB_E="<email_addr>"

ssh_gen() {
    ssh-keygen -t ed25519 -C $GITHUB_E
    # > Generating public/private ALGORITHM key pair.
    # > Enter a file in which to save the key: [Press enter]
    # > Enter passphrase: [passphrase]
    # > Enter same passphrase again: [passphrase]
}

ssh_start_agent() {
    eval "$(ssh-agent -s)"
    # > Agent pid 59566
    # The --apple-use-keychain option stores the passphrase in your 
    # keychain for you when you add an SSH key to the ssh-agent. 
}

ssh_add_key() {
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519
}

# For MacOS < v12.0
ssh_gen_lt_12() {
    ssh-keygen -t rsa -b 4096 -C $GITHUB_E
    # > Generating public/private ALGORITHM key pair.
    # > Enter a file in which to save the key: [Press enter]
    # > Enter passphrase: [passphrase]
    # > Enter same passphrase again: [passphrase]
}

ssh_add_key_lt_12() {
    # In macOS versions prior to Monterey (12.0), 
    # use -K instead of --apple-use-keychain
    ssh-add -K ~/.ssh/id_ed25519
    # If you continue to be prompted for your passphrase, you may need to 
    # add the command to your ~/.zshrc file (or your ~/.bashrc file for bash).
}

# For MacOS > v10.12.2
ssh_start_agent_gt_10_12_2() {
    # If you're using macOS Sierra 10.12.2 or later, 
    # you will need to modify your ~/.ssh/config file 
    # to automatically load keys into the ssh-agent and 
    # store passphrases in your keychain.

    # Let's do it programmatically
    util_ssh_config_gt_10_12_2
}

util_ssh_config_gt_10_12_2() {
    # Checks if the ~/.ssh/config file exists and, if not, 
    # creates it and adds the requireds content.
    SSH_CONFIG="$HOME/.ssh/config"
    SSH_HOST="github.com"
    SSH_IDENTITY_FILE="$HOME/.ssh/id_ed25519"

    # Check if the SSH config file exists
    if [ ! -f "$SSH_CONFIG" ]; then
        echo "The file $SSH_CONFIG does not exist. Creating it now..."
        touch "$SSH_CONFIG"
    else
        echo "The file $SSH_CONFIG already exists."
    fi

    # Check if the configuration already exists
    if grep -q "Host $SSH_HOST" "$SSH_CONFIG"; then
        echo "Configuration for $SSH_HOST already exists in $SSH_CONFIG."
    else
        # Add configuration to the SSH config file
        echo "Adding configuration for $SSH_HOST to $SSH_CONFIG..."
        cat >> "$SSH_CONFIG" <<EOF
Host $SSH_HOST
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile $SSH_IDENTITY_FILE
EOF
        echo "Configuration added successfully."
    fi
}

set_git_config() {
    git config --global user.name $GITHUB_U
    git config --global user.email $GITHUB_E
}