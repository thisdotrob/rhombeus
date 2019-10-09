require 'json'
require 'pg'
require 'sinatra'

conn = PG.connect( dbname: 'postgres' )
conn.exec( "SELECT * FROM pg_stat_activity" ) do |result|
  puts "     PID | User             | Query"
  result.each do |row|
    puts " %7d | %-16s | %s " %
         row.values_at('pid', 'usename', 'current_query')
  end
end

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
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
