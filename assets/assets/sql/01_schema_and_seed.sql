-- ==============================================================================
-- MAISON DE LUX SÉTIF — SUPABASE POSTGRESQL SCHEMA & SEED DATA
-- System: Serialized Costume & Wedding Dress Rental + Sales Management ERP
-- Date: September 6, 2026
-- ==============================================================================

-- 1. EXTENSIONS & ENUMS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$ BEGIN
    CREATE TYPE user_role_enum AS ENUM ('ADMIN', 'MANAGER', 'SELLER', 'STOCK_MANAGER', 'ACCOUNTANT');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE unit_status_enum AS ENUM ('AVAILABLE', 'RESERVED', 'RENTED', 'RETURNED', 'CLEANING', 'REPAIR', 'DAMAGED', 'LOST', 'SOLD', 'RETIRED');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE unit_condition_enum AS ENUM ('EXCELLENT', 'GOOD', 'NEEDS_CLEANING', 'NEEDS_REPAIR', 'DAMAGED', 'LOST');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE rental_status_enum AS ENUM ('DRAFT', 'RESERVED', 'ACTIVE', 'PARTIALLY_RETURNED', 'RETURNED', 'OVERDUE', 'CANCELLED');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE payment_method_enum AS ENUM ('CASH', 'CARD', 'BANK', 'CCP', 'OTHER');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 2. TABLES DEFINITIONS
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name user_role_enum UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
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

