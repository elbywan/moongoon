require "../src/moongoon"

private class IndexModel < Moongoon::Collection
  collection "index_models"

  property a : String
  property b : Int32

  index a: -1, name: "a_desc"
  index _id: 1, a: 1, options: { unique: true }
  index ({ "_id" => 1, "$**" => "text" })
  index ({ "b" => 1 }), name: "index_name", options: { "unique" => true }
end

require "./spec_helper"

describe Moongoon::Collection do
  it "should define indexes" do
    IndexModel.collection.list_indexes.each_with_index { |index, i|
      case i
      when 0
        index["name"].should eq "_id_"
        index["key"].as(BSON).to_json.should eq ({_id: 1}).to_json
      when 1
        index["name"].should eq "a_desc"
        index["key"].as(BSON).to_json.should eq ({a: -1}).to_json
      when 2
        index["name"].should eq "_id_1_a_1"
        index["key"].as(BSON).to_json.should eq ({_id: 1, a: 1}).to_json
        index["unique"].should eq true
      when 3
        index["name"].should eq "_id_1_$**_text"
        index["key"].as(BSON).to_json.should eq ({_id: 1, _fts: "text", _ftsx: 1}).to_json
      when 4
        index["name"].should eq "index_name"
        index["key"].as(BSON).to_json.should eq ({b: 1}).to_json
        index["unique"].should eq true
      end
    }
  end
end
