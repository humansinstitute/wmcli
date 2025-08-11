#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Installing go-wingman script globally...${NC}"

# Option 1: Install to /usr/local/bin (requires sudo)
install_to_usr_local() {
    sudo cp init-project.sh /usr/local/bin/go-wingman
    sudo chmod +x /usr/local/bin/go-wingman
    echo -e "${GREEN}✓ Installed to /usr/local/bin/go-wingman${NC}"
    echo -e "${GREEN}You can now run 'go-wingman' from anywhere${NC}"
}

# Option 2: Install to user's local bin
install_to_home_bin() {
    mkdir -p ~/bin
    cp init-project.sh ~/bin/go-wingman
    chmod +x ~/bin/go-wingman
    
    # Add ~/bin to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo "" >> ~/.bashrc
        echo "# Added by go-wingman installer" >> ~/.bashrc
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
        echo "" >> ~/.zshrc 2>/dev/null
        echo "# Added by go-wingman installer" >> ~/.zshrc 2>/dev/null
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc 2>/dev/null
        echo -e "${BLUE}Added ~/bin to PATH in shell config${NC}"
        echo -e "${BLUE}Please run: source ~/.bashrc (or restart terminal)${NC}"
    fi
    
    echo -e "${GREEN}✓ Installed to ~/bin/go-wingman${NC}"
    echo -e "${GREEN}You can now run 'go-wingman' from anywhere${NC}"
}

# Option 3: Create an alias
create_alias() {
    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/init-project.sh"
    
    echo "" >> ~/.bashrc
    echo "# Alias for go-wingman" >> ~/.bashrc
    echo "alias go-wingman='$SCRIPT_PATH'" >> ~/.bashrc
    
    echo "" >> ~/.zshrc 2>/dev/null
    echo "# Alias for go-wingman" >> ~/.zshrc 2>/dev/null
    echo "alias go-wingman='$SCRIPT_PATH'" >> ~/.zshrc 2>/dev/null
    
    echo -e "${GREEN}✓ Created alias 'go-wingman'${NC}"
    echo -e "${BLUE}Please run: source ~/.bashrc (or restart terminal)${NC}"
    echo -e "${GREEN}You can now run 'go-wingman' from anywhere${NC}"
}

echo ""
echo "Choose installation method:"
echo "1) Install to /usr/local/bin (requires sudo)"
echo "2) Install to ~/bin (user only)"
echo "3) Create alias (links to current location)"
echo "4) Cancel"
echo ""
read -p "Choice [1-4]: " choice

case $choice in
    1) install_to_usr_local ;;
    2) install_to_home_bin ;;
    3) create_alias ;;
    4) echo "Installation cancelled" ;;
    *) echo "Invalid choice" ;;
esac