#!/usr/bin/env node

const { exec, spawn } = require('child_process');
const readline = require('readline');
const util = require('util');
const execPromise = util.promisify(exec);

// Color codes
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  bright: '\x1b[1m'
};

// Configuration
const SESSIONS_PER_PAGE = 9;
let currentPage = 0;

// Tmux status bar color themes
const statusThemes = [
  {
    name: 'blue',
    bg: '#1e3a8a',    // blue-800
    fg: '#ffffff',
    accent: '#60a5fa'  // blue-400
  },
  {
    name: 'green',
    bg: '#166534',    // green-800
    fg: '#ffffff',
    accent: '#4ade80'  // green-400
  },
  {
    name: 'purple',
    bg: '#7c3aed',    // violet-600
    fg: '#ffffff',
    accent: '#a78bfa'  // violet-400
  },
  {
    name: 'orange',
    bg: '#ea580c',    // orange-600
    fg: '#ffffff',
    accent: '#fb923c'  // orange-400
  },
  {
    name: 'red',
    bg: '#dc2626',    // red-600
    fg: '#ffffff',
    accent: '#f87171'  // red-400
  },
  {
    name: 'teal',
    bg: '#0f766e',    // teal-700
    fg: '#ffffff',
    accent: '#5eead4'  // teal-300
  },
  {
    name: 'pink',
    bg: '#be185d',    // pink-700
    fg: '#ffffff',
    accent: '#f472b6'  // pink-400
  },
  {
    name: 'indigo',
    bg: '#4338ca',    // indigo-600
    fg: '#ffffff',
    accent: '#818cf8'  // indigo-400
  },
  {
    name: 'cyan',
    bg: '#0891b2',    // cyan-600
    fg: '#ffffff',
    accent: '#67e8f9'  // cyan-300
  }
];

// Create readline interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Promisify readline question
const question = (query) => new Promise((resolve) => rl.question(query, resolve));

// Hash function to consistently assign colors based on session name
function hashString(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  return Math.abs(hash);
}

// Get theme for session
function getThemeForSession(sessionName) {
  const hash = hashString(sessionName);
  return statusThemes[hash % statusThemes.length];
}

// Set tmux status bar colors and configuration for a session
async function setSessionColors(sessionName) {
  const theme = getThemeForSession(sessionName);
  
  try {
    // Set status bar colors and essential configuration
    const commands = [
      // Status bar colors
      `tmux set-option -t "${sessionName}" status-bg "${theme.bg}"`,
      `tmux set-option -t "${sessionName}" status-fg "${theme.fg}"`,
      `tmux set-option -t "${sessionName}" status-left-style "bg=${theme.accent},fg=${theme.bg}"`,
      `tmux set-option -t "${sessionName}" status-right-style "bg=${theme.accent},fg=${theme.bg}"`,
      `tmux set-option -t "${sessionName}" window-status-current-style "bg=${theme.accent},fg=${theme.bg}"`,
      `tmux set-option -t "${sessionName}" window-status-style "bg=${theme.bg},fg=${theme.fg}"`,
      `tmux set-option -t "${sessionName}" pane-active-border-style "fg=${theme.accent}"`,
      `tmux set-option -t "${sessionName}" pane-border-style "fg=${theme.bg}"`,
      
      // Essential configuration
      `tmux set-option -t "${sessionName}" mouse on`,
      `tmux set-option -t "${sessionName}" history-limit 10000`,
      `tmux set-option -t "${sessionName}" base-index 1`,
      `tmux set-window-option -t "${sessionName}" pane-base-index 1`,
      `tmux set-window-option -t "${sessionName}" mode-keys vi`,
      `tmux set-option -t "${sessionName}" renumber-windows on`,
      
      // Auto split screen keybindings
      `tmux bind-key -t "${sessionName}" c new-window \\; split-window -h -c "#{pane_current_path}" \\; select-pane -L`,
      `tmux bind-key -t "${sessionName}" S new-session \\; split-window -h -c "#{pane_current_path}" \\; select-pane -L`,
      
      // Clipboard integration
      `tmux bind-key -t "${sessionName}" -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"`,
      `tmux bind-key -t "${sessionName}" -T copy-mode-vi v send-keys -X begin-selection`,
      `tmux bind-key -t "${sessionName}" -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"`,
      `tmux bind-key -t "${sessionName}" p paste-buffer`
    ];
    
    // Execute all color commands
    for (const cmd of commands) {
      await execPromise(cmd);
    }
    
    return theme;
  } catch (error) {
    // Ignore errors if session doesn't exist yet
    return theme;
  }
}

