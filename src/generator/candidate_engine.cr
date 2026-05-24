require "../patterns/schema"
require "../patterns/frequency_data"

module Lxpen
  module Generator
    class CandidateEngine
      @patterns : Array(Patterns::Pattern)
      @slot_data : Hash(Patterns::SlotType, Array(Patterns::SlotEntry))

      def initialize
        @patterns = Patterns::FrequencyData::PATTERNS.sort_by { |p| -p.frequency }
        @slot_data = {} of Patterns::SlotType => Array(Patterns::SlotEntry)
        Patterns::SlotType.each do |st|
          data = Patterns::FrequencyData.get_slot_data(st)
          @slot_data[st] = data.sort_by { |e| -e.frequency } unless data.empty?
        end
      end

      def each_candidate(& : String ->) : Nil
        @patterns.each do |pattern|
          slot_values = pattern.slots.map do |slot|
            if val = slot.fixed_value
              [Patterns::SlotEntry.new(val, 1.0)]
            else
              @slot_data[slot.type]? || [] of Patterns::SlotEntry
            end
          end

          next if slot_values.any?(&.empty?)

          indices = Array.new(slot_values.size, 0)

          loop do
            candidate = String.build do |io|
              indices.each_with_index do |slot_idx, i|
                io << slot_values[i][slot_idx].value
              end
            end

            yield candidate

            carry = slot_values.size - 1
            while carry >= 0
              indices[carry] += 1
              if indices[carry] < slot_values[carry].size
                break
              else
                indices[carry] = 0
                carry -= 1
              end
            end

            break if carry < 0
          end
        end
      end

      def each_pattern_data(& : Array(Array(String)), Patterns::Pattern ->) : Nil
        @patterns.each do |pattern|
          slot_strings = [] of Array(String)
          valid = true

          pattern.slots.each do |slot|
            if val = slot.fixed_value
              slot_strings << [val]
            else
              data = @slot_data[slot.type]?
              if data && !data.empty?
                slot_strings << data.map(&.value)
              else
                valid = false
                break
              end
            end
          end

          next unless valid
          yield slot_strings, pattern
        end
      end

      def count_candidates : Int64
        total = 0_i64
        @patterns.each do |pattern|
          combo = 1_i64
          pattern.slots.each do |slot|
            if slot.fixed_value
              combo *= 1
            else
              data = @slot_data[slot.type]?
              combo *= data.size if data
            end
          end
          total += combo
        end
        total
      end
    end
  end
end
