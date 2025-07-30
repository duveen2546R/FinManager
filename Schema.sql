-- Enable UUID extension (optional, for better ID handling)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,
    phone_no VARCHAR(15),
    email VARCHAR(255) UNIQUE NOT NULL,
    password TEXT NOT NULL
);

CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    title VARCHAR(255),
    description TEXT,
    amount NUMERIC(10, 2) NOT NULL,
    category VARCHAR(100),
    transaction_type VARCHAR(50) CHECK (transaction_type IN ('Income', 'Expense')),
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
