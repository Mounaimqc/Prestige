-- ==============================================================================
-- MAISON DE LUX SÉTIF — RESET & COMPLETE DROP SQL SCRIPT
-- WARNING: THIS SCRIPT COMPLETELY DELETES ALL TABLES AND DATA IN SUPABASE!
-- Date: September 6, 2026
-- ==============================================================================

-- 1. DROP ALL EXISTING TABLES WITH CASCADE
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS unit_history CASCADE;
DROP TABLE IF EXISTS cleaning_records CASCADE;
DROP TABLE IF EXISTS repair_records CASCADE;
DROP TABLE IF EXISTS cash_movements CASCADE;
DROP TABLE IF EXISTS cash_registers CASCADE;
DROP TABLE IF EXISTS expenses CASCADE;
DROP TABLE IF EXISTS deposit_transactions CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS purchase_items CASCADE;
DROP TABLE IF EXISTS purchases CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS sale_items CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS reservation_items CASCADE;
DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS rental_items CASCADE;
DROP TABLE IF EXISTS rentals CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS product_units CASCADE;
DROP TABLE IF EXISTS locations CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS role_permissions CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- 2. DROP ENUM TYPES
DROP TYPE IF EXISTS user_role_enum CASCADE;
DROP TYPE IF EXISTS unit_status_enum CASCADE;
DROP TYPE IF EXISTS unit_condition_enum CASCADE;
DROP TYPE IF EXISTS rental_status_enum CASCADE;
DROP TYPE IF EXISTS reservation_status_enum CASCADE;
DROP TYPE IF EXISTS payment_status_enum CASCADE;
DROP TYPE IF EXISTS location_type_enum CASCADE;
DROP TYPE IF EXISTS payment_method_enum CASCADE;
DROP TYPE IF EXISTS transaction_type_enum CASCADE;
DROP TYPE IF EXISTS deposit_trans_enum CASCADE;

-- 3. DROP FUNCTIONS
DROP FUNCTION IF EXISTS check_unit_availability CASCADE;

-- ==============================================================================
-- RECREATE CLEAN FRESH DATABASE SCHEMA
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE user_role_enum AS ENUM ('ADMIN', 'MANAGER', 'SELLER', 'STOCK_MANAGER', 'ACCOUNTANT');
CREATE TYPE unit_status_enum AS ENUM ('AVAILABLE', 'RESERVED', 'RENTED', 'RETURNED', 'CLEANING', 'REPAIR', 'DAMAGED', 'LOST', 'SOLD', 'RETIRED');
CREATE TYPE unit_condition_enum AS ENUM ('EXCELLENT', 'GOOD', 'NEEDS_CLEANING', 'NEEDS_REPAIR', 'DAMAGED', 'LOST');
CREATE TYPE rental_status_enum AS ENUM ('DRAFT', 'RESERVED', 'ACTIVE', 'PARTIALLY_RETURNED', 'RETURNED', 'OVERDUE', 'CANCELLED');
CREATE TYPE payment_method_enum AS ENUM ('CASH', 'CARD', 'BANK', 'CCP', 'OTHER');

CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name user_role_enum UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    category_id UUID NOT NULL REFERENCES categories(id),
    brand TEXT,
    gender TEXT DEFAULT 'UNISEX',
    description TEXT,
    color TEXT,
    material TEXT,
    purchase_price NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    sale_price NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    rental_price NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    default_deposit NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    can_be_sold BOOLEAN NOT NULL DEFAULT TRUE,
    can_be_rented BOOLEAN NOT NULL DEFAULT TRUE,
    image_url TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    type TEXT DEFAULT 'STORE',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE product_units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    serial_number TEXT UNIQUE NOT NULL,
    barcode TEXT UNIQUE NOT NULL,
    qr_code TEXT UNIQUE NOT NULL,
    size TEXT NOT NULL,
    color TEXT,
    purchase_price NUMERIC(12,2),
    sale_price NUMERIC(12,2),
    rental_price NUMERIC(12,2),
    condition unit_condition_enum NOT NULL DEFAULT 'EXCELLENT',
    status unit_status_enum NOT NULL DEFAULT 'AVAILABLE',
    location_id UUID REFERENCES locations(id),
    acquisition_date DATE DEFAULT CURRENT_DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    phone TEXT UNIQUE NOT NULL,
    secondary_phone TEXT,
    address TEXT,
    city TEXT DEFAULT 'Sétif',
    identification_type TEXT,
    identification_number TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE rentals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rental_number TEXT UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES customers(id),
    start_date DATE NOT NULL,
    expected_return_date DATE NOT NULL,
    actual_return_date DATE,
    status rental_status_enum NOT NULL DEFAULT 'ACTIVE',
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    discount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    total NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    deposit_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    deposit_paid NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    amount_paid NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    remaining_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    payment_status TEXT DEFAULT 'UNPAID',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE rental_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rental_id UUID NOT NULL REFERENCES rentals(id) ON DELETE CASCADE,
    physical_unit_id UUID NOT NULL REFERENCES product_units(id),
    rental_price NUMERIC(12,2) NOT NULL,
    discount NUMERIC(12,2) DEFAULT 0.00,
    start_date DATE NOT NULL,
    expected_return_date DATE NOT NULL,
    actual_return_date DATE,
    condition_before unit_condition_enum DEFAULT 'EXCELLENT',
    condition_after unit_condition_enum,
    damage_cost NUMERIC(12,2) DEFAULT 0.00,
    notes TEXT
);

CREATE INDEX idx_units_serial ON product_units(serial_number);
CREATE INDEX idx_units_barcode ON product_units(barcode);
CREATE INDEX idx_units_status ON product_units(status);
CREATE INDEX idx_customers_phone ON customers(phone);

CREATE OR REPLACE FUNCTION check_unit_availability(
    p_unit_id UUID,
    p_start_date DATE,
    p_end_date DATE
) RETURNS BOOLEAN AS $$
DECLARE
    v_conflict_count INT;
    v_status unit_status_enum;
BEGIN
    SELECT status INTO v_status FROM product_units WHERE id = p_unit_id;
    IF v_status IN ('SOLD', 'RETIRED', 'DAMAGED', 'LOST') THEN
        RETURN FALSE;
    END IF;

    SELECT COUNT(*) INTO v_conflict_count
    FROM rental_items ri
    JOIN rentals r ON ri.rental_id = r.id
    WHERE ri.physical_unit_id = p_unit_id
      AND r.status IN ('ACTIVE', 'RESERVED', 'PARTIALLY_RETURNED')
      AND ri.start_date <= p_end_date
      AND ri.expected_return_date >= p_start_date;

    IF v_conflict_count > 0 THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
