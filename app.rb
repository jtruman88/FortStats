require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'bcrypt'

require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload "database_persistence.rb"
end

helpers do
  def admin?(user)
    @data.is_admin?(user)
  end
end

before do
  @data = DatabasePersistence.new
  @current_season = @data.get_season
end

after do
  @data.disconnect
end

def valid_credentials?(user, password)
  if user
    bcrypt_password = BCrypt::Password.new(user[:pass])
    bcrypt_password == password
  else
    false
  end
end

def valid_new_user?(username, pass, repass, question)
  valid_username?(username) && valid_password?(pass, repass) &&
  valid_security?(question)
end

def valid_username?(username)
  usernames = @data.get_users.map { |user| user[:username].downcase }
  if usernames.include?(username.downcase)
    session[:error] = "'#{username}' is already is use. Please choose another username."
    false
  elsif username.empty?
    session[:error] = 'Username cannot be empty.'
    false
  else
    true
  end
end

def valid_password?(pass, repass)
  if pass.length < 6
    session[:error] = 'Password must be at least 6 characters long.'
    false
  elsif pass.downcase.match(/[^a-z0-9]/)
    session[:error] = 'Password must only include numbers and letters.'
    false
  elsif pass != repass
    session[:error] = 'Password fields did not match. Please try again.'
    false
  else
    true
  end
end

def valid_security?(question)
  if question.empty?
    session[:error] = 'Security question cannot be blank.'
    false
  else
    true
  end
end

def add_new_user(username, password, question)
  bcrypt_password = BCrypt::Password.create(password)
  bcrypt_question = BCrypt::Password.create(question)
  @data.add_new_player(username, bcrypt_password, bcrypt_question)
end

def valid_reset_info?(user, question)
  if user
    bcrypt_question = BCrypt::Password.new(user[:question])
    bcrypt_question == question
  else
    false
  end
end

def update_password(username, password)
  bcrypt_password = BCrypt::Password.create(password)
  @data.update_password(username, bcrypt_password)
end

def valid_stats?(place, elims)
  (place > 0 && place < 100) &&
  (elims < 99)
end

def calc_elim_points(type, elims, players)
  multiplier = {'solo' => 1, 'duo' => 2, 'squad' => 4}
  points = @data.get_elim_points * multiplier[type] * elims
end

def calc_place_points(type, place, players)
  handicap_multiplier = {'solo' => 1, 'duo' => 2, 'squad' => 2.4}
  divisor = {'solo' => 1, 'duo' => 2, 'squad' => 4}
  points = @data.get_place_points(place) / divisor[type]
  handicap = if type == 'squad'
               missing_players = 4 - players
               points * handicap_multiplier[type] * missing_players
             elsif type == 'duo'
               missing_players = 2 - players
               points * handicap_multiplier[type] * missing_players
             else
               0
             end

  (points + handicap).round
end

get '/' do
  if session[:logged_in]
    @last_ten = @data.get_last_ten
  end
  
  erb :home
end

get '/players/login' do
  
  erb :login
end

post '/players/login' do
  users = @data.get_users
  @username = params[:username].strip
  password = params[:password]
  
  user = users.find { |info| info[:username].downcase == @username.downcase }
  
  if valid_credentials?(user, password)
    session[:current_user] = user[:username]
    session[:logged_in] = true
    session[:success] = 'You have succesfully logged in!'
    
    redirect '/'
  else
    session[:error] = 'Invalid login info...'
    
    erb :login
  end
end

post '/players/logout' do
  session[:logged_in] = false
  session.delete(:current_user)
  session[:success] = "You have successfully been signed out."
  redirect '/'
end

get '/players/new' do
  
  erb :new
end

post '/players/new' do
  @username = params[:username].strip
  password = params[:password]
  repass = params[:repass]
  @question = params[:question].strip
  
  if valid_new_user?(@username, password, repass, @question)
    session[:success] = "You have succesfully created a new account! Please login."
    add_new_user(@username, password, @question)

    redirect '/players/login'
  else
    erb :new
  end
end

get '/players/login/reset' do
  erb :reset
end

post '/players/login/reset' do
  users = @data.get_users
  @username = params[:username].strip
  @question = params[:question].strip
  
  user = users.find { |info| info[:username].downcase == @username.downcase }
  
  if valid_reset_info?(user, @question)
    session[:current_user] = user[:username]
    redirect '/players/login/update'
  else
    session[:error] = 'Did not find any matching data in system.'
    
    erb :reset
  end
end

get '/players/login/update' do
  erb :update
end

post '/players/login/update' do
  password = params[:password]
  repass = params[:repass]
  username = session[:current_user]
  
  if valid_password?(password, repass)
    session[:success] = 'You have successfully updated your password. Please log in.'
    update_password(username, password)
    redirect '/players/login'
  else
    erb :update
  end
