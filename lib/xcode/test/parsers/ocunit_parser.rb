
require 'xcode/test/report/report'
require 'time'

module Xcode
  
  module Test
    
    module Parsers
    
      class OCUnitParser
      
        attr_accessor :reports
      
        def initialize(&configure_report)
          @configure_report = configure_report
          @reports = []
          @suite_identifier = 0
        end
        
        def <<(piped_row)
        
          case piped_row.force_encoding("UTF-8")
          
            when /Run unit tests for architecture '(.*?)' \(GC (.*?)\)/
              architecture = $1
              garbage_collection_state = $2
              
              path_suffix = File.join(architecture, "GC_#{garbage_collection_state}")
              metadata = { "Architecture" => architecture, "Garbage Collection" => garbage_collection_state }
              
              start_new_report path_suffix, metadata
            
            when /Test Suite '(\S+)'.*started at\s+(.*)/
              name = $1
              time = Time.parse($2)
              if name=~/\//
                current_report.start
              else
                current_report.add_suite name, next_suite_identifier, current_report.metadata, time
              end
            
            when /Test Suite '(\S+)'.*finished at\s+(.*)./
              name = $1
              time = Time.parse($2)
              if name=~/\//
                current_report.finish
              else
                current_report.in_current_suite do |suite|
                  suite.finish(time)
                end
              end
            
            when /Test Case '-\[\S+\s+(\S+)\]' started./
              name = $1
              current_report.in_current_suite do |suite|
                suite.add_test_case name
              end
            
            when /Test Case '-\[\S+\s+(\S+)\]' passed \((.*) seconds\)/
              duration = $2.to_f
              current_report.in_current_test do |test|
                test.passed(duration)
              end
            
            when /(.*): error: -\[(\S+) (\S+)\] : (.*)/
              message = $4
              location = $1
              current_report.in_current_test do |test|
                test.add_error(message, location)
              end
            
            when /Test Case '-\[\S+ (\S+)\]' failed \((\S+) seconds\)/
              duration = $2.to_f
              current_report.in_current_test do |test|
                test.failed(duration)
              end
            
            # when /failed with exit code (\d+)/,
              
            
            when /BUILD FAILED/
              current_report.finish
              save_current_report
            
            when /Segmentation fault/
              current_report.abort
              save_current_report
            
            when /Run test case (\w+)/
              # ignore
            
            when /Run test suite (\w+)/
              # ignore
            
            when /Executed (\d+) test, with (\d+) failures \((\d+) unexpected\) in (\S+) \((\S+)\) seconds/
              # ignore
            
            else
              # ignore if no current report?
              
              return if @current_report.nil?
              
              @current_report.in_current_test do |test|
                test << piped_row
              end
            
          end # case
          
        end # <<
        
        def flush
          save_current_report
        end
        
        private
        
        def current_report
          if @current_report.nil?
            start_new_report
          end
          @current_report
        end
        
        def start_new_report(path_suffix=nil, metadata=nil)
          save_current_report
          
          new_report = Xcode::Test::Report.new(path_suffix, metadata)
          @configure_report.call new_report unless @configure_report.nil?
          @current_report = new_report
        end
        
        def save_current_report
          report = @current_report
          @current_report = nil
          return if report.nil?
          
          report.finish
          @reports << report
        end

        def next_suite_identifier
          identifier = @suite_identifier
          @suite_identifier += 1
          identifier
        end
      
      end # OCUnitParser
    
    end # Parsers
  
  end # Test

end # Xcode
