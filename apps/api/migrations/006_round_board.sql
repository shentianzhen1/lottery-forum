-- 006 期号归属版块。Runtime source is SQLite (RoundStore adds the column on startup).
-- board_id 可空：本片之前创建的旧期号没有归属版块，只有管理员能推进。
-- 归属校验（版块存在、彩种一致、版主本人）在服务层完成。
alter table rounds add column board_id text references moderator_boards(board_id);
create index if not exists idx_rounds_board on rounds(board_id);
