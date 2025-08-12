# Wingman CLI 🚁

A powerful terminal session manager and project enhancement tool that combines intelligent tmux session management with comprehensive project setup utilities.

## 🌟 Features

- **Smart tmux session management** with project-aware templates
- **Dual-mode project initialization** (new projects vs. existing repositories)
- **Enhanced clipboard integration** with cmd+c/cmd+v support on macOS
- **Git worktree management** for efficient branch switching
- **Project type detection** and framework-specific configurations
- **Interactive development menu** with context-sensitive options
- **Cross-platform support** (macOS and Linux)

## 🚀 Quick Start

### Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd wingman-cli
   ```

2. **Install globally (optional):**
   ```bash
   ./gowt/install-global.sh
   # Choose installation method:
   # 1. Install to /usr/local/bin (requires sudo)
   # 2. Install to ~/bin (user only)  
   # 3. Create alias (links to current location)
   ```

3. **Install dependencies for Node.js features:**
   ```bash
   npm install
   ```

### Prerequisites

- **tmux** - Session management
  ```bash
  # macOS
  brew install tmux
  
  # Ubuntu/Debian
  sudo apt install tmux
  ```

- **Node.js & npm** - For project features
- **Git** - For repository management
- **jq** (recommended) - For package.json manipulation
- **reattach-to-user-namespace** (macOS, recommended) - For better clipboard integration
  ```bash
  brew install reattach-to-user-namespace
  ```

## 🎯 Usage

### Wingman CLI Session Manager

**Start the session manager:**
```bash
# From project directory
node index.js

# Or if installed globally
wingman-cli
```

**Features:**
- **Project context detection** - Shows project name, type, and available commands
- **Smart session naming** - Suggests context-aware session names
- **Multi-window templates** - Creates specialized layouts for different project types
- **Enhanced clipboard** - Full cmd+c/cmd+v support

### Project Enhancement (GOWT)

**For new projects:**
```bash
mkdir my-project && cd my-project
./gowt/init-project.sh --init
# Creates full project structure with all tooling
```

**For existing repositories:**
```bash
git clone https://github.com/user/existing-project.git
cd existing-project
./gowt/init-project.sh --enhance
# Adds wingman tooling without overwriting existing files
```

**Auto-detection mode:**
```bash
./gowt/init-project.sh
# Automatically detects if directory is empty (init) or has existing project (enhance)
```

## 📋 Detailed Features

### 🎮 Session Management

#### Project-Aware Session Creation
When you create a new session, Wingman CLI detects your project context and:

- **Suggests intelligent names** based on project name and type
- **Creates multi-window layouts** optimized for your project type:
  
  **Node.js/React/Next.js Projects:**
  - Window 0: Terminal
  - Window 1: Editor  
  - Window 2: Development server (`npm run dev`)
  - Window 3: Test runner (`npm run test`)
  - Window 4: Project menu (if `menu.sh` exists)

  **Rust Projects:**
  - Window 0: Terminal
  - Window 1: Editor
  - Window 2: Cargo runner (`cargo run`)

  **Go Projects:**
  - Window 0: Terminal  
  - Window 1: Editor
  - Window 2: Go runner (`go run .`)

#### Session Features
- **Color-coded themes** - Each session gets a unique color scheme
- **Session descriptions** - Add notes about what each session is for
- **Split-screen options** - Choose single pane or automatic left/right split
- **Session editing** - Rename sessions and update descriptions
- **Pagination** - Handle large numbers of sessions efficiently

### 📋 Clipboard Integration

#### macOS Support
- **Full cmd+c/cmd+v compatibility** in tmux sessions
- **Automatic `reattach-to-user-namespace` integration** when available
- **Mouse selection copying** - Click and drag automatically copies to system clipboard
- **Multiple copy modes** - Supports both vi-mode and emacs-mode

#### Copy Methods
- **Mouse selection** - Click and drag to copy
- **Vi-mode shortcuts:**
  - `v` - Start visual selection
  - `y` - Copy to system clipboard
  - `Enter` - Copy to system clipboard
- **Emacs-mode shortcuts:**
  - `M-w` - Copy to system clipboard
  - `C-w` - Cut to system clipboard
- **Paste:** `p` - Paste from tmux buffer

### 🌳 Git Worktree Management

#### Automatic Setup
- **Detects existing worktrees** and enhances them
- **Creates standard branches** (`main`, `hotfix`)
- **Provides management scripts** for easy worktree operations

#### Worktree Commands
```bash
# Switch to existing worktree
npm run worktree:switch main
npm run worktree:switch feature-branch

