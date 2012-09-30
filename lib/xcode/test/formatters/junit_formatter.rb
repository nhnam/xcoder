
require 'builder'
require 'socket'
require 'time'

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
            :timestamp  => suite.end_time.iso8601
            ) do |testsuite|
            
            testsuite.properties do |properties|
              suite.properties.each do |key, val|
              	properties.property(
              	  :name => key,
              	  :value => val
              	)
              end
            end
            
            suite.tests.each do |test|
              testsuite.testcase(
                :classname  => suite.name,
                :name       => test.name,
                :time       => test.time
                ) do |testcase|
                
                test.errors.each do |error|
                  testcase.failure error[:location], :message => error[:message], :type => 'Failure'
                end
              end
            end
            
            testsuite.tag! "system-out"
            testsuite.tag! "system-err"
          end
          
          suite_file_path = @dir
          
          path_suffix = suite.report.path_suffix
          suite_file_path = File.join suite_file_path, path_suffix unless path_suffix.nil?
          
          FileUtils.mkdir_p suite_file_path
          
          suite_file_path = File.join suite_file_path, "TEST-#{suite.name}.xml"
          
          File.open suite_file_path, 'w' do |file|
	          file.write xml.target!
	      end
        
        end # write
      
      end # JUnitFormatter
    
    end # Formatters
  
  end # Test

end # Xcode
