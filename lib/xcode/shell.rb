
module Xcode
  
  module Shell
    
    def self.execute(cmd, show_output=true, raise_on_error=true)
      out = []
      
      puts "EXECUTE: #{cmd}\n"
      
      IO.popen cmd do |f| 
        f.each do |line|
          puts line if show_output
          yield line if block_given?
          out << line
        end
      end
      
      raise "Error (#{$?.exitstatus}) executing '#{cmd}'\n\n  #{out.join("  ")}" if raise_on_error and $?.exitstatus > 0
      
      out
    end
  
  end

end
