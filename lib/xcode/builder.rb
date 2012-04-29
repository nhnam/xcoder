
require 'xcode/shell'
require 'xcode/provisioning_profile'
require 'xcode/test/parsers/ocunit_parser.rb'
require 'xcode/testflight'

module Xcode

  #
  # This class tries to pull various bits of Xcoder together to provide a higher-level API for common 
  # project build tasks.
  #
  class Builder
    
    attr_accessor :profile, :identity, :build_path, :keychain, :sdk, :objroot, :symroot
    
    def initialize(config)
      @config = config
      @target = config.target
      
      @sdk = config.get("sdkroot") || @target.project.sdk
      
      build_path = config.built_products_dir
      
      @build_path = build_path
      @objroot = build_path
      @symroot = build_path
    end
    
    
    def build
      cmd = build_command
      
      with_keychain do
        begin
          Xcode::Shell.execute(cmd)
        rescue
          puts "Exception:"
          puts $!, *$@
        end
      end
      
      self
    end
    
    def run
      build
    end
    
    # 
    # Invoke the configuration's test target and parse the resulting output
    #
    # If a block is provided, the report is yielded for configuration before the test is run
    #
    def test
      cmd = build_command
      cmd << "TEST_AFTER_BUILD=YES"
      #cmd << "TEST_HOST=''" if @sdk == 'iphonesimulator'
      cmd << { :err => [ :child, :out ] }
      
      parser = Xcode::Test::Parsers::OCUnitParser.new do |report|
        report.add_formatter :junit, 'test-reports'
      end
      
      begin
        Xcode::Shell.execute(cmd, false, false) do |line|
          $stderr.puts line
          parser << line
        end
      rescue
        puts "Exception:"
        puts $!, *$@
      ensure
        parser.flush
      end
      
      reports = parser.reports
      
      reports
    end
    
    def testflight(api_token, team_token)
      raise "Can't find #{ipa_path}, do you need to call builder.package?" unless File.exists? ipa_path
      raise "Can't find #{dsym_zip_path}, do you need to call builder.package?" unless File.exists? dsym_zip_path
      
      testflight = Xcode::Testflight.new(api_token, team_token)
      yield(testflight) if block_given?
      testflight.upload(ipa_path, dsym_zip_path)
    end
    
    def clean
      
      cmd = []
      
      cmd << "xcodebuild"
      
      unless @sdk.nil?
        cmd << "-sdk"
        cmd << @sdk
      end
      
      cmd << "-project"
      cmd << @target.project.path
      
      unless @scheme.nil?
        cmd << "-scheme"
        cmd << @scheme.name
      else
        cmd << "-target"
        cmd << @target.name
        cmd << "-configuration"
        cmd << @config.name
      end
      
      add_sdk_specific_options cmd
      
      cmd << "OBJROOT=#{@objroot}"
      cmd << "SYMROOT=#{@symroot}"
      
      cmd << "clean"
      
      Xcode::Shell.execute(cmd)
      
      @built = false
      @packaged = false
      # FIXME: Totally not safe
      # cmd = []
      # cmd << "rm -Rf #{build_path}"
      # Xcode::Shell.execute(cmd)
      self
    end
    
    def sign
      cmd = []
      cmd << "codesign"
      cmd << "--force"
      cmd << "--sign"
      cmd << @identity
      cmd << "--resource-rules=#{product_path}/ResourceRules.plist"
      cmd << "--entitlements"
      cmd << entitlements_path
      cmd << ipa_path
      Xcode::Shell.execute(cmd)
 
