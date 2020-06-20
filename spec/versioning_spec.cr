require "./spec_helper.cr"

private class AutoVersionModel < Moongoon::Collection
  include Versioning

  collection "model_autoversions"
  versioning auto: true, ref_field: "original_id" { |v, o|
    self.transform(v, o)
  }

  property one : String = "One"
  property two : Int64? = nil
  property three : Int64? = nil

  def self.transform(versioned_model, original_model) : BSON
    if versioned_model.has_key? "two"
      versioned_model["three"] = original_model["two"].as(Int64) * 2_i64
    end
    versioned_model
  end
end

private class VersionModel < Moongoon::Collection
  include Versioning
  collection "model_versions"
  versioning
  property key : String = "value"
end

describe Moongoon::Traits::Database::Versioning do
  it "should version documents automatically" do
    history_collection = AutoVersionModel.history_collection
    model = AutoVersionModel.new
    model.count_versions.should eq 0

    # Insertion
    model.insert
    model.count_versions.should eq 1
    version = model.find_latest_version.not_nil!
    version.one.should eq "One"
    version.two.should be_nil
    version.three.should be_nil
    bson_version = history_collection.find_one({_id: version._id}).not_nil!
    bson_version["original_id"].should eq model._id.to_s

    # Update
    model.two = 2
    model.update
    model.count_versions.should eq 2
    version = model.find_latest_version.not_nil!
    version.one.should eq "One"
    version.two.should eq 2
    version.three.should eq 4

    # Static update
    AutoVersionModel.update({one: "One"}, {"$set": {two: 3_i64}})
    model.count_versions.should eq 3
    version = model.find_latest_version.not_nil!
    version.one.should eq "One"
    version.two.should eq 3
    version.three.should eq 6
  end

  context "methods" do
    it "#find_latest_version" do
      model = VersionModel.new.insert
      model.find_latest_version.should be_nil
      model.create_version
      model.key = "value2"
      model.update
      model.create_version
      version = model.find_latest_version.not_nil!
      version.key.should eq "value2"
    end

    it "#find_all_versions" do
      model = VersionModel.new.insert
      model.find_all_versions.should eq [] of VersionModel
      3.times { |i|
        model.key = "value#{i}"
        model.update
        model.create_version
      }
      versions = model.find_all_versions(order_by: {_id: 1})
      versions.size.should eq 3
      versions.each_with_index { |v, i|
        v.key.should eq "value#{i}"
      }
    end

    it "#count_versions" do
      model = VersionModel.new.insert
      model.count_versions.should eq 0
      3.times {
        model.create_version
      }
      model.count_versions.should eq 3
    end

    it "#create_version &block" do
      model = VersionModel.new.insert
      model.create_version { |version|
        version.key += "2"
        version
      }
      model.find_latest_version.not_nil!.key.should eq "value2"
    end

    it "#self.find_latest_version_by_id" do
      model = VersionModel.new.insert
      model.create_version
      model.key = "value2"
      model.update
      model.create_version

      version = VersionModel.find_latest_version_by_id(model.id!).not_nil!
      version.key.should eq "value2"
    end

    it "#self.find_specific_version" do
      model = VersionModel.new.insert
      version_id = model.create_version
      model.create_version
      VersionModel.find_specific_version(version_id).not_nil!.id.should eq version_id
    end

    it "#self.find_specific_versions" do
      model = VersionModel.new.insert
      version_ids = 5.times.map {
        model.create_version.not_nil!
      }.to_a
      versions = VersionModel.find_specific_versions(version_ids[2..], order_by: {_id: 1})
      versions.size.should eq 3
      versions.each_with_index { |v, i|
        v.id.should eq version_ids[i + 2]
      }
    end

    it "#self.find_all_versions" do
      model = VersionModel.new.insert
      version_ids = 5.times.map {
        model.create_version.not_nil!
      }.to_a
      versions = VersionModel.find_all_versions(model.id!, order_by: {_id: 1})
      versions.size.should eq 5
      versions.each_with_index { |v, i|
        v.id.should eq version_ids[i]
      }
    end

    it "#self.count_versions" do
      model = VersionModel.new.insert
      counter = VersionModel.count_versions(model.id!)
      5.times { model.create_version }
      VersionModel.count_versions(model.id!).should eq counter + 5
    end

    it "#self.clear_history" do
      VersionModel.history_collection.count_documents.should_not eq 0
      VersionModel.clear_history
      VersionModel.history_collection.count_documents.should eq 0
    end

    it "#self.create_version_by_id" do
      model = VersionModel.new.insert
      VersionModel.create_version_by_id(model.id!) { |version|
        version.key += "2"
        version
      }
      model.find_latest_version.not_nil!.key.should eq "value2"
    end
  end
end
