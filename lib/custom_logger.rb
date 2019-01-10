
class CustomLogger
  attr_accessor :level, :message, :level_code, :error_codename, :timestamp, :object

  VALID_LEVELS = {
    'DEBUG' => 7,
    'INFO' => 6,
    'NOTICE' => 5,
    'WARNING' => 4,
    'ERROR' => 3,
    'CRITICAL' => 2,
    'ALERT' => 1,
    'EMERGENCY' => 0
  }

  # Set active LOG_LEVEL based on env. Default 'info'
  LOG_LEVEL = ENV['LOG_LEVEL'].nil? || ! VALID_LEVELS.keys.include?(ENV['LOG_LEVEL'].upcase) ? 'info' : ENV['LOG_LEVEL']

  # Creates a customer logger given a hash.
  # Right now, message and level are required, and level must be included in the keys of VALID_LEVELS
  def initialize(hash)
    hash.keys.each do |key|
      m = "#{key}="
      self.send( m, hash[key] ) if self.respond_to?( m )
    end

    self.timestamp = Time.now if self.timestamp == nil
  end

  # Returns array where first element is true or false, depending on validity of log message.
  # Second value reports what's missing.
  def validity_report
    return_array = [true, ""]

    if self.level == nil || VALID_LEVELS.keys.include?(self.level.upcase) == false
      return_array[0] = false
      return_array[1] += "Invalid level. "
    end

    if self.level == nil || self.message == nil || self.timestamp == nil
      return_array[0] = false
      return_array[1] += "Missing required fields: "
      return_array_missing_fields = []
      return_array_missing_fields << "level" if self.level == nil || VALID_LEVELS.keys.include?(self.level.upcase) == false
      return_array_missing_fields << "message" if self.message == nil
      return_array_missing_fields << "timestamp" if self.timestamp == nil
      return_array[1] += return_array_missing_fields.join(', ')
    end

    return_array
  end

  # Returns the boolean value of the validity report, being true or false.
  def valid?
    validity_report[0]
  end

  # Formats the values of level and timestamp and auto-generates level code based on level.
  def reformat_fields
    self.level = self.level.upcase
    self.level_code = VALID_LEVELS[self.level]
    self.timestamp = self.timestamp
  end

  # If valid, log_message will log JSON to Cloudwatch logs and return 'true', else will return 'false'.
  def log_message
    return valid? if valid? == false
    formatted_message = self.reformat_fields
    json_message = JSON.generate(level: self.level,
                                 message: self.message,
                                 object: self.object,
                                 levelCode: self.level_code,
                                 errorCodename: self.error_codename,
                                 timestamp: self.timestamp)

    # NOOP if active log_level < level_code
    return nil if VALID_LEVELS[LOG_LEVEL.upcase] < self.level_code

    puts json_message
    return true
  end

  # Convenience statics:

  def self.info (message, obj)
    self.log 'info', message, obj
  end

  def self.debug (message, obj)
    self.log 'debug', message, obj
  end

  def self.error (message, obj)
    self.log 'error', message, obj
  end

  def self.log (level, message, obj)
    log_obj = {
      'level' => level,
      'message' => message,
      'object' => obj
    }
    self.new(log_obj).log_message
  end
end
