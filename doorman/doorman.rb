begin require 'rubygems' rescue e end
require 'date'
require 'json'
require 'httparty'
require 'twitter'

STATE_FILE_NAME = 'doorman.state'
LOCK_FILE_NAME = 'doorman.state.lock'
CREDS_FILE_NAME = 'doorman.creds'

STATUS_URL = 'http://hacdc.org/sites/default/files/last_occsensor.txt'

STATUS_STRINGS ={
  false => 'HacDC is currently closed.',
  true => 'HacDC is currently open.'}
TIME_FORMAT = ' (as of %a, %b %d at %r )'

class Status
  attr_accessor :timestamp, :status, :last_change
  TIMEISH_REGEXP = /\d{4}-\d{2}-\d{2}.*\d{2}:\d{2}:\d{2}/
  TRUE_FALSE = {'true' => true, 'false' => false}
  def initialize(u = nil, s = nil, c = nil)
    u,c = *[u,c].map do |t|
      t ||= DateTime.new
      t = t.to_s
      raise 'malformed data: unexpected date-time value '+t unless t =~ TIMEISH_REGEXP
      t = DateTime.parse(t)
    end

    s = s.to_s
    if s.empty?
      s = nil
    else
      s = TRUE_FALSE[s.to_s.downcase]
      raise 'malformed data: unexpected true/false value' if s.nil?
    end
    @timestamp, @status, @last_change = u, s, c
  end
  def to_json(*a)
    return {
      'json_class' => self.class.name,
      'timestamp' => @timestamp,
      'status' => @status,
      'last_change' => @last_change,
    }.to_json(*a)
  end
  def self.from_json(o)
    new(o['timestamp'], o['status'], o['last_change'])
  end
end

res = HTTParty.get(STATUS_URL)
raise "Failed to get occupancy data: #{res.code} #{res.message}" unless res.code == 200

parts = res.body.split(',')
raise 'malformed data: wrong number of parts' if parts.length != 7

cur = Status.new(parts[0], parts[2])

l = File.new(LOCK_FILE_NAME, File::CREAT|File::EXCL|File::WRONLY)
begin
  l.puts Process.pid

  if File.exists?(STATE_FILE_NAME) and File.size?(STATE_FILE_NAME) 
    f = File.new(STATE_FILE_NAME, 'r+')
    prev = JSON.parse(f.read)
    prev = Status.from_json(prev) unless prev.is_a?(Status)
  else 
    f = File.new(STATE_FILE_NAME, 'w')
    prev = Status.new
  end

  cur.last_change = (cur.status == prev.status)? prev.last_change : cur.timestamp

  f.truncate(0)
  f.seek(0, IO::SEEK_SET)
  f.puts JSON.dump(cur)
  f.close
ensure
  l.close
  File.unlink(LOCK_FILE_NAME)
end

# if nothing's changed, then we're done
exit if cur.status == prev.status

# tweet about it

f = File.new(CREDS_FILE_NAME, 'r')
creds = JSON.parse(f.read)
f.close

oauth = Twitter::OAuth.new(creds['conumer_key'], creds['consumer_secret'])
oauth.authorize_from_access(creds['access_token'], creds['access_secret'])

twit = Twitter::Base.new(oauth)
twit.update(STATUS_STRINGS[cur.status] + DateTime.now.strftime(TIME_FORMAT))
