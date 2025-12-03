require "yaml"

def pretty_print_yaml(value : YAML::Any, indent = 0) : String
  case raw = value.raw
  when Nil
    "null"
  when Bool
    raw.to_s
  when Int64, Float64
    raw.to_s
  when String
    if raw.includes?("\n") || raw.includes?(":") || raw.includes?(" ") # simple scalar check
      "---\n#{raw.strip}\n..."
    else
      raw
    end
  when Time
    raw.to_s
  when Array
    arr = raw.as(Array(YAML::Any))
    if arr.empty?
      "[]"
    else
      output = "-\n"
      arr.each do |item|
        item_str = pretty_print_yaml(item, indent + 1)
        output += "  " * indent + "- #{item_str.sub(/^\s*- /, "")}\n"
      end
      output.chomp
    end
  when Hash
    h = raw.as(Hash(YAML::Any, YAML::Any))
    if h.empty?
      "{}"
    else
      output = ""
      h.each do |k, v|
        k_str = k.as_s
        v_str = pretty_print_yaml(v, indent + 1)
        if v_str.starts_with?("-")
          output += "  " * indent + "#{k_str}:\n#{v_str}\n"
        else
          output += "  " * indent + "#{k_str}: #{v_str}\n"
        end
      end
      output.chomp
    end
  else
    raw.to_s
  end
end

def get_value(current : YAML::Any, path : String) : YAML::Any
  parts = path.split(".").reject(&.empty?)
  parts.each do |part|
    if part.ends_with?("]") && part.includes?("[")
      key = part[0, part.index('[').not_nil!]
      index_str = part[part.index('[').not_nil! + 1..-2]
      index = index_str.to_i?
      if index.nil?
        return YAML::Any.new(nil)
      end
      if !key.empty?
        if current.raw.is_a?(Hash)
          current = current.as_h[YAML::Any.new(key)]? || YAML::Any.new(nil)
        else
          return YAML::Any.new(nil)
        end
      end
      if current.raw.is_a?(Array)
        if index < current.as_a.size
          current = current.as_a[index]
        else
          return YAML::Any.new(nil)
        end
      else
        return YAML::Any.new(nil)
      end
    else
      if current.raw.is_a?(Hash)
        current = current.as_h[YAML::Any.new(part)]? || YAML::Any.new(nil)
      else
        return YAML::Any.new(nil)
      end
    end
  end
  current
end

def main
  args = ARGV
  if args.size < 2
    puts "Usage:"
    puts "  yaml pretty <file or ->"
    puts "  yaml get <path> <file or ->"
    puts "Path example: .key.subkey[0]"
    exit 0
  end

  command = args.shift
  input = args.last
  data = if input == "-"
           STDIN.gets_to_end
         else
           File.read(input)
         end

  begin
    value = YAML.parse(data)
  rescue ex
    puts "Error parsing YAML: #{ex.message}"
    exit 1
  end

  case command
  when "pretty"
    puts pretty_print_yaml(value)
  when "get"
    if args.size < 2
      puts "Usage: yaml get <path> <file or ->"
      exit 0
    end
    path = args[0]
    result = get_value(value, path)
    puts pretty_print_yaml(result)
  else
    puts "Unknown command: #{command}"
  end
end

main if __FILE__ == PROGRAM_NAME
