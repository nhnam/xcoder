
require 'nokogiri'

module Xcode
  
  # Schemes are an XML file that describe build, test, launch and profile actions
  # For the purposes of Xcoder, we want to be able to build and test
  # The scheme's build action only describes a target, so we need to look at launch for the config
  class Scheme
	
    attr_reader :project, :path, :name
	attr_reader :buildForRun, :run
	attr_reader :buildForTest, :test
	
    def initialize(project, path)
      @project = project
      @path = File.expand_path(path)
      @name = File.basename(path).gsub(/\.xcscheme$/,'')
      
      doc = Nokogiri::XML(open(@path))
	  
	  parse_action doc, 'run', "LaunchAction"
	  parse_action doc, 'test'
    end
	
	def self.action(action_name)
	  
	  action_name_string = action_name.to_s
	  
	  define_method "perform#{action_name_string.capitalize}" do
		perform_action action_name_string
	  end
	  
	end
	
	def performRun
	  
	end
	
	action :test
	
	def performProfile
	  
	end
	
    def performAnalyse
      
    end
    
    def performArchive
      
    end
    
    private
	
	def parse_buildable_reference_to_configuration(buildableReference, configurationName)
	  identifier = buildableReference.xpath('@BlueprintIdentifier').text
	  name = buildableReference.xpath('@BlueprintName').text
	  
	  containerIdentifier = buildableReference.xpath('@ReferencedContainer').text
	  
	  containerComponents = containerIdentifier.split(':')
	  return {} unless containerComponents[0] == 'container'
	  containerName = containerComponents[1]
	  
	  searchProject = nil
	  if containerName == File.basename(@project.path)
		# Identifier should be inside @project.registry
		
		searchProject = @project
	  else
		# We need to initialise the new project and find it's target
		
		enclosingDirectory = File.dirname(@project.path)
		
		foreignProjectPath = File.join enclosingDirectory, containerName
		foreignProject = Xcode::Project.new foreignProjectPath, @project.sdk
		
		searchProject = foreignProject
	  end
	  return {} if searchProject.nil?
	  
	  target = searchProject.targets.select {|t| t.identifier == identifier}.first
	  configuration = target.config configurationName
	  
	  { identifier => configuration }
	end
	
	def parse_buildable_entries(document, buildFor, configurationName)
	  blueprintIdentifierToConfiguration = {}
	  
	  buildableReferences = document.xpath("/Scheme/BuildAction/BuildActionEntries/BuildActionEntry[@#{buildFor} = 'YES']/BuildableReference")
	  
	  buildableReferences.each do |currentBuildableReference|
		blueprintIdentifierToConfiguration.merge! parse_buildable_reference_to_configuration(currentBuildableReference, configurationName)
	  end
	  
	  blueprintIdentifierToConfiguration
	end
    
	def parse_action_configurations_and_build_configurations(document, actionName)
      
      action = document.xpath("/Scheme/#{actionName}").first
      actionBuildConfigurationName = action.xpath('@buildConfiguration').text
	  
	  blueprintIdentifierToBuildConfiguration = {}
	  blueprintIdentifierToActionConfiguration = {}
	  
      if actionName == 'TestAction'
		blueprintIdentifierToBuildConfiguration.merge! parse_buildable_entries(document, "buildForTesting", actionBuildConfigurationName)
        
        testablesEnabled = action.xpath("Testables/TestableReference[@skipped = 'NO']")
        testablesEnabled.each do |testableEnabled|
		  buildableReference = testableEnabled.xpath('BuildableReference')
		  blueprintIdentifierToActionConfiguration.merge! parse_buildable_reference_to_configuration(buildableReference, actionBuildConfigurationName)
        end
	  elsif actionName == 'LaunchAction'
		blueprintIdentifierToBuildConfiguration.merge! parse_buildable_entries(document, "buildForRunning", actionBuildConfigurationName)
		
		buildableReference = action.xpath('BuildableProductRunnable/BuildableReference')
		blueprintIdentifierToActionConfiguration.merge! parse_buildable_reference_to_configuration(buildableReference, actionBuildConfigurationName)
      end
      
	  return blueprintIdentifierToBuildConfiguration, blueprintIdentifierToActionConfiguration
	  
    end
	
	def parse_action(document, modelName, actionName = nil)
	  if actionName.nil?
		actionName = "#{modelName.capitalize}Action"
	  end
	  
	  blueprintIdentifierToBuildConfiguration, blueprintIdentifierToActionConfiguration = parse_action_configurations_and_build_configurations(document, actionName)
	  
	  instance_variable_set "@buildFor#{modelName.capitalize}".to_sym, blueprintIdentifierToBuildConfiguration
	  instance_variable_set "@#{modelName}".to_sym, blueprintIdentifierToActionConfiguration
	end
	
	def perform_action(action)
	  send(action).each do |configuration|
		build_options.each do |key, val|
		  configuration.set key, val
		end
		
		builder = Xcode::Builder.new configuration
        builder.send action
	  end
	end
	
	def build_options
	  options = {}
	  options["sdk"] = "iphonesimulator"
	  options["built_products_dir"] = File.join File.dirname(configuration.target.project.path), "build"
	  options
	end
    
  end
  
end
