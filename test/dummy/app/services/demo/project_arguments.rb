# frozen_string_literal: true

module Demo
  module ProjectArguments
    module_function

    def fetch(context, name)
      bag = context.respond_to?(:arguments) ? context.arguments : context.params
      hash = bag.respond_to?(:to_unsafe_h) ? bag.to_unsafe_h : bag.to_h
      hash = hash.stringify_keys
      hash[name.to_s]
    end

    def slice(context, *names)
      names.each_with_object({}) do |name, memo|
        value = fetch(context, name)
        memo[name.to_s] = value unless value.nil?
      end
    end
  end
end
