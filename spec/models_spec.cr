require "./spec_helper"

private class Model < Moongoon::Collection
  collection "models"

  property name : String
  property age : Int32
  property humor : Int32?

  def self.insert_models(models)
    models.map { |model|
      from_json(model.to_json).insert
    }
  end
end

describe Moongoon::Collection do
  raw_models = [
    {name: "one", age: 10, humor: nil},
    {name: "two", age: 10, humor: 0},
    {name: "three", age: 20, humor: 15},
  ]

  before_each {
    Model.clear
    Moongoon::Config.reset
  }

  describe "Get" do
    it "#self.find" do
      models = Model.insert_models raw_models

      results = Model.find({age: 0})
      results.size.should eq 0

      results = Model.find({age: 10}, order_by: {"_id": 1})
      results.to_json.should eq [models[0], models[1]].to_json
    end

    it "#self.find!" do
      models = Model.insert_models raw_models

      expect_raises(Moongoon::Error::NotFound) {
        Model.find!({name: "invalid name"})
      }
      results = Model.find!({age: 10}, order_by: {"_id": 1})
      results.to_json.should eq [models[0], models[1]].to_json
    end

    it "#self.find_one" do
      models = Model.insert_models raw_models

      result = Model.find_one({age: 10}, order_by: {"_id": 1})
      result.to_json.should eq models[0].to_json
    end

    it "#self.find_one!" do
      models = Model.insert_models raw_models

      expect_raises(Moongoon::Error::NotFound) {
        Model.find_one!({name: "invalid name"})
      }

      result = Model.find_one!({age: 10}, order_by: {"_id": 1})
      result.to_json.should eq models[0].to_json
    end

    it "#self.find_by_id" do
      models = Model.insert_models raw_models

      result = Model.find_by_id(models[2].id!)
      result.to_json.should eq models[2].to_json
    end

    it "#self.find_by_id!" do
      models = Model.insert_models raw_models

      expect_raises(Moongoon::Error::NotFound) {
        Model.find_by_id!("507f1f77bcf86cd799439011")
      }

      result = Model.find_by_id!(models[2].id!)
      result.to_json.should eq models[2].to_json
    end

    it "#self.find_by_ids" do
      models = Model.insert_models raw_models

      results = Model.find_by_ids([models[1], models[2]].map(&.id!), order_by: {_id: 1})
      results.to_json.should eq [models[1], models[2]].to_json
    end

    it "#self.find_by_ids!" do
      models = Model.insert_models raw_models

      expect_raises(Moongoon::Error::NotFound) {
        Model.find_by_ids!(["507f1f77bcf86cd799439011"])
      }

      results = Model.find_by_ids!([models[1], models[2]].map(&.id!), order_by: {_id: 1})
      results.to_json.should eq [models[1], models[2]].to_json
    end

    it "#self.count" do
      Model.insert_models raw_models

      count = Model.count({age: 10})
      count.should eq 2
    end

    it "#self.exist!" do
      Model.insert_models raw_models

      expect_raises(Moongoon::Error::NotFound) {
        Model.exist!({age: 100})
      }

      Model.exist!({age: 10}).should be_true
    end

    it "#self.exist_by_id!" do
      models = Model.insert_models raw_models

      expect_raises(Moongoon::Error::NotFound) {
        Model.exist_by_id!("507f1f77bcf86cd799439011")
      }

      Model.exist_by_id!(models[0].id!).should be_true
    end
  end

  describe "Post" do
    it "#insert" do
      model = Model.from_json(raw_models[0].to_json).insert
      Model.find_by_id(model.id!).to_json.should eq model.to_json
    end

    it "#self.bulk_insert" do
      models = Model.bulk_insert raw_models.map { |m| Model.from_json(m.to_json) }
      Model.find(order_by: {_id: 1}).to_json.should eq models.to_json
    end
  end

  describe "Patch" do
    it "#update" do
      models = Model.insert_models raw_models
      model = models[2]
      model.age = 15
      model = model.update
      Model.find_by_id!(model.id!).age.should eq 15
    end

    it "#update (skip nils)" do
      models = Model.insert_models raw_models
      model = models[2]
      model.humor = nil
      model = model.update
      Model.find_by_id!(model.id!).humor.should eq 15
    end

    it "#update (specific fields)" do
      models = Model.insert_models raw_models
      model = models[2]

      model.age = 1
      model = model.update(fields: {:name})
      Model.find_by_id!(model.id!).age.should eq 20
      model = model.update(fields: {:age})
      Model.find_by_id!(model.id!).age.should eq 1

      Moongoon.configure do |config|
        config.unset_nils = true
      end

      model = models[1]
      model.humor = nil
      model = model.update(fields: {:name})
      Model.find_by_id!(model.id!).humor.should eq 0
      model = model.update(fields: {:humor})
      Model.find_by_id!(model.id!).humor.should be_nil
    end

    it "#update (unset nils)" do
      Moongoon.configure do |config|
        config.unset_nils = true
      end
      models = Model.insert_models raw_models
      model = models[2]
      model.humor = nil
      model = model.update
      Model.find_by_id!(model.id!).humor.should eq nil
    end

    it "#update_fields" do
      models = Model.insert_models raw_models
      model = models[2]

      model.humor = 1
      model = model.update_fields({age: 1})
      Model.find_by_id!(model.id!).age.should eq 1
      Model.find_by_id!(model.id!).humor.should eq 15

      Moongoon.configure do |config|
        config.unset_nils = true
      end

      model = models[1]
      model.age = 20
      model = model.update_fields({humor: nil})
      Model.find_by_id!(model.id!).humor.should be_nil
      Model.find_by_id!(model.id!).age.should eq 10
    end

    it "#self.update" do
      models = Model.insert_models raw_models
      model = models[1]
      Model.update({_id: model._id}, {"$set": {age: 15}})
      Model.find_by_id!(model.id!).age.should eq 15
    end

    it "#update_query" do
      models = Model.insert_models raw_models
      model = models[1]
      model.age = 15
      model.update_query({_id: model._id})
      Model.find_by_id!(model.id!).age.should eq 15
    end

    it "#update_query (skip nils)" do
      models = Model.insert_models raw_models
      model = models[1]
      model.humor = nil
      model.update_query({_id: model._id})
      Model.find_by_id!(model.id!).humor.should eq 0
    end

    it "#update_query (unset nils)" do
      Moongoon.configure do |config|
        config.unset_nils = true
      end
      models = Model.insert_models raw_models
      model = models[1]
      model.humor = nil
      model.update_query({_id: model._id})
      Model.find_by_id!(model.id!).humor.should eq nil
    end

    it "#self.update_by_id" do
      models = Model.insert_models raw_models
      model = models[0]
      Model.update_by_id(model.id!, {"$set": {age: 15}})
      Model.find_by_id!(model.id!).age.should eq 15
    end

    it "#self.update_by_ids" do
      models = Model.insert_models raw_models
      Model.update_by_ids(models.map(&.id!), {"$set": {age: 15}})
      Model.find.each(&.age.should eq 15)
    end

    it "#self.find_and_modify" do
      models = Model.insert_models raw_models
      model = Model.find_and_modify({_id: models[1]._id}, {"$set": {age: 15}}, new: true)
      model.not_nil!.age.should eq 15
    end

    it "#self.find_and_modify_by_id" do
      models = Model.insert_models raw_models
      model = Model.find_and_modify_by_id(models[1].id!, {"$set": {age: 15}}, new: true)
      model.not_nil!.age.should eq 15
    end
  end

  describe "Delete" do
    it "#remove" do
      models = Model.insert_models raw_models
      model = models[2]
      Model.count.should eq 3
      model.remove
      Model.count.should eq 2
      Model.find.map { |m| m.id.should_not eq model.id }
    end

    it "#self.remove" do
      models = Model.insert_models raw_models
      model = models[1]
      Model.count.should eq 3
      Model.remove({_id: model._id})
      Model.count.should eq 2
      Model.find.map { |m| m.id.should_not eq model.id }
    end

    it "#self.remove_by_id" do
      models = Model.insert_models raw_models
      model = models[1]
      Model.count.should eq 3
      Model.remove_by_id(model.id!)
      Model.count.should eq 2
      Model.find.map { |m| m.id.should_not eq model.id }
    end

    it "#self.remove_by_ids" do
      models = Model.insert_models raw_models
      models_subset = [models[2], models[1]]
      Model.count.should eq 3
      Model.remove_by_ids(models_subset.map(&.id!))
      Model.count.should eq 1
      Model.find[0].to_json.should eq models[0].to_json
    end

    it "#self.clear" do
      Model.insert_models raw_models
      Model.count.should eq 3
      Model.clear
      Model.count.should eq 0
    end
  end
end
