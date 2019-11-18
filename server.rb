require 'json'
require 'pg'
require 'sinatra'
require 'json'

conn = PG.connect( dbname: 'postgres' )
conn.type_map_for_results = PG::BasicTypeMapForResults.new conn

def amex_query (search)
  'SELECT CAST(at.reference as TEXT) as id, '\
  '       at.transaction_date as date, '\
  '       at.minor_units as amount, '\
  '       at.counter_party_name as description, '\
  '       COALESCE(string_agg(t.value, \' \'), \'\') AS tags '\
  'FROM amex_transactions AS at '\
  'LEFT JOIN amex_transactions_tags AS att '\
  'ON at.reference = att.transaction_id '\
  'LEFT JOIN tags AS t '\
  'ON t.id = att.tag_id '\
  'WHERE at.counter_party_name LIKE \'%' + search + '%\' '\
  'GROUP BY at.reference '\
  'ORDER BY at.transaction_date DESC;'
end

def starling_query (search)
  'SELECT CAST(st.feed_item_uid as TEXT) as id, '\
  '       st.transaction_time as date, '\
  '       st.minor_units as amount, '\
  '       st.direction as direction, '\
  '       st.counter_party_name as description, '\
  '       COALESCE(string_agg(t.value, \' \'), \'\') AS tags '\
  'FROM starling_transactions AS st '\
  'LEFT JOIN starling_transactions_tags AS stt '\
  'ON st.feed_item_uid = stt.transaction_id '\
  'LEFT JOIN tags AS t '\
  'ON t.id = stt.tag_id '\
  'WHERE st.counter_party_name LIKE \'%' + search + '%\' '\
  'GROUP BY st.feed_item_uid '\
  'ORDER BY st.transaction_time DESC;'
end

def valid_date_str(str)
  /\d{4}-\d{2}-\d{2}/ === str
end

def all_transactions_query (tags, date_from, date_to)
  tags = tags.split
  tags = tags.map { |tag| "'" + tag + "'" }.join(',')
  amex_filters = []
  starling_filters = []
  if tags != ''
    amex_filters.push 'att.tag_id IN (SELECT id FROM tags WHERE value IN (' + tags + '))'
    starling_filters.push 'stt.tag_id IN (SELECT id FROM tags WHERE value IN (' + tags + '))'
  end
  if date_from != '' and valid_date_str(date_from)
    amex_filters.push "at.transaction_date >= '" + date_from + "'"
    starling_filters.push "st.transaction_time >= '" + date_from + "'"
  end
  if date_to != '' and valid_date_str(date_to)
    amex_filters.push "at.transaction_date <= '" + date_to + "'"
    starling_filters.push "st.transaction_time <= '" + date_to + "'"
  end
  amex_filter_str = ''
  if amex_filters.length > 0
    amex_filter_str = 'WHERE ' + amex_filters.join(' AND ')
  end
  starling_filter_str = ''
  if starling_filters.length > 0
    starling_filter_str = 'WHERE ' + starling_filters.join(' AND ')
  end
  'SELECT CAST(at.reference as TEXT) as id, '\
  '       FLOOR(EXTRACT(epoch from at.transaction_date) * 1000) as date, '\
  '       at.minor_units as amount, '\
  '       \'n.a.\' as direction, '\
  '       at.counter_party_name as description, '\
  '       COALESCE(string_agg(t.value, \' \'), \'\') AS tags, '\
  '       \'amex\' as source '\
  'FROM amex_transactions AS at '\
  'LEFT JOIN amex_transactions_tags AS att '\
  'ON at.reference = att.transaction_id '\
  'LEFT JOIN tags AS t '\
  'ON t.id = att.tag_id '\
  '' + amex_filter_str + ' '\
  'GROUP BY at.reference '\
  'UNION '\
  'SELECT CAST(st.feed_item_uid as TEXT) as id, '\
  '       FLOOR(EXTRACT(epoch from st.transaction_time) * 1000) as date, '\
  '       st.minor_units as amount, '\
  '       st.direction as direction, '\
  '       st.counter_party_name as description, '\
  '       COALESCE(string_agg(t.value, \' \'), \'\') AS tags, '\
  '       \'starling\' as source '\
  'FROM starling_transactions AS st '\
  'LEFT JOIN starling_transactions_tags AS stt '\
  'ON st.feed_item_uid = stt.transaction_id '\
  'LEFT JOIN tags AS t '\
  'ON t.id = stt.tag_id '\
  '' + starling_filter_str + ' '\
  'GROUP BY st.feed_item_uid '\
  'ORDER BY date DESC;'
