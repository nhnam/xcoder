
require 'xcode/test/report/report'
require 'time'

module Xcode
  
  module Test
	
    module Parsers
	  
      class OCUnitParser
		
        attr_accessor :reports
        
        def initialize(&configureReport)
		  @configureReport = configureReport
          @reports = []
        end
		
        def <<(piped_row)
		  
          case piped_row.force_encoding("UTF-8")
			
			when /Run unit tests for architecture '(.*?)' \(GC (.*?)\)/
			  if @currentReport.nil?
				start_new_report
			  end
			  architecture = $1
			  garbageCollectionState = $2
			  @currentReport.identifier = "#{architecture}/GC_#{garbageCollectionState}"
			
            when /Test Suite '(\S+)'.*started at\s+(.*)/
              name = $1
              time = Time.parse($2)
			  if @currentReport.nil?
				start_new_report
			  end
              if name=~/\//
                @currentReport.start
              else
                @currentReport.add_suite name, time
              end
            
            when /Test Suite '(\S+)'.*finished at\s+(.*)./
              time = Time.parse($2)
              name = $1
              if name=~/\//
                @currentReport.finish
              else
                @currentReport.in_current_suite do |suite|
                  suite.finish(time)
                end
              end
			
            when /Test Case '-\[\S+\s+(\S+)\]' started./
              name = $1
              @currentReport.in_current_suite do |suite|
                suite.add_test_case name
              end
			
            when /Test Case '-\[\S+\s+(\S+)\]' passed \((.*) seconds\)/
              duration = $2.to_f
              @currentReport.in_current_test do |test|
                test.passed(duration)
              end
			
            when /(.*): error: -\[(\S+) (\S+)\] : (.*)/
              message = $4
              location = $1
              @currentReport.in_current_test do |test|
                test.add_error(message, location)
              end
            
            when /Test Case '-\[\S+ (\S+)\]' failed \((\S+) seconds\)/
              duration = $2.to_f
              @currentReport.in_current_test do |test|
                test.failed(duration)
              end
            
            # when /failed with exit code (\d+)/, 
            when /BUILD FAILED/
              @currentReport.finish
			  save_current_report
            
            when /Segmentation fault/
              @currentReport.abort
			  save_current_report
            
            when /Run test case (\w+)/
              # ignore
            when /Run test suite (\w+)/
              # ignore
            when /Executed (\d+) test, with (\d+) failures \((\d+) unexpected\) in (\S+) \((\S+)\) seconds/
              # ignore
            else
              return if @currentReport.nil?

			  @currentReport.in_current_test do |test|
				test << piped_row
			  end
          end # case
		  
        end # <<
		
		def flush
		  save_current_report
		end
		
		private
		
		def start_new_report(identifier="")
		  newReport = Xcode::Test::Report.new do |report|
			report.identifier = identifier
		  end
		  unless @configureReport.nil?
			@configureReport.call newReport
		  end
		  @currentReport = newReport
		end
		
		def save_current_report
		  report = @currentReport
		  @currentReport = nil
		  return if report.nil?
		  
		  report.finish
		  @reports << report
		end
		
      end # OCUnitParser
	  
    end # Parsers
	
  end # Test
  
end # Xcode
