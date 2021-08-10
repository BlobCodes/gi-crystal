require "yaml"

module Generator
  class NamespaceConfig
    getter ignore = Set(String).new
    getter includes = Array(Path).new

    def initialize
    end

    def initialize(any : Hash, yaml_dir : String)
      load_ignore_list(any)
      load_include_list(any, yaml_dir)
    end

    private def load_ignore_list(any)
      ignore = any["ignore"]?
      return if ignore.nil?

      list = ignore.as_a?
      raise Error.new("Ignore key must be a string list.") if list.nil?

      list.each do |item|
        str_item = item.as_s?
        raise Error.new("Ignore key must be a string list.") if str_item.nil?
        Log.warn { "Duplicated item on ignore list: #{str_item}" } if @ignore.includes?(str_item)
        @ignore << str_item
      end
    end

    private def load_include_list(any, yaml_dir)
      includes = any["include"]?
      return if includes.nil?

      include_list = includes.as_a?
      raise Error.new("Ignore key must be a string list.") if include_list.nil?

      include_list.each do |file|
        @includes << Path.new(File.join(yaml_dir, file.as_s)).expand
      end
    end

    def ignore?(name : String) : Bool
      @ignore.includes?(name)
    end
  end

  class Config
    class_property search_paths = [Path.new(Dir.current)]
    @@configs = Hash(String, NamespaceConfig).new

    def self.load(namespace : String) : NamespaceConfig
      @@configs[namespace] ||= begin
        filename = "#{namespace.underscore}.yml"
        config = load_yaml(filename)
        if config.nil?
          Log.notice do
            "No valid configuration found for #{namespace} (#{filename}), " \
            "looked at #{Config.search_paths.map(&.expand).join(", ")}."
          end
          NamespaceConfig.new
        else
          config
        end
      end
    end

    private def self.load_yaml(filename : String) : NamespaceConfig?
      filepath = find_in_search_paths(filename)
      return if filepath.nil?

      Log.notice { "Loading #{filepath}" }
      any_hash = YAML.parse(File.read(filepath)).as_h?
      if any_hash.nil?
        Log.warn { "#{filepath} is blank!" }
        NamespaceConfig.new
      else
        NamespaceConfig.new(any_hash, filepath.dirname)
      end
    end

    def self.for(namespace : String) : NamespaceConfig
      load(namespace)
    end

    private def self.find_in_search_paths(file : String) : Path?
      @@search_paths.each do |path|
        path = File.join(path, file)
        return Path.new(path).expand if File.exists?(path)
      end
      nil
    end
  end
end
