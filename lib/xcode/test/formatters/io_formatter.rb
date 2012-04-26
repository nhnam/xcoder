
module Xcode
  
  module Test
	
    module Formatters
	  
      class IoFormatter
        
        def initialize(output)
		  @output = output
          @errors = []
        end
		
        def before(report)
          puts "Begin tests"
        end
        
        def after(report)
          puts "\n\nThe following failures occured:" if @errors.count>0
          @errors.each do |e|
            puts "[#{e.suite.name} #{e.name}]"
            e.errors.each do |error|
              puts "  #{error[:message]}"
              puts "    at #{error[:location]}"
              if error[:data].count>0
                puts "\n   Test Output:"
                puts "   > #{error[:data].join("   > ")}\n\n"
              end
            end       
            
            # if there is left over data in the test report, show that
            if e.data.count>0
              puts "\n  There was this trailing output after the above failures"
              puts "   > #{e.data.join("   > ")}\n\n"
            end
          end
          
          puts "\n\nEnd tests (#{report.failed? ? 'FAILED' : 'PASSED'}).  Took #{report.duration}s"
        end
        
        def before_suite(suite)
          print "#{suite.name}: "
        end
        
        def after_suite(suite)
          puts " [#{suite.total_passed_tests}/#{suite.tests.count}]"
        end
        
        def before_test(test)
          # puts "[#{test.suite.name} #{test.name}] << BEGIN"
        end
        
        def after_test(test)
          if test.passed?
            print "." 
          elsif test.failed?
            print "F"
            @errors << test 
          end 
          # puts "[#{test.suite.name} #{test.name}] << END"
		end
		
		private
		
		def print(*args)
		  @output.print *args
		end
		
		def puts(*args)
		  @output.puts *args
		end
		
      end # IoFormatter
	  
    end # Formatters
	
  end # Test
  
end # Xcode
