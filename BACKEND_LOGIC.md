# Node.js Backend Logic - Dental Clinic Management Software

## Backend Architecture Overview

### Main Process Responsibilities
The Electron main process handles all business logic, database operations, file system interactions, and hardware integration. The renderer process communicates via IPC channels.

### Core Modules Structure
```
main/
├── database/
│   ├── connection.js        # Database connection management
│   ├── queries.js           # SQL query builders
│   └── operations.js        # CRUD operations
├── services/
│   ├── patientService.js    # Patient management logic
│   ├── appointmentService.js # Appointment scheduling logic
│   ├── clinicalService.js   # Clinical operations logic
│   ├── financialService.js  # Financial calculations and billing
│   ├── documentService.js   # Document management and scanning
│   └── staffService.js      # Staff management logic
├── utils/
│   ├── pdfGenerator.js      # PDF report generation
│   ├── backupManager.js     # Database backup/restore
│   ├── printerManager.js    # Print job management
│   └── scannerManager.js    # Document scanning
└── ipcHandlers.js           # IPC communication handlers
```

## Database Operations Layer

### Connection Management
```javascript
// database/connection.js
const Database = require('better-sqlite3');
const path = require('path');

class DatabaseManager {
  constructor() {
    this.db = null;
    this.isConnected = false;
  }

  async connect(databasePath = null) {
    try {
      const dbPath = databasePath || path.join(__dirname, '../../database/clinic.db');
      this.db = new Database(dbPath);
      this.db.pragma('journal_mode = WAL'); // Enable WAL mode for better concurrency
      this.db.pragma('foreign_keys = ON');  // Enable foreign key constraints
      this.isConnected = true;

      // Run migrations if needed
      await this.runMigrations();

      return true;
    } catch (error) {
      console.error('Database connection failed:', error);
      throw error;
    }
  }

  async runMigrations() {
    // Check and run pending migrations
    const migrations = fs.readdirSync('./migrations');
    // Migration logic here
  }

  getConnection() {
    if (!this.isConnected || !this.db) {
      throw new Error('Database not connected');
    }
    return this.db;
  }
}
```

### Query Builder Pattern
```javascript
// database/queries.js
class QueryBuilder {
  constructor(table) {
    this.table = table;
    this.selectFields = ['*'];
    this.whereConditions = [];
    this.orderByClause = '';
    this.limitClause = '';
  }

  select(fields) {
    this.selectFields = Array.isArray(fields) ? fields : [fields];
    return this;
  }

  where(column, operator, value) {
    this.whereConditions.push({ column, operator, value });
    return this;
  }

  orderBy(column, direction = 'ASC') {
    this.orderByClause = `ORDER BY ${column} ${direction}`;
    return this;
  }

  limit(count) {
    this.limitClause = `LIMIT ${count}`;
    return this;
  }

  build() {
    const select = `SELECT ${this.selectFields.join(', ')} FROM ${this.table}`;
    const where = this.whereConditions.length > 0
      ? `WHERE ${this.whereConditions.map(c => `${c.column} ${c.operator} ?`).join(' AND ')}`
      : '';
    const sql = `${select} ${where} ${this.orderByClause} ${this.limitClause}`;

    const values = this.whereConditions.map(c => c.value);
    return { sql, values };
  }
}
```

## Service Layer - Business Logic

