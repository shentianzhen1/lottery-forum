-- 账户与会话。密码和 token 只保存摘要。

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
