# frozen_string_literal: true

module TRuby
  class UnionTypeParser
    def initialize(type_string)
      @type_string = type_string.strip
    end

    def parse
      # Check if it contains pipes (union indicator)
      if @type_string.include?("|")
        parse_union
      else
        parse_simple
      end
    end

    private

    def parse_union
      members = @type_string.split("|").map { |m| m.strip }.compact

      {
        type: :union,
        members: members,
        has_duplicates: members.length != members.uniq.length,
        unique_members: members.uniq
      }
    end

    def parse_simple
      {
        type: :simple,
        value: @type_string
      }
    end
  end
end
