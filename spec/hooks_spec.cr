require "./spec_helper"

last_query : BSON? = nil
last_update : BSON? = nil

private abstract class HooksModel < Moongoon::Collection
  collection "hooks_models"

  property index : Int32 = 0

  def self.increment(model : self)
    model.index += 1
    model
  end
end

private class HooksBefore < HooksModel
  before_insert { |model|
    ->self.increment(self).call(model)
  }
  before_update { |model|
    ->self.increment(self).call(model)
  }
  before_remove { |model|
    ->self.increment(self).call(model)
  }
  before_update_static { |query, update|
    self.update({index: 0}, {"$inc": {index: 1}}, no_hooks: true)
    last_query = query
    last_update = update
  }
  before_remove_static { |query|
    self.update(query, {"$inc": {index: 1}}, no_hooks: true)
    last_query = query
  }
end

private class HooksAfter < HooksModel
  after_insert { |model|
    ->self.increment(self).call(model)
  }
  after_update { |model|
    ->self.increment(self).call(model)
  }
  after_remove { |model|
    ->self.increment(self).call(model)
  }
  after_update_static { |query, update|
    self.update({index: 1}, {"$inc": {index: 1}}, no_hooks: true)
    last_query = query
    last_update = update
  }
  after_remove_static { |query|
    self.update({index: 0}, {"$inc": {index: 1}}, no_hooks: true)
    last_query = query
  }
end

describe Moongoon::Collection do
  before_each {
    HooksBefore.clear
    HooksAfter.clear
    last_query = nil
    last_update = nil
  }

  describe "hooks" do
    describe "instance" do
      it "before_insert" do
        model = HooksBefore.new
        model.insert
        model.index.should eq 1
        HooksBefore.find_by_id!(model.id!).index.should eq 1
      end
      it "after_insert" do
        model = HooksAfter.new
        model.insert
        model.index.should eq 1
        HooksAfter.find_by_id!(model.id!).index.should eq 0
      end
      it "before_update" do
        model = HooksBefore.new(index: 0)
        model.insert # +1
        model.update # +1
        model.index.should eq 2
        HooksBefore.find_by_id!(model.id!).index.should eq 2
      end
      it "after_update" do
        model = HooksAfter.new(index: 0)
        model.insert
        model.update
        model.index.should eq 2
        HooksAfter.find_by_id!(model.id!).index.should eq 1
      end
      it "before_remove" do
        model = HooksBefore.new(index: 0)
        model.insert             # +1
        model.remove({index: 0}) # +1
        model.index.should eq 2
        HooksBefore.find_by_id!(model.id!).index.should eq 1
      end
      it "after_remove" do
        model = HooksBefore.new(index: 0)
        model.insert
        model.remove({index: 0})
        model.index.should eq 2
        HooksBefore.find_by_id!(model.id!).index.should eq 1
      end
    end
    describe "static" do
      it "before_update_static" do
        model = HooksBefore.new(index: 0)
        model.insert(no_hooks: true)
        query, update = {index: 1}, {"$inc": {index: 1}}
        HooksBefore.update(query, update)
        last_query.should eq query.to_bson
        last_update.should eq update.to_bson
        HooksBefore.find_by_id!(model.id!).index.should eq 2
      end
      it "before_update_static (find_and_modify)" do
        model = HooksBefore.new(index: 0)
        model.insert(no_hooks: true)
        query, update = {index: 1}, {"$inc": {index: 1}}
        HooksBefore.find_and_modify(query, update)
        last_query.should eq query.to_bson
        last_update.should eq update.to_bson
        HooksBefore.find_by_id!(model.id!).index.should eq 2
      end
      it "after_update_static" do
        model = HooksAfter.new(index: 0)
        model.insert(no_hooks: true)
        query, update = {index: 0}, {"$inc": {index: 1}}
        HooksAfter.update(query, update)
        last_query.should eq query.to_bson
        last_update.should eq update.to_bson
        HooksAfter.find_by_id!(model.id!).index.should eq 2
      end
      it "after_update_static (find_and_modify)" do
        model = HooksAfter.new(index: 0)
        model.insert(no_hooks: true)
        query, update = {index: 0}, {"$inc": {index: 1}}
        HooksAfter.find_and_modify(query, update)
        last_query.should eq query.to_bson
        last_update.should eq update.to_bson
        HooksAfter.find_by_id!(model.id!).index.should eq 2
      end
      it "before_remove_static" do
        model = HooksAfter.new(index: 0)
        model.insert(no_hooks: true)
        query = {index: 0}
        HooksBefore.remove(query)
        last_query.should eq query.to_bson
        HooksAfter.find_by_id!(model.id!).index.should eq 1
      end
      it "after_remove_static" do
        model = HooksAfter.new(index: 0)
        model.insert(no_hooks: true)
        query = {index: 1}
        HooksAfter.remove(query)
        last_query.should eq query.to_bson
        HooksAfter.find_by_id!(model.id!).index.should eq 1
      end
    end
  end
end
