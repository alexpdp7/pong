begin;
    set search_path=pong;

    select plan(17);

    select isa_ok(create_player('joe'), 'uuid');
    select isa_ok(create_player('stu'), 'uuid');
    select isa_ok(create_player('lee'), 'uuid');
    select isa_ok(create_player('pat'), 'uuid');
    select isa_ok(create_player('ron'), 'uuid');

    select is(count(*)::integer, 5::integer) from teams;
    select is(count(*)::integer, 5::integer) from players;

    with pl_1 as (select player_id from players order by player_id limit 1 offset 0),
         pl_2 as (select player_id from players order by player_id limit 1 offset 1),
         pl_3 as (select player_id from players order by player_id limit 1 offset 2),
         pl_4 as (select player_id from players order by player_id limit 1 offset 3)
    select pl_1.player_id as pl_1_id,
           pl_2.player_id as pl_2_id,
           pl_3.player_id as pl_3_id,
           pl_4.player_id as pl_4_id
    into   temporary table player_ids
    from   pl_1, pl_2, pl_3, pl_4
    limit  1;
    
    select isa_ok(create_doubles_team(pl_1_id, pl_2_id), 'uuid') from player_ids;
    select isa_ok(create_doubles_team(pl_3_id, pl_4_id), 'uuid') from player_ids;
    select throws_ok('select create_doubles_team(' || pl_2_id || ',' || pl_1_id || ');') from player_ids;
    
    select is(count(*)::integer, 7::integer) from teams;
    select is(count(*)::integer, 5::integer) from players;
    select is(count(*)::integer, 2::integer) from doubles_teams;

    with dt_1 as (select team_id from doubles_teams order by team_id limit 1 offset 0),
         dt_2 as (select team_id from doubles_teams order by team_id limit 2 offset 0)
    select dt_1.team_id as dt_1_id,
           dt_2.team_id as dt_2_id
    into   temporary table doubles_team_ids
    from   dt_1, dt_2
    limit  1;
    
    prepare single_game_insert as insert into games(sets, doubles, team_1_id, team_2_id)
                                  select 3, false, pl_1_id, pl_2_id
                                  from   player_ids;

    select lives_ok('single_game_insert');

    prepare doubles_game_insert as insert into games(sets, doubles, team_1_id, team_2_id)
                                   select 3, true, dt_1_id, dt_2_id
                                   from   doubles_team_ids;

    select lives_ok('doubles_game_insert');

    prepare bad_game_insert as insert into games(sets, doubles, team_1_id, team_2_id)
                               select 3, false, dt_1_id, dt_2_id
                               from   doubles_team_ids;

    select throws_ok('bad_game_insert');

    select is(count(*)::integer, 2::integer) from games;

    select * from finish();
rollback;
