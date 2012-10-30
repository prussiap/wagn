require File.expand_path('../../spec_helper', File.dirname(__FILE__))

describe Wagn::Set::Views do
  context "load_all" do
    it "loads files in the modules directory" do
      pending 'needs further isolation; generates broader dependency issues'
      begin
        file = "#{Rails.root}/local/dummy_spec_module.rb"
        File.open(file, "w") do |f|
          f.write <<-EOF
            module JBob 
              def self.foo(); "bar"; end
            end
          EOF
        end
        Wagn::Set::Views.dirs << file
        Wagn::Set::Views.load_all
        JBob.foo.should == "bar"
      ensure
        `rm #{file}`  #PLATFORM SPECIFIC
      end
    end
  end
end                                            
