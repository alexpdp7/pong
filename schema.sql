create extension if not exists "uuid-ossp";
create extension if not exists pgtap;

create table teams (
  team_id          uuid primary key default uuid_generate_v4()
);

create table players (
  player_id        uuid primary key references teams(team_id),
  name             text not null
);

create function create_player(name text) returns uuid as $create_player$
  declare
    result uuid;
  begin
    with ins as (
      insert into teams default values returning team_id
    )
    insert into players(player_id, name) (
      select team_id, name
      from ins
    )
    returning player_id into strict result;
    return result;
  end
$create_player$ language plpgsql;

create table doubles_teams (
  team_id          uuid primary key references teams(team_id),
  player_1_id      uuid not null references players(player_id),
  player_2_id      uuid not null references players(player_id),
  check (player_1_id < player_2_id),
  unique (player_1_id, player_2_id)
);

create function create_doubles_team(player_1_id uuid, player_2_id uuid) returns uuid as $create_player$
  declare
    result uuid;
  begin
    with ins as (
      insert into teams default values returning team_id
    )
    insert into doubles_teams(team_id, player_1_id, player_2_id) (
      select team_id, player_1_id, player_2_id
      from ins
    )
    returning team_id into strict result;
    return result;
  end
$create_player$ language plpgsql;


create table games (
  game_id          uuid primary key default uuid_generate_v4(),
  started_at       timestamp with time zone default now(),
  sets             integer not null check (sets>0),
  doubles          boolean not null,
  team_1_id        uuid not null references teams(team_id),
  team_2_id        uuid not null references teams(team_id)
);

create function check_single_player(team_id uuid) returns void as $check_single_player$
  begin
    perform 1 from players where player_id = team_id;
    if not found then
      raise exception 'player % not found', team_id;
    end if;
  end
$check_single_player$ language plpgsql;

create function check_doubles_team(team_id uuid) returns void as $check_doubles_team$
  begin
    perform 1 from doubles_teams where doubles_teams.team_id = $1;
    if not found then
      raise exception 'doubles team % not found', team_id;
    end if;
  end
$check_doubles_team$ language plpgsql;


create function check_valid_teams() returns trigger as $check_valid_teams$
  begin
    if new.doubles then
      perform check_doubles_team(new.team_1_id);
      perform check_doubles_team(new.team_2_id);
    else
      perform check_single_player(new.team_1_id);
      perform check_single_player(new.team_2_id);
    end if;
    return new;
  end;
$check_valid_teams$ language plpgsql;

create trigger valid_teams before insert or update on games for each row execute procedure check_valid_teams();

create table points (
  game_id          uuid not null references games(game_id),
  team_id          uuid not null references teams(team_id),
  scored_at        timestamp with time zone default now(),
  primary key (game_id, scored_at)
);

create function check_valid_scorer() returns trigger as $check_valid_scorer$
  begin
    perform 1 from games where game_id = new.game_id and new.team_id in (team_1_id, team_2_id);
    if not found then
      raise exception 'team % not in game %', new.team_id, new.game_id;
    end if;
    return new;
  end
$check_valid_scorer$ language plpgsql;

create trigger valid_scores before insert or update on points for each row execute procedure check_valid_scorer();

-- TODO: testing
-- TODO: sets
-- TODO: winner
-- TODO: serving
create view partial_results as
with recursive partial_results as (
  select game_id,
         0 as team_1_points,
         0 as team_2_points,
         started_at as when
  from   games
  union all (
  select partial_results.game_id,
         partial_results.team_1_points + case when points.team_id = games.team_1_id then 1 else 0 end,
         partial_results.team_2_points + case when points.team_id = games.team_2_id then 1 else 0 end,
         points.scored_at as when
  from   partial_results
  join   points on partial_results.game_id = points.game_id
  join   games on points.game_id = games.game_id
  where  points.scored_at > partial_results.when
  limit 1)
)
select * from partial_results;
