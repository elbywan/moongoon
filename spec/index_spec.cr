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
