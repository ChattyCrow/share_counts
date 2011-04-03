require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

class ShareCountsTest < ActiveSupport::TestCase
  setup do
    $stderr = @stderr = StringIO.new
    $stdin  = @stdin  = StringIO.new
    $stdout = @stdout = StringIO.new
  end
  
  def teardown
    $stderr = @stderr =  STDERR
    $stdin  = @stdin  =  STDIN
    $stdout = @stdout =  STDOUT
  end
  
  test ".supported_networks returns the supported networks" do
    assert_equal(%w(reddit digg twitter facebook fblike linkedin googlebuzz stumbleupon).sort, ShareCounts.supported_networks.sort)
  end
  
  test ".make_request makes a request to a remove service and returns the response" do
    stub_request(:get, SOME_URL).with(:query => SOME_PARAMS.to_hash).to_return(:body => "---RESPONSE---")
  
    assert_equal("---RESPONSE---", ShareCounts.send(:make_request, SOME_URL, *SOME_PARAMS ))
    assert_equal(0, @stdout.string.split("\n").size)
  end
  
  test ".make_request should raise an exception if the remote service returns a 500 status code for three attempts" do
    stub_request(:get, SOME_URL).to_return(:status =>  [500, "Internal Server Error"])
  
    assert_raise(Exception) { ShareCounts.send(:make_request, SOME_URL)  }
    
    errors = []
    3.times {|n| errors << "Failed #{n+1} attempt(s) - 500 Internal Server Error" }
    assert_equal(errors.sort, @stdout.string.split("\n").sort)
  end
  
  
  test ".make_request should raise an exception if the remote service times out for three attempts" do
    stub_request(:get, SOME_URL).to_timeout
    
    assert_raise(Exception) { ShareCounts.send(:make_request, SOME_URL)  }
    
    errors = []
    3.times {|n| errors << "Failed #{n+1} attempt(s) - Request Timeout" }
    assert_equal(errors.sort, @stdout.string.split("\n").sort)
  end
  
  test ".make_request should return response if remote service fails < 3 attempts" do
    stub_request(:get, SOME_URL).
      to_return(:status =>  [500, "Internal Server Error"]).then.
      to_timeout.then.
      to_return(:body => "---RESPONSE---" )
    
    assert_nothing_raised(Exception) { assert_equal("---RESPONSE---", ShareCounts.send(:make_request, SOME_URL)) }
    
    assert_equal(["Failed 1 attempt(s) - 500 Internal Server Error", "Failed 2 attempt(s) - Request Timeout"].sort, @stdout.string.split("\n").sort)
  end
  
  test ".make_request should strip the callback call from the JSON response if a callback has been specified" do
    stub_request(:get, SOME_URL).with(:query => SOME_PARAMS.to_hash).
      to_return(:body => "myCallback(JSON_DATA);").then.
      to_return(:body => "myCallback(JSON_DATA)")
  
    assert_equal("JSON_DATA", ShareCounts.send(:make_request, SOME_URL, *SOME_PARAMS ))
    assert_equal("JSON_DATA", ShareCounts.send(:make_request, SOME_URL, *SOME_PARAMS ))
    assert_equal(0, @stdout.string.split("\n").size)
  end
  
  
  test ".from_json parses the JSON response returned by a remote service" do
    stub_request(:get, SOME_URL).to_return(:body => "{\"a\":1,\"b\":2}").then.to_return(:body => "[\"a\", \"b\", 1, 2]")
    stub_request(:get, SOME_URL).with(:query => SOME_PARAMS.to_hash).to_return(:body => "myCallback({\"a\":1,\"b\":2})")
  
    assert_equal({ "a" => 1, "b" => 2 }, ShareCounts.send(:from_json, SOME_URL))
    assert_equal(["a", "b", 1, 2], ShareCounts.send(:from_json, SOME_URL))
    assert_equal({ "a" => 1, "b" => 2 }, ShareCounts.send(:from_json, SOME_URL, *SOME_PARAMS ))
    assert_equal(0, @stdout.string.split("\n").size)
  end
  
  test ".extract_info correctly extract the information from the parsed JSON data received, in XPATH style" do
    teardown
    
    stub_request(:get, Reddit.api).with(:query => Reddit.params.to_hash).to_return(:body => Reddit.json)
    stub_request(:get, Digg.api).with(:query => Digg.params.to_hash).to_return(:body => Digg.json)
    stub_request(:get, Twitter.api).with(:query => Twitter.params.to_hash).to_return(:body => Twitter.json)
    stub_request(:get, Facebook.api).with(:query => Facebook.params.to_hash).to_return(:body => Facebook.json)
    stub_request(:get, Linkedin.api).with(:query => Linkedin.params.to_hash).to_return(:body => Linkedin.json)
    

    assert_equal(31,  ShareCounts.send(:extract_info, ShareCounts.send(:from_json, Reddit.api, *Reddit.params), { :selector => Reddit.selector } ))
    assert_equal(1,   ShareCounts.send(:extract_info, ShareCounts.send(:from_json, Digg.api, *Digg.params), { :selector => Digg.selector } ))
    assert_equal(35,   ShareCounts.send(:extract_info, ShareCounts.send(:from_json, Twitter.api, *Twitter.params), { :selector => Twitter.selector } ))
    assert_equal(23,   ShareCounts.send(:extract_info, ShareCounts.send(:from_json, Facebook.api, *Facebook.params), { :selector => Facebook.selector } ))
    assert_equal(23,   ShareCounts.send(:extract_info, ShareCounts.send(:from_json, Linkedin.api, *Linkedin.params), { :selector => Linkedin.selector } ))
    
  end

  test ".reddit should return the reddit score" do
    stub_request(:get, Reddit.api).with(:query => Reddit.params.to_hash).to_return(:body => Reddit.json)
    assert_equal(31, ShareCounts.reddit(SOME_URL))
  end

  test ".reddit with raise_exceptions=true should raise exception" do
    stub_request(:get, Reddit.api).with(:query => Reddit.params.to_hash).to_raise(Exception)
    assert_raise(Exception) { ShareCounts.reddit(SOME_URL, true) }
  end

  test ".digg should return the digg score" do
    stub_request(:get, Digg.api).with(:query => Digg.params.to_hash).to_return(:body => Digg.json)
    assert_equal(1, ShareCounts.digg(SOME_URL))
  end

  test ".digg with raise_exceptions=true should raise exception" do
    stub_request(:get, Digg.api).with(:query => Digg.params.to_hash).to_raise(Exception)
    assert_raise(Exception) { ShareCounts.digg(SOME_URL, true) }
  end
  
  test ".twitter should return the twitter score" do
    stub_request(:get, Twitter.api).with(:query => Twitter.params.to_hash).to_return(:body => Twitter.json)
    assert_equal(35, ShareCounts.twitter(SOME_URL))
  end

  test ".twitter with raise_exceptions=true should raise exception" do
    stub_request(:get, Twitter.api).with(:query => Twitter.params.to_hash).to_raise(Exception)
    assert_raise(Exception) { ShareCounts.twitter(SOME_URL, true) }
  end
  
  test ".facebook should return the facebook score" do
    stub_request(:get, Facebook.api).with(:query => Facebook.params.to_hash).to_return(:body => Facebook.json)  
    assert_equal(23, ShareCounts.facebook(SOME_URL))
  end

  test ".facebook with raise_exceptions=true should raise exception" do
    stub_request(:get, Facebook.api).with(:query => Facebook.params.to_hash).to_raise(Exception)
    assert_raise(Exception) { ShareCounts.facebook(SOME_URL, true) }
  end
  
  test ".linkedin should return the linkedin score" do
    stub_request(:get, Linkedin.api).with(:query => Linkedin.params.to_hash).to_return(:body => Linkedin.json)
    assert_equal(23, ShareCounts.linkedin(SOME_URL))
  end

  test ".linkedin with raise_exceptions=true should raise exception" do
    stub_request(:get, Linkedin.api).with(:query => Linkedin.params.to_hash).to_raise(Exception)
    assert_raise(Exception) { ShareCounts.linkedin(SOME_URL, true) }
  end
  
  test ".googlebuzz should return the googlebuzz score" do
    stub_request(:get, GoogleBuzz.api).with(:query => GoogleBuzz.params.to_hash).to_return(:body => GoogleBuzz.json)
    assert_equal(1, ShareCounts.googlebuzz(SOME_URL))
  end

  test ".googlebuzz with raise_exceptions=true should raise exception" do
    stub_request(:get, GoogleBuzz.api).with(:query => GoogleBuzz.params.to_hash).to_raise(Exception)
    assert_raise(Exception) { ShareCounts.googlebuzz(SOME_URL, true) }
  end
  
  test ".stumbleupon should return the stumbleupon score" do
    stub_request(:get, StumbleUpon.api).with(:query => StumbleUpon.params.to_hash).to_return(:body => StumbleUpon.html)
    assert_equal(6, ShareCounts.stumbleupon(SOME_URL))
  end

  test ".stumbleupon with raise_exceptions=true should raise exception" do
    stub_request(:get, StumbleUpon.api).with(:query => StumbleUpon.params.to_hash).to_raise(Exception)
    assert_raise(Exception) { ShareCounts.stumbleupon(SOME_URL, true) }
  end
  
end