// Clear screen and show header
function showHeader() {
  console.clear();
  console.log(`${colors.cyan}╔═══════════════════════════════════════════════════════════╗${colors.reset}`);
  console.log(`${colors.cyan}║${colors.white}${colors.bright}                    TMUX SESSION MANAGER                   ${colors.cyan}║${colors.reset}`);
  console.log(`${colors.cyan}╚═══════════════════════════════════════════════════════════╝${colors.reset}`);
  console.log();
}

// Check if tmux is installed
async function checkTmux() {
  try {
    await execPromise('which tmux');
    return true;
  } catch (error) {
    console.log(`${colors.red}Error: tmux is not installed${colors.reset}`);
    console.log('Please install tmux first: brew install tmux (macOS) or apt install tmux (Ubuntu)');
    process.exit(1);
  }
}

// Get all tmux sessions
async function getSessions() {
  try {
    const { stdout } = await execPromise('tmux list-sessions -F "#{session_name}"');
    if (!stdout.trim()) return [];
    return stdout.trim().split('\n');
  } catch (error) {
    // No sessions exist
    return [];
  }
}

// Get detailed session info
async function getSessionInfo(sessionName) {
  try {
    const { stdout } = await execPromise(
      `tmux list-sessions -F "#{session_name}:#{session_windows}:#{?session_attached,attached,not attached}" | grep "^${sessionName}:"`
    );
    const [, windows, status] = stdout.trim().split(':');
    return `${windows} windows, ${status}`;
  } catch (error) {
    return 'unknown';
  }
}

// Display sessions with pagination
async function displaySessions(sessions) {
  const totalSessions = sessions.length;
  const startIdx = currentPage * SESSIONS_PER_PAGE;
  const endIdx = Math.min(startIdx + SESSIONS_PER_PAGE, totalSessions);
  
  console.log(`${colors.yellow}Available Sessions:${colors.reset}`);
  console.log(`${colors.blue}─────────────────────────────────${colors.reset}`);
  
  if (totalSessions === 0) {
    console.log(`${colors.red}No tmux sessions found${colors.reset}`);
    return false;
  }
  
  let displayCount = 0;
  for (let i = startIdx; i < endIdx; i++) {
    displayCount++;
    const sessionName = sessions[i];
    const sessionInfo = await getSessionInfo(sessionName);
    
    console.log(`${colors.white}${displayCount})${colors.reset} ${colors.green}${sessionName}${colors.reset}`);
    console.log(`   ${colors.magenta}${sessionInfo}${colors.reset}`);
  }
  
  // Show pagination info
  const totalPages = Math.ceil(totalSessions / SESSIONS_PER_PAGE);
  if (totalPages > 1) {
    console.log();
    console.log(`${colors.cyan}Page ${currentPage + 1} of ${totalPages}${colors.reset}`);
  }
  
  return true;
}

// Connect to a session
async function connectToSession() {
  while (true) {
    showHeader();
    
    const sessions = await getSessions();
    const hasSessions = await displaySessions(sessions);
    
    if (!hasSessions) {
      console.log();
      console.log(`${colors.yellow}Options:${colors.reset}`);
      console.log(`${colors.white}n)${colors.reset} Create new session`);
      console.log(`${colors.white}q)${colors.reset} Quit`);
      console.log();
      
      const choice = await question('Enter your choice: ');
      
      switch(choice.toLowerCase()) {
        case 'n':
          await createNewSession();
          return;
        case 'q':
          process.exit(0);
        default:
          console.log(`${colors.red}Invalid option${colors.reset}`);
          await sleep(1000);
      }
      continue;
    }
    
    const totalSessions = sessions.length;
    const startIdx = currentPage * SESSIONS_PER_PAGE;
    const endIdx = Math.min(startIdx + SESSIONS_PER_PAGE, totalSessions);
    const totalPages = Math.ceil(totalSessions / SESSIONS_PER_PAGE);
    
    console.log();
    console.log(`${colors.yellow}Options:${colors.reset}`);
    console.log(`${colors.white}1-9)${colors.reset} Connect to session`);
    
    if (totalPages > 1) {
      if (currentPage > 0) {
        console.log(`${colors.white}p)${colors.reset} Previous page`);
      }
      if (currentPage + 1 < totalPages) {
        console.log(`${colors.white}n)${colors.reset} Next page`);
      }
    }
    
    console.log(`${colors.white}c)${colors.reset} Create new session`);
    console.log(`${colors.white}d)${colors.reset} Delete session`);
    console.log(`${colors.white}r)${colors.reset} Refresh`);
    console.log(`${colors.white}q)${colors.reset} Quit`);
    console.log();
    
    const choice = await question('Enter your choice: ');
    
    if (/^[1-9]$/.test(choice)) {
      const sessionIdx = startIdx + parseInt(choice) - 1;
      if (sessionIdx < endIdx && sessionIdx < totalSessions) {
        const selectedSession = sessions[sessionIdx];
        
        // Set session colors before connecting
        const theme = await setSessionColors(selectedSession);
        console.log(`${colors.green}Connecting to session: ${selectedSession} (${theme.name} theme)${colors.reset}`);
        await sleep(1000);
        
        // Attach to tmux session
        rl.close();
        const tmux = spawn('tmux', ['attach-session', '-t', selectedSession], {
          stdio: 'inherit'
        });
        
        tmux.on('exit', () => {
          process.exit(0);
        });
        
        return;
      } else {
        console.log(`${colors.red}Invalid session number${colors.reset}`);
        await sleep(1000);
      }
    } else {
      switch(choice.toLowerCase()) {
        case 'p':
          if (currentPage > 0) {
            currentPage--;
          } else {
            console.log(`${colors.red}Already on first page${colors.reset}`);
            await sleep(1000);
          }
          break;
        case 'n':
          if (currentPage + 1 < totalPages) {
            currentPage++;
          } else {
            await createNewSession();
            return;
          }
          break;
        case 'c':
          await createNewSession();
          return;
        case 'd':
          await deleteSession();
          currentPage = 0;
          break;
        case 'r':
          currentPage = 0;
          break;
        case 'q':
          process.exit(0);
        default:
          console.log(`${colors.red}Invalid option${colors.reset}`);
          await sleep(1000);
      }
    }
  }
}

