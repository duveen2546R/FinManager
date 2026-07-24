-- Apply this migration to databases created by the pre-release schema.
-- It is idempotent; new installations can use ../Schema.sql directly.
ALTER TABLE customers ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS merchant VARCHAR(255);
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS source VARCHAR(32) NOT NULL DEFAULT 'Manual';
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS payment_method VARCHAR(100);
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS recurrence_status VARCHAR(32) NOT NULL DEFAULT 'Unknown';
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS confidence NUMERIC(3, 2) NOT NULL DEFAULT 1.00;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS import_fingerprint VARCHAR(128);
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS is_essential BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS user_category_override BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON transactions (user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_user_merchant ON transactions (user_id, merchant);
CREATE UNIQUE INDEX IF NOT EXISTS uq_transactions_import_fingerprint
    ON transactions (user_id, import_fingerprint) WHERE import_fingerprint IS NOT NULL;

CREATE TABLE IF NOT EXISTS token_blocklist (
    jti VARCHAR(128) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES customers(user_id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_token_blocklist_expiry ON token_blocklist (expires_at);

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    token_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES customers(user_id) ON DELETE CASCADE,
    token_hash CHAR(64) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    attempts SMALLINT NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_expiry
    ON password_reset_tokens (user_id, expires_at DESC);

CREATE TABLE IF NOT EXISTS merchant_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES customers(user_id) ON DELETE CASCADE,
    merchant_pattern VARCHAR(255) NOT NULL,
    display_merchant VARCHAR(255),
    category VARCHAR(100),
    is_essential BOOLEAN,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, merchant_pattern)
);

CREATE TABLE IF NOT EXISTS import_batches (
    import_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES customers(user_id) ON DELETE CASCADE,
    source VARCHAR(32) NOT NULL CHECK (source IN ('CSVImport', 'BankStatementPDF', 'FinancialSMS')),
    filename VARCHAR(255),
    status VARCHAR(32) NOT NULL DEFAULT 'review_required',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS import_items (
    item_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    import_id UUID NOT NULL REFERENCES import_batches(import_id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    category VARCHAR(100) NOT NULL DEFAULT 'Others',
    transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN ('Income', 'Expense')),
    transaction_date TIMESTAMPTZ NOT NULL,
    merchant VARCHAR(255),
    payment_method VARCHAR(100),
    confidence NUMERIC(3, 2) NOT NULL DEFAULT 0.50 CHECK (confidence BETWEEN 0 AND 1),
    import_fingerprint VARCHAR(128) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'duplicate', 'accepted', 'discarded', 'invalid')),
    error_message VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_import_items_batch_status ON import_items (import_id, status);

CREATE TABLE IF NOT EXISTS recurring_commitments (
    commitment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES customers(user_id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    merchant VARCHAR(255),
    expected_amount NUMERIC(12, 2) NOT NULL CHECK (expected_amount > 0),
    frequency VARCHAR(20) NOT NULL CHECK (frequency IN ('weekly', 'monthly', 'quarterly', 'yearly')),
    next_due_date DATE NOT NULL,
    is_essential BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_commitments_user_due ON recurring_commitments (user_id, next_due_date) WHERE is_active;

CREATE TABLE IF NOT EXISTS expense_insights (
    insight_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES customers(user_id) ON DELETE CASCADE,
    insight_key VARCHAR(255) NOT NULL,
    kind VARCHAR(64) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    confidence NUMERIC(3, 2) NOT NULL CHECK (confidence BETWEEN 0 AND 1),
    amount NUMERIC(12, 2),
    projected_annual_cost NUMERIC(12, 2),
    evidence JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(32) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'helpful', 'incorrect', 'expected', 'ignored')),
    feedback_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, insight_key)
);
CREATE INDEX IF NOT EXISTS idx_expense_insights_user_status ON expense_insights (user_id, status, updated_at DESC);

CREATE TABLE IF NOT EXISTS chat_sessions (
    session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES customers(user_id) ON DELETE CASCADE,
    title VARCHAR(120) NOT NULL DEFAULT 'New expense chat',
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_message_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_recent
    ON chat_sessions (user_id, is_archived, last_message_at DESC NULLS LAST);

CREATE TABLE IF NOT EXISTS chat_messages (
    message_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES chat_sessions(session_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES customers(user_id) ON DELETE CASCADE,
    role VARCHAR(16) NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 4000),
    context JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_chat_messages_session_created
    ON chat_messages (session_id, created_at, message_id);
