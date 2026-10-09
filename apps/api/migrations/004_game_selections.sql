create table if not exists game_selections (
    selection_id text primary key,
    account_id text not null,
    game_id text not null,
    numbers text not null,
    pair_count integer not null,
    idempotency_key text not null,
    stake integer not null default 0,
    payout integer not null default 0,
    unique (account_id, game_id, idempotency_key)
);
