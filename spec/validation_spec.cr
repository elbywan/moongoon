require "./spec_helper"

private abstract class ValidationsModel < Moongoon::Collection
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

private class NormalModel < ValidationsModel
end

private class PresenceModel < ValidationsModel
  validate :humor, :present
end

private class PositiveNegativeModel < ValidationsModel
  validate :age, :positive
  validate :humor, :negative
end

private class SimpleValidatorModel < ValidationsModel
  validate :age, "must be 7" do |model|
    model.age == 7
  end

  validate :humor, "must be 8" do |model|
    model.humor == 8
  end
end

private class SimpleValidatorMultipleModel < ValidationsModel
  validate :age, "must be 7" do |model|
    model.age == 7 || nil # nil to fall through to the next one
  end

  validate :humor, "must be 8" do |model|
    model.humor == 8
  end
end

private class ComplexValidatorModel < ValidationsModel
  validate do |model, problems|
    unless (80...90).includes?(model.age)
      problems << Moongoon::Validation::BasicError.new("You must be an octogenarian to use this feature")
      false
    end
  end

  validate do |model, problems|
    unless model.humor == 10
      problems << Moongoon::Validation::BasicError.new("I say, chaps, humor must be a 10")
      false
    end
  end
end

private class ComplexValidatorMultipleModel < ValidationsModel
  validate do |model, problems|
    unless (80...90).includes?(model.age)
      problems << Moongoon::Validation::BasicError.new("You must be an octogenarian to use this feature")
    end
    nil
  end

  validate do |model, problems|
    unless model.humor == 2
      problems << Moongoon::Validation::BasicError.new("I say, chaps, humor must be a 2")
    end
    nil
  end
end

private class ComplexValidatorWarningModel < ValidationsModel
  validate do |model, problems|
    unless (80...90).includes?(model.age)
      problems << Moongoon::Validation::BasicError.new("You must be an octogenarian to use this feature")
    end
    nil
  end

  validate do |model, problems|
    unless model.humor == 2
      problems << Moongoon::Validation::BasicError.new("I say, chaps, humor must be a 2")
    end
    nil
  end

  validate do |model, problems|
    if (model.humor || 0) < 5
      problems << Moongoon::Validation::BasicWarning.new("This person has very little sense of humor... save but send their mom an email")
    end
    nil
  end
end

private class ComplexValidatorCustomProblemsModel < ValidationsModel
  validate do |model, problems|
    if model.age < 30
      problems << MySpecialError.new("You are too young to run for President")
    end
    nil
  end

  validate do |model, problems|
    if model.humor > 50
      problems << MySpecialError.new("You are too funny to run for President")
    end
    nil
  end

  validate do |model, problems|
    if (model.humor || 0) < 5
      problems << MySpecialWarning.new("WARNING: You have almost no sense of humor")
    end
    nil
  end
end

struct MySpecialError < Moongoon::Validation::Error
end

struct MySpecialWarning < Moongoon::Validation::Warning
end

describe Moongoon::Validation do
  raw_models = [
    {name: "one", age: 10, humor: nil},
    {name: "two", age: 10, humor: 0},
    {name: "three", age: 20, humor: 15},
  ]

  before_each {
    NormalModel.clear # they all share the same collection so just call it once
    Moongoon::Config.reset
  }

  describe "built_in validators" do
    it "save models without validations" do
      models = NormalModel.insert_models raw_models
      model = NormalModel.find_one!({age: 20})
      model.humor = nil
      model.save.should be_true
    end

    it ":present" do
      NormalModel.insert_models raw_models

      model = PresenceModel.find_one!({age: 20})
      model.humor = nil
      model.save.should be_false
      model.validation_error_messages.size.should eq 1
      model.validation_error_messages.first.should eq "Humor must be present"
      model.humor = 11
      model.save.should be_true
    end

    it ":positive" do
      NormalModel.insert_models raw_models

      model = PositiveNegativeModel.find_one!({name: "one"})
      model.humor = -10
      model.save.should be_true
      model.age = 0
      model.save.should be_false
      model.validation_error_messages.size.should eq 1
      model.validation_error_messages.first.should eq "Age must be greater than zero"
      model.age = 11
      model.save.should be_true
    end

    it ":negative" do
      NormalModel.insert_models raw_models

      model = PositiveNegativeModel.find_one!({name: "one"})
      model.save.should be_false
      model.validation_error_messages.size.should eq 1
      model.validation_error_messages.first.should eq "Humor must be less than zero"
      model.humor = -11
      model.save.should be_true
    end
  end

  describe "simple validators" do
    it "single field with message" do
      NormalModel.insert_models raw_models

      model = SimpleValidatorModel.find_one!({name: "one"})
      model.save.should be_false
      model.validation_error_messages.size.should eq 1
      model.validation_error_messages.first.should eq "Age must be 7"
      model.age = 7
      model.save.should be_false
      model.validation_error_messages.size.should eq 1
      model.validation_error_messages.first.should eq "Humor must be 8"
      model.humor = 8
      model.save.should be_true
    end

    it "single field with message and multiple errors" do
      NormalModel.insert_models raw_models

      model = SimpleValidatorMultipleModel.find_one!({name: "one"})
      model.save.should be_false
      model.validation_error_messages.size.should eq 2
      model.validation_error_messages.first.should eq "Age must be 7"
      model.validation_error_messages.last.should eq "Humor must be 8"
      model.age = 7
      model.humor = 8
      model.save.should be_true
    end
  end

  describe "complex validators" do
    it "allow multiple errors which stop validation" do
      NormalModel.insert_models raw_models

      model = ComplexValidatorModel.find_one!({name: "one"})
      model.save.should be_false
      model.validation_error_messages.size.should eq 1
      model.validation_error_messages.first.should eq "You must be an octogenarian to use this feature"
      model.age = 85
      model.save.should be_false
      model.validation_error_messages.first.should eq "I say, chaps, humor must be a 10"
      model.humor = 10
      model.save.should be_true
    end

    it "allow multiple errors which continue validation" do
      NormalModel.insert_models raw_models

      model = ComplexValidatorMultipleModel.find_one!({name: "one"})
      model.save.should be_false
      model.validation_error_messages.size.should eq 2
      model.validation_error_messages.first.should eq "You must be an octogenarian to use this feature"
      model.validation_error_messages.last.should eq "I say, chaps, humor must be a 2"
      model.age = 85
      model.humor = 2
      model.save.should be_true
    end

    it "allow warnings which do not prevent saving" do
      NormalModel.insert_models raw_models

      model = ComplexValidatorWarningModel.find_one!({name: "three"})
      model.age = 85
      model.humor = 2
      model.save.should be_true
      model.validation_error_messages.size.should eq 0
      model.validation_warning_messages.size.should eq 1
      model.validation_warning_messages.first.should eq "This person has very little sense of humor... save but send their mom an email"
    end

    it "allow custom errors and warnings" do
      NormalModel.insert_models raw_models

      model = ComplexValidatorWarningModel.find_one!({name: "two"})
      model.save.should be_false

      model.validation_error_messages.size.should eq 1
      model.validation_warning_messages.first.should eq "You are too young to run for President"
      model.validation_errors.first.should be_a(MySpecialError)

      model.validation_warning_messages.size.should eq 1
      model.validation_warning_messages.first.should eq "WARNING: You have almost no sense of humor"
      model.validation_warnings.first.should be_a(MySpecialWarning)
    end
  end
end
