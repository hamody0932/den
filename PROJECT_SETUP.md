# Project Setup Guide - Dental Clinic Management Software

## Quick Start

This guide provides the essential steps to set up and run the Dental Clinic Management Software project.

### Prerequisites

- **Node.js**: Version 16.x or higher
- **npm** or **yarn**: Package manager
- **Git**: For version control
- **Windows**: For hardware integration testing (recommended)

### 1. Project Initialization

```bash
# Clone or download the project
git clone <repository-url>
cd dental-clinic-management-software

# Install dependencies
npm install

# Install additional hardware integration dependencies
npm install printer twain puppeteer jimp pdf-lib winston better-sqlite3
```

### 2. Project Structure Setup

```bash
# Create necessary directories
mkdir -p database/temp scans public/assets
mkdir -p src/components/{layout,common,forms,dashboard,patients,appointments,clinical,financial,utilities,staff,reports}
mkdir -p src/pages src/services src/hooks src/contexts src/utils
mkdir -p main/database main/services main/utils
```

### 3. Database Setup

```bash
# Initialize SQLite database
node -e "
const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

const dbPath = path.join(__dirname, 'database/clinic.db');
const schemaPath = path.join(__dirname, 'DATABASE_SCHEMA.sql');

const db = new Database(dbPath);
const schema = fs.readFileSync(schemaPath, 'utf8');

db.exec(schema);
console.log('Database initialized successfully!');
"
```

### 4. Environment Configuration

Create `.env` file:
```env
NODE_ENV=development
DATABASE_PATH=./database/clinic.db
PORT=3000
```

Create `.env.production`:
```env
NODE_ENV=production
DATABASE_PATH=./resources/database/clinic.db
```

### 5. Development Scripts

Add to `package.json`:
```json
{
  "scripts": {
    "dev": "concurrently \"npm run electron-dev\" \"npm run react-dev\"",
    "electron-dev": "NODE_ENV=development electron .",
    "react-dev": "webpack serve --mode development",
    "build": "webpack --mode production && electron-builder",
    "build:win": "webpack --mode production && electron-builder --win",
    "test": "jest",
    "lint": "eslint src main --ext .js,.jsx",
    "format": "prettier --write src/**/*.js main/**/*.js"
  }
}
```

### 6. Key Configuration Files

#### `main/main.js` - Main Process Entry Point
```javascript
const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const isDev = process.env.NODE_ENV === 'development';

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    },
    icon: path.join(__dirname, '../public/assets/icon.png')
  });

  const startUrl = isDev
    ? 'http://localhost:3000'
    : `file://${path.join(__dirname, '../build/index.html')}`;

  mainWindow.loadURL(startUrl);
  mainWindow.maximize();

  if (isDev) {
    mainWindow.webContents.openDevTools();
  }
}

app.whenReady().then(() => {
  createWindow();

  // Register IPC handlers
  require('./ipcHandlers').registerIPCHandlers();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
```

#### `main/preload.js` - Secure IPC Bridge
```javascript
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  // Patient operations
  getPatients: (filters) => ipcRenderer.invoke('patients:get-all', filters),
  getPatientById: (id) => ipcRenderer.invoke('patients:get-by-id', id),
  createPatient: (data) => ipcRenderer.invoke('patients:create', data),
  updatePatient: (id, data) => ipcRenderer.invoke('patients:update', id, data),

  // Appointment operations
  getAppointments: (dateRange) => ipcRenderer.invoke('appointments:get-all', dateRange),
  createAppointment: (data) => ipcRenderer.invoke('appointments:create', data),
  updateAppointmentStatus: (id, status, notes) =>
    ipcRenderer.invoke('appointments:update-status', id, status, notes),

  // Hardware operations
  getPrinters: () => ipcRenderer.invoke('system:get-printers'),
  printDocument: (printerName, documentPath, options) =>
    ipcRenderer.invoke('hw:print-document', printerName, documentPath, options),
  getScanners: () => ipcRenderer.invoke('system:get-scanners'),
  scanDocument: (scannerId, options) =>
    ipcRenderer.invoke('hw:scan-document', scannerId, options),

  // Utility operations
  backupDatabase: () => ipcRenderer.invoke('fs:backup-database'),
  restoreDatabase: (backupPath) => ipcRenderer.invoke('fs:restore-database', backupPath)
});
```

### 7. React Application Setup

#### `src/App.js` - Main React Component
```jsx
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import AppLayout from './components/layout/AppLayout';
import DashboardPage from './pages/DashboardPage';
import PatientsPage from './pages/PatientsPage';
import AppointmentsPage from './pages/AppointmentsPage';
// Import other pages...

