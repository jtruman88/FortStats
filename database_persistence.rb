require 'pg'

class DatabasePersistence
  def initialize
    @db = connect_to_database
  end
  
  def disconnect
    db.close
  end
  
  def query(statement, *params)
    db.exec_params(statement, params)
  end
  
  def get_users
    sql = <<~SQL
      SELECT username, pass, question FROM players;
    SQL
    
    result = query(sql)
    
    result.map do |tuple|
      { username: tuple['username'], pass: tuple['pass'], question: tuple['question'] }
    end
  end
  
  def add_new_player(username, password, question)
    sql = <<~SQL
      INSERT INTO players (username, pass, question)
      VALUES ($1, $2, $3);
    SQL
    
    query(sql, username, password, question)
  end
  
  def get_last_ten
    sql = <<~SQL
      SELECT players.username, matches.place, matches.elims, match_types.match_type,
      (matches.elim_points + matches.place_points) AS points
      FROM players JOIN matches ON players.id = matches.player_id
      JOIN match_types ON match_types.id = matches.match_type_id
      ORDER BY matches.date_played DESC
      LIMIT 10;
    SQL
    
    result = query(sql)
    
    result.map do |tuple|
      last_ten_hash(tuple)
    end
  end
  
  def update_password(username, password)
    sql = <<~SQL
      UPDATE players SET pass = $1
      WHERE username = $2;
    SQL
    
    query(sql, password, username)
  end
  
  def get_season
    sql = 'SELECT season FROM seasons WHERE active = true;'
    
    result = query(sql)
    
    result.map { |tuple| tuple['season'] }.first
  end
  
  def get_seasons
    sql = 'SELECT season FROM seasons ORDER BY season ASC;'
    
    result = query(sql)
    
    result.map { |tuple| {number: tuple['season']} }
  end
  
  def is_admin?(user)
    sql = 'SELECT admin FROM players WHERE username = $1;'
    
    result = query(sql, user)
    
    admin = result.map { |tuple| {admin: tuple['admin']} }
    admin.first[:admin] == 't'
  end
  
  def get_summary(user, season, type)
    user_id = get_user_id(user)
    season_id = get_season_id(season)
    type_id = get_type_id(type)
    
    if season == 'all' && type == 'combined'
      sql = summary_unfiltered
      result = query(sql, user_id)
    elsif season == 'all'
      sql = summary_filtered_type
      result = query(sql, user_id, type_id)
    elsif type == 'combined'
      sql = summary_filtered_season
      result = query(sql, user_id, season_id)
    else
      sql = summary_filtered_season_type
      result = query(sql, user_id, season_id, type_id)
    end  
        
    result.map { |tuple| summary_hash(tuple) }
  end

  def get_match(user, season, type, offset)
    user_id = get_user_id(user)
    season_id = get_season_id(season)
    type_id = get_type_id(type)
    
    if season == 'all' && type == 'combined'
      sql = match_unfiltered
      result = query(sql, user_id, offset)
    elsif season == 'all'
      sql = match_filtered_type
      result = query(sql, user_id, type_id, offset)
    elsif type == 'combined'
      sql = match_filtered_season
      result = query(sql, user_id, season_id, offset)
    else
      sql = match_filtered_season_type
      result = query(sql, user_id, season_id, type_id, offset)
    end    

    result.map { |tuple| match_hash(tuple) }
  end
  
  def get_elim_points
    sql = 'SELECT point_value FROM elim_points;'
    
    result = query(sql)
    
    result.map { |tuple| tuple['point_value'] }.first.to_i
  end
  
  def get_place_points(place)
    sql = 'SELECT point_value FROM place_points WHERE ($1)::integer <@ place;'
    
    result = query(sql, place.to_i)
    
    result.map { |tuple| tuple['point_value'] }.first.to_i
  end
  
  def add_stats(user, type, season, place_points, elim_points, place, elims)
    user_id = get_user_id(user)
    type_id = get_type_id(type)
    season_id = get_season_id(season)
    
    sql = <<~SQL
      INSERT INTO matches (player_id, match_type_id, season_id, place_points,
      elim_points, place, elims) VALUES ($1, $2, $3, $4, $5, $6, $7);
    SQL
    
    result = query(sql, user_id, type_id, season_id, place_points, elim_points, place, elims)
  end
  
  private #-----------------------------------------------------------------------------------------
  
  attr_reader :db
  
  def connect_to_database
    if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: "fort_test")
    end
  end
  
  def last_ten_hash(tuple)
    { username: tuple['username'],
      place: tuple['place'].to_i,
      elims: tuple['elims'].to_i,
      match_type: tuple['match_type'].capitalize,
      points: tuple['points'].to_i }
  end
  
  def summary_hash(tuple)
    { wins: tuple['wins'],
      avg_place: tuple['avg_place'],
      elims: tuple['elims'],
      avg_elims: tuple['avg_elims'],
      points: tuple['points'] }
  end

  def match_hash(tuple)
    { date: tuple['date'],
      place: tuple['place'],
      elims: tuple['elims'],
      type: tuple['type'],
      points: tuple['points'],
      entries: tuple['entries'].to_i }
  end
  
  def get_user_id(user)
    sql = 'SELECT id FROM players WHERE username = $1;'
    result = query(sql, user)
    result.map { |tuple| {id: tuple['id']} }.first[:id]
  end
  
  def get_season_id(season)
    return 0 if season == 'all'
    sql = 'SELECT id FROM seasons WHERE season = $1;'
    result = query(sql, season)
    result.map { |tuple| {id: tuple['id']} }.first[:id]
  end
  
  def get_type_id(type)
    return 0 if type == 'combined'
    sql = 'SELECT id FROM match_types WHERE match_type = $1;'
    result = query(sql, type)
    result.map { |tuple| {id: tuple['id']} }.first[:id]
  end
  
  def summary_unfiltered
    sql = <<~SQL
      SELECT (SELECT COUNT(place) FROM matches WHERE place = 1 AND player_id = $1) AS wins,
      ROUND(AVG(matches.place)) AS avg_place, SUM(matches.elims) AS elims,
      ROUND(AVG(matches.elims)) AS avg_elims, SUM(place_points + elim_points) AS points
      FROM matches JOIN players ON matches.player_id = players.id
      JOIN match_types ON matches.match_type_id = match_types.id
      JOIN seasons ON matches.season_id = seasons.id
      WHERE players.id = $1
      GROUP BY players.username
      ORDER BY points;
    SQL
  end
  
  def summary_filtered_season_type
    sql = <<~SQL
      SELECT (SELECT COUNT(place) FROM matches WHERE place = 1 AND player_id = $1 AND
      season_id = $2 AND match_type_id = $3) AS wins,
      ROUND(AVG(matches.place)) AS avg_place, SUM(matches.elims) AS elims,
      ROUND(AVG(matches.elims)) AS avg_elims, SUM(place_points + elim_points) AS points
      FROM matches JOIN players ON matches.player_id = players.id
      JOIN match_types ON matches.match_type_id = match_types.id
      JOIN seasons ON matches.season_id = seasons.id
      WHERE players.id = $1 AND seasons.id = $2 AND match_types.id = $3
      GROUP BY players.username
      ORDER BY points;
    SQL
  end
  
  def summary_filtered_season
    sql = <<~SQL
      SELECT (SELECT COUNT(place) FROM matches WHERE place = 1 AND player_id = $1 AND
      season_id = $2) AS wins,
      ROUND(AVG(matches.place)) AS avg_place, SUM(matches.elims) AS elims,
      ROUND(AVG(matches.elims)) AS avg_elims, SUM(place_points + elim_points) AS points
      FROM matches JOIN players ON matches.player_id = players.id
      JOIN match_types ON matches.match_type_id = match_types.id
      JOIN seasons ON matches.season_id = seasons.id
      WHERE players.id = $1 AND seasons.id = $2
      GROUP BY players.username
      ORDER BY points;
    SQL
  end
  
  def summary_filtered_type
    sql = <<~SQL
      SELECT (SELECT COUNT(place) FROM matches WHERE place = 1 AND player_id = $1 AND
      match_type_id = $2) AS wins,
      ROUND(AVG(matches.place)) AS avg_place, SUM(matches.elims) AS elims,
      ROUND(AVG(matches.elims)) AS avg_elims, SUM(place_points + elim_points) AS points
      FROM matches JOIN players ON matches.player_id = players.id
      JOIN match_types ON matches.match_type_id = match_types.id
      JOIN seasons ON matches.season_id = seasons.id
      WHERE players.id = $1 AND match_types.id = $2
      GROUP BY players.username
      ORDER BY points;
    SQL
  end

  def match_unfiltered
    sql = <<~SQL
      SELECT (EXTRACT(month from date_played) || '/' || EXTRACT(day FROM date_played) || '/' || EXTRACT(year FROM date_played)) AS date,
      (SELECT COUNT(matches.id) FROM matches WHERE player_id = $1) AS entries,
      matches.place AS place, matches.elims AS elims, match_types.match_type AS type, (place_points + elim_points) AS points
      FROM matches JOIN players ON matches.player_id = players.id
      JOIN seasons ON matches.season_id = seasons.id
      JOIN match_types ON matches.match_type_id = match_types.id
      WHERE players.id = $1
      ORDER BY date_played
      LIMIT 10 OFFSET $2;
    SQL
  end

  def match_filtered_type
    sql = <<~SQL
      SELECT (EXTRACT(month from date_played) || '/' || EXTRACT(day FROM date_played) || '/' || EXTRACT(year FROM date_played)) AS date,
      (SELECT COUNT(matches.id) FROM matches WHERE player_id = $1 AND match_type_id = $2) AS entries,
      matches.place AS place, matches.elims AS elims, match_types.match_type AS type, (place_points + elim_points) AS points
      FROM matches JOIN players ON matches.player_id = players.id
      JOIN seasons ON matches.season_id = seasons.id
      JOIN match_types ON matches.match_type_id = match_types.id
      WHERE players.id = $1 AND match_types.id = $2
      ORDER BY date_played
      LIMIT 10 OFFSET $3;
    SQL
  end

  def match_filtered_season
    sql = <<~SQL
      SELECT (EXTRACT(month from date_played) || '/' || EXTRACT(day FROM date_played) || '/' || EXTRACT(year FROM date_played)) AS date,
      (SELECT COUNT(matches.id) FROM matches WHERE player_id = $1 AND season_id = $2) AS entries,
      matches.place AS place, matches.elims AS elims, match_types.match_type AS type, (place_points + elim_points) AS points
      FROM matches JOIN players ON matches.player_id = players.id
      JOIN seasons ON matches.season_id = seasons.id
      JOIN match_types ON matches.match_type_id = match_types.id
      WHERE players.id = $1 AND seasons.id = $2
      ORDER BY date_played
      LIMIT 10 OFFSET $3;
    SQL
  end

  def match_filtered_season_type
    sql = <<~SQL
      SELECT (EXTRACT(month from date_played) || '/' || EXTRACT(day FROM date_played) || '/' || EXTRACT(year FROM date_played)) AS date,
      (SELECT COUNT(matches.id) FROM matches
      WHERE player_id = $1 AND season_id = $2 AND match_type_id = $3) AS entries,
      matches.place AS place, matches.elims AS elims, match_types.match_type AS type, (place_points + elim_points) AS points
      FROM matches JOIN players ON matches.player_id = players.id
      JOIN seasons ON matches.season_id = seasons.id
      JOIN match_types ON matches.match_type_id = match_types.id
      WHERE players.id = $1 AND seasons.id = $2 AND match_types.id = $3
      ORDER BY date_played
      LIMIT 10 OFFSET $4;
    SQL
  end
end