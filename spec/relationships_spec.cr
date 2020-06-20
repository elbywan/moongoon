require "./spec_helper.cr"

private class ParentModel < Moongoon::Collection
  collection "parents"

  reference single_child, model: SingleChildModel, delete_cascade: true, clear_reference: true, back_reference: parent_id
  reference children, model: ChildrenModel, many: true, delete_cascade: true, clear_reference: true, back_reference: parent_id
end

private class SingleChildModel < Moongoon::Collection
  collection "single_children"

  property parent_id : String
end

private class ChildrenModel < Moongoon::Collection
  collection "children"

  property parent_id : String
end

describe Moongoon::Traits::Database::Relationships do
  it "should back reference another collection" do
    parent = ParentModel.new.insert

    parent.single_child.should be_nil
    single_child = SingleChildModel.new(parent_id: parent.id!).insert
    parent = parent.fetch
    parent.single_child.should eq single_child._id.to_s

    parent.children.should eq [] of String
    children = 3.times.map {
      ChildrenModel.new(parent_id: parent.id!).insert
    }.to_a
    parent = parent.fetch
    parent.children.size.should eq 3
    parent.children.each_with_index { |id, i|
      id.should eq children[i].id!
    }
  end

  context "should perform cascading deletes when the reference is" do
    it "single" do
      parent = ParentModel.new.insert
      parent.single_child.should be_nil
      single_child = SingleChildModel.new(parent_id: parent.id!).insert

      parent.remove

      expect_raises(Moongoon::Error::NotFound) {
        single_child.fetch
      }
    end

    it "single with a static deletion" do
      parent = ParentModel.new.insert
      parent.single_child.should be_nil
      single_child = SingleChildModel.new(parent_id: parent.id!).insert

      ParentModel.remove_by_id parent.id!

      expect_raises(Moongoon::Error::NotFound) {
        single_child.fetch
      }
    end

    it "many" do
      parent = ParentModel.new.insert
      children = 3.times.map {
        ChildrenModel.new(parent_id: parent.id!).insert
      }.to_a

      parent.remove

      children.each { |child|
        expect_raises(Moongoon::Error::NotFound) {
          child.fetch
        }
      }
    end

    it "many with a static deletion" do
      parent = ParentModel.new.insert
      children = 3.times.map {
        ChildrenModel.new(parent_id: parent.id!).insert
      }.to_a

      ParentModel.remove_by_id parent.id!

      children.each { |child|
        expect_raises(Moongoon::Error::NotFound) {
          child.fetch
        }
      }
    end
  end

  context "should clear reference on target deletion when the reference is" do
    it "single" do
      parent = ParentModel.new.insert
      single_child = SingleChildModel.new(parent_id: parent.id!).insert
      single_child.remove
      parent.fetch.single_child.should be_nil
    end

    it "single with a static deletion" do
      parent = ParentModel.new.insert
      single_child = SingleChildModel.new(parent_id: parent.id!).insert
      SingleChildModel.remove_by_id single_child.id!
      parent.fetch.single_child.should be_nil
    end

    it "many" do
      parent = ParentModel.new.insert
      children = 3.times.map {
        ChildrenModel.new(parent_id: parent.id!).insert
      }.to_a

      parent.fetch.children.size.should eq 3

      2.downto 0 { |i|
        children[i].remove
        parent.fetch.children.size.should eq i
      }
    end

    it "many with a static deletion" do
      parent = ParentModel.new.insert
      children = 3.times.map {
        ChildrenModel.new(parent_id: parent.id!).insert
      }.to_a

      parent.fetch.children.size.should eq 3
      ChildrenModel.remove_by_ids children.map(&.id!)
      parent.fetch.children.size.should eq 0
    end
  end
end
