
module Xcode
  
  module Shell
    
    def self.execute(cmd, show_output=true)
      out = []
	  
      puts "EXECUTE: #{cmd}"
	  
      IO.popen cmd do |f| 
        f.each do |line|
          puts line if show_output
          yield line if block_given?
          out << line
        end
      end
	  
	  raise "Error (#{$?.exitstatus}) executing '#{cmd}'\n\n  #{out.join("  ")}" if $?.exitstatus > 0
	  
      out
	  
    end
    
  end
  
end
