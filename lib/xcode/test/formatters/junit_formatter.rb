
require 'builder'
require 'socket'

module Xcode
  
  module Test
	
    module Formatters
	  
      class JunitFormatter
		
        def initialize(dir)
          @dir = File.expand_path(dir)
        end
        
        def after_suite(suite)
          write(suite)
        end
		
        def write(suite)
		  
          if suite.end_time.nil?
            raise "Report #{suite} #{suite.name} has a nil end time!?"
          end
		  
          xml = ::Builder::XmlMarkup.new( :indent => 2 )
          xml.instruct! :xml, :encoding => "UTF-8"
          xml.testsuite(
			:errors     => suite.total_errors,
            :failures   => suite.total_failed_tests,
            :hostname   => Socket.gethostname,
            :name       => suite.name,
            :tests      => suite.tests.count,
            :time       => (suite.end_time - suite.start_time),
            :timestamp  => suite.end_time
            ) do |p|
			
            suite.tests.each do |t|
              p.testcase(
				:classname  => suite.name,
                :name       => t.name,
                :time       => t.time
                ) do |testcase|
				
                t.errors.each do |error|
                  testcase.failure error[:location], :message => error[:message], :type => 'Failure'
                end
              end
            end
          end
		  
          suiteFilePath = @dir
		  
		  reportIdentifier = suite.report.identifier
		  if reportIdentifier.length > 0
			suiteFilePath = File.join suiteFilePath, reportIdentifier
		  end
		  
		  FileUtils.mkdir_p suiteFilePath
		  
		  suiteFilePath = File.join suiteFilePath, "TEST-#{suite.name}.xml"
          File.open(suiteFilePath, 'w') do |current_file|
            current_file.write xml.target!
          end
          
        end # write
        
      end # JUnitFormatter
      
    end # Formatters
	
  end # Test
  
end # Xcode