### 1. Patient Service (`patientService.js`)
```javascript
const { ipcMain } = require('electron');
const db = require('../database/connection');

class PatientService {
  // Patient CRUD operations
  static async getPatients(filters = {}) {
    const query = new QueryBuilder('patients');

    if (filters.search) {
      query.where('first_name', 'LIKE', `%${filters.search}%`)
           .orWhere('last_name', 'LIKE', `%${filters.search}%`);
    }

    if (filters.status) {
      query.where('is_active', '=', filters.status);
    }

    query.orderBy('last_name', 'ASC');

    const { sql, values } = query.build();
    return db.getConnection().prepare(sql).all(values);
  }

  static async getPatientById(id) {
    const patient = db.getConnection()
      .prepare('SELECT * FROM patients WHERE id = ?')
      .get(id);

    if (patient) {
      // Get related data
      patient.medicalHistory = await this.getMedicalHistory(id);
      patient.contacts = await this.getPatientContacts(id);
    }

    return patient;
  }

  static async createPatient(patientData) {
    const dbConn = db.getConnection();

    // Generate unique patient number
    const patientNumber = await this.generatePatientNumber();

    const result = dbConn.prepare(`
      INSERT INTO patients (patient_number, first_name, last_name, date_of_birth,
                           gender, email, phone, address, emergency_contact, emergency_phone)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run([
      patientNumber,
      patientData.firstName,
      patientData.lastName,
      patientData.dateOfBirth,
      patientData.gender,
      patientData.email,
      patientData.phone,
      patientData.address,
      patientData.emergencyContact,
      patientData.emergencyPhone
    ]);

    return { id: result.lastInsertRowid, patientNumber };
  }

  static async updatePatient(id, patientData) {
    const dbConn = db.getConnection();

    const result = dbConn.prepare(`
      UPDATE patients SET
        first_name = ?, last_name = ?, date_of_birth = ?, gender = ?,
        email = ?, phone = ?, address = ?, emergency_contact = ?, emergency_phone = ?
      WHERE id = ?
    `).run([
      patientData.firstName, patientData.lastName, patientData.dateOfBirth,
      patientData.gender, patientData.email, patientData.phone,
      patientData.address, patientData.emergencyContact, patientData.emergencyPhone, id
    ]);

    return result.changes > 0;
  }

  static async getMedicalHistory(patientId) {
    return db.getConnection()
      .prepare('SELECT * FROM medical_history WHERE patient_id = ? ORDER BY created_at DESC')
      .all(patientId);
  }

  static async addMedicalHistory(patientId, historyData) {
    const dbConn = db.getConnection();

    return dbConn.prepare(`
      INSERT INTO medical_history (patient_id, condition, severity, diagnosed_date,
                                  treatment, medications, allergies, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run([
      patientId, historyData.condition, historyData.severity,
      historyData.diagnosedDate, historyData.treatment,
      historyData.medications, historyData.allergies, historyData.notes
    ]);
  }

  static async generatePatientNumber() {
    const dbConn = db.getConnection();
    const lastPatient = dbConn.prepare(
      'SELECT patient_number FROM patients ORDER BY id DESC LIMIT 1'
    ).get();

    if (!lastPatient) {
      return 'P001';
    }

    const lastNumber = parseInt(lastPatient.patient_number.substring(1));
    return `P${String(lastNumber + 1).padStart(3, '0')}`;
  }
}
```

### 2. Appointment Service (`appointmentService.js`)
```javascript
class AppointmentService {
  static async getAppointments(dateRange = {}) {
    const query = new QueryBuilder('appointments a');
    query.select([
      'a.*',
      'p.first_name as patient_first_name',
      'p.last_name as patient_last_name',
      's.first_name as staff_first_name',
      's.last_name as staff_last_name',
      'at.type_name',
      'at.duration_minutes'
    ]);

    query.join('patients p', 'a.patient_id = p.id');
    query.join('staff s', 'a.staff_id = s.id');
    query.join('appointment_types at', 'a.appointment_type_id = at.id');

    if (dateRange.start) {
      query.where('a.appointment_date', '>=', dateRange.start);
    }

    if (dateRange.end) {
      query.where('a.appointment_date', '<=', dateRange.end);
    }

    query.where('a.status', '!=', 'cancelled');
    query.orderBy('a.appointment_date', 'ASC');

    const { sql, values } = query.build();
    return db.getConnection().prepare(sql).all(values);
  }

  static async createAppointment(appointmentData) {
    const dbConn = db.getConnection();

    // Check for scheduling conflicts
    const conflicts = await this.checkConflicts(
      appointmentData.staffId,
      appointmentData.appointmentDate,
      appointmentData.durationMinutes
    );

    if (conflicts.length > 0) {
      throw new Error('Scheduling conflict detected');
    }

    const result = dbConn.prepare(`
      INSERT INTO appointments (patient_id, staff_id, appointment_type_id,
                              appointment_date, duration_minutes, notes)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run([
      appointmentData.patientId,
      appointmentData.staffId,
      appointmentData.appointmentTypeId,
      appointmentData.appointmentDate,
      appointmentData.durationMinutes,
      appointmentData.notes
    ]);

    // Send reminder if requested
    if (appointmentData.sendReminder) {
      await this.scheduleReminder(result.lastInsertRowid);
    }

    return { id: result.lastInsertRowid };
  }

  static async checkConflicts(staffId, appointmentDate, durationMinutes) {
    const endTime = new Date(new Date(appointmentDate).getTime() + durationMinutes * 60000);

    return db.getConnection().prepare(`
      SELECT * FROM appointments
      WHERE staff_id = ?
        AND status NOT IN ('cancelled', 'completed')
        AND (
          (appointment_date BETWEEN ? AND ?)
          OR (? BETWEEN appointment_date AND datetime(appointment_date, '+' || duration_minutes || ' minutes'))
        )
    `).all(staffId, appointmentDate, endTime, appointmentDate);
  }

  static async updateAppointmentStatus(id, status, notes = '') {
    const dbConn = db.getConnection();

    const result = dbConn.prepare(`
      UPDATE appointments SET status = ?, notes = ? WHERE id = ?
    `).run(status, notes, id);

    // If completed, create a visit record
    if (status === 'completed') {
      await this.createVisitFromAppointment(id);
    }

    return result.changes > 0;
  }
}
```

### 3. Clinical Service (`clinicalService.js`)
```javascript
class ClinicalService {
  static async createVisit(visitData) {
    const dbConn = db.getConnection();

    const result = dbConn.prepare(`
      INSERT INTO visits (patient_id, staff_id, appointment_id, visit_date,
                         chief_complaint, diagnosis, treatment_plan, notes, vitals_recorded)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run([
      visitData.patientId,
      visitData.staffId,
      visitData.appointmentId,
      visitData.visitDate,
      visitData.chiefComplaint,
      visitData.diagnosis,
      visitData.treatmentPlan,
      visitData.notes,
      JSON.stringify(visitData.vitals)
    ]);

    return { id: result.lastInsertRowid };
  }

  static async updateDentalChart(visitId, toothData) {
    const dbConn = db.getConnection();

    // Begin transaction
    const transaction = dbConn.transaction(() => {
      for (const tooth of toothData) {
        // Insert or update tooth status
        const existing = dbConn.prepare(
          'SELECT id FROM dental_chart WHERE visit_id = ? AND tooth_number = ?'
        ).get(visitId, tooth.toothNumber);

        if (existing) {
          dbConn.prepare(`
            UPDATE dental_chart SET current_status = ?, notes = ? WHERE id = ?
          `).run(tooth.status, tooth.notes, existing.id);
        } else {
          dbConn.prepare(`
            INSERT INTO dental_chart (visit_id, tooth_number, tooth_name, current_status, notes)
            VALUES (?, ?, ?, ?, ?)
          `).run(visitId, tooth.toothNumber, tooth.toothName, tooth.status, tooth.notes);
        }

        // Record procedures for this tooth
        if (tooth.procedures && tooth.procedures.length > 0) {
          for (const procedure of tooth.procedures) {
            dbConn.prepare(`
              INSERT INTO tooth_procedures (dental_chart_id, procedure_name, procedure_date, cost, notes)
              VALUES (?, ?, ?, ?, ?)
            `).run(existing?.id || 0, procedure.name, procedure.date, procedure.cost, procedure.notes);
          }
        }
      }
    });

    transaction();
    return true;
  }

  static async getVisitHistory(patientId) {
    return db.getConnection().prepare(`
      SELECT v.*, s.first_name as staff_first_name, s.last_name as staff_last_name
      FROM visits v
      JOIN staff s ON v.staff_id = s.id
      WHERE v.patient_id = ?
      ORDER BY v.visit_date DESC
    `).all(patientId);
  }

  static async getDentalChart(visitId) {
    const teeth = db.getConnection().prepare(`
      SELECT dc.*, tp.procedure_name, tp.procedure_date, tp.cost, tp.notes as procedure_notes
      FROM dental_chart dc
      LEFT JOIN tooth_procedures tp ON dc.id = tp.dental_chart_id
      WHERE dc.visit_id = ?
      ORDER BY dc.tooth_number, tp.procedure_date
    `).all(visitId);

    // Group procedures by tooth
    const chart = {};
    teeth.forEach(tooth => {
      if (!chart[tooth.tooth_number]) {
        chart[tooth.tooth_number] = {
          toothNumber: tooth.tooth_number,
          toothName: tooth.tooth_name,
          status: tooth.current_status,
          notes: tooth.notes,
          procedures: []
        };
      }

      if (tooth.procedure_name) {
        chart[tooth.tooth_number].procedures.push({
          name: tooth.procedure_name,
          date: tooth.procedure_date,
          cost: tooth.cost,
          notes: tooth.procedure_notes
        });
      }
    });

    return chart;
  }
}
```

### 4. Financial Service (`financialService.js`)
```javascript
class FinancialService {
  static async generateInvoice(invoiceData) {
    const dbConn = db.getConnection();

    // Calculate totals
    const subtotal = invoiceData.procedures.reduce((sum, proc) => sum + proc.totalCost, 0);
    const taxRate = await this.getTaxRate();
    const taxAmount = subtotal * taxRate;
    const insuranceDiscount = await this.calculateInsuranceDiscount(invoiceData.patientId, subtotal);

    const total = subtotal + taxAmount - insuranceDiscount;

    const result = dbConn.prepare(`
      INSERT INTO invoices (patient_id, visit_id, invoice_number, invoice_date, due_date,
                           subtotal, discount_amount, tax_amount, insurance_discount, total_amount)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run([
      invoiceData.patientId,
      invoiceData.visitId,
      await this.generateInvoiceNumber(),
      invoiceData.invoiceDate,
      invoiceData.dueDate,
      subtotal,
      invoiceData.discountAmount || 0,
      taxAmount,
      insuranceDiscount,
      total
    ]);

    const invoiceId = result.lastInsertRowid;

    // Add procedure details
    for (const procedure of invoiceData.procedures) {
      await this.addInvoiceProcedure(invoiceId, procedure);
    }

    return { id: invoiceId, total, invoiceNumber: invoiceData.invoiceNumber };
  }

  static async processPayment(paymentData) {
    const dbConn = db.getConnection();

    // Record payment
    const result = dbConn.prepare(`
      INSERT INTO payments (invoice_id, payment_date, payment_method, amount, reference_number, notes)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run([
      paymentData.invoiceId,
      paymentData.paymentDate,
      paymentData.paymentMethod,
      paymentData.amount,
      paymentData.referenceNumber,
      paymentData.notes
    ]);

    // Update invoice paid amount and status
    await this.updateInvoiceAfterPayment(paymentData.invoiceId, paymentData.amount);

    return { id: result.lastInsertRowid };
  }

  static async updateInvoiceAfterPayment(invoiceId, paymentAmount) {
    const dbConn = db.getConnection();

    // Get current invoice data
    const invoice = dbConn.prepare('SELECT * FROM invoices WHERE id = ?').get(invoiceId);

    if (!invoice) {
      throw new Error('Invoice not found');
    }

    const newPaidAmount = invoice.paid_amount + paymentAmount;
    let newStatus = 'unpaid';

    if (newPaidAmount >= invoice.total_amount) {
      newStatus = 'paid';
    } else if (newPaidAmount > 0) {
      newStatus = 'partially_paid';
    }

    dbConn.prepare(`
      UPDATE invoices SET paid_amount = ?, status = ? WHERE id = ?
    `).run(newPaidAmount, newStatus, invoiceId);
  }

  static async calculateInsuranceDiscount(patientId, subtotal) {
    const policies = db.getConnection().prepare(`
      SELECT * FROM insurance_policies WHERE patient_id = ? AND is_active = 1
    `).all(patientId);

    let totalDiscount = 0;

    for (const policy of policies) {
      if (policy.coverage_percentage) {
        totalDiscount += subtotal * (policy.coverage_percentage / 100);
      }
    }

    return Math.min(totalDiscount, subtotal); // Can't exceed subtotal
  }
}
```

### 5. Document Service (`documentService.js`)
```javascript
class DocumentService {
  static async scanDocument(scanOptions) {
    const scanner = require('../utils/scannerManager');

    try {
      const scanResult = await scanner.scan(scanOptions);

      // Save to database
      const dbConn = db.getConnection();
      const result = dbConn.prepare(`
        INSERT INTO documents (patient_id, visit_id, category_id, document_name,
                             file_path, file_type, file_size, scan_date, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run([
        scanOptions.patientId,
        scanOptions.visitId,
        scanOptions.categoryId,
        scanOptions.documentName,
        scanResult.filePath,
        scanResult.fileType,
        scanResult.fileSize,
        new Date().toISOString(),
        scanOptions.notes
      ]);

      return { id: result.lastInsertRowid, ...scanResult };
    } catch (error) {
      console.error('Document scanning failed:', error);
      throw error;
    }
  }

  static async printDocument(printOptions) {
    const printer = require('../utils/printerManager');

    try {
      const printResult = await printer.print(printOptions);
      return printResult;
    } catch (error) {
      console.error('Document printing failed:', error);
      throw error;
    }
  }

  static async generatePDFReport(reportData) {
    const pdfGenerator = require('../utils/pdfGenerator');

    try {
      const pdfPath = await pdfGenerator.generate(reportData);
      return { filePath: pdfPath };
    } catch (error) {
      console.error('PDF generation failed:', error);
      throw error;
    }
  }
}
```

## IPC Communication Handlers

### IPC Event Registration (`ipcHandlers.js`)
```javascript
const { ipcMain } = require('electron');
const PatientService = require('./services/patientService');
const AppointmentService = require('./services/appointmentService');
const ClinicalService = require('./services/clinicalService');
const FinancialService = require('./services/financialService');
const DocumentService = require('./services/documentService');

function registerIPCHandlers() {
  // Patient Management
  ipcMain.handle('patients:get-all', (event, filters) => PatientService.getPatients(filters));
  ipcMain.handle('patients:get-by-id', (event, id) => PatientService.getPatientById(id));
  ipcMain.handle('patients:create', (event, data) => PatientService.createPatient(data));
  ipcMain.handle('patients:update', (event, id, data) => PatientService.updatePatient(id, data));
  ipcMain.handle('patients:add-medical-history', (event, patientId, data) =>
    PatientService.addMedicalHistory(patientId, data));

  // Appointment Management
  ipcMain.handle('appointments:get-all', (event, dateRange) => AppointmentService.getAppointments(dateRange));
  ipcMain.handle('appointments:create', (event, data) => AppointmentService.createAppointment(data));
  ipcMain.handle('appointments:update-status', (event, id, status, notes) =>
    AppointmentService.updateAppointmentStatus(id, status, notes));

  // Clinical Operations
  ipcMain.handle('visits:create', (event, data) => ClinicalService.createVisit(data));
  ipcMain.handle('visits:get-history', (event, patientId) => ClinicalService.getVisitHistory(patientId));
  ipcMain.handle('dental-chart:update', (event, visitId, toothData) =>
    ClinicalService.updateDentalChart(visitId, toothData));
  ipcMain.handle('dental-chart:get', (event, visitId) => ClinicalService.getDentalChart(visitId));

  // Financial Operations
  ipcMain.handle('invoices:generate', (event, data) => FinancialService.generateInvoice(data));
  ipcMain.handle('payments:process', (event, data) => FinancialService.processPayment(data));

  // Document Operations
  ipcMain.handle('documents:scan', (event, options) => DocumentService.scanDocument(options));
  ipcMain.handle('documents:print', (event, options) => DocumentService.printDocument(options));
  ipcMain.handle('reports:generate-pdf', (event, data) => DocumentService.generatePDFReport(data));
}

module.exports = { registerIPCHandlers };
```

## Error Handling Strategy

### Centralized Error Handler
```javascript
class ErrorHandler {
  static handle(error, context = '') {
    console.error(`Error in ${context}:`, error);

    // Log to file in production
    if (process.env.NODE_ENV === 'production') {
      this.logToFile(error, context);
    }

    // Return user-friendly error
    return {
      success: false,
      error: this.getUserFriendlyMessage(error),
      code: error.code || 'UNKNOWN_ERROR'
    };
  }

  static getUserFriendlyMessage(error) {
    // Map technical errors to user-friendly messages
    const errorMap = {
      'SQLITE_CONSTRAINT': 'This operation would violate data integrity rules.',
      'SQLITE_BUSY': 'Database is currently busy. Please try again.',
      'ENOENT': 'Required file not found.',
      'EACCES': 'Permission denied. Please check file permissions.'
    };

    return errorMap[error.code] || 'An unexpected error occurred. Please try again.';
  }
}
```

This backend architecture provides a solid foundation for the dental clinic management system, with proper separation of concerns, comprehensive error handling, and scalable service-based design.