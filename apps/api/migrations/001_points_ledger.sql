-- 通用积分账本。余额是投影，历史分录只追加。
-- 不包含充值、提现、兑付或用户间转账。

create table if not exists points_accounts (
    account_id text primary key,
    balance integer not null default 0 check (balance >= 0),
    created_at timestamptz not null default now()
);

create table if not exists points_entries (
    entry_id text primary key,
    account_id text not null references points_accounts(account_id),
    direction text not null check (direction in ('credit', 'debit')),
    amount integer not null check (amount > 0),
    reason text not null check (reason in ('opening_grant', 'game_settlement', 'correction')),
    reference_type text not null,
    reference_id text not null,
    idempotency_key text not null,
    operator_id text not null,
    note text not null default '',
    corrects_entry_id text references points_entries(entry_id),
    created_at timestamptz not null default now(),
    unique (account_id, idempotency_key)
);

create index if not exists points_entries_account_created
    on points_entries (account_id, created_at);