// Create a new session
async function createNewSession() {
  showHeader();
  console.log(`${colors.yellow}Create New Tmux Session${colors.reset}`);
  console.log(`${colors.blue}─────────────────────────────────${colors.reset}`);
  console.log();
  
  while (true) {
    const sessionName = await question("Enter session name (or 'q' to quit): ");
    
    if (sessionName.toLowerCase() === 'q') {
      return;
    }
    
    if (!sessionName) {
      console.log(`${colors.red}Session name cannot be empty${colors.reset}`);
      continue;
    }
    
    // Check if session already exists
    try {
      await execPromise(`tmux has-session -t "${sessionName}"`);
      console.log(`${colors.red}Session '${sessionName}' already exists${colors.reset}`);
      const connectChoice = await question('Do you want to connect to it instead? (y/n): ');
      
      if (connectChoice.toLowerCase() === 'y') {
        // Set session colors before connecting
        const theme = await setSessionColors(sessionName);
        console.log(`${colors.green}Connecting to existing session: ${sessionName} (${theme.name} theme)${colors.reset}`);
        await sleep(1000);
        
        rl.close();
        const tmux = spawn('tmux', ['attach-session', '-t', sessionName], {
          stdio: 'inherit'
        });
        
        tmux.on('exit', () => {
          process.exit(0);
        });
        
        return;
      }
    } catch (error) {
      // Session doesn't exist, create it
      const theme = getThemeForSession(sessionName);
      console.log(`${colors.green}Creating session: ${sessionName} (${theme.name} theme)${colors.reset}`);
      await sleep(500);
      
      // Create session in detached mode with auto-split, then set colors, then attach
      try {
        await execPromise(`tmux new-session -d -s "${sessionName}"`);
        // Auto-split the initial window
        await execPromise(`tmux split-window -h -t "${sessionName}:0" -c "#{pane_current_path}"`);
        await execPromise(`tmux select-pane -t "${sessionName}:0.0"`);
        await setSessionColors(sessionName);
        
        rl.close();
        const tmux = spawn('tmux', ['attach-session', '-t', sessionName], {
          stdio: 'inherit'
        });
        
        tmux.on('exit', () => {
          process.exit(0);
        });
        
        return;
      } catch (createError) {
        console.log(`${colors.red}Failed to create session: ${createError.message}${colors.reset}`);
        await sleep(1000);
        continue;
      }
    }
  }
}

