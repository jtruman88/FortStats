require 'pg'

class DatabasePersistence
  def initialize
    @db = connect_to_database
  end
  
  def disconnect
    db.close
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
end