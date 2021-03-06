require 'rest-client'
require 'json'

module Xcode
  class Testflight
    attr_accessor :api_token, :team_token, :notify, :proxy, :notes, :lists
    
    def initialize(api_token, team_token)
      @api_token = api_token
      @team_token = team_token
      @notify = true
      @notes = nil
      @lists = []
      @proxy = ENV['http_proxy'] || ENV['HTTP_PROXY']
    end
    
    def upload(ipa_path, dsymzip_path=nil)
      puts "Uploading to Testflight..."
      
      # RestClient.proxy = @proxy || ENV['http_proxy'] || ENV['HTTP_PROXY']
      # RestClient.log = '/tmp/restclient.log'
      # 
      # response = RestClient.post('http://testflightapp.com/api/builds.json',
      #   :file => File.new(ipa_path),
      #   :dsym => File.new(dsymzip_path),
      #   :api_token => @api_token,
      #   :team_token => @team_token,
      #   :notes => @notes,
      #   :notify => @notify ? 'True' : 'False',
      #   :distribution_lists => @lists.join(',')
      # )
      # 
      # json = JSON.parse(response)
      # puts " + Done, got: #{json.inspect}"
      # json
      
      cmd = []
      cmd << "curl"
      unless @proxy.nil? or @proxy==''
        cmd << "--proxy"
        cmd << @proxy
      end
      cmd << "-X"
      cmd << "POST"
      cmd << "http://testflightapp.com/api/builds.json"
      cmd << "-F"
      cmd << "file=@\"#{ipa_path}\""
      unless dsymzip_path.nil?
        cmd << "-F"
        cmd << "dsym=@\"#{dsymzip_path}\""
      end
      cmd << "-F"
      cmd << "api_token='#{@api_token}'"
      cmd << "-F"
      cmd << "team_token='#{@team_token}'"
      unless @notes.nil?
        cmd << "-F"
        cmd << "notes=\"#{@notes}\""
      end
      cmd << "-F"
      cmd << "notify=#{@notify ? 'True' : 'False'}"
      unless @lists.count==0
        cmd << "-F"
        cmd << "distribution_lists='#{@lists.join(',')}'"
      end
      
      response = Xcode::Shell.execute(cmd)
      
      json = JSON.parse(response.join(''))
      puts " + Done, got: #{json.inspect}"
      
      yield(json) if block_given?
      
      json
    end
  end
end