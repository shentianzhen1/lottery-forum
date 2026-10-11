create table if not exists rounds (
    round_id text primary key,
    lottery_id text not null,
    code text,
    status text not null check (
        status in ('UPCOMING', 'OPEN', 'CLOSED', 'DRAWN', 'SETTLING', 'SETTLED')
    ),
    created_at text not null default (datetime('now'))
);
create index if not exists idx_rounds_lottery on rounds(lottery_id);
