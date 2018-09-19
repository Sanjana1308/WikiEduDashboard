# frozen_string_literal: true

# Gets data from ORES — Objective Revision Evaluation Service
# https://meta.wikimedia.org/wiki/Objective_Revision_Evaluation_Service
class OresApi
  # This is the maximum number of concurrent requests the app should make.
  # As of 2018-09-19, ORES policy is a max of 4 parallel connections per IP:
  # https://lists.wikimedia.org/pipermail/wikitech-l/2018-September/090835.html
  CONCURRENCY = 4

  def initialize(wiki)
    raise InvalidProjectError unless wiki.project == 'wikipedia'
    @project_code = wiki.language + 'wiki'
  end

  def get_revision_data(rev_id)
    response = ores_server.get query_url(rev_id)
    ores_data = Oj.load(response.body)
    ores_data
  rescue StandardError => error
    raise error unless TYPICAL_ERRORS.include?(error.class)
    return {}
  end

  TYPICAL_ERRORS = [
    Errno::ETIMEDOUT,
    Net::ReadTimeout,
    Errno::ECONNREFUSED,
    Oj::ParseError,
    Errno::EHOSTUNREACH,
    Faraday::ConnectionFailed,
    Faraday::TimeoutError
  ].freeze

  class InvalidProjectError < StandardError
  end

  private

  def query_url(rev_id)
    base_url = "/v3/scores/#{@project_code}/"
    url = base_url + rev_id.to_s + '/articlequality?features'
    url = URI.encode url
    url
  end

  def ores_server
    conn = Faraday.new(url: 'https://ores.wikimedia.org')
    conn.headers['User-Agent'] = ENV['dashboard_url'] + ' ' + Rails.env
    conn
  end
end
