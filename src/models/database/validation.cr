# Seems odd to bury this stuff all the way down to Moongoon::Traits::Database::Validators... but would that be cleaner tho?
# folks will have to check the type of validation problems so it seems mean to make them .is_a?(Moongoon::Traits::Database::Validators::Error)
# will also have to `problems << Mongoon::Validation::Error("Stuff")`
module Moongoon::Validation
  # Can be overridden to add special cases for odd field names
  def self.format_field(field : Symbol)
    field.to_s.capitalize.gsub("_", " ")
  end

  # Can be overridden to add i18n, shortcut expansion (e.g. :caffeinated to "must be full of caffeine"), custom formatters etc
  def self.format_message(message : String | Symbol)
    message.to_s
  end

  # Can be overridden to add periods or other formatting to the final generated message
  # (whether it was constructed from field/message pairs or just a single message).
  def self.format_problem(message : String)
    message
  end

  abstract struct Problem
    property message : String
    property field : Symbol? = nil

    # you should probably use strings for messages unless you're doing expansion in format_message.
    def initialize(message : String | Symbol, @field = nil)
      @message = message.to_s
    end

    def to_s
      if field_name = @field
        ::Moongoon::Validation.format_problem "#{::Moongoon::Validation.format_field(field_name)} #{::Moongoon::Validation.format_message(@message)}"
      else
        ::Moongoon::Validation.format_problem ::Moongoon::Validation.format_message(@message)
      end
    end
  end

  abstract struct Error < Problem
  end

  struct BasicError < Error
  end

  abstract struct Warning < Problem
  end

  struct BasicWarning < Warning
  end
end

# :nodoc:
module Moongoon::Traits::Database::Validators
  macro included
  	{% verbatim do %}
  		macro inherited
  			{% unless @type.abstract? %}
	  			BUILT_IN_VALIDATORS = Hash(Symbol, NamedTuple(message: String, callback: BuiltInCallback)){
				    :present => {
				      message:  "must be present",
				      callback: ->(model : self, field : Symbol) {
				        if val = model.to_tuple[field]
				          if sval = val.as?(String)
				            return !sval.blank?
				          else
				            return true
				          end
				        end
				        false
				      },
				    },
				    :positive => {
				      message:  "must be greater than zero",
				      callback: ->(model : self, field : Symbol) {
				        case value = model.to_tuple[field]
				        when Int, Float
				          return value > 0
				        when String
				          if i = value.to_i?
				            return i > 0
				          elsif f = value.to_f?
				            return f > 0
				          end
				        end

				        false
				      },
				    },
				    :negative => {
				      message:  "must be less than zero",
				      callback: ->(model : self, field : Symbol) {
				        case value = model.to_tuple[field]
				        when Int, Float
				          return value < 0
				        when String
				          if i = value.to_i?
				            return i < 0
				          elsif f = value.to_f?
				            return f < 0
				          end
				        end

				        false
				      },
				    },
				  }

			  	alias BuiltInCallback = Proc(self, Symbol, Bool)

				  # :nodoc:
				  # return values
				  # nil: creates a validation error and continues to run the chain
				  # false: creates a validation error and stops the chain
				  # true: keeps running validations
				  alias SimpleCallback = Proc(self, Bool?)

				  # :nodoc:
				  # you can add as many errors/warnings as you like (or even strip off earlier problems) from the problems array
				  # return values
				  # nil: keeps running validations
				  # false: stops the chain
				  # true: keeps running validations
				  alias ComplexCallback = Proc(self, Array(::Moongoon::Validation::Problem), Bool?)

				  @@validators = Array({field: Symbol?, message: String | Symbol?, callback: BuiltInCallback | SimpleCallback | ComplexCallback}).new

					@[JSON::Field(ignore: true)]
					@[BSON::Field(ignore: true)]
					getter validation_problems = [] of ::Moongoon::Validation::Problem

					#built-in validators ala `validate :username, :present`
					def self.validate(field : Symbol, validator : Symbol)
						if built_in = BUILT_IN_VALIDATORS[validator]
							@@validators << {field: field, message: built_in[:message], callback: built_in[:callback]}
			      else
			        raise "Invalid built-in validation: #{validator}"
			      end
					end

					def self.validate(field : Symbol, message : String | Symbol, &cb : SimpleCallback)
						@@validators << {field: field, message: message, callback: cb}
					end

					def self.validate(message : String, &cb : SimpleCallback)
						@@validators << {field: nil, message: message, callback: cb}
					end

					def self.validate(&cb : ComplexCallback)
						@@validators << {field: nil, message: nil, callback: cb}
					end

					def valid?
						self.force_valid
						@@validators.each do |validator|
							callback = validator[:callback]
							case callback
							when BuiltInCallback
								if callback.call(self.as(self), validator[:field].not_nil!)
									next
								else
									@validation_problems << ::Moongoon::Validation::BasicError.new(message: validator[:message].not_nil!, field: validator[:field])
								end
							when SimpleCallback
								case callback.call(self.as(self))
								when true
									next
								when false
									@validation_problems << ::Moongoon::Validation::BasicError.new(message: validator[:message].not_nil!, field: validator[:field])
									break
								when nil
									@validation_problems << ::Moongoon::Validation::BasicError.new(message: validator[:message].not_nil!, field: validator[:field])
									#don't break
								end
							when ComplexCallback
								if callback.call(self.as(self), self.validation_problems) == false
									break
								end
							end
						end
						self.validation_errors.empty?	#warnings are ok
					end

					def valid!
						raise @validation_errors.first unless self.valid?
						true
					end

					def force_valid
						@validation_problems.clear
					end

					def validation_errors
						@validation_problems.select(&.is_a?(::Moongoon::Validation::Error))
					end

					def validation_error_messages
						self.validation_errors.map(&.to_s)
					end

					def validation_warnings
						@validation_problems.select(&.is_a?(::Moongoon::Validation::Warning))
					end

					def validation_warning_messages
						self.validation_warnings.map(&.to_s)
					end

					def save
			      if self.valid?
			        if self.persisted?
			          self.update
			        else
			          self.insert
			        end
			        true
			      else
			        false
			      end
			    end
				{% end %}
			end
		{% end %}
	end
end
