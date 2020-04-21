require "./spec_helper"

describe Moongoon::Collection do

  models = [
    { name: "one" },
    { name: "two" },
    { name: "three" }
]

  before_each {
    Model.clear
    models.each { |model|
      Model.from_json(model.to_json).insert
    }
  }

  describe "#self.find" do
    results = Model.find({ name: "name"})
    results.size.should eq 1
  end

  describe "#self.find!" do


  end

  describe "#self.find_one" do


  end

  describe "#self.find_one!" do


  end

  describe "#self.find_by_id" do


  end

  describe "#self.find_by_id!" do


  end

  describe "#self.find_by_ids" do


  end

  describe "#self.find_by_ids!" do


  end

  describe "#self.count" do


  end

  describe "#self.exist!" do


  end

  describe "#self.exist_by_id!" do


  end
end