end

def upsert_tags_query (tags)
  'INSERT INTO tags (value) VALUES ' + tags.map { |tag| "('" + tag + "')" }.join(",") + 'ON CONFLICT (value) DO UPDATE ' + 'SET value = EXCLUDED.value ' + 'RETURNING id, value;'
end

def drop_amex_tags_query(transaction_id)
  "DELETE FROM amex_transactions_tags WHERE transaction_id = '" + transaction_id + "'"
end

def drop_starling_tags_query(transaction_id)
  "DELETE FROM starling_transactions_tags WHERE transaction_id = '" + transaction_id + "'"
end

def insert_amex_tags_query(transaction_id, tag_ids)
  values = tag_ids.map { |id| "('" + id.to_s + "', '" + transaction_id +  "')" }.join(",")
  "INSERT INTO amex_transactions_tags (tag_id, transaction_id) VALUES " + values
end

def insert_starling_tags_query(transaction_id, tag_ids)
  values = tag_ids.map { |id| "('" + id.to_s + "', '" + transaction_id +  "')" }.join(",")
  "INSERT INTO starling_transactions_tags (tag_id, transaction_id) VALUES " + values
end

def get_amex_transactions(conn, search)
  conn.exec(amex_query(search)) do |result|
    response = []
    result.each do |row|
      row['amount'] = row['amount'] / 100.0
      response.push row
    end
    response
  end
end

def get_starling_transactions(conn, search)
  conn.exec(starling_query(search)) do |result|
    response = []
    result.each do |row|
      row['amount'] = row['amount'] / 100.0
      if row['direction'] == 'IN'
        row['amount'] = -1 * row['amount']
      end
      response.push row
    end
    response
  end
end

def get_all_transactions(conn, tags, date_from, date_to)
  conn.exec(all_transactions_query(tags, date_from, date_to)) do |result|
    response = []
    result.each do |row|
      row['amount'] = row['amount'] / 100.0
      if row['source'] == 'starling' and row['direction'] == 'IN'
        row['amount'] = -1 * row['amount']
      end
      response.push row
    end
    response
  end

end

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

get '/tags' do
  send_file File.join(settings.public_folder, 'tags.html')
end

get '/filter' do
  send_file File.join(settings.public_folder, 'filter.html')
end

get '/amex/transactions' do
  search = params[:search]
  response = get_amex_transactions(conn, search)
  response.to_json
end

get '/starling/transactions' do
  search = params[:search]
  response = get_starling_transactions(conn, search)
  response.to_json
end

get '/all/transactions' do
  puts params
  tags = params[:tags]
  date_from = params[:date_from]
  date_to = params[:date_to]
  response = get_all_transactions(conn, tags, date_from, date_to)
  response.to_json
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
      conn.exec(drop_amex_tags_query(transaction_id))
      conn.exec(insert_amex_tags_query(transaction_id, tag_ids))
    end
  end
  search = params[:search]
  response = get_amex_transactions(conn, search)
  response.to_json
end

post '/starling/update_tags' do
  updates = JSON.parse(request.body.read)
  updates.each do |update|
    transaction_id = update["id"]
    tags =  update["tags"].split
    conn.exec(upsert_tags_query(tags)) do |tags|
      tag_ids = tags.map { |t| t["id"] }
      conn.exec(drop_starling_tags_query(transaction_id))
      conn.exec(insert_starling_tags_query(transaction_id, tag_ids))
    end
  end
  search = params[:search]
  response = get_starling_transactions(conn, search)
  response.to_json
end
