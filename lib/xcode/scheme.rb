
require 'nokogiri'

module Xcode
  
  # Schemes are an XML file that describe build, test, launch and profile actions
  # For the purposes of Xcoder, we want to be able to build and test
  # The scheme's build action only describes a target, so we need to look at launch for the config
  class Scheme
	
    attr_reader :project, :path, :name, :launch, :test
	
    def initialize(project, path)
      @project = project
      @path = File.expand_path(path)
      @name = File.basename(path).gsub(/\.xcscheme$/,'')
      
      doc = Nokogiri::XML(open(@path))
      @launch = parse_action(doc, 'launch')
      @test = parse_action(doc, 'test')
    end
    
    def builder
      Xcode::Builder.new(self)
    end
    
    private
    
    def parse_action(doc, action_name)
      
      action = doc.xpath("/Scheme/#{action_name.capitalize}Action").first
      actionBuildConfiguration = action.xpath('@buildConfiguration').text
      
      if action_name == 'launch' then
        target_name = action.xpath('BuildableProductRunnable/BuildableReference/@BlueprintName').text
        target = @project.target(target_name)
        configuration = target.config(actionBuildConfiguration)
        return configuration
      end
      
      if action_name == 'test' then
        testTargets = []
        
        testablesEnabled = action.xpath('Testables/TestableReference[@skipped = \'NO\']')
        testablesEnabled.each do |testableEnabled|
          containerIdentifier = testableEnabled.xpath('BuildableReference/@ReferencedContainer').text
          
          identifier = testableEnabled.xpath('BuildableReference/@BlueprintIdentifier').text
          name = testableEnabled.xpath('BuildableReference/@BlueprintName').text
          
          containerComponents = containerIdentifier.split(':')
          next unless containerComponents[0] == "container"
          containerName = containerComponents[1]
          
          searchProject = nil
          if containerName == File.basename(@project.path) then
            # Identifier should be inside @project.registry
            
            searchProject = @project
          else
            # We need to initialise the new project and find it's target
            
            enclosingDirectory = File.dirname(@project.path)
            
            foreignProjectPath = File.join enclosingDirectory, containerName
            foreignProject = Xcode::Project.new foreignProjectPath, @project.sdk
            
            searchProject = foreignProject
          end
          next if searchProject.nil?
          
          target = searchProject.targets.select {|t| t.identifier == identifier}.first
          testTargets << target.config(actionBuildConfiguration)
        end
        
        return testTargets.size > 0 ? testTargets : nil
      end
      
    end
    
  end
  
end
