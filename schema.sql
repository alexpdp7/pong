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
  primary key (game_id, team_id)
);