CREATE TABLE IF NOT EXISTS locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    type TEXT DEFAULT 'STORE',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_units (
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

CREATE TABLE IF NOT EXISTS customers (
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

CREATE TABLE IF NOT EXISTS rentals (
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

CREATE TABLE IF NOT EXISTS rental_items (
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

CREATE TABLE IF NOT EXISTS sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_number TEXT UNIQUE NOT NULL,
    customer_id UUID REFERENCES customers(id),
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    tva NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    total NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    payment_method payment_method_enum DEFAULT 'CASH',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    physical_unit_id UUID REFERENCES product_units(id),
    unit_price NUMERIC(12,2) NOT NULL,
    quantity INT DEFAULT 1,
    total NUMERIC(12,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS cash_registers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    opening_balance NUMERIC(12,2) NOT NULL DEFAULT 25000.00,
    closing_balance NUMERIC(12,2),
    total_sales NUMERIC(12,2) DEFAULT 0.00,
    total_rentals NUMERIC(12,2) DEFAULT 0.00,
    total_expenses NUMERIC(12,2) DEFAULT 0.00,
    status TEXT DEFAULT 'OPEN',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cash_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cash_register_id UUID REFERENCES cash_registers(id),
    type TEXT NOT NULL, -- 'IN' / 'OUT'
    amount NUMERIC(12,2) NOT NULL,
    label TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS unit_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_id UUID NOT NULL REFERENCES product_units(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. INDEXES FOR HIGH PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_units_serial ON product_units(serial_number);
CREATE INDEX IF NOT EXISTS idx_units_barcode ON product_units(barcode);
CREATE INDEX IF NOT EXISTS idx_units_status ON product_units(status);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);

-- 4. AVAILABILITY ENGINE RPC FUNCTION
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
    IF v_status IN ('SOLD', 'RETIRED', 'DAMAGED', 'LOST', 'CLEANING', 'REPAIR') THEN
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

-- 4.5. ATOMIC SERIALIZED SALE RPC FUNCTION (SALES PROTECTION)
CREATE OR REPLACE FUNCTION sell_serialized_unit(
    p_unit_id UUID,
    p_sale_number TEXT,
    p_unit_price NUMERIC
) RETURNS BOOLEAN AS $$
DECLARE
    v_status unit_status_enum;
    v_product_id UUID;
    v_sale_id UUID;
BEGIN
    SELECT status, product_id INTO v_status, v_product_id FROM product_units WHERE id = p_unit_id;
    IF v_status != 'AVAILABLE' THEN
        RAISE EXCEPTION 'Unit % is not available for sale (status: %)', p_unit_id, v_status;
    END IF;

    INSERT INTO sales (sale_number, total, payment_method)
    VALUES (p_sale_number, p_unit_price, 'CASH')
    RETURNING id INTO v_sale_id;

    INSERT INTO sale_items (sale_id, product_id, physical_unit_id, unit_price, quantity, total)
    VALUES (v_sale_id, v_product_id, p_unit_id, p_unit_price, 1, p_unit_price);

    UPDATE product_units SET status = 'SOLD', updated_at = NOW() WHERE id = p_unit_id;

    INSERT INTO unit_history (unit_id, event_type, description)
    VALUES (p_unit_id, 'SOLD', 'Unit sold via POS sale number ' || p_sale_number);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. SEED DATA INSERTION (USING VALID HEXADECIMAL UUIDs)
INSERT INTO categories (id, name, slug) VALUES
  ('c1111111-1111-4111-a111-111111111111', 'Costumes', 'costumes'),
  ('c2222222-2222-4222-a222-222222222222', 'Robes de Mariée', 'robes-mariee'),
  ('c3333333-3333-4333-a333-333333333333', 'Karakous', 'karakous')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO products (id, reference, name, category_id, sale_price, rental_price, default_deposit) VALUES
  ('11111111-1111-4111-a111-111111111111', 'CST-SLIM-BK', 'Costume Slim 3 Pièces Noir', 'c1111111-1111-4111-a111-111111111111', 25000.00, 8000.00, 15000.00),
  ('22222222-2222-4222-a222-222222222222', 'RM-PRINCESS-01', 'Robe Mariée Princesse', 'c2222222-2222-4222-a222-222222222222', 65000.00, 18000.00, 30000.00)
ON CONFLICT (reference) DO NOTHING;

INSERT INTO product_units (id, product_id, serial_number, barcode, qr_code, size, status, rental_price, sale_price) VALUES
  ('a1111111-1111-4111-a111-111111111111', '11111111-1111-4111-a111-111111111111', 'CST-0001', 'BAR-CST-0001', 'MDL::CST-0001', '48', 'AVAILABLE', 8000.00, 25000.00),
  ('a2222222-2222-4222-a222-222222222222', '11111111-1111-4111-a111-111111111111', 'CST-0002', 'BAR-CST-0002', 'MDL::CST-0002', '50', 'RENTED', 8000.00, 25000.00),
  ('a3333333-3333-4333-a333-333333333333', '22222222-2222-4222-a222-222222222222', 'RM-0001', 'BAR-RM-0001', 'MDL::RM-0001', '38', 'AVAILABLE', 18000.00, 65000.00)
ON CONFLICT (serial_number) DO NOTHING;

-- 6. ENABLE ROW LEVEL SECURITY & OPEN POLICIES (ALLOW APP INSERT/UPDATE/DELETE)
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE rentals ENABLE ROW LEVEL SECURITY;
ALTER TABLE rental_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_registers ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE unit_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public Full Access Categories" ON categories;
CREATE POLICY "Public Full Access Categories" ON categories FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Full Access Products" ON products;
CREATE POLICY "Public Full Access Products" ON products FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Full Access Locations" ON locations;
CREATE POLICY "Public Full Access Locations" ON locations FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Full Access Product Units" ON product_units;
CREATE POLICY "Public Full Access Product Units" ON product_units FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Full Access Customers" ON customers;
CREATE POLICY "Public Full Access Customers" ON customers FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Full Access Rentals" ON rentals;
CREATE POLICY "Public Full Access Rentals" ON rentals FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Full Access Rental Items" ON rental_items;
CREATE POLICY "Public Full Access Rental Items" ON rental_items FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Full Access Sales" ON sales;
CREATE POLICY "Public Full Access Sales" ON sales FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Full Access Sale Items" ON sale_items;
CREATE POLICY "Public Full Access Sale Items" ON sale_items FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Full Access Cash Registers" ON cash_registers;
CREATE POLICY "Public Full Access Cash Registers" ON cash_registers FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Full Access Cash Movements" ON cash_movements;
CREATE POLICY "Public Full Access Cash Movements" ON cash_movements FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Full Access Unit History" ON unit_history;
CREATE POLICY "Public Full Access Unit History" ON unit_history FOR ALL USING (true) WITH CHECK (true);