// Delete a session
async function deleteSession() {
  while (true) {
    showHeader();
    console.log(`${colors.yellow}Delete Tmux Session${colors.reset}`);
    console.log(`${colors.blue}─────────────────────────────────${colors.reset}`);
    console.log();
    
    const sessions = await getSessions();
    const hasSessions = await displaySessions(sessions);
    
    if (!hasSessions) {
      console.log();
      console.log(`${colors.yellow}No sessions to delete${colors.reset}`);
      console.log(`${colors.white}Press Enter to return...${colors.reset}`);
      await question('');
      return;
    }
    
    const totalSessions = sessions.length;
    const startIdx = currentPage * SESSIONS_PER_PAGE;
    const endIdx = Math.min(startIdx + SESSIONS_PER_PAGE, totalSessions);
    const totalPages = Math.ceil(totalSessions / SESSIONS_PER_PAGE);
    
    console.log();
    console.log(`${colors.red}⚠ WARNING: Deleting a session will terminate all processes in it${colors.reset}`);
    console.log();
    console.log(`${colors.yellow}Options:${colors.reset}`);
    console.log(`${colors.white}1-9)${colors.reset} Select session to delete`);
    
    if (totalPages > 1) {
      if (currentPage > 0) {
        console.log(`${colors.white}p)${colors.reset} Previous page`);
      }
      if (currentPage + 1 < totalPages) {
        console.log(`${colors.white}n)${colors.reset} Next page`);
      }
    }
    
    console.log(`${colors.white}r)${colors.reset} Refresh`);
    console.log(`${colors.white}q)${colors.reset} Back to menu`);
    console.log();
    
    const choice = await question('Enter your choice: ');
    
    if (/^[1-9]$/.test(choice)) {
      const sessionIdx = startIdx + parseInt(choice) - 1;
      if (sessionIdx < endIdx && sessionIdx < totalSessions) {
        const selectedSession = sessions[sessionIdx];
        console.log();
        console.log(`${colors.yellow}Are you sure you want to delete session: ${colors.red}${selectedSession}${colors.yellow}?${colors.reset}`);
        const confirm = await question("Type 'yes' to confirm: ");
        
        if (confirm === 'yes') {
          try {
            await execPromise(`tmux kill-session -t "${selectedSession}"`);
            console.log(`${colors.green}Session '${selectedSession}' deleted successfully${colors.reset}`);
          } catch (error) {
            console.log(`${colors.red}Failed to delete session '${selectedSession}'${colors.reset}`);
          }
          await sleep(1000);
          currentPage = 0;
        } else {
          console.log(`${colors.yellow}Deletion cancelled${colors.reset}`);
          await sleep(1000);
        }
      } else {
        console.log(`${colors.red}Invalid session number${colors.reset}`);
        await sleep(1000);
      }
    } else {
      switch(choice.toLowerCase()) {
        case 'p':
          if (currentPage > 0) {
            currentPage--;
          } else {
            console.log(`${colors.red}Already on first page${colors.reset}`);
            await sleep(1000);
          }
          break;
        case 'n':
          if (currentPage + 1 < totalPages) {
            currentPage++;
          } else {
            console.log(`${colors.red}Already on last page${colors.reset}`);
            await sleep(1000);
          }
          break;
        case 'r':
          currentPage = 0;
          break;
        case 'q':
          return;
        default:
          console.log(`${colors.red}Invalid option${colors.reset}`);
          await sleep(1000);
      }
    }
  }
}

// Show main menu
async function showMainMenu() {
  while (true) {
    showHeader();
    
    // Show quick stats
    const sessions = await getSessions();
    const sessionCount = sessions.length;
    
    if (sessionCount > 0) {
      console.log(`${colors.cyan}Current status: ${colors.green}${sessionCount} active session(s)${colors.reset}`);
    } else {
      console.log(`${colors.cyan}Current status: ${colors.yellow}No active sessions${colors.reset}`);
    }
    
    console.log();
    console.log(`${colors.yellow}Main Menu:${colors.reset}`);
    console.log(`${colors.blue}─────────────────────────────────${colors.reset}`);
    console.log(`${colors.white}1)${colors.reset} Connect to existing sessions`);
    console.log(`${colors.white}2)${colors.reset} Create new session`);
    console.log(`${colors.white}3)${colors.reset} Delete session`);
    console.log(`${colors.white}q)${colors.reset} Quit`);
    console.log();
    
    const choice = await question('Enter your choice: ');
    
    switch(choice) {
      case '1':
        currentPage = 0;
        await connectToSession();
        break;
      case '2':
        await createNewSession();
        break;
      case '3':
        currentPage = 0;
        await deleteSession();
        break;
      case 'q':
      case 'Q':
        console.log(`${colors.green}Goodbye!${colors.reset}`);
        process.exit(0);
      default:
        console.log(`${colors.red}Invalid option. Please choose 1, 2, 3, or q${colors.reset}`);
        await sleep(1000);
    }
  }
}

// Helper function for sleep
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Handle cleanup
process.on('SIGINT', () => {
  console.log();
  console.log(`${colors.green}Goodbye!${colors.reset}`);
  process.exit(0);
});

// Main execution
async function main() {
  await checkTmux();
  
  // Skip main menu and go directly to session management
  currentPage = 0;
  await connectToSession();
}

// Run the application
main().catch(error => {
  console.error(`${colors.red}Error: ${error.message}${colors.reset}`);
  process.exit(1);
});