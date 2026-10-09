create table if not exists points_holds (
    hold_id text primary key,
    account_id text not null references points_accounts(account_id),
    amount integer not null check (amount > 0),
    status text not null check (status in ('active', 'released')),
    idempotency_key text not null,
    operator_id text not null,
    unique (account_id, idempotency_key)
);
