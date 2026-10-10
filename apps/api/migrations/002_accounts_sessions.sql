-- 002 accounts and sessions. Runtime source is SQLite. PostgreSQL is not connected.
create table if not exists accounts (
    account_id text primary key,
    username text not null unique,
    password_hash text not null,
    role text not null
);

create table if not exists sessions (
    token_hash text primary key,
    account_id text not null references accounts(account_id)
);