end

get '/player/stats/:type/:season/page-:page_number' do
  @type = params[:type]
  @season = params[:season]
  @seasons = @data.get_seasons
  @page = params[:page_number].to_i
  offset = (@page - 1) * 10
  
  if session[:logged_in]
    @summary_stats = @data.get_summary(session[:current_user], @season, @type)
    @match_stats = @data.get_match(session[:current_user], @season, @type, offset)
    @page_limit = @match_stats.empty? ? 1 : (@match_stats.first[:entries] / 10.0).ceil
  end
  
  erb :my_stats
end

get '/player/stats/filter/page-:page_number' do
  @type = params[:type]
  @season = params[:season]
  @seasons = @data.get_seasons
  @page = params[:page_number].to_i
  offset = (@page - 1) * 10
  
  if session[:logged_in]
    @summary_stats = @data.get_summary(session[:current_user], @season, @type)
    @match_stats = @data.get_match(session[:current_user], @season, @type, offset)
    @page_limit = @match_stats.empty? ? 1 : (@match_stats.first[:entries] / 10.0).ceil
  end
  
  erb :my_stats
end

get '/player/stats/add' do
  @type = params[:type]
  
  erb :add_stats
end

post '/player/stats/add' do
  @type = params[:type]
  @players = params[:players].to_i
  @place = params[:place].to_i
  @elims = params[:elims].to_i
  user = session[:current_user]
  season = @current_season
  
  if valid_stats?(@place, @elims)
    elim_points = calc_elim_points(@type, @elims, @players)
    place_points = calc_place_points(@type, @place, @players)
    @data.add_stats(user, @type, season, place_points, elim_points, @place, @elims)
    session[:success] = 'Your stats have been added!'
    
    redirect '/player/stats/add'
  else
    session[:error] = 'Please enter valid values.'
    
    erb :add_stats
  end
end

get '/seasons/edit' do
  @seasons = @data.get_seasons
  
  erb :seasons
end

post '/seasons/set-active' do
  active = params[:active].to_i
  @data.update_active_season(active)
  session[:success] = "Season #{active} has been set to active."
  redirect "/player/stats/combined/#{@current_season}/page-1"
end

post '/seasons/add' do
  new_season = params[:new].to_i
  @data.add_new_season(new_season)
  session[:success] = "Season #{new_season} has been added."
  redirect "/player/stats/combined/#{@current_season}/page-1"
end

get '/players' do
  @players = @data.get_all_players
  
   erb :players
end

get '/players/:user/stats/:type/:season/page-:page_number' do
  @user = params[:user]
  @type = params[:type]
  @season = params[:season]
  @seasons = @data.get_seasons
  @page = params[:page_number].to_i
  offset = (@page - 1) * 10
  
  if session[:logged_in]
    @summary_stats = @data.get_summary(@user, @season, @type)
    @match_stats = @data.get_match(@user, @season, @type, offset)
    @page_limit = @match_stats.empty? ? 1 : (@match_stats.first[:entries] / 10.0).ceil
  end
  
  erb :player_stats
end

get '/players/:user/stats/filter/page-:page_number' do
  @user = params[:user]
  @type = params[:type]
  @season = params[:season]
  @seasons = @data.get_seasons
  @page = params[:page_number].to_i
  offset = (@page - 1) * 10
  
  if session[:logged_in]
    @summary_stats = @data.get_summary(@user, @season, @type)
    @match_stats = @data.get_match(@user, @season, @type, offset)
    @page_limit = @match_stats.empty? ? 1 : (@match_stats.first[:entries] / 10.0).ceil
  end
  
  erb :player_stats
end

get '/leaderboard/:type/:season/sort-by-:sort' do
  @type = params[:type]
  @season = params[:season]
  @sort = params[:sort]
  @seasons = @data.get_seasons
  @leader_stats = @data.get_leaderboard_stats(@type, @season, @sort)

  erb :leaderboard
end

get '/leaderboard/filter' do
  @type = params[:type]
  @season = params[:season]
  @sort = params[:sort]
  @seasons = @data.get_seasons
  @leader_stats = @data.get_leaderboard_stats(@type, @season, @sort)
  
  erb :leaderboard
end

# ADD PLAYED TO MY STATS AND PLAYER STATS. WILL EQUAL NUMBER OF MATCHES PLAYED
# ADD IF LOGGED_IN / ADMIN PROTECTION TO LOGIN / ADMIN ONLY PAGES
# ALSO ADD INVALID PAGE CATCH
# REMOVE ARROW FROM NEXT OR BACK IF NOT CLICKABLE
# MOVE FILTER METHODS TO  FILTERABLE MODULE