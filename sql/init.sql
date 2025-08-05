-- ruv-FANN PostgreSQL initialization
CREATE DATABASE IF NOT EXISTS fanndb;

\c fanndb;

-- Swarms table
CREATE TABLE IF NOT EXISTS swarms (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255),
    topology VARCHAR(50),
    max_agents INTEGER,
    strategy VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Agents table
CREATE TABLE IF NOT EXISTS agents (
    id VARCHAR(255) PRIMARY KEY,
    swarm_id VARCHAR(255) REFERENCES swarms(id),
    name VARCHAR(255),
    type VARCHAR(50),
    cognitive_pattern VARCHAR(50),
    capabilities JSONB,
    neural_config JSONB,
    status VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id VARCHAR(255) PRIMARY KEY,
    swarm_id VARCHAR(255) REFERENCES swarms(id),
    description TEXT,
    priority VARCHAR(20),
    status VARCHAR(50),
    assigned_agents JSONB,
    results JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- Memory storage
CREATE TABLE IF NOT EXISTS memory (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE,
    value TEXT,
    namespace VARCHAR(255),
    ttl INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

-- Neural models
CREATE TABLE IF NOT EXISTS neural_models (
    id VARCHAR(255) PRIMARY KEY,
    agent_id VARCHAR(255) REFERENCES agents(id),
    model_type VARCHAR(50),
    parameters JSONB,
    weights BYTEA,
    metrics JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Syncthing sync status
CREATE TABLE IF NOT EXISTS sync_status (
    id SERIAL PRIMARY KEY,
    folder_id VARCHAR(255),
    device_id VARCHAR(255),
    last_sync TIMESTAMP,
    files_synced INTEGER,
    status VARCHAR(50)
);

-- Create indexes
CREATE INDEX idx_agents_swarm ON agents(swarm_id);
CREATE INDEX idx_tasks_swarm ON tasks(swarm_id);
CREATE INDEX idx_memory_namespace ON memory(namespace);
CREATE INDEX idx_memory_key ON memory(key);
CREATE INDEX idx_neural_agent ON neural_models(agent_id);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO fann;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO fann;