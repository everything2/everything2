#!/usr/bin/env ruby
# Smoke test facility for Everything2
# Tests basic functionality before running full test suite

require 'net/http'
require 'uri'
require 'json'

class SmokeTest
  def initialize(base_url = 'http://localhost:9080')
    @base_url = base_url
    @cookies = {}
    @errors = []
    @warnings = []
  end

  def run
    puts "=" * 60
    puts "Everything2 Smoke Test"
    puts "=" * 60
    puts "Base URL: #{@base_url}"
    puts ""

    test_server_running
    test_homepage_loads
    test_login
    test_key_superdocs
    test_react_initialization
    test_nodelets
    test_xml_tickers
    test_xml_displaytypes

    report_results
  end

  private

  def test_server_running
    print "Testing server connectivity... "
    begin
      response = http_get('/')
      if response.code.to_i == 200
        # Check that we got actual E2 content, not just any 200 response
        if response.body && (response.body.include?('everything2.com') || response.body.include?('e2-react-root'))
          puts "✓ Server is running"
        else
          puts "✗ Server returned 200 but unexpected content"
          @errors << "Server returned 200 but response doesn't look like Everything2"
        end
      elsif response.code.to_i == 500
        # Internal server error often indicates Perl compilation failure
        puts "✗ Server returned 500 (possible Perl syntax error)"
        @errors << "Server returned 500 - check Apache error logs for Perl compilation errors"
      else
        puts "✗ Server returned #{response.code}"
        @errors << "Server not responding correctly (HTTP #{response.code})"
      end
    rescue => e
      puts "✗ Failed"
      @errors << "Cannot connect to server: #{e.message}"
    end
  end

  def test_homepage_loads
    print "Testing homepage... "
    begin
      response = http_get('/')
      body = response.body

      if response.code.to_i != 200
        puts "✗ HTTP #{response.code}"
        @errors << "Homepage returned HTTP #{response.code}"
        return
      end

      # Check for critical elements
      if body.include?('Everything2')
        puts "✓ Homepage loads"
      else
        puts "✗ Missing content"
        @warnings << "Homepage missing 'Everything2' text"
      end

      # Check for fatal errors
      if body.include?('Software error') || body.include?('Internal Server Error')
        @errors << "Homepage shows fatal error"
      end

      # Check for Perl errors
      if body =~ /at \/.*?\.pm line \d+/
        error_match = body.match(/(.{0,100}at \/.*?\.pm line \d+.{0,100})/)
        @errors << "Perl error on homepage: #{error_match[0]}" if error_match
      end

    rescue => e
      puts "✗ Exception"
      @errors << "Homepage test failed: #{e.message}"
    end
  end

  def test_login
    print "Testing login... "
    begin
      # Try to log in as root
      response = http_post('/', {
        'user' => 'root',
        'passwd' => 'blah',
        'op' => 'login'
      })

      store_cookies(response)

      # Check for login errors in POST response
      if response.body.include?('Invalid password') || response.body.include?('Login failed')
        puts "✗ Login failed"
        @errors << "Login failed with credentials user=root, passwd=blah"
        return
      end

      # Make a GET request to verify logged-in state
      response = http_get('/')

      # Check if login was successful by looking for logout link or user info
      if response.body.include?('Log Out') || response.body =~ /"title":"root"/
        puts "✓ Login successful"
      else
        puts "⚠ Login may have failed"
        @warnings << "Could not confirm successful login (no logout link found)"
      end

    rescue => e
      puts "✗ Exception"
      @errors << "Login test failed: #{e.message}"
    end
  end

  def test_key_superdocs
    puts "Testing all special documents..."

    # Auto-generated from docs/special-documents.md
    # Generated: 2025-11-20
    superdocs = []

    # Skip these documents (undersupported or not initialized in dev)
    skip_docs = ['Podcast RSS Feed']

    # Pages that require authentication (NoGuest security trait)
    # These pages will redirect to login if accessed without valid session
    # Also includes pages that require special permissions (chanop, editor, admin)
    # which show permission-denied style content to unauthorized users
    auth_required_pages = [
      'Silver Trinkets',
      'Golden Trinkets',
      'Sanctify user',
      'Admin Settings',
      'Decloaker',
      'Drafts',
      'Drafts for review',
      'Everything\'s Obscure Writeups',
      'Personal Scratchpad',
      'User Preferences',
      'User XML Generator',
      'Wharfinger\'s Linebreaker',
      'Write User',
      'Profile Settings',
      'Recent Node Notes',
      'Your Nodeshells',
      'E2 Bouncer',  # Chanop only
      'Create Room',  # Level-gated
    ]

    docs_path = File.expand_path('../docs/special-documents.md', __dir__)
    File.readlines(docs_path).each do |line|
      # Skip non-table rows
      next unless line.start_with?('| ') && !line.include?('Document | Type | URL')

      # Parse table row: | Document | Type | URL | Rendering |
      parts = line.split('|').map(&:strip)
      next if parts.length < 5

      title = parts[1]

      # Skip undersupported documents
      next if skip_docs.include?(title)

      url = parts[3].gsub('`', '')
      doc_type = parts[2]
      rendering = parts[4]

      superdocs << {
        title: title,
        path: url,
        type: doc_type,
        rendering: rendering,
        auth_required: auth_required_pages.include?(title)
      }
    end

    puts "  Found #{superdocs.length} documents to test"

    # Detect number of CPU cores for parallel testing
    num_cores = detect_cpu_cores
    num_workers = [num_cores - 2, 2].max  # cores - 2, minimum 2
    puts "  Using #{num_workers} parallel workers (detected #{num_cores} cores)"
    puts ""

    # Test documents in parallel using thread pool
    results = test_pages_parallel(superdocs, num_workers)

    # Count results
    passed = results.count { |r| r == :pass }
    tested = results.length

    puts ""
    puts "  Document Test Summary:"
    puts "  ✓ Passed: #{passed}/#{tested}"
  end

  def detect_cpu_cores
    # Try nproc first (most reliable)
    nproc = `nproc 2>/dev/null`.chomp
    return nproc.to_i if nproc && nproc =~ /^\d+$/

    # Fall back to /proc/cpuinfo
    if File.exist?('/proc/cpuinfo')
      count = File.readlines('/proc/cpuinfo').count { |line| line.start_with?('processor') }
      return count if count > 0
    end

    # Default to 2 if detection fails
    2
  end

  def test_pages_parallel(docs, num_workers)
    require 'thread'

    queue = Queue.new
    docs.each { |doc| queue << doc }

    results = []
    results_mutex = Mutex.new
    print_mutex = Mutex.new

    workers = (1..num_workers).map do
      Thread.new do
        until queue.empty?
          begin
            doc = queue.pop(true)
          rescue ThreadError
            # Queue is empty
            break
          end

          # Test the page
          result = test_page_quiet(doc[:title], doc[:path], doc[:type], doc[:rendering], doc[:auth_required], print_mutex)

          # Store result thread-safely
          results_mutex.synchronize do
            results << result
          end
        end
      end
    end

    workers.each(&:join)
    results
  end

  def test_page_quiet(name, path, doc_type, rendering, auth_required, print_mutex)
    # Retry configuration
    max_retries = 3
    retry_delay = 0.5  # seconds
    transient_codes = [400, 502, 503, 504]

    # Run the test with retry logic
    result = nil
    retries = 0

    loop do
      begin
        # Don't follow redirects for auth-required pages so we can detect 302
        response = http_get(path, follow_redirects: !auth_required)
        code = response.code.to_i

        # Debug for Everything's Obscure Writeups
        if name.include?('Obscure')
          location = response['location'] || response['Location']
          print_mutex.synchronize {
            puts "  DEBUG #{name}: auth_required=#{auth_required.inspect} code=#{code} location=#{location.inspect}"
          }
        end

        # Auth-required pages expect 302 redirect to login for guests
        if auth_required && code == 302
          location = response['location'] || response['Location']
          if location && location.include?('login')
            retry_msg = retries > 0 ? " (after #{retries} retries)" : ""
            print_mutex.synchronize { puts "  #{name}... ✓ (302 to login)#{retry_msg}" }
            return :pass
          end
        end

        # Permission denied is only expected for the "Permission Denied" page itself
        if code == 403 || (code == 200 && response.body.include?("You don't have access to that node.") && name != 'Permission Denied')
          print_mutex.synchronize { puts "  #{name}... ✗ Permission denied" }
          @errors << "#{name}: Unexpected permission denial (root should have access)"
          return :error
        end

        if code == 200
          body = response.body

          # For XML/JSON API endpoints (tickers), just verify they return XML-like content
          if rendering == 'XML/JSON API'
            if body.include?('<?xml') || body.include?('<') || body.include?('{')
              retry_msg = retries > 0 ? " (after #{retries} retries)" : ""
              print_mutex.synchronize { puts "  #{name}... ✓ (API)#{retry_msg}" }
              return :pass
            else
              print_mutex.synchronize { puts "  #{name}... ✗ Invalid API response" }
              @errors << "#{name}: API endpoint doesn't return XML/JSON"
              return :error
            end
          end

          # Check for fatal errors
          if body.include?('Software error') || body.include?('Internal Server Error')
            print_mutex.synchronize { puts "  #{name}... ✗ Fatal error" }
            @errors << "#{name}: Shows fatal error"
            return :error
          end

          # Check for Perl errors
          if body =~ /at \/.*?\.pm line \d+/
            print_mutex.synchronize { puts "  #{name}... ✗ Perl error" }
            error_match = body.match(/(.{0,150}at \/.*?\.pm line \d+.{0,50})/)
            @errors << "#{name}: Perl error - #{error_match[0]}" if error_match
            return :error
          end

          # Check for missing htmlcode errors
          if body.include?('could not be found as Everything::Delegation::htmlcode')
            print_mutex.synchronize { puts "  #{name}... ✗ Missing htmlcode" }
            error_match = body.match(/(.{0,50}could not be found as Everything::Delegation::htmlcode::\w+.{0,50})/)
            @errors << "#{name}: #{error_match[0]}" if error_match
            return :error
          end

          # Check for undefined method errors
          if body.include?("Can't locate object method")
            print_mutex.synchronize { puts "  #{name}... ✗ Method error" }
            error_match = body.match(/(Can't locate object method .{0,100})/)
            @errors << "#{name}: #{error_match[0]}" if error_match
            return :error
          end

          retry_msg = retries > 0 ? " (after #{retries} retries)" : ""
          print_mutex.synchronize { puts "  #{name}... ✓#{retry_msg}" }
          return :pass
        elsif code == 404
          print_mutex.synchronize { puts "  #{name}... ⚠ Not found" }
          @warnings << "#{name}: Page not found (may not exist in dev environment)"
          return :warning
        elsif transient_codes.include?(code) && retries < max_retries
          # Transient error - retry after delay
          retries += 1
          delay = retry_delay * (2 ** (retries - 1))  # Exponential backoff
          print_mutex.synchronize { puts "  #{name}... ⚠ HTTP #{code}, retrying (#{retries}/#{max_retries}) after #{delay}s" }
          sleep(delay)
          next  # Try again
        else
          # Hard error or max retries reached
          retry_msg = retries > 0 ? " (failed after #{retries} retries)" : ""
          print_mutex.synchronize { puts "  #{name}... ✗ HTTP #{code}#{retry_msg}" }
          @errors << "#{name}: HTTP #{code}#{retry_msg}"
          return :error
        end

      rescue => e
        # Check if exception is transient (timeout, connection reset, etc.)
        if (e.is_a?(Net::OpenTimeout) || e.is_a?(Net::ReadTimeout) || e.message.include?('Connection reset')) && retries < max_retries
          retries += 1
          delay = retry_delay * (2 ** (retries - 1))
          print_mutex.synchronize { puts "  #{name}... ⚠ #{e.class}, retrying (#{retries}/#{max_retries}) after #{delay}s" }
          sleep(delay)
          next  # Try again
        else
          retry_msg = retries > 0 ? " (failed after #{retries} retries)" : ""
          print_mutex.synchronize { puts "  #{name}... ✗ Exception#{retry_msg}" }
          @errors << "#{name}: #{e.message}#{retry_msg}"
          return :error
        end
      end

      break  # Exit loop if we reach here (shouldn't happen due to returns)
    end
  end

  def test_page(name, path, doc_type = 'Superdoc', rendering = 'E2 Legacy')
    print "  #{name}... "
    begin
      response = http_get(path)
      code = response.code.to_i

      # Permission denied is only expected for the "Permission Denied" page itself
      # Root user should have access to all other documents including restricted/oppressor
      # Check for the actual permission denial message, not just the text "Permission Denied"
      if code == 403 || (code == 200 && response.body.include?("You don't have access to that node.") && name != 'Permission Denied')
        puts "✗ Permission denied"
        @errors << "#{name}: Unexpected permission denial (root should have access)"
        return :error
      end

      if code == 200
        body = response.body

        # For XML/JSON API endpoints (tickers), just verify they return XML-like content
        if rendering == 'XML/JSON API'
          if body.include?('<?xml') || body.include?('<') || body.include?('{')
            puts "✓ (API)"
            return :pass
          else
            puts "✗ Invalid API response"
            @errors << "#{name}: API endpoint doesn't return XML/JSON"
            return :error
          end
        end

        # Check for fatal errors
        if body.include?('Software error') || body.include?('Internal Server Error')
          puts "✗ Fatal error"
          @errors << "#{name}: Shows fatal error"
          return :error
        end

        # Check for Perl errors
        if body =~ /at \/.*?\.pm line \d+/
          puts "✗ Perl error"
          error_match = body.match(/(.{0,150}at \/.*?\.pm line \d+.{0,50})/)
          @errors << "#{name}: Perl error - #{error_match[0]}" if error_match
          return :error
        end

        # Check for missing htmlcode errors
        if body.include?('could not be found as Everything::Delegation::htmlcode')
          puts "✗ Missing htmlcode"
          error_match = body.match(/(.{0,50}could not be found as Everything::Delegation::htmlcode::\w+.{0,50})/)
          @errors << "#{name}: #{error_match[0]}" if error_match
          return :error
        end

        # Check for undefined method errors
        if body.include?("Can't locate object method")
          puts "✗ Method error"
          error_match = body.match(/(Can't locate object method .{0,100})/)
          @errors << "#{name}: #{error_match[0]}" if error_match
          return :error
        end

        puts "✓"
        return :pass
      elsif code == 404
        puts "⚠ Not found"
        @warnings << "#{name}: Page not found (may not exist in dev environment)"
        return :warning
      else
        puts "✗ HTTP #{code}"
        @errors << "#{name}: HTTP #{code}"
        return :error
      end

    rescue => e
      puts "✗ Exception"
      @errors << "#{name}: #{e.message}"
      return :error
    end
  end

  def test_react_initialization
    print "Testing React initialization... "
    begin
      response = http_get('/')
      body = response.body

      # Check if window.e2 is initialized
      if body.include?('e2 = {')
        puts "✓ React data structure present"
      else
        puts "⚠ React data structure missing"
        @warnings << "e2 initialization not found on homepage"
      end

      # Check for React bundle
      if body.include?('bundle.js') || body.include?('react')
        # React is present
      else
        @warnings << "React bundle may not be loaded"
      end

    rescue => e
      puts "✗ Exception"
      @errors << "React initialization test failed: #{e.message}"
    end
  end

  def test_nodelets
    print "Testing nodelet data... "
    begin
      response = http_get('/')
      body = response.body

      # Check for React root container
      unless body.include?('e2-react-root')
        puts "✗ React root container missing"
        @errors << "React root container (e2-react-root) not found in HTML"
        return
      end

      # Check for nodelet data in JSON structure
      nodelets_found = 0
      ['epicenter', 'newWriteups', 'developerNodelet', 'coolnodes', 'staffpicks'].each do |nodelet|
        if body.include?("\"#{nodelet}\":")
          nodelets_found += 1
        end
      end

      if nodelets_found >= 3
        puts "✓ Found #{nodelets_found} nodelet data structures"
      else
        puts "⚠ Only found #{nodelets_found} nodelet data structures"
        @warnings << "Expected more nodelet data in JSON (found #{nodelets_found})"
      end

    rescue => e
      puts "✗ Exception"
      @errors << "Nodelet test failed: #{e.message}"
    end
  end

  def test_xml_tickers
    print "Testing XML tickers... "

    # Define all XML tickers with their expected characteristics
    tickers = [
      {name: 'Client Version XML Ticker', root: 'clientregistry', elements: ['client', 'version']},
      {name: 'Available Rooms XML Ticker', root: 'e2rooms', elements: ['roomlist']},
      {name: 'Cool Nodes XML Ticker II', root: 'coolwriteups', elements: ['cool', 'writeup']},
      {name: 'Editor Cools XML Ticker', root: 'editorcools', elements: ['edselection']},
      {name: 'Everything\'s Best Users XML Ticker', root: 'EBU', elements: ['bestuser']},
      {name: 'Maintenance Nodes XML Ticker', root: 'maintenance', elements: ['e2link']},
      {name: 'My Votes XML Ticker', root: 'votes', elements: ['vote']},
      {name: 'New Writeups XML Ticker', root: 'newwriteups', elements: ['wu', 'e2link']},
      {name: 'Node Heaven XML Ticker', root: 'nodeheaven', elements: ['nodeangel']},
      {name: 'Other Users XML Ticker II', root: 'otherusers', elements: ['user']},
      {name: 'Personal Session XML Ticker', root: 'e2session', elements: ['currentuser', 'servertime']},
      {name: 'Random Nodes XML Ticker', root: 'randomnodes', elements: ['wit', 'e2link']},
      {name: 'Raw Vars XML Ticker', root: 'vars', elements: ['key']},
      {name: 'Time Since XML Ticker', root: 'timesince', elements: ['lasttimes']},
      {name: 'Universal Message XML Ticker', root: 'messages', elements: ['room', 'topic']},
      {name: 'User Search XML Ticker II', root: 'usersearch', elements: ['wu']},
      {name: 'E2 XML Search Interface', root: 'searchinterface', elements: ['searchinfo', 'searchresults'], params: '?keywords=test'},
      {name: 'XML Interfaces Ticker', root: 'xmlcaps', elements: ['this', 'xmlexport']},
      # Atom/RSS feeds
      {name: 'Cool Archive Atom Feed', root: 'feed', elements: ['title', 'entry'], xmlns: true},
      {name: 'New Writeups Atom Feed', root: 'feed', elements: ['title', 'entry'], xmlns: true},
      {name: 'Podcast RSS Feed', root: 'rss', elements: ['channel', 'item']},
    ]

    passed = 0
    failed = 0

    tickers.each do |ticker|
      # URL-encode ticker name
      encoded_name = URI.encode_www_form_component(ticker[:name])
      path = "/node/ticker/#{encoded_name}"
      path += ticker[:params] if ticker[:params]

      begin
        response = http_get(path)
        body = response.body

        # Check HTTP status
        unless response.code.to_i == 200
          @errors << "#{ticker[:name]}: HTTP #{response.code}"
          failed += 1
          next
        end

        # Check for XML declaration
        unless body.start_with?('<?xml')
          @errors << "#{ticker[:name]}: Missing XML declaration"
          failed += 1
          next
        end

        # Check for root element
        unless body.include?("<#{ticker[:root]}")
          @errors << "#{ticker[:name]}: Missing root element <#{ticker[:root]}>"
          failed += 1
          next
        end

        # Check for key elements (field ordering validation)
        missing_elements = []
        ticker[:elements].each do |element|
          unless body.include?("<#{element}")
            missing_elements << element
          end
        end

        if missing_elements.any?
          @warnings << "#{ticker[:name]}: Missing elements: #{missing_elements.join(', ')}"
        end

        # Check for xmlns if expected (Atom/RSS)
        if ticker[:xmlns] && !body.include?('xmlns=')
          @warnings << "#{ticker[:name]}: Missing xmlns declaration"
        end

        # Check for Perl errors in XML
        if body.include?('at /var/everything') || body.include?('line ')
          @errors << "#{ticker[:name]}: Contains Perl error"
          failed += 1
          next
        end

        # Validate field ordering by checking first occurrence positions
        if ticker[:elements].length >= 2
          positions = ticker[:elements].map { |el| body.index("<#{el}") }.compact
          unless positions == positions.sort
            @warnings << "#{ticker[:name]}: Field ordering may have changed (#{ticker[:elements].take(3).join(' → ')})"
          end
        end

        passed += 1

      rescue => e
        @errors << "#{ticker[:name]}: Exception - #{e.message}"
        failed += 1
      end
    end

    if failed == 0
      puts "✓ #{passed}/#{tickers.length} tickers passed"
    else
      puts "✗ #{failed} failed, #{passed} passed"
    end
  end

  def test_xml_displaytypes
    print "Testing displaytype=xml/xmltrue... "

    # Test critical node types using seed data
    tests = [
      # displaytype=xml tests - uses Everything::XML::node2xml format with <NODE> wrapper
      {path: '/user/normaluser1/writeups/lazy%20dog?displaytype=xml', name: 'writeup (xml)', must_include: ['<NODE>', '<INFO>rendered by Everything::Node->to_xml()</INFO>', '<title']},
      {path: '/title/lazy%20dog?displaytype=xml', name: 'e2node (xml)', must_include: ['<NODE>', '<title', 'lazy dog']},

      # displaytype=xmltrue tests - uses form representation with <node> wrapper
      {path: '/user/normaluser1/writeups/lazy%20dog?displaytype=xmltrue', name: 'writeup (xmltrue)', must_include: ['<node node_id', '<type>writeup</type>', '<doctext>']},
      {path: '/title/lazy%20dog?displaytype=xmltrue', name: 'e2node (xmltrue)', must_include: ['<node node_id', '<type>']},
    ]

    passed = 0
    failed = 0

    tests.each do |test|
      begin
        response = http_get(test[:path])
        body = response.body

        # Check HTTP status
        unless response.code.to_i == 200
          @errors << "#{test[:name]}: HTTP #{response.code}"
          failed += 1
          next
        end

        # Check for XML declaration
        unless body.start_with?('<?xml') || body.include?('<?xml')
          @errors << "#{test[:name]}: Missing XML declaration"
          failed += 1
          next
        end

        # Check for required elements
        missing = []
        test[:must_include].each do |required|
          unless body.include?(required)
            missing << required
          end
        end

        if missing.any?
          @errors << "#{test[:name]}: Missing required elements: #{missing.join(', ')}"
          failed += 1
          next
        end

        # Check for Perl errors
        if body.include?('at /var/everything') || body =~ /at .*?\.pm line \d+/
          @errors << "#{test[:name]}: Contains Perl error"
          failed += 1
          next
        end

        passed += 1

      rescue => e
        @errors << "#{test[:name]}: Exception - #{e.message}"
        failed += 1
      end
    end

    if failed == 0
      puts "✓ #{passed}/#{tests.length} displaytype tests passed"
    else
      puts "✗ #{failed} failed, #{passed} passed"
    end
  end

  def http_get(path, follow_redirects: true)
    uri = URI.join(@base_url, path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Cookie'] = cookies_string if @cookies.any?

    response = http.request(request)

    # Follow redirects (up to 5 hops)
    redirect_count = 0
    while follow_redirects && response.is_a?(Net::HTTPRedirection) && redirect_count < 5
      redirect_count += 1
      location = response['Location']

      # Handle both absolute and relative redirects
      if location.start_with?('http')
        uri = URI.parse(location)
      else
        uri = URI.join(@base_url, location)
      end

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10
      request = Net::HTTP::Get.new(uri.request_uri)
      request['Cookie'] = cookies_string if @cookies.any?
      response = http.request(request)
    end

    response
  end

  def http_post(path, params)
    uri = URI.join(@base_url, path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Cookie'] = cookies_string if @cookies.any?
    request.set_form_data(params)

    http.request(request)
  end

  def store_cookies(response)
    if response['Set-Cookie']
      response.get_fields('Set-Cookie').each do |cookie|
        cookie_name, cookie_value = cookie.split(';').first.split('=', 2)
        @cookies[cookie_name] = cookie_value if cookie_name && cookie_value
      end
    end
  end

  def cookies_string
    @cookies.map { |k, v| "#{k}=#{v}" }.join('; ')
  end

  def report_results
    puts ""
    puts "=" * 60
    puts "Smoke Test Results"
    puts "=" * 60

    if @errors.empty? && @warnings.empty?
      puts "✓ All tests passed! Application is ready."
      exit 0
    end

    if @warnings.any?
      puts "\n⚠ Warnings (#{@warnings.length}):"
      @warnings.each_with_index do |warning, i|
        puts "  #{i + 1}. #{warning}"
      end
    end

    if @errors.any?
      puts "\n✗ Errors (#{@errors.length}):"
      @errors.each_with_index do |error, i|
        puts "  #{i + 1}. #{error}"
      end
      puts ""
      puts "=" * 60
      puts "SMOKE TESTS FAILED - Fix errors before running full test suite"
      puts "=" * 60
      exit 1
    else
      puts ""
      puts "=" * 60
      puts "Smoke tests passed with warnings"
      puts "=" * 60
      exit 0
    end
  end
end

# Run smoke tests if executed directly
if __FILE__ == $0
  base_url = ARGV[0] || ENV['E2_BASE_URL'] || 'http://localhost:9080'
  SmokeTest.new(base_url).run
end
