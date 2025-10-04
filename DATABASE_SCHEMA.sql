-- Dental Clinic Management Software - SQLite Database Schema
-- Comprehensive schema for all clinic management modules

-- =====================================================
-- CORE TABLES
-- =====================================================

-- Staff Management
CREATE TABLE staff_roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    permissions TEXT, -- JSON string of permissions
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staff (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    role_id INTEGER,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    license_number VARCHAR(50),
    specialization VARCHAR(100),
    is_active BOOLEAN DEFAULT 1,
    hire_date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (role_id) REFERENCES staff_roles(id)
);

-- Patient Management
CREATE TABLE patients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_number VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    date_of_birth DATE,
    gender VARCHAR(10),
    email VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    emergency_contact VARCHAR(100),
    emergency_phone VARCHAR(20),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE patient_contacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    contact_type VARCHAR(20) NOT NULL, -- 'email', 'phone', 'sms'
    contact_value VARCHAR(100) NOT NULL,
    is_preferred BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
);

CREATE TABLE medical_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    condition VARCHAR(200) NOT NULL,
    severity VARCHAR(20), -- 'mild', 'moderate', 'severe'
    diagnosed_date DATE,
    treatment TEXT,
    medications TEXT,
    allergies TEXT,
    notes TEXT,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
);

-- Appointment Management
CREATE TABLE appointment_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_name VARCHAR(100) NOT NULL UNIQUE,
    duration_minutes INTEGER NOT NULL DEFAULT 30,
    color_code VARCHAR(7), -- Hex color for calendar display
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE appointments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    staff_id INTEGER NOT NULL,
    appointment_type_id INTEGER NOT NULL,
    appointment_date DATETIME NOT NULL,
    duration_minutes INTEGER NOT NULL,
    status VARCHAR(20) DEFAULT 'scheduled', -- 'scheduled', 'confirmed', 'cancelled', 'completed', 'no_show'
    notes TEXT,
    reminder_sent BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id),
    FOREIGN KEY (staff_id) REFERENCES staff(id),
    FOREIGN KEY (appointment_type_id) REFERENCES appointment_types(id)
);

-- Clinical Operations
CREATE TABLE visits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    staff_id INTEGER NOT NULL,
    appointment_id INTEGER,
    visit_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    chief_complaint TEXT,
    diagnosis TEXT,
    treatment_plan TEXT,
    notes TEXT,
    vitals_recorded TEXT, -- JSON string of vital signs
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id),
    FOREIGN KEY (staff_id) REFERENCES staff(id),
    FOREIGN KEY (appointment_id) REFERENCES appointments(id)
);

-- Dental Chart System
CREATE TABLE dental_chart (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    visit_id INTEGER NOT NULL,
    tooth_number INTEGER NOT NULL, -- 1-32 for adult teeth
    tooth_name VARCHAR(10), -- e.g., 'Upper Right Central Incisor'
    current_status VARCHAR(50), -- 'healthy', 'caries', 'filling', 'crown', 'missing', 'implant', etc.
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (visit_id) REFERENCES visits(id) ON DELETE CASCADE,
    UNIQUE(visit_id, tooth_number)
);

CREATE TABLE tooth_procedures (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dental_chart_id INTEGER NOT NULL,
    procedure_name VARCHAR(100) NOT NULL,
    procedure_date DATE NOT NULL,
    cost DECIMAL(10,2),
    insurance_covered DECIMAL(10,2) DEFAULT 0,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (dental_chart_id) REFERENCES dental_chart(id) ON DELETE CASCADE
);

-- Procedure Management
CREATE TABLE procedures (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    procedure_code VARCHAR(20) UNIQUE NOT NULL,
    procedure_name VARCHAR(200) NOT NULL,
    category VARCHAR(50), -- 'diagnostic', 'preventive', 'restorative', 'endodontic', 'prosthodontic', 'surgical'
    base_cost DECIMAL(10,2) NOT NULL,
    duration_minutes INTEGER DEFAULT 30,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE visit_procedures (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    visit_id INTEGER NOT NULL,
    procedure_id INTEGER NOT NULL,
    quantity INTEGER DEFAULT 1,
    unit_cost DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    total_cost DECIMAL(10,2) NOT NULL,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (visit_id) REFERENCES visits(id) ON DELETE CASCADE,
    FOREIGN KEY (procedure_id) REFERENCES procedures(id)
);

-- Financial & Billing
CREATE TABLE insurance_policies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    policy_number VARCHAR(50) NOT NULL,
    insurance_company VARCHAR(100) NOT NULL,
    coverage_percentage DECIMAL(5,2) DEFAULT 0, -- e.g., 80.00 for 80%
    max_annual_coverage DECIMAL(10,2),
    deductible_amount DECIMAL(10,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT 1,
    expiry_date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id),
    UNIQUE(patient_id, policy_number)
);

CREATE TABLE invoices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    visit_id INTEGER,
    invoice_number VARCHAR(20) UNIQUE NOT NULL,
    invoice_date DATE NOT NULL,
    due_date DATE,
    subtotal DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    insurance_discount DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL,
    paid_amount DECIMAL(10,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'unpaid', -- 'unpaid', 'paid', 'partially_paid', 'overdue'
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id),
    FOREIGN KEY (visit_id) REFERENCES visits(id)
);

CREATE TABLE payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id INTEGER NOT NULL,
    payment_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    payment_method VARCHAR(20), -- 'cash', 'card', 'check', 'insurance'
    amount DECIMAL(10,2) NOT NULL,
    reference_number VARCHAR(50), -- Check number, transaction ID, etc.
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
);

