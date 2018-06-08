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
      ORDER BY matches.date_played
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
  
  private
  
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
end