class SierraMod11
  
  # Ruby port of https://github.com/NYPL-discovery/convert-2-scsb-module/blob/2b8982b9e934d58dd41c05a83c3946ba1cb1f86d/lib/parseapi.js#L175-L193
  def self.mod11 (id)
    original = id
    id = id.sub /^\.[bci]/, ''

    results = []
    multiplier = 2
    id.reverse.split('').each do |c|
      results.push(c.to_i * multiplier)
      multiplier += 1
    end

    remainder = results.reduce(:+) % 11

    # [Ruby port of Matt Miller comment]:
    # OMG THIS IS WRONG! Sierra doesn't do mod11 riggghhttttt
    # remainder = 11 - remainder

    return "#{original}0" if remainder == 11 
    return "#{original}x" if remainder == 10

    "#{original}#{remainder}"
  end
end
