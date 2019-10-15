require 'json'
require 'pg'
require 'sinatra'

conn = PG.connect( dbname: 'postgres' )

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

get '/update_tags' do
  send_file File.join(settings.public_folder, 'update_tags.html')
end

get '/amex' do
  conn.exec( "SELECT * FROM amex_transactions" ) do |result|
    response = []
    result.each do |row|
      response.push row
    end
    response.to_json
  end
end

get '/starling' do
  conn.exec( "SELECT * FROM starling_transactions" ) do |result|
    response = []
    result.each do |row|
      response.push row
    end
    response.to_json
  end
end

post '/tags' do
  tags = request.body.read.split
  tags = tags.map { |tag| "('" + tag + "')" }
  values = tags.join(",")
  conn.exec("INSERT INTO tags (value) VALUES " + values) do |result|
    puts result
  end
end
