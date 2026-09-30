CREATE TABLE IF NOT EXISTS incidents (
    id BIGSERIAL PRIMARY KEY,

    title VARCHAR(255) NOT NULL,

    description TEXT,

    severity VARCHAR(20) NOT NULL
        CHECK (
            severity IN (
                'low',
                'medium',
                'high',
                'critical'
            )
        ),

    status VARCHAR(30) NOT NULL DEFAULT 'open'
        CHECK (
            status IN (
                'open',
                'investigating',
                'resolved'
            )
        ),

    service VARCHAR(100) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_incidents_status
ON incidents(status);

CREATE INDEX IF NOT EXISTS idx_incidents_severity
ON incidents(severity);