function App() {
  return (
    <Router>
      <AppLayout>
        <Routes>
          <Route path="/" element={<DashboardPage />} />
          <Route path="/patients" element={<PatientsPage />} />
          <Route path="/appointments" element={<AppointmentsPage />} />
          {/* Add other routes */}
        </Routes>
      </AppLayout>
    </Router>
  );
}

export default App;
```

#### `src/services/api.js` - IPC Communication Service
```javascript
class API {
  // Patient API methods
  static async getPatients(filters = {}) {
    try {
      const patients = await window.electronAPI.getPatients(filters);
      return patients;
    } catch (error) {
      console.error('Failed to fetch patients:', error);
      throw error;
    }
  }

  static async getPatientById(id) {
    try {
      const patient = await window.electronAPI.getPatientById(id);
      return patient;
    } catch (error) {
      console.error('Failed to fetch patient:', error);
      throw error;
    }
  }

  static async createPatient(patientData) {
    try {
      const result = await window.electronAPI.createPatient(patientData);
      return result;
    } catch (error) {
      console.error('Failed to create patient:', error);
      throw error;
    }
  }

  static async updatePatient(id, patientData) {
    try {
      const result = await window.electronAPI.updatePatient(id, patientData);
      return result;
    } catch (error) {
      console.error('Failed to update patient:', error);
      throw error;
    }
  }

  // Hardware API methods
  static async getPrinters() {
    try {
      const printers = await window.electronAPI.getPrinters();
      return printers;
    } catch (error) {
      console.error('Failed to get printers:', error);
      throw error;
    }
  }

  static async printDocument(printerName, documentPath, options = {}) {
    try {
      const result = await window.electronAPI.printDocument(printerName, documentPath, options);
      return result;
    } catch (error) {
      console.error('Failed to print document:', error);
      throw error;
    }
  }

  static async getScanners() {
    try {
      const scanners = await window.electronAPI.getScanners();
      return scanners;
    } catch (error) {
      console.error('Failed to get scanners:', error);
      throw error;
    }
  }

  static async scanDocument(scannerId, options = {}) {
    try {
      const result = await window.electronAPI.scanDocument(scannerId, options);
      return result;
    } catch (error) {
      console.error('Failed to scan document:', error);
      throw error;
    }
  }
}

export default API;
```

### 8. Hardware Integration Testing

```javascript
# Test hardware integration
npm run dev

# In the running application:
# 1. Check if printers are detected
# 2. Check if scanners are detected
# 3. Test print functionality with a test document
# 4. Test scan functionality with a test document
```

### 9. Production Build

```bash
# Build for production
npm run build

# Build Windows installer (requires electron-builder)
npm run build:win

# The built application will be in the 'dist' folder
# For Windows, it creates an .exe installer
```

### 10. Troubleshooting

#### Common Issues:

1. **Database Connection Issues**:
   - Ensure SQLite database file exists
   - Check file permissions on database directory
   - Verify database schema is properly initialized

2. **Hardware Detection Issues**:
   - Ensure printer drivers are installed
   - Check Windows services (Print Spooler, WIA)
   - Verify user permissions for hardware access

3. **Build Issues**:
   - Clear node_modules and reinstall if needed
   - Check for missing dependencies
   - Verify all configuration files are present

### 11. Next Steps

After successful setup:

1. **Implement Core Components**: Start with patient management and appointment scheduling
2. **Add Hardware Integration**: Implement printer and scanner functionality
3. **Testing**: Thoroughly test all modules before deployment
4. **Deployment**: Package the application for Windows distribution

### 12. Development Workflow

1. **Start Development**: `npm run dev`
2. **Make Changes**: Edit React components and Node.js services
3. **Test Changes**: Verify functionality in the running application
4. **Commit Changes**: Use git for version control
5. **Build**: Test production build regularly

This setup provides a solid foundation for developing the complete Dental Clinic Management Software with all the specified features and integrations.