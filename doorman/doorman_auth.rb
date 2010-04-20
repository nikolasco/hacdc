begin require 'rubygems' rescue e end
require 'date'
require 'json'
require 'twitter'

CREDS_FILE_NAME = 'doorman.creds'

f = File.new(CREDS_FILE_NAME)
creds = JSON.parse(f.read)
f.close

oauth = Twitter::OAuth.new(creds['conumer_key'], creds['consumer_secret'])
req_tok = oauth.request_token

puts "please go to #{req_tok.authorize_url}"
puts "enter the PIN Twitter gave you"
pin = gets.chomp
oauth.authorize_from_request(req_tok.token, req_tok.secret, pin)
creds['access_token'] = oauth.access_token.token
creds['access_secret'] = oauth.access_token.secret

puts "new creds:\n"
puts JSON.dump(creds)
