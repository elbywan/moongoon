module Moongoon
  class Config
    @@instance : self = self.new

    def self.reset
      @@instance = self.new
    end

    def self.singleton
      @@instance
    end

    @unset_nils : Bool
    property unset_nils

    def initialize
      @unset_nils = false
    end
  end

  def self.configure
    yield Config.singleton
  end

  def self.config
    Config.singleton
  end
end