# CodeSign build/AdHoc-iphoneos/Dial.app
#     cd "/Users/ray/Projects/Clients/CBAA/Community Radio"
#     setenv CODESIGN_ALLOCATE /Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/codesign_allocate
#     setenv PATH "/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin:/Developer/usr/bin:/Users/ray/.rvm/gems/ruby-1.9.2-p290@cbaa/bin:/Users/ray/.rvm/gems/ruby-1.9.2-p290@global/bin:/Users/ray/.rvm/rubies/ruby-1.9.2-p290/bin:/Users/ray/.rvm/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin:/usr/local/git/bin"
#     /usr/bin/codesign --force --sign "iPhone Distribution: Community Broadcasting Association of Australia" "--resource-rules=/Users/ray/Projects/Clients/CBAA/Community Radio/build/AdHoc-iphoneos/Dial.app/ResourceRules.plist" --keychain "\"/Users/ray/Projects/Clients/CBAA/Community\\" "Radio/Provisioning/CBAA.keychain\"" --entitlements "/Users/ray/Projects/Clients/CBAA/Community Radio/build/CommunityRadio.build/AdHoc-iphoneos/CommunityRadio.build/Dial.xcent" "/Users/ray/Projects/Clients/CBAA/Community Radio/build/AdHoc-iphoneos/Dial.app"
# iPhone Distribution: Community Broadcasting Association of Australia: no identity found
# Command /usr/bin/codesign failed with exit code 1
      
      self
    end
    
    def package
      raise "Can't find #{product_path}, do you need to call builder.build?" unless File.exists? product_path
      
      #package IPA
      cmd = []      
      cmd << "xcrun"
      unless @sdk.nil?
        cmd << "-sdk"
        cmd << @sdk
      end
      cmd << "PackageApplication"
      cmd << "-v"
      cmd << product_path
      cmd << "-o"
      cmd << ipa_path
      
      # cmd << "OTHER_CODE_SIGN_FLAGS=\"--keychain #{@keychain.path}\"" unless @keychain.nil?
      # 
      # unless @identity.nil?
      #   cmd << "--sign \"#{@identity}\""
      # end
      
      unless @profile.nil?
        cmd << "--embed"
        cmd << @profile
      end
      
      with_keychain do
        Xcode::Shell.execute(cmd)
      end
      
      # package dSYM
      cmd = []
      cmd << "zip"
      cmd << "-r"
      cmd << "-T"
      cmd << "-y"
      cmd << "#{dsym_zip_path}"
      cmd << "#{dsym_path}"
      Xcode::Shell.execute(cmd)

      self
    end
    
    def configuration_build_path
      "#{build_path}/#{@config.name}-#{@sdk}"
    end
    
    def entitlements_path
      "#{build_path}/#{@target.name}.build/#{name}-#{@target.project.sdk}/#{@target.name}.build/#{@config.product_name}.xcent"
    end
    
    def product_path
      "#{configuration_build_path}/#{@config.product_name}.#{@config.wrapper_extension}"
    end
    
    def product_version_basename
      version = @config.info_plist.version
      version = "SNAPSHOT" if version.nil? or version==""
      "#{configuration_build_path}/#{@config.product_name}-#{@config.name}-#{version}"
    end
    
    def ipa_path
      "#{product_version_basename}.ipa"
    end
    
    def dsym_path
      "#{product_path}.dSYM"
    end
    
    def dsym_zip_path
      "#{product_version_basename}.dSYM.zip"
    end
    
    private
    
    def with_keychain(&block)
      if @keychain.nil?
        yield
      else
        Xcode::Keychains.with_keychain_in_search_path @keychain, &block
      end
    end
    
    def install_profile
      return nil if @profile.nil?
      # TODO: remove other profiles for the same app?
      p = ProvisioningProfile.new(@profile)
      
      ProvisioningProfile.installed_profiles.each do |installed|
        if installed.identifiers==p.identifiers and installed.uuid==p.uuid
          installed.uninstall
        end
      end
      
      p.install
      p
    end
    
    def build_command
      profile = install_profile
      
      cmd = []
      
      cmd << "xcodebuild"
      
      unless @sdk.nil?
        cmd << "-sdk"
        cmd << @sdk
      end
      
      cmd << "-project"
      cmd << @target.project.path
      
      unless @scheme.nil?
        cmd << "-scheme"
        cmd << @scheme.name
      else
        cmd << "-target"
        cmd << @target.name
        cmd << "-configuration"
        cmd << @config.name
      end
      
      add_sdk_specific_options cmd
      
      cmd << "OTHER_CODE_SIGN_FLAGS='--keychain #{@keychain.path}'" unless @keychain.nil?
      cmd << "CODE_SIGN_IDENTITY=#{@identity}" unless @identity.nil?
      cmd << "PROVISIONING_PROFILE=#{profile.uuid}" unless profile.nil?
      
      cmd << "OBJROOT=#{@objroot}"
      cmd << "SYMROOT=#{@symroot}"
      
      cmd
    end
    
    def add_sdk_specific_options(cmd)
      if @sdk == "iphonesimulator"
        cmd << "ARCHS=i386"
        cmd << "ONLY_ACTIVE_ARCH=NO"
      end
    end
  
  end

end