# Create new worktree  
npm run worktree:create feature-name
npm run worktree:create bugfix-123 main

# Or use scripts directly
./scripts/worktree-switch.sh main
./scripts/worktree-create.sh feature-name
```

### 🔧 Project Enhancement

#### Smart Detection
The enhancement system detects and preserves:
- **Existing package.json** - Merges new scripts without overwriting
- **Project structure** - Only creates missing directories
- **Configuration files** - Preserves existing `.gitignore`, `README.md`, etc.
- **Framework detection** - Identifies React, Vue, Angular, Next.js, etc.

#### Enhancement Features
- **Package.json enhancement** - Adds wingman scripts while preserving existing ones
- **Development menu** - Creates interactive project management interface
- **Database setup** (optional) - SQLite integration for Node.js projects
- **Environment configuration** - Creates `.env` files if missing
- **Testing setup** - Adds Jest, ESLint, Prettier configurations

### 📱 Interactive Menu System

**Access the menu:**
```bash
npm run menu
# Or directly
./menu.sh
```

**Menu Features:**
- **Worktree management** - Switch, create, delete worktrees
- **Script runner** - Execute any npm script interactively  
- **Git operations** - Status, log, branch management
- **Development tools** - Launch editors, Claude Code
- **Project information** - View project details and dependencies
- **Database operations** (if configured) - Run migrations, seed data

## 🎨 Project Types & Templates

### Supported Project Types
- **Node.js** - Basic Node.js applications
- **React** - React applications and libraries
- **Next.js** - Next.js full-stack applications
- **Vue.js** - Vue applications and components
- **Angular** - Angular applications
- **Rust** - Rust applications and libraries
- **Go** - Go applications and modules
- **Python** - Python applications with requirements.txt or pyproject.toml

### Template Features
Each project type gets:
- **Optimized tmux layouts** with relevant windows
- **Framework-specific scripts** and commands
- **Development server integration** with auto-start
- **Testing integration** with dedicated test windows
- **Menu customization** based on available tools

## ⚙️ Configuration

### Command Line Arguments
```bash
# Force initialization mode (overwrites existing files)
./gowt/init-project.sh --init

# Force enhancement mode (preserves existing files)  
./gowt/init-project.sh --enhance

# Auto-detection mode (recommended)
./gowt/init-project.sh
```

### Environment Detection
- **Automatic platform detection** (macOS vs Linux)
- **Tool availability checking** (jq, reattach-to-user-namespace, etc.)
- **Framework detection** from dependencies and config files
- **Development command detection** (dev, start, serve scripts)

## 🐛 Troubleshooting

### Clipboard Issues
If cmd+c/cmd+v isn't working:

1. **Install reattach-to-user-namespace:**
   ```bash
   brew install reattach-to-user-namespace
   ```

2. **Restart tmux:**
   ```bash
   tmux kill-server
   # Then start a new session
   ```

3. **Check mouse mode:**
   ```bash
   tmux show-options -g mouse
   # Should show: mouse on
   ```

### Session Issues
If sessions aren't creating properly:

1. **Check tmux version:**
   ```bash
   tmux -V
   # Requires tmux 2.1+
   ```

2. **Verify project context:**
   ```bash
   # Make sure you're in a project directory
   ls package.json  # For Node.js projects
   ```

### Enhancement Issues
If enhancement mode isn't working:

1. **Check jq availability:**
   ```bash
   which jq || echo "Install jq for better package.json handling"
   ```

2. **Verify permissions:**
   ```bash
   # Make sure scripts are executable
   chmod +x scripts/*.sh menu.sh
   ```

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch:** `git checkout -b feature-name`
3. **Make your changes** and test thoroughly
4. **Submit a pull request** with a clear description

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

- **Issues:** Report bugs and feature requests in the GitHub issues
- **Discussions:** Join conversations about usage and improvements
- **Documentation:** Check the wiki for additional guides and examples

---

**Made with ❤️ for developers who want better terminal workflows**