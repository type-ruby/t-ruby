# frozen_string_literal: true

module TRuby
  class IntersectionTypeParser
    def initialize(type_string)
      @type_string = type_string.strip
    end

    def parse
      if @type_string.include?("&")
        parse_intersection
      else
        { type: :simple, value: @type_string }
      end
    end

    private

    def parse_intersection
      members = @type_string.split("&").map { |m| m.strip }.compact

      {
        type: :intersection,
        members: members,
        has_duplicates: members.length != members.uniq.length,
        unique_members: members.uniq
      }
    end
  end
end