CREATE TABLE insurance_claims (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id INTEGER NOT NULL,
    insurance_policy_id INTEGER NOT NULL,
    claim_number VARCHAR(50),
    claim_amount DECIMAL(10,2) NOT NULL,
    approved_amount DECIMAL(10,2),
    claim_status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'submitted', 'approved', 'denied'
    submission_date DATE,
    approval_date DATE,
    denial_reason TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id),
    FOREIGN KEY (insurance_policy_id) REFERENCES insurance_policies(id)
);

-- Document Management
CREATE TABLE document_categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER,
    visit_id INTEGER,
    category_id INTEGER NOT NULL,
    document_name VARCHAR(200) NOT NULL,
    file_path TEXT NOT NULL,
    file_type VARCHAR(10), -- 'pdf', 'jpg', 'png', 'dcm' (DICOM)
    file_size INTEGER, -- Size in bytes
    scan_date DATETIME,
    is_archived BOOLEAN DEFAULT 0,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id),
    FOREIGN KEY (visit_id) REFERENCES visits(id),
    FOREIGN KEY (category_id) REFERENCES document_categories(id)
);

-- System & Utilities
CREATE TABLE backups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_name VARCHAR(200) NOT NULL,
    file_path TEXT NOT NULL,
    file_size INTEGER,
    backup_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    backup_type VARCHAR(20) DEFAULT 'automatic', -- 'automatic', 'manual'
    status VARCHAR(20) DEFAULT 'completed', -- 'completed', 'failed', 'in_progress'
    notes TEXT
);

CREATE TABLE system_settings (
    id INTEGER PRIMARY KEY,
    setting_key VARCHAR(50) UNIQUE NOT NULL,
    setting_value TEXT,
    setting_type VARCHAR(20) DEFAULT 'string', -- 'string', 'number', 'boolean', 'json'
    description TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Patient search indexes
CREATE INDEX idx_patients_name ON patients(first_name, last_name);
CREATE INDEX idx_patients_number ON patients(patient_number);
CREATE INDEX idx_patients_phone ON patients(phone);

-- Appointment indexes
CREATE INDEX idx_appointments_date ON appointments(appointment_date);
CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_appointments_staff ON appointments(staff_id);
CREATE INDEX idx_appointments_status ON appointments(status);

-- Visit indexes
CREATE INDEX idx_visits_patient ON visits(patient_id);
CREATE INDEX idx_visits_date ON visits(visit_date);
CREATE INDEX idx_visits_staff ON visits(staff_id);

-- Financial indexes
CREATE INDEX idx_invoices_patient ON invoices(patient_id);
CREATE INDEX idx_invoices_date ON invoices(invoice_date);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_payments_invoice ON payments(invoice_id);
CREATE INDEX idx_payments_date ON payments(payment_date);

-- Document indexes
CREATE INDEX idx_documents_patient ON documents(patient_id);
CREATE INDEX idx_documents_category ON documents(category_id);

-- =====================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- =====================================================

-- Update timestamp trigger
CREATE TRIGGER update_timestamp
    AFTER UPDATE ON patients
    FOR EACH ROW
    WHEN NEW.updated_at = OLD.updated_at
BEGIN
    UPDATE patients SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Apply same trigger to other main tables
CREATE TRIGGER update_staff_timestamp
    AFTER UPDATE ON staff
    FOR EACH ROW
    WHEN NEW.updated_at = OLD.updated_at
BEGIN
    UPDATE staff SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER update_appointments_timestamp
    AFTER UPDATE ON appointments
    FOR EACH ROW
    WHEN NEW.updated_at = OLD.updated_at
BEGIN
    UPDATE appointments SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER update_visits_timestamp
    AFTER UPDATE ON visits
    FOR EACH ROW
    WHEN NEW.updated_at = OLD.updated_at
BEGIN
    UPDATE visits SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- =====================================================
-- INITIAL DATA
-- =====================================================

-- Insert default appointment types
INSERT INTO appointment_types (type_name, duration_minutes, color_code) VALUES
('Consultation', 30, '#3498db'),
('Cleaning', 45, '#2ecc71'),
('Filling', 60, '#e74c3c'),
('Crown', 90, '#f39c12'),
('Root Canal', 120, '#9b59b6'),
('Extraction', 45, '#e67e22'),
('Emergency', 30, '#c0392b');

-- Insert default procedure categories
INSERT INTO document_categories (category_name, description) VALUES
('X-Rays', 'Dental radiographs and imaging'),
('Insurance Cards', 'Patient insurance documentation'),
('Treatment Photos', 'Before and after treatment photos'),
('Lab Reports', 'External laboratory test results'),
('Correspondence', 'Letters and communications');

-- Insert default system settings
INSERT INTO system_settings (setting_key, setting_value, setting_type, description) VALUES
('clinic_name', 'Dental Clinic', 'string', 'Name of the dental clinic'),
('clinic_address', '', 'string', 'Physical address of the clinic'),
('clinic_phone', '', 'string', 'Primary phone number'),
('clinic_email', '', 'string', 'Primary email address'),
('tax_rate', '0.08', 'number', 'Default tax rate (8%)'),
('backup_frequency', 'daily', 'string', 'Automatic backup frequency');

-- Insert default staff role
INSERT INTO staff_roles (role_name, permissions) VALUES
('Dentist', '["read_patients", "write_patients", "read_appointments", "write_appointments", "read_financial", "write_financial", "manage_staff"]'),
('Assistant', '["read_patients", "read_appointments", "assist_procedures"]'),
('Admin', '["read_all", "write_all", "manage_settings", "manage_backups"]');