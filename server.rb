require 'json'
require 'pg'
require 'sinatra'
require 'json'

conn = PG.connect( dbname: 'postgres' )

amex_query = 'SELECT at.reference as id, '\
             '       at.transaction_date as date, '\
             '       at.minor_units as amount, '\
             '       at.counter_party_name as description, '\
             'COALESCE(string_agg(t.value, \' \'), \'\') AS tags '\
             'FROM amex_transactions AS at '\
             'LEFT JOIN amex_transactions_tags AS att '\
             'ON at.reference = att.transaction_id '\
             'LEFT JOIN tags AS t '\
             'ON t.id = att.tag_id '\
             'GROUP BY at.reference '\
             'ORDER BY at.transaction_date DESC;'

starling_query = 'SELECT st.feed_item_uid as id, '\
                 '       st.transaction_time as date, '\
                 '       st.minor_units as amount, '\
                 '       st.counter_party_name as description, '\
                 'COALESCE(string_agg(t.value, \' \'), \'\') AS tags '\
                 'FROM starling_transactions AS st '\
                 'LEFT JOIN starling_transactions_tags AS stt '\
                 'ON st.feed_item_uid = stt.transaction_id '\
                 'LEFT JOIN tags AS t '\
                 'ON t.id = stt.tag_id '\
                 'GROUP BY st.feed_item_uid '\
                 'ORDER BY st.transaction_time DESC;'

def upsert_tags_query (tags)
  'INSERT INTO tags (value) VALUES ' + tags.map { |tag| "('" + tag + "')" }.join(",") + 'ON CONFLICT (value) DO UPDATE ' + 'SET value = EXCLUDED.value ' + 'RETURNING id, value;'
end

def insert_amex_tags_query(transaction_id, tag_ids)
  values = tag_ids.map { |id| "('" + id + "', '" + transaction_id +  "')" }.join(",")
  "INSERT INTO amex_transactions_tags (tag_id, transaction_id) VALUES " + values
end

def insert_starling_tags_query(transaction_id, tag_ids)
  values = tag_ids.map { |id| "('" + id + "', '" + transaction_id +  "')" }.join(",")
  "INSERT INTO starling_transactions_tags (tag_id, transaction_id) VALUES " + values
end

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

get '/tags' do
  send_file File.join(settings.public_folder, 'tags.html')
end

get '/amex/transactions' do
  conn.exec(amex_query) do |result|
    response = []
    result.each do |row|
      response.push row
    end
    response.to_json
  end
end

get '/starling/transactions' do
  conn.exec(starling_query) do |result|
    response = []
    result.each do |row|
      response.push row
    end
    response.to_json
  end
end

get '/tags/all' do
  conn.exec( "SELECT * FROM tags" ) do |result|
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
  conn.exec( "INSERT INTO tags (value) VALUES " + values ) do |result|
    puts result
  end
end

post '/delete_tag' do
  tag_id = request.body.read
  conn.exec( "DELETE FROM tags WHERE id = " + tag_id ) do |result|
    puts result
  end
end

post '/amex/update_tags' do
  updates = JSON.parse(request.body.read)
  updates.each do |update|
    transaction_id = update["id"]
    tags =  update["tags"].split
    conn.exec(upsert_tags_query(tags)) do |tags|
      tag_ids = tags.map { |t| t["id"] }
      conn.exec(insert_amex_tags_query(transaction_id, tag_ids))
    end
  end
  conn.exec(amex_query) do |result|
    response = []
    result.each do |row|
      response.push row
    end
    response.to_json
  end
end

post '/starling/update_tags' do
  updates = JSON.parse(request.body.read)
  updates.each do |update|
    transaction_id = update["id"]
    tags =  update["tags"].split
    conn.exec(upsert_tags_query(tags)) do |tags|
      tag_ids = tags.map { |t| t["id"] }
      conn.exec(insert_starling_tags_query(transaction_id, tag_ids))
    end
  end
  conn.exec(starling_query) do |result|
    response = []
    result.each do |row|
      response.push row
    end
    response.to_json
  end
end
