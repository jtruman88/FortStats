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

before do
  @data = DatabasePersistence.new
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