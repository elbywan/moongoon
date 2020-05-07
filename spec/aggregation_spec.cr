require "./spec_helper.cr"

private class AggregatedModel < Moongoon::Collection
  collection "aggregated_models"

  property array : Array(Int32)?
  property size : Int32?

  aggregation_pipeline(
    {
      "$addFields": {
        size: {
          "$size": "$array",
        },
      },
    },
    {
      "$project": {
        array: 0,
      },
    }
  )

  def self.insert_models(models)
    models.map_with_index { |model|
      from_json(model.to_json).insert
    }
  end

  def format
    self.dup.tap { |copy|
      copy.size = self.array.try(&.size)
      copy.array = nil
    }
  end
end

describe Moongoon::Collection do
  raw_models = [
    {array: [] of Int32},
    {array: [1, 2, 3]},
    {array: [1, 2, 3]},
    {array: [1]},
  ]

  before_each {
    AggregatedModel.clear
  }

  describe "Get" do
    it "#self.find" do
      models = AggregatedModel.insert_models raw_models

      results = AggregatedModel.find({array: [] of Int32})
      results.size.should eq 1

      results = AggregatedModel.find({array: [1, 2, 3]}, order_by: {"_id": 1})
      results.size.should eq 2
      results.to_json.should eq [models[1], models[2]].map(&.format).to_json
    end

    it "#self.find!" do
      models = AggregatedModel.insert_models raw_models

      expect_raises(Moongoon::Error::NotFound) {
        AggregatedModel.find!({name: "invalid name"})
      }
      results = AggregatedModel.find!({array: [1, 2, 3]}, order_by: {"_id": 1})
      results.to_json.should eq [models[1], models[2]].map(&.format).to_json
    end

    it "#self.find_one" do
      models = AggregatedModel.insert_models raw_models

      result = AggregatedModel.find_one({array: [1, 2, 3]}, order_by: {"_id": 1})
      result.to_json.should eq models[1].format.to_json
    end

    it "#self.find_one!" do
      models = AggregatedModel.insert_models raw_models

      expect_raises(Moongoon::Error::NotFound) {
        AggregatedModel.find_one!({name: "invalid name"})
      }

      result = AggregatedModel.find_one!({array: [1, 2, 3]}, order_by: {"_id": -1})
      result.to_json.should eq models[2].format.to_json
    end

    it "#self.find_by_id" do
      models = AggregatedModel.insert_models raw_models

      result = AggregatedModel.find_by_id(models[2].id!)
      result.to_json.should eq models[2].format.to_json
    end

    it "#self.find_by_id!" do
      models = AggregatedModel.insert_models raw_models

      expect_raises(Moongoon::Error::NotFound) {
        AggregatedModel.find_by_id!("invalid id")
      }

      result = AggregatedModel.find_by_id!(models[2].id!)
      result.to_json.should eq models[2].format.to_json
    end

    it "#self.find_by_ids" do
      models = AggregatedModel.insert_models raw_models

      results = AggregatedModel.find_by_ids([models[1], models[2]].map(&.id!), order_by: {_id: 1})
      results.to_json.should eq [models[1], models[2]].map(&.format).to_json
    end

    it "#self.find_by_ids!" do
      models = AggregatedModel.insert_models raw_models

      expect_raises(Moongoon::Error::NotFound) {
        AggregatedModel.find_by_ids!(["invalid id"])
      }

      results = AggregatedModel.find_by_ids!([models[1], models[2]].map(&.id!), order_by: {_id: 1})
      results.to_json.should eq [models[1], models[2]].map(&.format).to_json
    end

    it "#self.count" do
      AggregatedModel.insert_models raw_models

      count = AggregatedModel.count({array: [1, 2, 3]})
      count.should eq 2
    end

    it "#self.exist!" do
      AggregatedModel.insert_models raw_models

      expect_raises(Moongoon::Error::NotFound) {
        AggregatedModel.exist!({array: [0]})
      }

      AggregatedModel.exist!({array: [1]}).should be_true
    end

    it "#self.exist_by_id!" do
      models = AggregatedModel.insert_models raw_models

      expect_raises(Moongoon::Error::NotFound) {
        AggregatedModel.exist_by_id!("invalid id")
      }

      AggregatedModel.exist_by_id!(models[0].id!).should be_true
    end
  end
end
