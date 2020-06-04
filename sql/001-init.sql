CREATE USER rhombeus PASSWORD 'untwinecootieairmass';

CREATE DATABASE finances;

\c finances

DROP TABLE IF EXISTS tags CASCADE;
DROP TABLE IF EXISTS starling_transactions_tags;
DROP TABLE IF EXISTS amex_transactions_tags;

CREATE TABLE tags (
       id SERIAL PRIMARY KEY,
       value TEXT UNIQUE CHECK (value ~ '^[a-z0-9_]+$')
);

CREATE TABLE starling_transactions_tags (
       id SERIAL PRIMARY KEY,
       transaction_id UUID REFERENCES starling_transactions(feed_item_uid),
       tag_id INTEGER REFERENCES tags(id)
);

CREATE TABLE amex_transactions_tags (
       id SERIAL PRIMARY KEY,
       transaction_id TEXT REFERENCES amex_transactions(reference),
       tag_id INTEGER REFERENCES tags(id)
);

GRANT SELECT, UPDATE, INSERT ON ALL TABLES IN SCHEMA public TO rhombeus;
GRANT UPDATE ON ALL SEQUENCES IN SCHEMA public TO rhombeus;
