module Lxpen
  module Patterns
    enum SlotType
      LowerWord
      UpperWord
      CapWord
      Name
      CapName
      Number
      Year
      SeqDigits
      Symbol
      SymbolSuffix
      Keyboard
      L33t
      CapL33t
      Literal
    end

    record Slot, type : SlotType, fixed_value : String? = nil

    record Pattern,
      name : String,
      slots : Array(Slot),
      frequency : Float64

    record SlotEntry, value : String, frequency : Float64
  end
end
