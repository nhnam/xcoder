module Xcode
  class Keychain
    attr_accessor :name, :path
    
    TEMP_PASSWORD = "build_keychain_password"
    
    #
    # Open the keychain with the specified name.  It is assumed that keychains reside in the 
    # ~/Library/Keychains directory
    # 
    # @param [String] the name of the keychain
    #
    def initialize(path)
      @path = File.expand_path path
      @name = File.basename path
      
      yield(self) if block_given?
    end
    
    #
    # Import the .p12 certificate file into the keychain using the provided password
    # 
    # @param [String] the path to the .p12 certificate file
    # @param [String] the password to open the certificate file
    #
    def import(cert, password)
      cmd = []
      cmd << "security"
      cmd << "import '#{cert}'"
      cmd << "-k \"#{@path}\""
      cmd << "-P #{password}"
      cmd << "-T /usr/bin/codesign"
      Xcode::Shell.execute(cmd)
    end
    
    #
    # Returns a list of identities in the keychain. 
    # 
    # @return [Array<String>] a list of identity names
    #
    def identities
      names = []
      cmd = []
      cmd << "security"
      cmd << "find-certificate"
      cmd << "-a"
      cmd << "\"#{@path}\""
      data = Xcode::Shell.execute(cmd, false).join("")
      data.scan /\s+"labl"<blob>="([^"]+)"/ do |m|
        names << m[0]
      end
      names
    end
    
    #
    # Unlock the keychain using the provided password
    # 
    # @param [String] the password to open the keychain
    #
    def unlock(password)
      cmd = []
      cmd << "security"
      cmd << "unlock-keychain"
      cmd << "-p #{password}"
      cmd << "\"#{@path}\""
      Xcode::Shell.execute(cmd)
    end
    
    #
    # Create a new keychain with the given name and password
    # 
    # @param [String] the name for the new keychain
    # @param [String] the password for the new keychain
    # @return [Xcode::Keychain] an object representing the new keychain
    #
    def self.create(path, password)
      cmd = []
      cmd << "security"
      cmd << "create-keychain"
      cmd << "-p #{password}"
      cmd << "\"#{path}\""
      Xcode::Shell.execute(cmd)
      
      kc = Xcode::Keychain.new(path)
      yield(kc) if block_given?
      kc
    end
    
    #
    # Remove the keychain from the filesystem
    #
    # FIXME: dangerous
    #
    def delete
      cmd = []
      cmd << "security"
      cmd << "delete-keychain \"#{@path}\""
      Xcode::Shell.execute(cmd)
    end
    
    #
    # Creates a keychain with the given name that lasts for the duration of the provided block.  
    # The keychain is deleted even if the block throws an exception.
    #
    # If no block is provided, the temporary keychain is returned and it is deleted on system exit
    #
    def self.temp
      kc = Xcode::Keychain.create("/tmp/xcoder#{Time.now.to_i}", TEMP_PASSWORD)
      kc.unlock(TEMP_PASSWORD)
      
      if !block_given?
        at_exit do
          kc.delete
        end
        kc
      else
        begin
          yield(kc)
        ensure
          kc.delete
        end
      end
    end
    
    #
    # Opens the default login.keychain for current user
    # 
    # @return [Xcode::Keychain] the current user's login keychain
    #
    def self.login
      kc = Xcode::Keychain.new("~/Library/Keychains/login.keychain")
      yield(kc) if block_given?
      kc
    end
  end
end