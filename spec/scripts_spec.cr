require "./spec_helper"

describe Moongoon::Database::Scripts do
  it "should process scripts in order" do
    collection = Moongoon.database["scripts_collection"]
    collection.count_documents.should eq 1
    collection.find_one.not_nil!.["value"].should eq 3
  end

  it "should mark as retryable" do
    collection = Moongoon.database["scripts"]
    scripts = collection.find.to_a
    scripts.each { |script|
      case script["name"]
      when "Moongoon::Database::Scripts::One"
        script["status"].should eq "done"
        script["retry"].should eq false
        script["error"]?.should be_nil
      when "Moongoon::Database::Scripts::Two"
        script["status"].should eq "error"
        script["retry"].should eq true
        script["error"].should eq "Error raised"
      when "Moongoon::Database::Scripts::Three"
        script["status"].should eq "done"
        script["retry"].should eq true
        script["error"]?.should be_nil
      else
        raise "Invalid script name."
      end
    }
  end
end
